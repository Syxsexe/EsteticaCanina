-- Clientes nuevos de un mes cualquiera, para revisar meses pasados en el
-- Resumen del panel.
--
-- `clientes_nuevos_mes()` solo sabe del mes en curso y se queda para esa
-- vista. Esta recibe el mes. Va con otro nombre y no como sobrecarga porque
-- PostgREST resuelve mal dos funciones con el mismo nombre cuando un
-- parámetro puede faltar.

create or replace function public.clientes_nuevos_en(p_mes date)
returns int
language sql
security definer
set search_path = public
stable
as $$
  -- El mes se corta en el reloj de Bogotá: un cliente que se registró el 31
  -- de octubre a las 20:00 de Bogotá es de octubre, aunque en UTC ya sea
  -- 1 de noviembre. Como en `clientes_nuevos_mes`, quien no sea admin
  -- recibe cero.
  select count(*)::int
  from public.perfiles p
  where public.es_admin()
    and not exists (select 1 from public.admins a where a.id = p.id)
    -- `p_mes::timestamp` antes de truncar: un `date` suelto se convertiría
    -- a timestamptz con la zona de la sesión, y el corte dependería de ella.
    and p.creado_en >= (date_trunc('month', p_mes::timestamp)
                          at time zone 'America/Bogota')
    and p.creado_en < ((date_trunc('month', p_mes::timestamp) + interval '1 month')
                          at time zone 'America/Bogota');
$$;

-- Supabase da `execute` a `anon` y `authenticated` por separado en cada
-- función nueva: hay que quitárselo a `anon` de forma explícita.
revoke all on function public.clientes_nuevos_en(date) from public, anon;
grant execute on function public.clientes_nuevos_en(date) to authenticated;
