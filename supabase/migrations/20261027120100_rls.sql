-- Políticas de acceso.
--
-- Punto de partida: todo cerrado. Cada tabla se abre solo a lo que la app
-- necesita de verdad, y las citas no se abren en absoluto para escritura —
-- reservar pasa por la función `reservar_cita` de la migración siguiente.

alter table public.perfiles         enable row level security;
alter table public.mascotas         enable row level security;
alter table public.servicios        enable row level security;
alter table public.horario_atencion enable row level security;
alter table public.cierres          enable row level security;
alter table public.citas            enable row level security;
alter table public.cita_servicios   enable row level security;
alter table public.referidos        enable row level security;

-- ===========================================================================
-- Público: lo que se puede ver sin cuenta
-- ===========================================================================

-- Navegar el catálogo y el horario no exige identificarse. Es deliberado:
-- con OTP por teléfono cada registro cuesta un SMS, así que nadie debería
-- tener que crear cuenta para mirar qué hay y cuándo abren.

create policy "el catálogo activo es público"
  on public.servicios for select
  to anon, authenticated
  using (activo);

create policy "el horario es público"
  on public.horario_atencion for select
  to anon, authenticated
  using (true);

create policy "los cierres son públicos"
  on public.cierres for select
  to anon, authenticated
  using (true);

-- Ojo: las horas ocupadas NO se exponen aquí. Una política sobre `citas`
-- que dejara verlas enseñaría también de quién son. Eso se resuelve con la
-- función `horarios_ocupados`, que proyecta solo dos columnas de tiempo.

-- ===========================================================================
-- Privado: cada quien lo suyo
-- ===========================================================================

create policy "cada quien ve su perfil"
  on public.perfiles for select
  to authenticated
  using (id = (select auth.uid()));

create policy "cada quien edita su perfil"
  on public.perfiles for update
  to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- El perfil lo crea el trigger `al_crear_usuario`, no el cliente: no hay
-- política de insert.

create policy "cada quien ve sus mascotas"
  on public.mascotas for select
  to authenticated
  using (dueno_id = (select auth.uid()));

create policy "cada quien registra sus mascotas"
  on public.mascotas for insert
  to authenticated
  with check (dueno_id = (select auth.uid()));

create policy "cada quien edita sus mascotas"
  on public.mascotas for update
  to authenticated
  using (dueno_id = (select auth.uid()))
  with check (dueno_id = (select auth.uid()));

create policy "cada quien borra sus mascotas"
  on public.mascotas for delete
  to authenticated
  using (dueno_id = (select auth.uid()));

create policy "cada quien ve sus citas"
  on public.citas for select
  to authenticated
  using (cliente_id = (select auth.uid()));

-- Cancelar es lo único que el cliente escribe directamente sobre una cita.
-- El `with check` impide que use este camino para moverla de hora y saltarse
-- las validaciones de `reservar_cita`.
create policy "cada quien cancela sus citas"
  on public.citas for update
  to authenticated
  using (cliente_id = (select auth.uid()) and estado = 'reservada')
  with check (cliente_id = (select auth.uid()) and estado = 'cancelada');

create policy "cada quien ve el detalle de sus citas"
  on public.cita_servicios for select
  to authenticated
  using (
    exists (
      select 1 from public.citas c
      where c.id = cita_servicios.cita_id
        and c.cliente_id = (select auth.uid())
    )
  );

create policy "cada quien ve a quién refirió"
  on public.referidos for select
  to authenticated
  using (
    quien_refiere = (select auth.uid()) or referido = (select auth.uid())
  );

-- No hay política de insert sobre `referidos`: un referido se registra al
-- canjear un código, y eso será una función con sus propias comprobaciones.
-- Dejarlo abierto sería dejar que cualquiera se autoasignara referidos.
