-- Las funciones que la app llama.
--
-- Son tres: ver qué horas están ocupadas (sin cuenta), reservar (con cuenta)
-- y consultar la fidelidad.

-- ===========================================================================
-- Horas ocupadas, sin revelar de quién son
-- ===========================================================================

-- El cliente necesita saber que el miércoles a las 10:00 no hay sitio, pero
-- no quién lo tiene, con qué perro ni con qué teléfono. Como la función es
-- `security definer`, se salta las políticas de `citas`; y como solo
-- proyecta dos columnas de tiempo, no queda nada que filtrar.
--
-- Deliberadamente NO es una vista: en Supabase una vista corre como su
-- dueño salvo que lleve `security_invoker = true`, y esa ambigüedad ha
-- causado filtraciones reales. Una función se audita de un vistazo.
create or replace function public.horarios_ocupados(desde date, hasta date)
returns table (empieza timestamptz, termina timestamptz)
language sql
security definer
set search_path = public
stable
as $$
  select c.empieza, c.termina
  from public.citas c
  where c.estado in ('reservada', 'cumplida')
    and c.empieza >= (desde::timestamp at time zone 'America/Bogota')
    and c.empieza < ((hasta + 1)::timestamp at time zone 'America/Bogota');
$$;

revoke all on function public.horarios_ocupados(date, date) from public;
grant execute on function public.horarios_ocupados(date, date)
  to anon, authenticated;

-- ===========================================================================
-- Reservar
-- ===========================================================================

-- Toda la reserva en una llamada y una transacción: valida, calcula el
-- precio y escribe la cita con su detalle.
--
-- El precio y la duración salen de la tabla `servicios`, nunca de lo que
-- mande el cliente. Si el total viajara desde el teléfono, cualquiera
-- podría reservar un corte de raza por mil pesos.
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
  v_pedidos int := coalesce(array_length(p_servicios, 1), 0);
  v_encontrados int;
  v_principales int;
  v_minutos int;
  v_total int;
  v_local timestamp;
  v_cita uuid;
begin
  if v_cliente is null then
    raise exception 'Hay que iniciar sesión para reservar'
      using errcode = '28000';
  end if;

  if p_mascota_id is not null and not exists (
    select 1 from public.mascotas
    where id = p_mascota_id and dueno_id = v_cliente
  ) then
    raise exception 'Esa mascota no está a tu nombre'
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

  -- La misma regla de dos niveles del paso 1: uno principal, los extras que
  -- se quieran encima.
  if v_principales <> 1 then
    raise exception 'La cita necesita exactamente un servicio principal';
  end if;

  -- El horario se razona en hora de Bogotá. Colombia no tiene horario de
  -- verano, así que la conversión es estable todo el año.
  v_local := p_empieza at time zone 'America/Bogota';

  if exists (select 1 from public.cierres where fecha = v_local::date) then
    raise exception 'Ese día la estética está cerrada';
  end if;

  -- La cita tiene que caber entera dentro de una sola franja: ni pisar el
  -- almuerzo ni terminar después de cerrar.
  if not exists (
    select 1 from public.horario_atencion h
    where h.dia_semana = extract(isodow from v_local)
      and v_local::time >= h.abre
      and (v_local + make_interval(mins => v_minutos))::time <= h.cierra
  ) then
    raise exception 'A esa hora la cita no cabe en el horario de atención';
  end if;

  insert into public.citas (cliente_id, mascota_id, empieza, minutos, total_cop)
  values (v_cliente, p_mascota_id, p_empieza, v_minutos, v_total)
  returning id into v_cita;

  insert into public.cita_servicios (cita_id, servicio_id, precio_cop, minutos)
  select v_cita, s.id, s.precio_cop, s.minutos
  from public.servicios s
  where s.id = any (p_servicios);

  return v_cita;

exception
  -- Lo lanza la restricción `sin_solapes`: alguien reservó ese hueco entre
  -- que la pantalla se dibujó y el cliente pulsó.
  when exclusion_violation then
    raise exception 'Ese horario lo acaban de tomar, elige otro'
      using errcode = 'P0001';
end;
$$;

revoke all on function public.reservar_cita(uuid, timestamptz, text[]) from public;
grant execute on function public.reservar_cita(uuid, timestamptz, text[])
  to authenticated;

-- ===========================================================================
-- Fidelidad
-- ===========================================================================

-- Esta sí es `security invoker`: corre con los permisos de quien llama y se
-- apoya en la política "cada quien ve sus citas". No hace falta saltarse
-- nada, así que no se salta nada.
create or replace function public.mi_fidelidad()
returns table (visitas int, faltan_para_gratis int, referidos int)
language sql
security invoker
stable
as $$
  with cumplidas as (
    select count(*)::int as n
    from public.citas
    where cliente_id = (select auth.uid()) and estado = 'cumplida'
  )
  select
    c.n,
    8 - (c.n % 8),
    (select count(*)::int from public.referidos
      where quien_refiere = (select auth.uid()))
  from cumplidas c;
$$;

grant execute on function public.mi_fidelidad() to authenticated;
