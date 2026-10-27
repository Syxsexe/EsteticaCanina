-- Datos de arranque.
--
-- El catálogo es el mismo que hoy está escrito en
-- lib/features/booking/data/service_catalog.dart. OJO: esos precios y
-- duraciones son de muestra, como avisa el propio archivo de Dart. Hay que
-- reemplazarlos por los de Perro Look antes de enseñarle esto a un cliente
-- — y la gracia de tenerlos aquí es que para eso ya no hace falta tocar la
-- app ni publicar una versión.

insert into public.servicios
  (id, nombre, nota, precio_cop, minutos, es_extra, orden)
values
  ('bano', 'Baño',
   'Agua caliente, cepillado y secado.', 35000, 60, false, 1),
  ('corte_completo', 'Corte completo',
   'Baño más corte de todo el manto.', 40000, 120, false, 2),
  ('corte_raza', 'Corte de raza',
   'Corte acorde al estándar de la raza.', 38000, 120, false, 3),
  ('cachorro', 'Visita de cachorro',
   'Primera vez, con calma y sin máquina.', 45000, 120, false, 4),
  ('unas', 'Corte de uñas',
   'Incluye limado.', 10000, 10, true, 5),
  ('oidos', 'Limpieza de oídos',
   'Revisión y limpieza suave.', 5000, 10, true, 6),
  ('dientes', 'Limpieza de dientes',
   'Cepillado con pasta canina.', 12000, 15, true, 7),
  ('deslanado', 'Deslanado',
   'Retira el pelo muerto del manto doble.', 30000, 60, true, 8)
on conflict (id) do update set
  nombre     = excluded.nombre,
  nota       = excluded.nota,
  precio_cop = excluded.precio_cop,
  minutos    = excluded.minutos,
  es_extra   = excluded.es_extra,
  orden      = excluded.orden;

-- Lunes a viernes, mañana y tarde. Sábado y domingo no aparecen: un día sin
-- filas es un día cerrado, igual que en la app un DaySchedule sin franjas.
insert into public.horario_atencion (dia_semana, abre, cierra)
select dia, abre, cierra
from generate_series(1, 5) as dia,
     (values (time '08:00', time '12:00'),
             (time '14:30', time '18:00')) as franja(abre, cierra)
on conflict (dia_semana, abre) do update set
  cierra = excluded.cierra;
