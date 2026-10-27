/// Nombres en español, escritos a mano.
///
/// La app no trae `intl` y aquí solo hacen falta dos listas; es la misma
/// decisión que ya tomó `formatCop` al no arrastrar un paquete por separar
/// miles con puntos.
const List<String> _weekdays = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];

const List<String> _months = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

String _capitalizar(String palabra) =>
    '${palabra[0].toUpperCase()}${palabra.substring(1)}';

/// Minutos desde medianoche como `08:00` o `14:30`.
String formatHour(int minutes) {
  final horas = (minutes ~/ 60).toString().padLeft(2, '0');
  final resto = (minutes % 60).toString().padLeft(2, '0');
  return '$horas:$resto';
}

/// `Lun`, `Mié`, `Sáb`. Para la tira de días, donde no cabe más.
String formatWeekdayShort(DateTime date) =>
    _capitalizar(_weekdays[date.weekday - 1].substring(0, 3));

/// `Miércoles 30 de septiembre`, para confirmar qué día se eligió.
String formatLongDate(DateTime date) {
  final dia = _capitalizar(_weekdays[date.weekday - 1]);
  return '$dia ${date.day} de ${_months[date.month - 1]}';
}

/// `Septiembre`, para la cabecera de la tira de días.
String formatMonth(DateTime date) => _capitalizar(_months[date.month - 1]);
