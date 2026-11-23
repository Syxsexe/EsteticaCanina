import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/format/phone.dart';
import '../../core/navigation/flow_page_route.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'booking_confirmed_screen.dart';
import 'data/booking_repository.dart';
import 'data/service_catalog.dart';
import 'models/booking.dart';
import 'models/cliente_reserva.dart';

/// Lo que el paso 3 le devuelve al paso 2 cuando no termina en confirmación.
enum ResultadoIdentificacion {
  /// Alguien tomó la hora mientras se llenaba el paso 3. El paso 2 tiene que
  /// recargar la agenda y pedir otra.
  horarioTomado,
}

/// Paso 3 de la reserva: quién reserva.
///
/// La cita queda a nombre del cliente con el celular que se escriba aquí, no
/// de la sesión que haya abierta en el equipo. Así una tablet compartida con
/// la sesión de la administradora no reserva a su nombre, y la misma persona
/// es un solo cliente aunque reserve desde otro teléfono.
///
/// Se piden los tres datos en cada reserva: no hay sesión ni almacenamiento
/// local que los recuerde.
class IdentificationScreen extends StatefulWidget {
  const IdentificationScreen({
    super.key,
    required this.booking,
    this.bookingRepository,
  });

  /// El día, la hora y los servicios elegidos en los pasos 1 y 2.
  final Booking booking;

  /// Quién guarda la cita. Nulo significa "el que toque".
  final BookingRepository? bookingRepository;

  @override
  State<IdentificationScreen> createState() => _IdentificationScreenState();
}

class _IdentificationScreenState extends State<IdentificationScreen> {
  final _nombre = TextEditingController();
  final _telefono = TextEditingController();
  final _mascota = TextEditingController();

  String? _errorNombre;
  String? _errorTelefono;
  String? _errorMascota;

  /// Cierto mientras la cita se guarda. Bloquea el botón: sin esto, dos
  /// toques seguidos mandan dos reservas.
  bool _guardando = false;

  @override
  void dispose() {
    _nombre.dispose();
    _telefono.dispose();
    _mascota.dispose();
    super.dispose();
  }

  Future<void> _reservar() async {
    final nombre = _nombre.text.trim();
    final telefono = normalizarTelefono(_telefono.text);
    final mascota = _mascota.text.trim();

    setState(() {
      _errorNombre = nombre.isEmpty ? 'Dinos cómo te llamas.' : null;
      // Un fijo tampoco vale: no recibe el recordatorio por mensaje.
      _errorTelefono =
          telefono == null ? 'Escribe un celular colombiano.' : null;
      _errorMascota =
          mascota.isEmpty ? 'Dinos cómo se llama tu mascota.' : null;
    });
    if (nombre.isEmpty || telefono == null || mascota.isEmpty) return;

    setState(() => _guardando = true);
    final mensajero = ScaffoldMessenger.of(context);
    final navegador = Navigator.of(context);

    try {
      // Guardar primero y navegar después. Al revés, la pantalla diría
      // "¡Cita confirmada!" antes de saber si lo está.
      final repositorio =
          widget.bookingRepository ?? defaultBookingRepository();
      await repositorio.reservar(
        widget.booking,
        ClienteReserva(nombre: nombre, telefono: telefono, mascota: mascota),
      );

      if (!mounted) return;
      // La confirmación es terminal: los tres pasos salen de la pila. Si se
      // pudiera volver atrás desde ella, solo serviría para reservar dos
      // veces.
      navegador.pushAndRemoveUntil(
        FlowPageRoute<void>(
          builder: (_) => BookingConfirmedScreen(booking: widget.booking),
        ),
        (route) => route.isFirst,
      );
    } on SlotTakenException {
      if (!mounted) return;
      // Aquí no se puede elegir otra hora: se vuelve al paso 2, que avisa y
      // recarga la agenda.
      navegador.pop(ResultadoIdentificacion.horarioTomado);
    } catch (_) {
      if (!mounted) return;
      setState(() => _guardando = false);
      mensajero.showSnackBar(
        const SnackBar(
          content: Text('No pudimos guardar la cita. Intenta de nuevo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final booking = widget.booking;

    return Scaffold(
      appBar: AppBar(title: const Text('PASO 03 DE 03')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          Text('¿Quién\nreserva?', style: textTheme.displaySmall),
          const SizedBox(height: 12),
          Text(
            'Con tu celular te reconocemos y te escribimos la tarde anterior '
            'para recordarte la cita.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 28),
          TextField(
            controller: _nombre,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Tu nombre',
              border: const OutlineInputBorder(),
              errorText: _errorNombre,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _telefono,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            // Deja escribir el número como cada quien lo tenga en la cabeza:
            // con espacios, con +57 o sin nada.
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9 +()-]')),
            ],
            decoration: InputDecoration(
              labelText: 'Tu celular',
              hintText: '300 111 2233',
              border: const OutlineInputBorder(),
              errorText: _errorTelefono,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _mascota,
            textCapitalization: TextCapitalization.words,
            onSubmitted: (_) => _guardando ? null : _reservar(),
            decoration: InputDecoration(
              labelText: 'Nombre de tu mascota',
              border: const OutlineInputBorder(),
              errorText: _errorMascota,
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TU CITA', style: AppTheme.sectionLabel),
                        const SizedBox(height: 2),
                        Text(
                          '${formatLongDate(booking.date)}, '
                          '${formatHour(booking.startMinutes)}',
                          style: textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    formatCop(booking.price(ServiceCatalog.todos)),
                    style: textTheme.headlineSmall,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _guardando ? null : _reservar,
                  child: Text(_guardando ? 'Reservando…' : 'Reservar cita'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
