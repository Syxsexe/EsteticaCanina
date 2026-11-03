-- Prueba de humo. Correr en el SQL Editor, por bloques y en orden.
--
-- No comprueba que el esquema se haya creado —eso ya lo dijo el panel—,
-- sino que las reglas que lo justifican funcionan de verdad. Sobre todo la
-- de solapamiento, que es la única defensa real contra la doble reserva y
-- hasta ahora nunca se ha ejercitado.

-- ===========================================================================
-- 1. El seed entró
-- ===========================================================================

select id, nombre, precio_cop, minutos, es_extra
from servicios order by orden;
-- Esperado: 8 filas. 4 con es_extra = false y 4 con true.

select dia_semana, abre, cierra
from horario_atencion order by dia_semana, abre;
-- Esperado: 10 filas. Días 1 a 5, dos franjas cada uno. Ni 6 ni 7.

-- ===========================================================================
-- 2. La función pública responde
-- ===========================================================================

select * from horarios_ocupados(current_date, current_date + 14);
-- Esperado: 0 filas, porque todavía no hay citas. Lo que se comprueba aquí
-- es que la función existe y que `anon` puede ejecutarla.

-- ===========================================================================
-- 3. El perfil nace solo
-- ===========================================================================

-- ANTES de seguir: crea un usuario de prueba desde el panel, en
-- Authentication -> Users -> Add user, con un teléfono cualquiera
-- (+573000000001 sirve). Luego:

select id, telefono, creado_en from perfiles;
-- Esperado: 1 fila, creada por el disparador `al_crear_usuario`. Si está
-- vacío, el disparador no se ejecutó.

-- ===========================================================================
-- 4. La prueba que importa: dos citas no pueden pisarse
-- ===========================================================================

-- Se insertan directo en la tabla, saltándose `reservar_cita`, porque esa
-- función necesita una sesión y en el editor no hay ninguna. Aquí se está
-- probando la restricción, no la función.

-- 4a. Mañana de 09:00 a 10:00. Debe PASAR.
insert into citas (cliente_id, empieza, minutos, total_cop)
values (
  (select id from perfiles limit 1),
  (current_date + 1 + time '09:00') at time zone 'America/Bogota',
  60, 35000
);

-- 4b. Mañana de 09:30 a 10:30: se mete en la anterior. Debe FALLAR con
--     "conflicting key value violates exclusion constraint sin_solapes".
--     Si esta pasa, la doble reserva está abierta y hay que arreglarlo.
insert into citas (cliente_id, empieza, minutos, total_cop)
values (
  (select id from perfiles limit 1),
  (current_date + 1 + time '09:30') at time zone 'America/Bogota',
  60, 35000
);

-- 4c. Mañana a las 10:00 en punto, justo cuando termina la primera. Debe
--     PASAR: los rangos se tocan pero no se solapan, y `&&` sobre rangos
--     semiabiertos lo distingue bien.
insert into citas (cliente_id, empieza, minutos, total_cop)
values (
  (select id from perfiles limit 1),
  (current_date + 1 + time '10:00') at time zone 'America/Bogota',
  60, 35000
);

-- 4d. El disparador calculó el final de cada una.
select empieza, minutos, termina from citas order by empieza;
-- Esperado: 2 filas (4a y 4c), con termina = empieza + minutos.

-- 4e. Y ahora la función pública sí las ve, sin decir de quién son.
select * from horarios_ocupados(current_date, current_date + 14);
-- Esperado: 2 filas, solo con empieza y termina.

-- ===========================================================================
-- 5. Limpiar
-- ===========================================================================

delete from citas;
-- El usuario de prueba puede quedarse; si molesta, bórralo desde el panel
-- y su perfil se va con él por el `on delete cascade`.

-- ===========================================================================
-- 6. El rol de administradora
-- ===========================================================================
--
-- Requiere haber aplicado 20261103130000_rol_admin.sql y haber nombrado a
-- alguien administradora (ver el README).

-- 6a. ¿Quién es administradora?
select a.id, u.email, a.anotacion
from public.admins a join auth.users u on u.id = a.id;
-- Esperado: la fila de la dueña. Si está vacío, falta el insert.

-- 6b. La función responde. Desde el SQL Editor no hay sesión, así que
--     auth.uid() es nulo y debe dar false. Que diga false aquí es lo
--     correcto: significa que no concede acceso a quien no se identificó.
select public.es_admin() as deberia_ser_false;

-- 6c. Las políticas de administración existen.
select tablename, policyname
from pg_policies
where schemaname = 'public' and policyname like 'la estética%'
order by tablename, policyname;
-- Esperado: 8 filas, sobre citas (2), perfiles, mascotas, cita_servicios,
-- servicios, horario_atencion y cierres.

-- 6d. La columna de la nota entró.
select column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name = 'citas'
  and column_name = 'notas_estilista';
-- Esperado: 1 fila, text.

-- 6e. Nadie puede leer `admins` desde la app. Esta tabla tiene RLS activo
--     y ninguna política, así que la consulta de abajo debe devolver 0
--     filas para cualquiera que no sea el rol `postgres` del editor.
select count(*) as politicas_sobre_admins
from pg_policies where schemaname = 'public' and tablename = 'admins';
-- Esperado: 0. Si algún día aparece una política aquí, alguien abrió la
-- puerta de quién manda y conviene saber por qué.
