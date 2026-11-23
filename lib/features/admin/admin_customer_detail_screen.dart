import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/format/phone.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../booking/data/availability_repository.dart';
import 'admin_appointment_form_screen.dart';
import 'data/admin_appointment_repository.dart';
import 'data/customer_directory_repository.dart';
import 'data/foto_mascota_service.dart';
import 'models/admin_observation.dart';
import 'models/agenda_entry.dart';
import 'models/customer_entry.dart';
import 'models/pet_record.dart';
import 'widgets/customer_forms.dart';

/// La ficha de un cliente: contacto, mascotas, citas y observaciones.
///
/// La estética corrige aquí el contacto y las fichas de las mascotas, pero
/// no borra ni clientes ni mascotas. Las observaciones y las notas internas
/// de mascota solo salen aquí. El cliente no las ve porque sus tablas no
/// tienen política para él, no porque esta pantalla las esconda.
class AdminCustomerDetailScreen extends StatefulWidget {
  const AdminCustomerDetailScreen({
    super.key,
    required this.cliente,
    required this.customersRepository,
    required this.appointmentsRepository,
    this.availabilityRepository,
    this.today,
    this.fotoService,
  });

  final CustomerEntry cliente;
  final CustomerDirectoryRepository customersRepository;
  final AdminAppointmentRepository appointmentsRepository;
  final AvailabilityRepository? availabilityRepository;
  final DateTime? today;

  /// Quién elige y convierte la foto de una mascota. Se inyecta en las
  /// pruebas; en la app es el de los plugins.
  final FotoMascotaService? fotoService;

  @override
  State<AdminCustomerDetailScreen> createState() =>
      _AdminCustomerDetailScreenState();
}

class _AdminCustomerDetailScreenState
    extends State<AdminCustomerDetailScreen> {
  /// El cliente tal como se ve ahora: cambia al corregir el contacto.
  late CustomerEntry _cliente = widget.cliente;

  List<AgendaEntry>? _citas;
  List<PetRecord>? _mascotas;
  List<AdminObservation>? _observaciones;
  Object? _fallo;

  /// Mientras se elimina, el botón no acepta otro toque.
  bool _eliminando = false;

  /// Las fotos ya descargadas, por ruta. La ruta cambia con cada foto nueva,
  /// así que una entrada nunca queda vieja.
  final Map<String, Uint8List> _fotos = {};

  /// Las rutas que no se pudieron descargar: se pinta el marcador.
  final Set<String> _fotosFallidas = {};

  /// Las mascotas cuya foto se está subiendo o quitando.
  final Set<String> _guardandoFoto = {};

  FotoMascotaService get _fotoService =>
      widget.fotoService ?? defaultFotoMascotaService();

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  /// Descarga las fotos que todavía no estén en memoria. Un fallo solo deja
  /// el marcador de esa mascota; el resto del detalle sigue.
  Future<void> _cargarFotos(List<PetRecord> mascotas) async {
    for (final mascota in mascotas) {
      final ruta = mascota.fotoPath;
      if (ruta == null || _fotos.containsKey(ruta)) continue;
      try {
        final bytes = await widget.customersRepository.fotoDe(ruta);
        if (!mounted) return;
        setState(() => _fotos[ruta] = bytes);
      } catch (_) {
        if (!mounted) return;
        setState(() => _fotosFallidas.add(ruta));
      }
    }
  }

  /// Con foto, se abre en grande para verla en detalle, y desde ahí se
  /// cambia o se quita. Sin foto (o si no cargó), las opciones directamente.
  Future<void> _tocarFoto(PetRecord mascota) async {
    final ruta = mascota.fotoPath;
    final bytes = ruta == null ? null : _fotos[ruta];
    if (bytes == null) return _opcionesDeFoto(mascota);

    final eleccion = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _VisorFoto(foto: bytes, nombre: mascota.nombre),
      ),
    );
    if (!mounted) return;
    if (eleccion == 'elegir') await _elegirFoto(mascota);
    if (eleccion == 'quitar') await _quitarFoto(mascota);
  }

  Future<void> _opcionesDeFoto(PetRecord mascota) async {
    final tieneFoto = mascota.fotoPath != null;
    final eleccion = await showModalBottomSheet<String>(
      context: context,
      builder: (contexto) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(tieneFoto ? 'Cambiar foto' : 'Elegir foto'),
              onTap: () => Navigator.of(contexto).pop('elegir'),
            ),
            if (tieneFoto)
              ListTile(
                leading: const Icon(Icons.hide_image_outlined),
                title: const Text('Quitar foto'),
                onTap: () => Navigator.of(contexto).pop('quitar'),
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (eleccion == 'elegir') await _elegirFoto(mascota);
    if (eleccion == 'quitar') await _quitarFoto(mascota);
  }

  Future<void> _elegirFoto(PetRecord mascota) async {
    final mensajero = ScaffoldMessenger.of(context);
    final Uint8List? original;
    try {
      original = await _fotoService.elegir();
    } catch (_) {
      mensajero.showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el selector de fotos.')),
      );
      return;
    }
    // Cerró el selector sin elegir: la foto no cambia.
    if (original == null || !mounted) return;

    setState(() => _guardandoFoto.add(mascota.id!));
    try {
      final webp = await _fotoService.aWebp(original);
      final guardada =
          await widget.customersRepository.guardarFotoMascota(mascota, webp);
      if (!mounted) return;
      setState(() {
        _guardandoFoto.remove(mascota.id);
        // Lo recién subido ya se tiene en memoria: no hace falta bajarlo.
        if (guardada.fotoPath != null) _fotos[guardada.fotoPath!] = webp;
        _mascotas = [
          for (final m in _mascotas ?? const <PetRecord>[])
            if (m.id == guardada.id) guardada else m,
        ];
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _guardandoFoto.remove(mascota.id));
      mensajero.showSnackBar(SnackBar(
        content: Text(switch (error) {
          ArchivoNoLegibleException() =>
            'No pudimos usar ese archivo como imagen.',
          WebpNoDisponibleException() =>
            'Este navegador no puede convertir fotos. Usa Chrome, Edge o Firefox.',
          _ => 'No se pudo guardar la foto.',
        }),
      ));
    }
  }

  Future<void> _quitarFoto(PetRecord mascota) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: Text('Quitar la foto de ${mascota.nombre}'),
        content: const Text('La foto se borra y no se puede recuperar.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('Volver'),
          ),
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    final mensajero = ScaffoldMessenger.of(context);
    setState(() => _guardandoFoto.add(mascota.id!));
    try {
      final sinFoto =
          await widget.customersRepository.quitarFotoMascota(mascota);
      if (!mounted) return;
      setState(() {
        _guardandoFoto.remove(mascota.id);
        _mascotas = [
          for (final m in _mascotas ?? const <PetRecord>[])
            if (m.id == sinFoto.id) sinFoto else m,
        ];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _guardandoFoto.remove(mascota.id));
      mensajero.showSnackBar(
        const SnackBar(content: Text('No se pudo quitar la foto.')),
      );
    }
  }

  Future<void> _cargar() async {
    setState(() {
      _citas = null;
      _mascotas = null;
      _observaciones = null;
      _fallo = null;
    });
    try {
      // Las citas se piden ya filtradas por cliente: no se baja el
      // historial entero de la estética para quedarse con unas pocas.
      final resultados = await Future.wait([
        widget.appointmentsRepository.historialDe(_cliente.id),
        widget.customersRepository.mascotasDe(_cliente.id),
        widget.customersRepository.observaciones(_cliente.id),
      ]);
      if (!mounted) return;
      setState(() {
        _citas = resultados[0] as List<AgendaEntry>;
        _mascotas = resultados[1] as List<PetRecord>;
        _observaciones = resultados[2] as List<AdminObservation>;
      });
      _cargarFotos(_mascotas!);
    } catch (error) {
      if (!mounted) return;
      setState(() => _fallo = error);
    }
  }

  /// Con las mascotas al día, para que el formulario de cita las ofrezca.
  CustomerEntry get _clienteConMascotas => CustomerEntry(
        id: _cliente.id,
        nombre: _cliente.nombre,
        telefono: _cliente.telefono,
        citas: _cliente.citas,
        mascotas: [
          for (final mascota in _mascotas ?? const <PetRecord>[])
            if (mascota.id != null)
              PetRef(id: mascota.id!, nombre: mascota.nombre),
        ],
      );

  Future<void> _editarContacto() async {
    final editado = await editarContacto(context, cliente: _cliente);
    if (editado == null || !mounted) return;

    final mensajero = ScaffoldMessenger.of(context);
    try {
      await widget.customersRepository.actualizarContacto(
        clienteId: _cliente.id,
        nombre: editado.nombre,
        telefono: editado.telefono,
      );
      if (!mounted) return;
      setState(() {
        _cliente = CustomerEntry(
          id: _cliente.id,
          nombre: editado.nombre,
          telefono: editado.telefono,
          citas: _cliente.citas,
          mascotas: _cliente.mascotas,
        );
      });
    } catch (_) {
      mensajero.showSnackBar(
        const SnackBar(content: Text('No se pudo guardar el contacto.')),
      );
    }
  }

  Future<void> _editarMascota([PetRecord? actual]) async {
    final ficha = await editarMascota(
      context,
      duenoId: _cliente.id,
      actual: actual,
    );
    if (ficha == null || !mounted) return;

    final mensajero = ScaffoldMessenger.of(context);
    try {
      await widget.customersRepository.guardarMascota(ficha);
      if (!mounted) return;
      await _cargar();
    } catch (_) {
      mensajero.showSnackBar(
        const SnackBar(content: Text('No se pudo guardar la mascota.')),
      );
    }
  }

  Future<void> _editarNota(PetRecord mascota) async {
    final texto = await editarNotaMascota(context, mascota: mascota);
    if (texto == null || !mounted) return;

    final mensajero = ScaffoldMessenger.of(context);
    try {
      await widget.customersRepository.guardarNotaMascota(
        mascotaId: mascota.id!,
        texto: texto,
      );
      if (!mounted) return;
      await _cargar();
    } catch (_) {
      mensajero.showSnackBar(
        const SnackBar(content: Text('No se pudo guardar la nota.')),
      );
    }
  }

  Future<void> _nuevaCita() async {
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdminAppointmentFormScreen(
          appointmentsRepository: widget.appointmentsRepository,
          availabilityRepository: widget.availabilityRepository!,
          customersRepository: widget.customersRepository,
          cliente: _clienteConMascotas,
          hoy: widget.today,
        ),
      ),
    );
    if (guardado == true && mounted) await _cargar();
  }

  Future<void> _editarObservacion({AdminObservation? observacion}) async {
    final controlador =
        TextEditingController(text: observacion?.texto ?? '');
    final texto = await showDialog<String>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: Text(observacion == null ? 'Nueva observación' : 'Editar observación'),
        content: TextField(
          controller: controlador,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: 'Solo la estética puede ver esto.',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final valor = controlador.text.trim();
              if (valor.isNotEmpty) Navigator.of(contexto).pop(valor);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (texto == null || !mounted) return;

    final mensajero = ScaffoldMessenger.of(context);
    try {
      await widget.customersRepository.guardarObservacion(
        id: observacion?.id,
        clienteId: _cliente.id,
        texto: texto,
      );
      if (!mounted) return;
      await _cargar();
    } catch (_) {
      mensajero.showSnackBar(
        const SnackBar(content: Text('No se pudo guardar la observación.')),
      );
    }
  }

  Future<void> _borrarObservacion(AdminObservation observacion) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Borrar observación'),
        content: const Text('Esta nota desaparece para siempre.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('Volver'),
          ),
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    final mensajero = ScaffoldMessenger.of(context);
    try {
      await widget.customersRepository.eliminarObservacion(observacion.id);
      if (!mounted) return;
      await _cargar();
    } catch (_) {
      mensajero.showSnackBar(
        const SnackBar(content: Text('No se pudo borrar la observación.')),
      );
    }
  }

  Future<void> _abrirCita(AgendaEntry cita) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdminAppointmentFormScreen(
          appointmentsRepository: widget.appointmentsRepository,
          availabilityRepository: widget.availabilityRepository!,
          customersRepository: widget.customersRepository,
          cita: cita,
          cliente: _clienteConMascotas,
          hoy: widget.today,
        ),
      ),
    );
    if (mounted) await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CLIENTE'),
        actions: [
          IconButton(
            onPressed: _eliminando ? null : _eliminar,
            icon: const Icon(Icons.person_remove_outlined),
            tooltip: 'Eliminar cliente',
          ),
        ],
      ),
      body: _cuerpo(),
    );
  }

  /// Anonimiza al cliente tras confirmarlo. Las cifras del negocio se
  /// conservan; los datos de la persona, no.
  Future<void> _eliminar() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: Text('Eliminar a ${_cliente.nombreVisible}'),
        content: const Text(
          'Se borran su nombre, su celular, sus mascotas con sus notas y sus '
          'observaciones. Sus citas futuras se cancelan.\n\n'
          'Sus citas pasadas se conservan como "Cliente eliminado", así que '
          'los ingresos y las estadísticas no cambian.\n\n'
          'No se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('Volver'),
          ),
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    setState(() => _eliminando = true);
    final mensajero = ScaffoldMessenger.of(context);
    final navegador = Navigator.of(context);
    try {
      await widget.customersRepository.eliminarCliente(_cliente.id);
      if (!mounted) return;
      // La lista de Clientes recarga al volver y ya no lo muestra.
      navegador.pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _eliminando = false);
      mensajero.showSnackBar(
        const SnackBar(content: Text('No se pudo eliminar el cliente.')),
      );
    }
  }

  Widget _cuerpo() {
    if (_fallo != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'No pudimos traer la ficha del cliente.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: _cargar, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    if (_citas == null || _mascotas == null || _observaciones == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final cliente = _cliente;
    final textTheme = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cliente.nombreVisible,
                          style: textTheme.headlineSmall),
                      const SizedBox(height: 4),
                      Text(
                        cliente.telefono == null
                            ? cliente.telefonoVisible
                            : formatTelefono(cliente.telefono!),
                        style: textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _citas!.length == 1
                            ? '1 cita registrada'
                            : '${_citas!.length} citas registradas',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _editarContacto,
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Editar contacto',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text('MASCOTAS', style: AppTheme.sectionLabel),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _editarMascota(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Registrar'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (_mascotas!.isEmpty)
            Text(
              'Sin mascotas registradas. Registra la primera.',
              style: textTheme.bodySmall,
            )
          else
            for (final mascota in _mascotas!)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _FichaMascota(
                  mascota: mascota,
                  foto: mascota.fotoPath == null
                      ? null
                      : _fotos[mascota.fotoPath],
                  cargandoFoto: _guardandoFoto.contains(mascota.id) ||
                      (mascota.fotoPath != null &&
                          !_fotos.containsKey(mascota.fotoPath) &&
                          !_fotosFallidas.contains(mascota.fotoPath)),
                  onFoto: () => _tocarFoto(mascota),
                  onEditar: () => _editarMascota(mascota),
                  onNota: () => _editarNota(mascota),
                ),
              ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text('CITAS', style: AppTheme.sectionLabel),
              const Spacer(),
              if (widget.availabilityRepository != null)
                TextButton.icon(
                  onPressed: _nuevaCita,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nueva cita'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_citas!.isEmpty)
            Text(
              'Este cliente todavía no tiene citas.',
              style: textTheme.bodySmall,
            )
          else
            for (final cita in _citas!)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: widget.availabilityRepository == null
                      ? null
                      : () => _abrirCita(cita),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${formatLongDate(cita.empieza)} · '
                                '${formatHour(cita.inicioEnMinutos)}',
                                style: textTheme.bodyMedium,
                              ),
                              Text(
                                '${cita.servicios.join(' · ')} · '
                                '${cita.estado.rotulo}',
                                style: textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          formatCop(cita.totalCop),
                          style: textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text('OBSERVACIONES', style: AppTheme.sectionLabel),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _editarObservacion(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Añadir'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (_observaciones!.isEmpty)
            Text(
              'Sin observaciones. Solo la estética las ve.',
              style: textTheme.bodySmall,
            )
          else
            for (final observacion in _observaciones!)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(observacion.texto, style: textTheme.bodyMedium),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            formatLongDate(observacion.creadaEn),
                            style: textTheme.bodySmall,
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () =>
                                _editarObservacion(observacion: observacion),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            tooltip: 'Editar',
                          ),
                          IconButton(
                            onPressed: () => _borrarObservacion(observacion),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            tooltip: 'Borrar',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// Una mascota con su ficha y su nota interna. Sin acción de borrar.
class _FichaMascota extends StatelessWidget {
  const _FichaMascota({
    required this.mascota,
    required this.foto,
    required this.cargandoFoto,
    required this.onFoto,
    required this.onEditar,
    required this.onNota,
  });

  final PetRecord mascota;

  /// Los bytes WebP de su foto, o nulo si no tiene o no cargó.
  final Uint8List? foto;

  /// Mientras se descarga, se sube o se quita la foto.
  final bool cargandoFoto;

  final VoidCallback onFoto;
  final VoidCallback onEditar;
  final VoidCallback onNota;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final nota = mascota.nota;
    final tieneNota = nota != null && nota.texto.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Miniatura(
                foto: foto,
                cargando: cargandoFoto,
                onTap: onFoto,
                nombre: mascota.nombre,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(mascota.nombre, style: textTheme.titleMedium),
              ),
              IconButton(
                onPressed: onEditar,
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Editar ficha',
              ),
              IconButton(
                onPressed: onNota,
                icon: const Icon(Icons.sticky_note_2_outlined, size: 18),
                tooltip: 'Nota interna',
              ),
            ],
          ),
          Text(
            '${mascota.razaVisible} · ${mascota.edadVisible} · '
            '${mascota.pesoVisible}',
            style: textTheme.bodySmall,
          ),
          if (tieneNota) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('NOTA INTERNA', style: AppTheme.sectionLabel),
                  const SizedBox(height: 4),
                  Text(nota.texto, style: textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Text(
                    // Antes del cambio la nota la escribía el tutor; esas
                    // llegan sin autor.
                    '${nota.autorId == null ? 'Heredada de la ficha del tutor' : 'Por la estética'}'
                    ' · ${formatLongDate(nota.actualizadaEn)}',
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// La foto de la mascota en pequeño, o una huella si no tiene. Tocarla abre
/// las opciones de foto.
class _Miniatura extends StatelessWidget {
  const _Miniatura({
    required this.foto,
    required this.cargando,
    required this.onTap,
    required this.nombre,
  });

  final Uint8List? foto;
  final bool cargando;
  final VoidCallback onTap;
  final String nombre;

  @override
  Widget build(BuildContext context) {
    final bytes = foto;
    return Tooltip(
      message: 'Foto de $nombre',
      child: InkWell(
        onTap: cargando ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 64,
            height: 64,
            color: AppColors.primarySoft,
            alignment: Alignment.center,
            child: cargando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : bytes == null
                    ? const Icon(
                        Icons.pets,
                        key: Key('sin-foto'),
                        color: AppColors.primaryDark,
                      )
                    : Image.memory(
                        bytes,
                        key: const Key('foto-mascota'),
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        // Bytes que no se pueden pintar: la huella.
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.pets,
                          color: AppColors.primaryDark,
                        ),
                      ),
          ),
        ),
      ),
    );
  }
}

/// La foto de una mascota a pantalla completa, para verla en detalle.
///
/// Se amplía pellizcando o con doble toque (que vuelve a su tamaño con otro
/// doble toque). Cierra devolviendo `'elegir'` o `'quitar'` si se pidió
/// cambiar o quitar la foto, o nulo si solo se miró.
class _VisorFoto extends StatefulWidget {
  const _VisorFoto({required this.foto, required this.nombre});

  final Uint8List foto;
  final String nombre;

  @override
  State<_VisorFoto> createState() => _VisorFotoState();
}

class _VisorFotoState extends State<_VisorFoto> {
  static const double _ampliacion = 2.5;

  final _transformacion = TransformationController();

  /// Dónde fue el doble toque, para ampliar justo ahí.
  Offset _puntoDobleToque = Offset.zero;

  @override
  void dispose() {
    _transformacion.dispose();
    super.dispose();
  }

  void _alternarAmpliacion() {
    final ampliada = _transformacion.value.getMaxScaleOnAxis() > 1.01;
    if (ampliada) {
      _transformacion.value = Matrix4.identity();
      return;
    }
    // Escalar alrededor del punto tocado: llevarlo al origen, escalar y
    // devolverlo.
    final punto = _puntoDobleToque;
    _transformacion.value = Matrix4.identity()
      ..translateByDouble(
        -punto.dx * (_ampliacion - 1),
        -punto.dy * (_ampliacion - 1),
        0,
        1,
      )
      ..scaleByDouble(_ampliacion, _ampliacion, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.nombre),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).pop('elegir'),
            icon: const Icon(Icons.photo_library_outlined),
            tooltip: 'Cambiar foto',
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop('quitar'),
            icon: const Icon(Icons.hide_image_outlined),
            tooltip: 'Quitar foto',
          ),
        ],
      ),
      body: GestureDetector(
        onDoubleTapDown: (detalles) =>
            _puntoDobleToque = detalles.localPosition,
        onDoubleTap: _alternarAmpliacion,
        child: InteractiveViewer(
          key: const Key('visor-foto'),
          transformationController: _transformacion,
          minScale: 1,
          maxScale: 5,
          child: SizedBox.expand(
            child: Image.memory(
              widget.foto,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => const Center(
                child: Icon(Icons.pets, color: Colors.white54, size: 64),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
