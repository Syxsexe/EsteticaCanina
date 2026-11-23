-- La gestión de clientes desde el panel: la estética corrige el contacto
-- de un cliente, registra y edita sus mascotas y les deja notas internas.
--
-- Solo para clientes que ya tienen cuenta. Un perfil sigue naciendo con su
-- usuario de `auth.users`; aquí no se crea ninguno.
--
-- ANTES de aplicarla en un proyecto con datos reales, respalda `mascotas`:
-- esta migración borra la columna `mascotas.notas` después de copiarla.

-- ===========================================================================
-- La estética escribe sobre clientes y mascotas
-- ===========================================================================
--
-- Hasta ahora solo podía leerlos. Las políticas se suman a las del cliente
-- ("cada quien edita su perfil", "cada quien registra sus mascotas"...): en
-- Postgres basta con que una política permita la fila.
--
-- No hay `delete` para la estética ni sobre perfiles ni sobre mascotas. Una
-- mascota borrada dejaría sus citas pasadas sin perro (`on delete set null`)
-- y el historial perdería información.

create policy "la estética edita a los clientes"
  on public.perfiles for update
  to authenticated
  using (es_admin())
  with check (es_admin());

create policy "la estética registra mascotas"
  on public.mascotas for insert
  to authenticated
  with check (es_admin());

create policy "la estética edita mascotas"
  on public.mascotas for update
  to authenticated
  using (es_admin())
  with check (es_admin());

-- ===========================================================================
-- Notas internas de mascota
-- ===========================================================================
--
-- Una nota por mascota que solo la estética lee y escribe. No puede vivir
-- en `mascotas`: el tutor ve sus mascotas con todas las columnas y la RLS es
-- por fila, no por columna. Revocar `select (notas)` tampoco sirve, porque
-- el tutor y la estética comparten el rol `authenticated`.

create table public.notas_mascota (
  mascota_id uuid primary key references public.mascotas (id) on delete cascade,
  texto text not null,
  -- Quién la escribió por última vez. Nulo en las notas heredadas de
  -- `mascotas.notas`, que no tienen autor conocido.
  autor_id uuid references auth.users (id) on delete set null,
  actualizada_en timestamptz not null default now()
);

comment on table public.notas_mascota is
  'Nota interna de la estética sobre una mascota. El tutor no la ve.';

alter table public.notas_mascota enable row level security;

-- Sin políticas para clientes: no la leen ni la escriben. Sin `delete`:
-- vaciar el texto es la forma de quitar una nota.
create policy "la estética ve las notas de mascota"
  on public.notas_mascota for select
  to authenticated
  using (es_admin());

create policy "la estética crea notas de mascota"
  on public.notas_mascota for insert
  to authenticated
  with check (es_admin());

create policy "la estética edita notas de mascota"
  on public.notas_mascota for update
  to authenticated
  using (es_admin())
  with check (es_admin());

-- Lo que el tutor había escrito pasa a ser nota interna. Desde aquí deja de
-- verlo; la app de clientes nunca lo mostraba.
insert into public.notas_mascota (mascota_id, texto, autor_id, actualizada_en)
select id, btrim(notas), null, now()
from public.mascotas
where nullif(btrim(notas), '') is not null;

alter table public.mascotas drop column notas;
