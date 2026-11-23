import 'package:flutter/material.dart';

import '../../../core/format/phone.dart';
import '../../booking/models/cliente_reserva.dart';
import '../models/customer_entry.dart';
import '../models/pet_record.dart';

/// Lo que devuelve el formulario de contacto: ya validado y con el teléfono
/// en E.164.
class ContactoEditado {
  const ContactoEditado({required this.nombre, required this.telefono});

  final String nombre;
  final String telefono;
}

/// Pide el nombre y el teléfono corregidos. Nulo si se cierra sin guardar.
///
/// Las dos cosas son obligatorias a propósito: con alguna vacía, el perfil
/// queda incompleto y la próxima reserva del cliente se las vuelve a pedir y
/// pisaría la corrección.
Future<ContactoEditado?> editarContacto(
  BuildContext context, {
  required CustomerEntry cliente,
}) =>
    showDialog<ContactoEditado>(
      context: context,
      builder: (_) => _FormularioContacto(cliente: cliente),
    );

class _FormularioContacto extends StatefulWidget {
  const _FormularioContacto({required this.cliente});

  final CustomerEntry cliente;

  @override
  State<_FormularioContacto> createState() => _FormularioContactoState();
}

class _FormularioContactoState extends State<_FormularioContacto> {
  late final _nombre = TextEditingController(text: widget.cliente.nombre ?? '');
  late final _telefono = TextEditingController(
    text: widget.cliente.telefono == null
        ? ''
        : formatTelefono(widget.cliente.telefono!),
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
    // El mismo criterio que la hoja de contacto de la reserva.
    final telefono = normalizarTelefono(_telefono.text);
    setState(() {
      _errorNombre = nombre.isEmpty ? 'Escribe el nombre del tutor.' : null;
      _errorTelefono =
          telefono == null ? 'Escribe un celular colombiano.' : null;
    });
    if (nombre.isEmpty || telefono == null) return;
    Navigator.of(context).pop(
      ContactoEditado(nombre: nombre, telefono: telefono),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar contacto'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('contacto-nombre'),
            controller: _nombre,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Nombre',
              errorText: _errorNombre,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('contacto-telefono'),
            controller: _telefono,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Celular',
              errorText: _errorTelefono,
            ),
            onSubmitted: (_) => _guardar(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }
}

/// Pide la ficha de una mascota: nueva si [actual] es nulo, corregida si no.
/// Nulo si se cierra sin guardar. No hay forma de borrarla desde aquí.
Future<PetRecord?> editarMascota(
  BuildContext context, {
  required String duenoId,
  PetRecord? actual,
}) =>
    showDialog<PetRecord>(
      context: context,
      builder: (_) => _FormularioMascota(duenoId: duenoId, actual: actual),
    );

class _FormularioMascota extends StatefulWidget {
  const _FormularioMascota({required this.duenoId, this.actual});

  final String duenoId;
  final PetRecord? actual;

  @override
  State<_FormularioMascota> createState() => _FormularioMascotaState();
}

class _FormularioMascotaState extends State<_FormularioMascota> {
  late final _nombre = TextEditingController(text: widget.actual?.nombre ?? '');
  late final _raza = TextEditingController(text: widget.actual?.raza ?? '');
  late final _edad =
      TextEditingController(text: widget.actual?.edadAnios?.toString() ?? '');
  late final _peso = TextEditingController(
    text: widget.actual?.pesoKg?.toString().replaceAll('.', ',') ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _raza.dispose();
    _edad.dispose();
    _peso.dispose();
    super.dispose();
  }

  void _guardar() {
    final edadTexto = _edad.text.trim();
    final pesoTexto = _peso.text.trim().replaceAll(',', '.');
    final edad = edadTexto.isEmpty ? null : int.tryParse(edadTexto);
    final peso = pesoTexto.isEmpty ? null : double.tryParse(pesoTexto);

    if (edadTexto.isNotEmpty && edad == null) {
      setState(() => _error = 'La edad va en años, sin decimales.');
      return;
    }
    if (pesoTexto.isNotEmpty && peso == null) {
      setState(() => _error = 'Escribe el peso en kilos, por ejemplo 12,5.');
      return;
    }

    final error = validarMascota(
      nombre: _nombre.text,
      edadAnios: edad,
      pesoKg: peso,
    );
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    final raza = _raza.text.trim();
    Navigator.of(context).pop(
      PetRecord(
        id: widget.actual?.id,
        duenoId: widget.duenoId,
        nombre: _nombre.text.trim(),
        raza: raza.isEmpty ? null : raza,
        edadAnios: edad,
        // La columna guarda un decimal.
        pesoKg: peso == null ? null : (peso * 10).roundToDouble() / 10,
        nota: widget.actual?.nota,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.actual == null ? 'Registrar mascota' : 'Editar ficha'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('mascota-nombre'),
              controller: _nombre,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('mascota-raza'),
              controller: _raza,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Raza (opcional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('mascota-edad'),
              controller: _edad,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Edad en años (opcional)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('mascota-peso'),
              controller: _peso,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Peso en kg (opcional)',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }
}

/// Pide los datos de un cliente nuevo para agendarle una cita: el mismo
/// paso 3 que ve el cliente en la app. Nulo si se cierra sin guardar.
///
/// Si el celular ya es de un cliente, la base usa ese cliente y no le cambia
/// el nombre; aquí no hace falta comprobarlo.
Future<ClienteReserva?> pedirClienteNuevo(BuildContext context) =>
    showDialog<ClienteReserva>(
      context: context,
      builder: (_) => const _FormularioClienteNuevo(),
    );

class _FormularioClienteNuevo extends StatefulWidget {
  const _FormularioClienteNuevo();

  @override
  State<_FormularioClienteNuevo> createState() =>
      _FormularioClienteNuevoState();
}

class _FormularioClienteNuevoState extends State<_FormularioClienteNuevo> {
  final _nombre = TextEditingController();
  final _telefono = TextEditingController();
  final _mascota = TextEditingController();
  String? _errorNombre;
  String? _errorTelefono;
  String? _errorMascota;

  @override
  void dispose() {
    _nombre.dispose();
    _telefono.dispose();
    _mascota.dispose();
    super.dispose();
  }

  void _guardar() {
    final nombre = _nombre.text.trim();
    final telefono = normalizarTelefono(_telefono.text);
    final mascota = _mascota.text.trim();
    setState(() {
      _errorNombre = nombre.isEmpty ? 'Escribe el nombre del dueño.' : null;
      _errorTelefono =
          telefono == null ? 'Escribe un celular colombiano.' : null;
      _errorMascota =
          mascota.isEmpty ? 'Escribe el nombre de la mascota.' : null;
    });
    if (nombre.isEmpty || telefono == null || mascota.isEmpty) return;
    Navigator.of(context).pop(
      ClienteReserva(nombre: nombre, telefono: telefono, mascota: mascota),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cliente nuevo'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('nuevo-nombre'),
              controller: _nombre,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Nombre del dueño',
                errorText: _errorNombre,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('nuevo-telefono'),
              controller: _telefono,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Celular',
                hintText: '300 111 2233',
                errorText: _errorTelefono,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('nuevo-mascota'),
              controller: _mascota,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Nombre de la mascota',
                errorText: _errorMascota,
              ),
              onSubmitted: (_) => _guardar(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(onPressed: _guardar, child: const Text('Continuar')),
      ],
    );
  }
}

/// Pide el texto de la nota interna. Nulo si se cierra sin guardar; vacío
/// si se borró el texto, que es como se quita una nota.
Future<String?> editarNotaMascota(
  BuildContext context, {
  required PetRecord mascota,
}) {
  final controlador = TextEditingController(text: mascota.nota?.texto ?? '');
  return showDialog<String>(
    context: context,
    builder: (contexto) => AlertDialog(
      title: Text('Nota interna de ${mascota.nombre}'),
      content: TextField(
        key: const Key('nota-mascota'),
        controller: controlador,
        autofocus: true,
        minLines: 3,
        maxLines: 6,
        decoration: const InputDecoration(
          hintText: 'Solo la estética la ve. El tutor no.',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(contexto).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(contexto).pop(controlador.text.trim()),
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
}
