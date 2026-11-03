-- El tercer nivel de acceso: la estética.
--
-- Hasta aquí el esquema solo distinguía dos: quien no ha entrado (ve el
-- catálogo y las horas ocupadas, sin saber de quién son) y quien ha entrado
-- (ve lo suyo). La dueña necesita ver todo, y con su cuenta de cliente hoy
-- vería exactamente lo mismo que cualquier otro.

-- ===========================================================================
-- Quién manda
-- ===========================================================================

-- Una tabla de uid y nada más. No lleva el rol como columna en `perfiles`
-- a propósito: una política sobre `perfiles` que consulte `perfiles` entra
-- en recursión, y hay que desactivarla con rodeos que nadie recuerda tres
-- meses después.
create table public.admins (
  id uuid primary key references auth.users (id) on delete cascade,
  anotacion text,
  creado_en timestamptz not null default now()
);

-- RLS activo y CERO políticas: desde el cliente esta tabla no se lee ni se
-- escribe, pase lo que pase. Se administra desde el panel de Supabase, que
-- es justo donde debe estar la decisión de quién manda.
alter table public.admins enable row level security;

-- `security definer` para que se salte el RLS de `admins` —si no, la
-- función no podría leer la tabla que acaba de cerrarse—. `stable` para que
-- Postgres la evalúe una vez por consulta y no una vez por fila.
create or replace function public.es_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.admins a where a.id = (select auth.uid())
  );
$$;

grant execute on function public.es_admin() to authenticated;

-- ===========================================================================
-- Lo que la estética ve
-- ===========================================================================

-- Las políticas se suman con OR, así que estas conviven con las de cliente
-- sin tocarlas: un cliente sigue viendo lo suyo, y quien además esté en
-- `admins` lo ve todo.

create policy "la estética ve todas las citas"
  on public.citas for select
  to authenticated
  using (es_admin());

-- Marcar cumplida o no asistió, y escribir la nota. Sin esto, ninguna cita
-- avanza nunca de `reservada`, y entonces la fidelidad y las analíticas se
-- quedan en cero para siempre.
create policy "la estética actualiza las citas"
  on public.citas for update
  to authenticated
  using (es_admin())
  with check (es_admin());

create policy "la estética ve a los clientes"
  on public.perfiles for select
  to authenticated
  using (es_admin());

create policy "la estética ve las mascotas"
  on public.mascotas for select
  to authenticated
  using (es_admin());

create policy "la estética ve el detalle de las citas"
  on public.cita_servicios for select
  to authenticated
  using (es_admin());

-- ===========================================================================
-- Lo que la estética administra
-- ===========================================================================

-- `for all` incluye el select, así que la dueña ve también los servicios
-- desactivados, que la política pública esconde.

create policy "la estética administra el catálogo"
  on public.servicios for all
  to authenticated
  using (es_admin())
  with check (es_admin());

create policy "la estética administra el horario"
  on public.horario_atencion for all
  to authenticated
  using (es_admin())
  with check (es_admin());

create policy "la estética administra los cierres"
  on public.cierres for all
  to authenticated
  using (es_admin())
  with check (es_admin());

-- ===========================================================================
-- La nota de la estilista
-- ===========================================================================

-- Del expediente del póster: "se incomoda con el secador cerca de las
-- orejas, secar con calma". Va en la cita y no en la mascota porque es lo
-- que pasó ese día; lo permanente del perro vive en `mascotas.notas`.
alter table public.citas add column notas_estilista text;
