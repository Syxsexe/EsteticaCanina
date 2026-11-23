-- Eliminar un cliente desde el panel, anonimizándolo.
--
-- El perfil no se borra: sus citas lo referencian con `on delete restrict`, y
-- los ingresos y estadísticas de meses pasados dependen de esas citas. Lo que
-- se borra es lo que identifica a la persona. Las citas pasadas se quedan con
-- su importe y su estado, a nombre de "Cliente eliminado".

-- Nulo en los perfiles activos. Con valor, el cliente fue eliminado.
alter table public.perfiles
  add column if not exists eliminado_en timestamptz;

-- ===========================================================================
-- La eliminación
-- ===========================================================================

create or replace function public.eliminar_cliente_admin(p_cliente_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.es_admin() then
    raise exception 'Solo la estética puede eliminar clientes'
      using errcode = '42501';
  end if;

  if exists (select 1 from public.admins where id = p_cliente_id) then
    raise exception 'Una cuenta administradora no se elimina desde aquí'
      using errcode = '42501';
  end if;

  if not exists (
    select 1 from public.perfiles
    where id = p_cliente_id and eliminado_en is null
  ) then
    raise exception 'Ese cliente no existe o ya fue eliminado'
      using errcode = 'P0002';
  end if;

  -- Las futuras que seguían en pie se cancelan. `sin_solapes` solo mira las
  -- reservadas y cumplidas, así que su horario queda libre para otros.
  update public.citas
  set estado = 'cancelada'
  where cliente_id = p_cliente_id
    and estado = 'reservada'
    and empieza > now();

  -- La nota de la estilista puede tener datos personales. El importe, los
  -- servicios y el estado se quedan: son las cifras del negocio.
  update public.citas
  set notas_estilista = null
  where cliente_id = p_cliente_id;

  delete from public.observaciones where cliente_id = p_cliente_id;

  -- `notas_mascota` cae en cascada y `citas.mascota_id` queda nulo
  -- (`on delete set null`).
  delete from public.mascotas where dueno_id = p_cliente_id;

  -- Sin celular, `reservar_cita_por_celular` ya no lo encuentra: si esa
  -- persona vuelve, entra como cliente nueva. `creado_en` no se toca, así que
  -- los clientes nuevos de su mes siguen contándolo.
  update public.perfiles
  set nombre = null,
      telefono = null,
      eliminado_en = now()
  where id = p_cliente_id;
end;
$$;

-- Supabase da `execute` a `anon` y `authenticated` por separado: hay que
-- quitárselo a `anon` de forma explícita.
revoke all on function public.eliminar_cliente_admin(uuid) from public, anon;
grant execute on function public.eliminar_cliente_admin(uuid) to authenticated;

-- ===========================================================================
-- Fuera de la lista de Clientes y de la búsqueda del formulario de cita
-- ===========================================================================

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
    and p.eliminado_en is null
    and not exists (select 1 from public.admins a where a.id = p.id)
  group by p.id, p.nombre, p.telefono
  order by coalesce(nullif(btrim(p.nombre), ''), 'zzzz'), p.telefono;
$$;
