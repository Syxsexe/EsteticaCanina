-- El cliente se identifica por su celular, no por la sesión del equipo.
--
-- Antes, la reserva creaba una cuenta anónima por dispositivo y la cita
-- quedaba a nombre de `auth.uid()`. Eso fallaba de tres maneras:
--   - si la administradora dejó su sesión abierta en la tablet, la cita
--     quedaba a su nombre;
--   - la misma persona era un cliente distinto en cada teléfono o navegador;
--   - la estética no podía agendar a quien nunca abrió la app.
--
-- Ahora el cliente escribe su nombre, su celular y el nombre de su mascota.
-- `reservar_cita_por_celular` busca o crea el perfil y la mascota y crea la
-- cita, todo en una sola transacción. La usan tanto la app de clientes como
-- el "Cliente nuevo" del panel.

-- ===========================================================================
-- Clientes sin cuenta
-- ===========================================================================
--
-- `perfiles.id` deja de ser una clave foránea a `auth.users`. Un perfil puede
-- existir sin cuenta: lo crea la función de abajo con un id aleatorio.
--
-- Lo que sigue igual:
--   - el trigger `crear_perfil` inserta `id = new.id`, así que un cliente con
--     cuenta conserva su perfil enlazado;
--   - las políticas `id = auth.uid()` no cambian. Un id aleatorio nunca
--     coincide con una cuenta, así que ningún cliente ve un perfil sin cuenta.
--
-- Lo que cambia: borrar una cuenta de `auth.users` ya no borra su perfil. El
-- perfil queda como cliente sin cuenta, con su historial intacto.

alter table public.perfiles drop constraint if exists perfiles_id_fkey;

alter table public.perfiles alter column id set default gen_random_uuid();

comment on table public.perfiles is
  'Un cliente. Nace con una cuenta (trigger al_crear_usuario) o sin ella, por celular (reservar_cita_por_celular).';

-- Para buscar por celular sin recorrer la tabla. No es único: las cuentas
-- anónimas de antes pudieron dejar el mismo celular repetido, y un índice
-- único fallaría al crearse.
create index if not exists perfiles_por_telefono on public.perfiles (telefono);

-- ===========================================================================
-- Reservar por celular
-- ===========================================================================

create or replace function public.reservar_cita_por_celular(
  p_nombre text,
  p_telefono text,
  p_mascota_nombre text,
  p_empieza timestamptz,
  p_servicios text[]
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_nombre text := btrim(coalesce(p_nombre, ''));
  v_telefono text := btrim(coalesce(p_telefono, ''));
  v_mascota_nombre text := btrim(coalesce(p_mascota_nombre, ''));
  v_cliente uuid;
  v_mascota uuid;
begin
  -- Cualquiera puede llamarla, con o sin sesión: la validación no puede
  -- depender de que la app ya la haya hecho.
  if v_telefono !~ '^\+573[0-9]{9}$' then
    raise exception 'Escribe un celular colombiano'
      using errcode = '22023';
  end if;

  if v_nombre = '' or length(v_nombre) > 80 then
    raise exception 'Escribe el nombre del dueño'
      using errcode = '22023';
  end if;

  if v_mascota_nombre = '' or length(v_mascota_nombre) > 40 then
    raise exception 'Escribe el nombre de la mascota'
      using errcode = '22023';
  end if;

  -- El cliente con ese celular. Si hay varios, que dejaron las cuentas
  -- anónimas de antes, el más antiguo. Las cuentas administradoras no
  -- cuentan: su celular no convierte a nadie en la estética.
  select p.id into v_cliente
  from public.perfiles p
  where p.telefono = v_telefono
    and not exists (select 1 from public.admins a where a.id = p.id)
  order by p.creado_en
  limit 1;

  -- Si ya existe, su nombre NO se toca: si no, cualquiera que supiera un
  -- celular podría renombrar a ese cliente.
  if v_cliente is null then
    insert into public.perfiles (nombre, telefono)
    values (v_nombre, v_telefono)
    returning id into v_cliente;
  end if;

  -- La mascota del cliente con ese nombre, sin mirar mayúsculas ni espacios.
  select m.id into v_mascota
  from public.mascotas m
  where m.dueno_id = v_cliente
    and lower(btrim(m.nombre)) = lower(v_mascota_nombre)
  order by m.creada_en
  limit 1;

  if v_mascota is null then
    insert into public.mascotas (dueno_id, nombre)
    values (v_cliente, v_mascota_nombre)
    returning id into v_mascota;
  end if;

  -- Las reglas de servicios, horario, cierres y precio siguen en un solo
  -- sitio. `crear_cita_para` está cerrada a las llamadas directas, pero esta
  -- función corre con los permisos de su dueño.
  return public.crear_cita_para(
    v_cliente, v_mascota, p_empieza, p_servicios
  );
exception
  -- Al salir por aquí se deshace todo el bloque, perfil y mascota incluidos:
  -- un horario tomado no deja clientes huérfanos.
  when exclusion_violation then
    raise exception 'Ese horario lo acaban de tomar, elige otro'
      using errcode = 'exclusion_violation';
end;
$$;

-- Supabase da `execute` a `anon` y `authenticated` por separado en cada
-- función nueva. Aquí se quiere justo eso, pero se deja escrito para que no
-- dependa de un valor por defecto.
revoke all on function public.reservar_cita_por_celular(
  text, text, text, timestamptz, text[]
) from public;
grant execute on function public.reservar_cita_por_celular(
  text, text, text, timestamptz, text[]
) to anon, authenticated;
