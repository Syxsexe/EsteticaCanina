/// Una pestaña del panel que sabe volver a pedir sus datos.
///
/// El panel monta las pestañas en un `IndexedStack`, así que siguen vivas al
/// cambiar de destino y no vuelven a cargar solas. Sin esto, marcar una cita
/// como cumplida en Agenda dejaba el Resumen con los ingresos de antes hasta
/// que alguien deslizaba para actualizar.
///
/// Recargar no reinicia la vista: el día de la agenda, el filtro y el orden
/// del historial se conservan.
abstract interface class PestanaRecargable {
  Future<void> recargar();
}
