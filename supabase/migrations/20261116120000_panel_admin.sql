-- El panel de administración: observaciones privadas, citas creadas y
-- editadas por la estética, y las consultas que alimentan las pestañas.
--
-- Las reglas de precio, duración y solape siguen viviendo en Postgres. La
-- pantalla solo manda ids de servicio y un instante; nunca un total.

-- ===========================================================================
-- Observaciones privadas
-- ===========================================================================

create table public.observaciones (
  id uuid primary key default gen_random_uuid(),
  cliente_id uuid not null references public.perfiles (id) on delete cascade,
  autor_id uuid not null references auth.users (id) on delete cascade,
  texto text not null check (length(btrim(texto)) > 0),
  creada_en timestamptz not null default now()
);

create index observaciones_por_cliente on public.observaciones (cliente_id);

alter table public.observaciones enable row level security;

-- No hay política para clientes: no las leen ni las escriben. El autor se
-- fija a quien las crea para que quede registro de quién las anotó.
create policy "la estética ve las observaciones"
  on public.observaciones for select
  to authenticated
  using (es_admin());

create policy "la estética crea observaciones"
  on public.observaciones for insert
  to authenticated
  with check (es_admin() and autor_id = (select auth.uid()));

create policy "la estética edita observaciones"
  on public.observaciones for update
  to authenticated
  using (es_admin())
  with check (es_admin());

create policy "la estética borra observaciones"
  on public.observaciones for delete
  to authenticated
  using (es_admin());

-- ===========================================================================
-- Crear una cita para cualquier cliente
-- ===========================================================================
--
-- Función interna. Las dos públicas la envuelven: una toma el cliente de la
-- sesión y la otra recibe el cliente elegido por la estética. Así la
-- validación de servicios, horario, cierre y precio se escribe una vez.

create or replace function public.crear_cita_para(
  p_cliente_id uuid,
  p_mascota_id uuid,
  p_empieza timestamptz,
  p_servicios text[]
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pedidos int := coalesce(array_length(p_servicios, 1), 0);
  v_encontrados int;
  v_principales int;
  v_minutos int;
  v_total int;
  v_local timestamp;
  v_cita uuid;
begin
  if p_cliente_id is null or not exists (
    select 1 from public.perfiles where id = p_cliente_id
  ) then
    raise exception 'Ese cliente no existe'
      using errcode = '42501';
  end if;

  if p_mascota_id is not null and not exists (
    select 1 from public.mascotas
    where id = p_mascota_id and dueno_id = p_cliente_id
  ) then
    raise exception 'Esa mascota no está a nombre del cliente'
      using errcode = '42501';
  end if;

  select count(*),
         count(*) filter (where not es_extra),
         coalesce(sum(minutos), 0),
         coalesce(sum(precio_cop), 0)
    into v_encontrados, v_principales, v_minutos, v_total
  from public.servicios
  where id = any (p_servicios) and activo;

  if v_encontrados <> v_pedidos then
    raise exception 'Alguno de esos servicios ya no está disponible';
  end if;

  if v_principales <> 1 then
    raise exception 'La cita necesita exactamente un servicio principal';
  end if;

  v_local := p_empieza at time zone 'America/Bogota';

  if exists (select 1 from public.cierres where fecha = v_local::date) then
    raise exception 'Ese día la estética está cerrada';
  end if;

  if not exists (
    select 1 from public.horario_atencion h
    where h.dia_semana = extract(isodow from v_local)
      and v_local::time >= h.abre
      and (v_local + make_interval(mins => v_minutos))::time <= h.cierra
  ) then
    raise exception 'A esa hora la cita no cabe en el horario de atención';
  end if;

  insert into public.citas (cliente_id, mascota_id, empieza, minutos, total_cop)
  values (p_cliente_id, p_mascota_id, p_empieza, v_minutos, v_total)
  returning id into v_cita;

  insert into public.cita_servicios (cita_id, servicio_id, precio_cop, minutos)
  select v_cita, s.id, s.precio_cop, s.minutos
  from public.servicios s
  where s.id = any (p_servicios);

  return v_cita;
end;
$$;

revoke all on function public.crear_cita_para(uuid, uuid, timestamptz, text[])
  from public;

-- La reserva del cliente, ahora sobre la función compartida.
create or replace function public.reservar_cita(
  p_mascota_id uuid,
  p_empieza timestamptz,
  p_servicios text[]
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cliente uuid := (select auth.uid());
begin
  if v_cliente is null then
    raise exception 'Hay que iniciar sesión para reservar'
      using errcode = '28000';
  end if;

  return public.crear_cita_para(
    v_cliente, p_mascota_id, p_empieza, p_servicios
  );
exception
  when exclusion_violation then
    raise exception 'Ese horario lo acaban de tomar, elige otro'
      using errcode = 'exclusion_violation';
end;
$$;

-- La reserva de la estética: el cliente lo elige ella, no la sesión.
create or replace function public.reservar_cita_admin(
  p_cliente_id uuid,
  p_mascota_id uuid,
  p_empieza timestamptz,
  p_servicios text[]
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.es_admin() then
    raise exception 'Solo la estética puede crear citas para un cliente'
      using errcode = '42501';
  end if;

  return public.crear_cita_para(
    p_cliente_id, p_mascota_id, p_empieza, p_servicios
  );
exception
  when exclusion_violation then
    raise exception 'Ese horario ya está ocupado, elige otro'
      using errcode = 'exclusion_violation';
end;
$$;

revoke all on function public.reservar_cita_admin(uuid, uuid, timestamptz, text[])
  from public;
grant execute on function public.reservar_cita_admin(uuid, uuid, timestamptz, text[])
  to authenticated;

-- ===========================================================================
-- Editar una cita desde la estética
-- ===========================================================================

create or replace function public.editar_cita_admin(
  p_cita_id uuid,
  p_empieza timestamptz,
  p_mascota_id uuid,
  p_servicios text[],
  p_estado text,
  p_notas text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cliente uuid;
  v_pedidos int := coalesce(array_length(p_servicios, 1), 0);
  v_encontrados int;
  v_principales int;
  v_minutos int;
  v_total int;
  v_local timestamp;
begin
  if not public.es_admin() then
    raise exception 'Solo la estética puede editar citas'
      using errcode = '42501';
  end if;

  select cliente_id into v_cliente
  from public.citas where id = p_cita_id;

  if v_cliente is null then
    raise exception 'Esa cita no existe'
      using errcode = '42501';
  end if;

  if p_estado not in ('reservada', 'cumplida', 'cancelada', 'no_asistio') then
    raise exception 'Estado de cita desconocido: %', p_estado;
  end if;

  if p_mascota_id is not null and not exists (
    select 1 from public.mascotas
    where id = p_mascota_id and dueno_id = v_cliente
  ) then
    raise exception 'Esa mascota no está a nombre del cliente'
      using errcode = '42501';
  end if;

  select count(*),
         count(*) filter (where not es_extra),
         coalesce(sum(minutos), 0),
         coalesce(sum(precio_cop), 0)
    into v_encontrados, v_principales, v_minutos, v_total
  from public.servicios
  where id = any (p_servicios) and activo;

  if v_encontrados <> v_pedidos then
    raise exception 'Alguno de esos servicios ya no está disponible';
  end if;

  if v_principales <> 1 then
    raise exception 'La cita necesita exactamente un servicio principal';
  end if;

  v_local := p_empieza at time zone 'America/Bogota';

  if exists (select 1 from public.cierres where fecha = v_local::date) then
    raise exception 'Ese día la estética está cerrada';
  end if;

  if not exists (
    select 1 from public.horario_atencion h
    where h.dia_semana = extract(isodow from v_local)
      and v_local::time >= h.abre
      and (v_local + make_interval(mins => v_minutos))::time <= h.cierra
  ) then
    raise exception 'A esa hora la cita no cabe en el horario de atención';
  end if;

  update public.citas set
    empieza = p_empieza,
    mascota_id = p_mascota_id,
    minutos = v_minutos,
    total_cop = v_total,
    estado = p_estado,
    notas_estilista = p_notas
  where id = p_cita_id;

  delete from public.cita_servicios where cita_id = p_cita_id;

  insert into public.cita_servicios (cita_id, servicio_id, precio_cop, minutos)
  select p_cita_id, s.id, s.precio_cop, s.minutos
  from public.servicios s
  where s.id = any (p_servicios);
exception
  when exclusion_violation then
    raise exception 'Ese horario ya está ocupado, elige otro'
      using errcode = 'exclusion_violation';
end;
$$;

revoke all on function public.editar_cita_admin(
  uuid, timestamptz, uuid, text[], text, text
) from public;
grant execute on function public.editar_cita_admin(
  uuid, timestamptz, uuid, text[], text, text
) to authenticated;

-- ===========================================================================
-- Consultas del panel
-- ===========================================================================

-- El directorio ya sale ordenado y sin cuentas administradoras. Con
-- `security definer` la estética ve lo mismo que le dejan las políticas,
-- pero sin tener que leer `admins`, que sigue cerrada al cliente.
create or replace function public.directorio_clientes()
returns table (id uuid, nombre text, telefono text, citas bigint)
language sql
security definer
set search_path = public
stable
as $$
  select p.id,
         p.nombre,
         p.telefono,
         count(c.id) as citas
  from public.perfiles p
  left join public.citas c on c.cliente_id = p.id
  where public.es_admin()
    and not exists (select 1 from public.admins a where a.id = p.id)
  group by p.id, p.nombre, p.telefono
  order by coalesce(nullif(btrim(p.nombre), ''), 'zzzz'), p.telefono;
$$;

revoke all on function public.directorio_clientes() from public;
grant execute on function public.directorio_clientes() to authenticated;

-- Clientes nuevos del mes, sin contar administradores. La fecha de corte
-- se calcula en el reloj de Bogotá, no en el del servidor.
create or replace function public.clientes_nuevos_mes()
returns int
language sql
security definer
set search_path = public
stable
as $$
  select count(*)::int
  from public.perfiles p
  where public.es_admin()
    and not exists (select 1 from public.admins a where a.id = p.id)
    and p.creado_en >= (
      date_trunc('month', now() at time zone 'America/Bogota')
        at time zone 'America/Bogota'
    );
$$;

revoke all on function public.clientes_nuevos_mes() from public;
grant execute on function public.clientes_nuevos_mes() to authenticated;
