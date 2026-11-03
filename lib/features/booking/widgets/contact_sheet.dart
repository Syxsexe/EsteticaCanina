import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/format/phone.dart';
import '../../../core/theme/app_colors.dart';
import '../models/customer_profile.dart';

/// Pide nombre y teléfono, una sola vez.
///
/// Aparece como hoja y no como un tercer paso a propósito: la app promete
/// reservar "en dos pasos", y quien ya reservó una vez no vuelve a verla
/// porque sus datos quedaron guardados. Convertirlo en pantalla fija
/// rompería la promesa para todo el mundo por culpa de la primera vez.
///
/// Devuelve el perfil si se completó, o `null` si se cerró sin guardar —y
/// en ese caso la reserva no se hace: una cita sin teléfono no se puede
/// confirmar.
Future<CustomerProfile?> pedirDatosDeContacto(
  BuildContext context, {
  required CustomerProfile actual,
}) {
  return showModalBottomSheet<CustomerProfile>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _ContactSheet(actual: actual),
  );
}

class _ContactSheet extends StatefulWidget {
  const _ContactSheet({required this.actual});

  final CustomerProfile actual;

  @override
  State<_ContactSheet> createState() => _ContactSheetState();
}

class _ContactSheetState extends State<_ContactSheet> {
  late final TextEditingController _nombre =
      TextEditingController(text: widget.actual.nombre ?? '');
  late final TextEditingController _telefono = TextEditingController(
    text: widget.actual.telefono ?? '',
  );

  String? _errorNombre;
  String? _errorTelefono;

  @override
  void dispose() {
    _nombre.dispose();
    _telefono.dispose();
    super.dispose();
  }

  void _guardar() {
    final nombre = _nombre.text.trim();
    final telefono = normalizarTelefono(_telefono.text);

    setState(() {
      _errorNombre = nombre.isEmpty ? 'Dinos cómo te llamas.' : null;
      _errorTelefono =
          telefono == null ? 'Escribe un celular colombiano.' : null;
    });

    if (nombre.isEmpty || telefono == null) return;
    Navigator.of(context).pop(
      CustomerProfile(nombre: nombre, telefono: telefono),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      // El teclado tapa la hoja si no se le deja sitio.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('¿A quién llamamos?', style: textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Te escribimos la tarde anterior para recordarte la cita. '
                'Solo lo pedimos esta vez.',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nombre,
                textCapitalization: TextCapitalization.words,
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
                // Deja escribir el número como cada quien lo tenga en la
                // cabeza: con espacios, con +57 o sin nada.
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9 +()-]')),
                ],
                onSubmitted: (_) => _guardar(),
                decoration: InputDecoration(
                  labelText: 'Tu celular',
                  hintText: '300 111 2233',
                  border: const OutlineInputBorder(),
                  errorText: _errorTelefono,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _guardar,
                child: const Text('Confirmar la cita'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
