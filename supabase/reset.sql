-- SOLO PARA DESARROLLO. Borra el esquema entero y todo lo que contenga.
--
-- Sirve para reintentar las migraciones desde cero cuando una falla a
-- medias. Es seguro correrlo las veces que haga falta —todo lleva
-- `if exists`— y es seguro correrlo sobre un proyecto vacío.
--
-- NO lo corras nunca sobre un proyecto con citas de verdad: no pide
-- confirmación y no hay deshacer.
--
-- No toca `auth.users`: las cuentas creadas con OTP sobreviven. Lo único
-- que se les quita es el disparador que les crea el perfil, que la
-- migración vuelve a poner.

drop trigger if exists al_crear_usuario on auth.users;

drop function if exists public.crear_perfil() cascade;
drop function if exists public.calcular_fin_cita() cascade;
drop function if exists public.horarios_ocupados(date, date) cascade;
drop function if exists public.reservar_cita_por_celular(text, text, text, timestamptz, text[]) cascade;
drop function if exists public.crear_cita_para(uuid, uuid, timestamptz, text[]) cascade;
drop function if exists public.reservar_cita(uuid, timestamptz, text[]) cascade;
drop function if exists public.reservar_cita_admin(uuid, uuid, timestamptz, text[]) cascade;
drop function if exists public.editar_cita_admin(uuid, timestamptz, uuid, text[], text, text) cascade;
drop function if exists public.directorio_clientes() cascade;
drop function if exists public.eliminar_cliente_admin(uuid) cascade;
drop function if exists public.clientes_nuevos_mes() cascade;
drop function if exists public.clientes_nuevos_en(date) cascade;
drop function if exists public.mi_fidelidad() cascade;
drop function if exists public.es_admin() cascade;

-- Las políticas de las fotos viven en `storage.objects`, que no se borra
-- con las tablas. El bucket no se puede borrar con objetos dentro: vacíalo
-- antes desde Storage en el panel si quieres empezar sin fotos.
drop policy if exists "la estética ve las fotos de mascotas" on storage.objects;
drop policy if exists "la estética sube fotos de mascotas" on storage.objects;
drop policy if exists "la estética cambia fotos de mascotas" on storage.objects;
drop policy if exists "la estética borra fotos de mascotas" on storage.objects;

-- En orden inverso al de creación. El `cascade` se encarga igualmente de
-- las claves foráneas que queden.
drop table if exists public.notas_mascota cascade;
drop table if exists public.observaciones cascade;
drop table if exists public.admins cascade;
drop table if exists public.referidos cascade;
drop table if exists public.cita_servicios cascade;
drop table if exists public.citas cascade;
drop table if exists public.cierres cascade;
drop table if exists public.horario_atencion cascade;
drop table if exists public.servicios cascade;
drop table if exists public.mascotas cascade;
drop table if exists public.perfiles cascade;
