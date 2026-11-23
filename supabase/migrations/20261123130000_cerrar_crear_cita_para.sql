-- Cierra `crear_cita_para` a las llamadas directas.
--
-- Es la función interna que valida y escribe una cita a nombre de
-- cualquier cliente. No comprueba `es_admin()`: eso lo hacen las funciones
-- públicas que la envuelven.
--
-- El `revoke ... from public` de `20261116120000_panel_admin.sql` no
-- bastaba. Supabase da `execute` sobre cada función nueva de `public` a
-- `anon` y `authenticated` por separado, y quitárselo a `public` no toca
-- esos permisos. Con ellos, cualquiera podía llamar a
-- `rpc/crear_cita_para` con el id de otro cliente y reservarle una cita
-- sin ser administradora.
--
-- Nadie pierde nada:
--   - el cliente reserva con `reservar_cita`;
--   - la estética crea con `reservar_cita_admin`;
--   - la estética edita con `editar_cita_admin`;
--   - las cancelaciones van por las políticas de `update` sobre `citas`.
-- Las dos funciones de reserva son `security definer`: llaman a
-- `crear_cita_para` con los permisos de su dueño, no con los de quien las
-- llama.
--
-- Comprobación, con la anon key:
--   POST /rest/v1/rpc/crear_cita_para
--   debe responder "permission denied for function crear_cita_para".

revoke execute on function public.crear_cita_para(uuid, uuid, timestamptz, text[])
  from anon, authenticated;
