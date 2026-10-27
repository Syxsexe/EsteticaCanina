-- Esquema de Perro Look.
--
-- Orden de lectura: perfiles y mascotas (quién reserva), servicios y horario
-- (qué se ofrece y cuándo), citas (lo que se reserva). Las políticas de
-- acceso van en la migración siguiente y las funciones en la de después.

create extension if not exists btree_gist;

-- ===========================================================================
-- Quién reserva
-- ===========================================================================

create table public.perfiles (
  id uuid primary key references auth.users (id) on delete cascade,
  nombre text,
  -- Copia del teléfono con el que se autenticó. Se guarda aquí además de en
  -- auth.users porque el esquema auth no se consulta desde el cliente.
  telefono text,
  creado_en timestamptz not null default now()
);

comment on table public.perfiles is
  'Un registro por cuenta. Nace solo al crearse el usuario.';

-- El perfil nace con la cuenta: con OTP por teléfono, auth.users.phone ya
-- viene relleno y el nombre se pide después, dentro de la app.
create or replace function public.crear_perfil()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.perfiles (id, telefono)
  values (new.id, new.phone)
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger al_crear_usuario
  after insert on auth.users
  for each row execute function public.crear_perfil();

create table public.mascotas (
  id uuid primary key default gen_random_uuid(),
  dueno_id uuid not null references public.perfiles (id) on delete cascade,
  nombre text not null,
  raza text,
  edad_anios int check (edad_anios between 0 and 30),
  peso_kg numeric(4, 1) check (peso_kg > 0),
  -- La nota de la estilista: "se incomoda con el secador cerca de las
  -- orejas, secar con calma".
  notas text,
  creada_en timestamptz not null default now()
);

create index mascotas_por_dueno on public.mascotas (dueno_id);

-- ===========================================================================
-- Qué se ofrece y cuándo
-- ===========================================================================

-- El catálogo vive en la base y no en el código para que la dueña pueda
-- cambiar precios sin que nadie publique una versión de la app.
create table public.servicios (
  id text primary key,
  nombre text not null,
  nota text not null,
  precio_cop int not null check (precio_cop >= 0),
  minutos int not null check (minutos > 0),
  -- Falso: es un servicio principal, se elige uno. Cierto: es un extra, se
  -- suman los que se quieran. Es la misma división de dos niveles del paso 1.
  es_extra boolean not null default false,
  activo boolean not null default true,
  orden int not null default 0
);

-- Las franjas de atención, una fila por tramo. Mañana y tarde van separadas
-- y el almuerzo es lo que queda en medio, igual que los TimeWindow de la app.
create table public.horario_atencion (
  id bigint generated always as identity primary key,
  -- ISO: 1 = lunes … 7 = domingo. Coincide con DateTime.weekday de Dart.
  dia_semana int not null check (dia_semana between 1 and 7),
  abre time not null,
  cierra time not null,
  check (abre < cierra),
  -- Una sola franja por día y hora de apertura. Además de evitar el
  -- disparate de dos "mañanas" el mismo día, le da al seed algo contra lo
  -- que hacer `on conflict`, para poder correrlo las veces que haga falta.
  unique (dia_semana, abre)
);

-- Festivos, vacaciones y cierres puntuales. Pisan al horario.
create table public.cierres (
  fecha date primary key,
  motivo text
);

-- ===========================================================================
-- Las citas
-- ===========================================================================

create table public.citas (
  id uuid primary key default gen_random_uuid(),
  cliente_id uuid not null references public.perfiles (id) on delete restrict,
  mascota_id uuid references public.mascotas (id) on delete set null,
  empieza timestamptz not null,
  minutos int not null check (minutos > 0),
  -- Lo calcula el disparador `citas_calcular_fin`, no una columna generada.
  -- En Postgres `timestamptz + interval` es STABLE y no IMMUTABLE: en cuanto
  -- el intervalo puede llevar días o meses, el resultado depende de la zona
  -- horaria de la sesión, y el operador se marca por su peor caso aunque
  -- aquí solo se le pasen minutos. Una columna generada exige inmutabilidad;
  -- un disparador no.
  termina timestamptz not null,
  estado text not null default 'reservada'
    check (estado in ('reservada', 'cumplida', 'cancelada', 'no_asistio')),
  -- Congelado al reservar. Si mañana sube el precio del baño, esta cita
  -- sigue costando lo que costaba.
  total_cop int not null check (total_cop >= 0),
  creada_en timestamptz not null default now()
);

create or replace function public.calcular_fin_cita()
returns trigger
language plpgsql
as $$
begin
  new.termina := new.empieza + make_interval(mins => new.minutos);
  return new;
end;
$$;

-- Solo cuando cambia algo que afecte al cálculo: marcar una cita como
-- cumplida no tiene por qué recalcular nada.
create trigger citas_calcular_fin
  before insert or update of empieza, minutos on public.citas
  for each row execute function public.calcular_fin_cita();

-- La regla que el cliente no puede saltarse.
--
-- La app ya comprueba solapamientos en Dart, pero eso corre en el teléfono:
-- dos personas con la pantalla abierta ven el mismo hueco libre y las dos
-- pulsan. Esta restricción rechaza la segunda de forma atómica, que es el
-- único sitio donde la regla se sostiene de verdad.
--
-- Si algún día hay dos estilistas, se añade `estilista_id with =` aquí.
alter table public.citas add constraint sin_solapes
  exclude using gist (tstzrange(empieza, termina) with &&)
  where (estado in ('reservada', 'cumplida'));

create index citas_por_cliente on public.citas (cliente_id);
create index citas_por_fecha on public.citas (empieza);

create table public.cita_servicios (
  cita_id uuid not null references public.citas (id) on delete cascade,
  servicio_id text not null references public.servicios (id),
  -- También congelados: el detalle de la factura no puede cambiar porque
  -- alguien edite el catálogo meses después.
  precio_cop int not null check (precio_cop >= 0),
  minutos int not null check (minutos >= 0),
  primary key (cita_id, servicio_id)
);

-- ===========================================================================
-- Fidelidad
-- ===========================================================================

-- Las visitas acumuladas NO se guardan en un contador: se cuentan sobre las
-- citas cumplidas. Un contador se desincroniza con cada cancelación o
-- corrección manual; una cuenta sobre la tabla real nunca miente.
--
-- Los referidos sí necesitan tabla, porque no se deducen de nada.
create table public.referidos (
  id uuid primary key default gen_random_uuid(),
  quien_refiere uuid not null references public.perfiles (id) on delete cascade,
  -- Cada persona puede ser referida una sola vez, por alguien distinto.
  referido uuid not null unique references public.perfiles (id) on delete cascade,
  creado_en timestamptz not null default now(),
  check (quien_refiere <> referido)
);

create index referidos_por_quien on public.referidos (quien_refiere);
