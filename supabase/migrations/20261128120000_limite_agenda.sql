-- Un periodo prudente para agendar: ninguna cita a más de 90 días vista.
--
-- Se pone en `crear_cita_para`, la función interna por la que pasan todas
-- las reservas: la de la app (reservar_cita_por_celular), la del panel
-- (reservar_cita_admin) y la del asistente de IA. El resto de la función
-- queda igual que en 20261116120000_panel_admin.sql.
--
-- `create or replace` conserva los permisos: crear_cita_para sigue cerrada
-- a las llamadas directas (20261123130000_cerrar_crear_cita_para.sql).

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

  -- Un periodo prudente: nada a más de 90 días vista. Vale para todas las
  -- vías de reserva (app, panel y asistente), porque todas pasan por aquí.
  if p_empieza > now() + interval '90 days' then
    raise exception 'Solo se puede agendar hasta 90 días adelante';
  end if;

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
