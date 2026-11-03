/// La estética vive en Bogotá; la app, en cualquier parte.
///
/// Todo el razonamiento sobre horarios —que la mañana va de 08:00 a 12:00,
/// que una cita de dos horas no cabe empezando a las 11:00— ocurre en el
/// reloj de pared de la estética. Pero `DateTime.now()` y `toLocal()` dan
/// la hora del dispositivo, que puede ser otra: un emulador en UTC, un
/// cliente de viaje, un teléfono mal configurado.
///
/// Mezclar las dos cosas fue un error real: la app enviaba las 09:00 del
/// dispositivo, Postgres las leía como las 04:00 de Bogotá y rechazaba la
/// cita por quedar fuera del horario. Por eso la conversión vive en un solo
/// sitio y nadie más llama a `toLocal()` sobre una fecha de agenda.
///
/// Colombia no tiene horario de verano, así que el desfase es fijo y no
/// hace falta una base de datos de zonas horarias.
library;

const Duration _desfaseBogota = Duration(hours: -5);

/// Un instante absoluto, leído en el reloj de la estética.
///
/// Lo que vuelve es un [DateTime] marcado como UTC cuyos campos —`hour`,
/// `day`— son los del reloj de Bogotá. Sirve para leerlo y mostrarlo, no
/// para volver a tratarlo como un instante.
DateTime enHoraEstetica(DateTime instante) =>
    instante.toUtc().add(_desfaseBogota);

/// Una hora del reloj de la estética, como instante absoluto.
///
/// Las 09:00 en la estética son las 14:00 UTC, que es lo que entiende
/// Postgres.
DateTime desdeHoraEstetica(DateTime pared) => DateTime.utc(
      pared.year,
      pared.month,
      pared.day,
      pared.hour,
      pared.minute,
    ).subtract(_desfaseBogota);

/// Qué día es hoy para la estética, a medianoche.
///
/// A las 23:00 en Bogotá un dispositivo en UTC ya está en mañana. Sin esto,
/// la agenda abriría en el día equivocado.
DateTime hoyEnLaEstetica() {
  final ahora = enHoraEstetica(DateTime.now());
  return DateTime(ahora.year, ahora.month, ahora.day);
}
