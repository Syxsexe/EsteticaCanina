import 'package:flutter/material.dart';

import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/format/phone.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/time/salon_time.dart';
import '../booking/data/availability_repository.dart';
import '../booking/data/booking_repository.dart';
import '../booking/data/service_catalog.dart';
import '../booking/models/cliente_reserva.dart';
import '../booking/models/schedule.dart';
import '../booking/models/service.dart';
import 'data/admin_appointment_repository.dart';
import 'data/customer_directory_repository.dart';
import 'models/agenda_entry.dart';
import 'models/customer_entry.dart';
import 'widgets/customer_forms.dart';

/// Crear una cita o corregir una existente desde el panel.
///
/// El precio y la duración no se envían: se marcan los servicios y Postgres
/// los vuelve a calcular. La pantalla solo muestra la suma para que la
/// estética sepa qué está vendiendo.
class AdminAppointmentFormScreen extends StatefulWidget {
  const AdminAppointmentFormScreen({
    super.key,
    required this.appointmentsRepository,
    required this.availabilityRepository,
    this.customersRepository,
    this.cita,
    this.cliente,
    this.hoy,
    this.diaInicial,
  });

  final AdminAppointmentRepository appointmentsRepository;
  final AvailabilityRepository availabilityRepository;
  final CustomerDirectoryRepository? customersRepository;

  /// Si viene, se edita esa cita; si no, se crea una nueva.
  final AgendaEntry? cita;

  /// El cliente ya elegido cuando se llega desde el directorio.
  final CustomerEntry? cliente;

  final DateTime? hoy;

  /// Al crear, el día que se abre elegido: el que muestra la agenda. Si ya
  /// pasó, se abre en hoy, porque no se reserva hacia atrás. En edición se
  /// ignora y manda el día de la cita.
  final DateTime? diaInicial;

  @override
  State<AdminAppointmentFormScreen> createState() =>
      _AdminAppointmentFormScreenState();
}

class _AdminAppointmentFormScreenState
    extends State<AdminAppointmentFormScreen> {
  final _busqueda = TextEditingController();
  final _notas = TextEditingController();

  CustomerEntry? _cliente;

  /// Un cliente que no está en el directorio, con su celular y su mascota.
  /// Excluye a [_cliente]: se elige uno o se escribe el otro.
  ClienteReserva? _clienteNuevo;

  List<CustomerEntry> _resultados = const [];
  bool _buscando = false;

  String? _mascotaId;
  Service? _principal;
  final Set<String> _extras = {};

  List<DaySchedule>? _dias;
  Object? _falloDias;
  DaySchedule? _dia;
  int? _inicio;
  int? _inicioOriginal;

  EstadoCita _estado = EstadoCita.reservada;

  bool _guardando = false;
  String? _error;

  bool get _editando => widget.cita != null;

  List<Service> get _elegidos => [
    ?_principal,
    for (final s in ServiceCatalog.extras)
      if (_extras.contains(s.id)) s,
  ];

  int get _minutos => _elegidos.fold(0, (total, s) => total + s.minutes);
  int get _total => _elegidos.fold(0, (total, s) => total + s.price);

  @override
  void initState() {
    super.initState();
    _cliente = widget.cliente;

    final cita = widget.cita;
    if (cita != null) {
      _principal = _servicioPorId(cita.servicioIds);
      for (final id in cita.servicioIds) {
        if (ServiceCatalog.extras.any((s) => s.id == id)) _extras.add(id);
      }
      _mascotaId = cita.mascotaId;
      _estado = cita.estado;
      _notas.text = cita.notasEstilista ?? '';
      _inicio = cita.inicioEnMinutos;
      _inicioOriginal = cita.inicioEnMinutos;
    }

    if (_cliente == null) _buscar('');
    _cargarDias();
  }

  @override
  void dispose() {
    _busqueda.dispose();
    _notas.dispose();
    super.dispose();
  }

  Service? _servicioPorId(List<String> ids) {
    for (final servicio in ServiceCatalog.principales) {
      if (ids.contains(servicio.id)) return servicio;
    }
    return null;
  }

  Future<void> _buscar(String texto) async {
    final repositorio = widget.customersRepository;
    if (repositorio == null) return;
    setState(() => _buscando = true);
    try {
      final clientes = await repositorio.clientes(busqueda: texto);
      if (!mounted) return;
      setState(() {
        _resultados = clientes;
        _buscando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _buscando = false);
    }
  }

  Future<void> _cargarDias() async {
    setState(() {
      _dias = null;
      _falloDias = null;
    });
    final desde = widget.cita?.empieza ?? _diaDeCreacion;
    try {
      final dias = await widget.availabilityRepository.daysFrom(desde);
      if (!mounted) return;
      setState(() {
        _dias = dias;
        _dia = _diaPara(dias);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _falloDias = error);
    }
  }

  /// El día con el que se abre una cita nueva: [AdminAppointmentFormScreen.
  /// diaInicial] si no ha pasado, y si no, hoy en la estética.
  DateTime get _diaDeCreacion {
    final base = widget.hoy ?? hoyEnLaEstetica();
    final hoy = DateTime(base.year, base.month, base.day);
    final pedido = widget.diaInicial;
    if (pedido == null) return hoy;
    final dia = DateTime(pedido.year, pedido.month, pedido.day);
    return dia.isBefore(hoy) ? hoy : dia;
  }

  /// En edición se abre el día de la cita. Al crear, el día pedido si está
  /// en la lista; si no, el primero con hueco.
  DaySchedule? _diaPara(List<DaySchedule> dias) {
    final cita = widget.cita;
    if (cita != null) {
      for (final dia in dias) {
        if (_mismoDia(dia.date, cita.empieza)) return dia;
      }
    } else if (widget.diaInicial != null) {
      final pedido = _diaDeCreacion;
      for (final dia in dias) {
        if (_mismoDia(dia.date, pedido)) return dia;
      }
    }
    for (final dia in dias) {
      if (dia.hasRoomFor(_minutos > 0 ? _minutos : 60)) return dia;
    }
    return dias.isEmpty ? null : dias.first;
  }

  static bool _mismoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _esHorarioOriginal(DaySchedule dia, int inicio) {
    final cita = widget.cita;
    return cita != null &&
        _inicioOriginal == inicio &&
        _mismoDia(dia.date, cita.empieza);
  }

  /// Las mascotas del cliente. Al editar sin la ficha cargada se conserva la
  /// que ya tenía la cita aunque no venga en la lista.
  List<PetRef> _mascotasDisponibles() {
    final mascotas = [...?_cliente?.mascotas];
    final cita = widget.cita;
    final id = cita?.mascotaId;
    if (id != null && !mascotas.any((m) => m.id == id)) {
      mascotas.add(PetRef(id: id, nombre: cita!.mascotaNombre ?? 'Mascota'));
    }
    return mascotas;
  }

  DateTime? get _empieza {
    final dia = _dia;
    final inicio = _inicio;
    if (dia == null || inicio == null) return null;
    final pared = DateTime(
      dia.date.year,
      dia.date.month,
      dia.date.day,
      inicio ~/ 60,
    ).add(Duration(minutes: inicio % 60));
    return desdeHoraEstetica(pared);
  }

  Future<void> _guardar() async {
    final cliente = _cliente;
    final clienteNuevo = _clienteNuevo;
    final empieza = _empieza;
    if ((cliente == null && clienteNuevo == null && !_editando) ||
        _principal == null ||
        empieza == null) {
      setState(() => _error = 'Elige cliente, servicio y horario.');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      if (_editando) {
        await widget.appointmentsRepository.editar(
          citaId: widget.cita!.id,
          empieza: empieza,
          mascotaId: _mascotaId,
          servicios: [for (final s in _elegidos) s.id],
          estado: _estado,
          notas: _notas.text.trim().isEmpty ? null : _notas.text.trim(),
        );
      } else if (clienteNuevo != null) {
        // Si el horario falla, la base no deja ni el cliente ni la mascota,
        // y aquí el formulario conserva lo escrito.
        await widget.appointmentsRepository.crearPorCelular(
          nombre: clienteNuevo.nombre,
          telefono: clienteNuevo.telefono,
          mascotaNombre: clienteNuevo.mascota,
          empieza: empieza,
          servicios: [for (final s in _elegidos) s.id],
        );
      } else {
        await widget.appointmentsRepository.crear(
          clienteId: cliente!.id,
          mascotaId: _mascotaId,
          empieza: empieza,
          servicios: [for (final s in _elegidos) s.id],
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on CitaRechazadaException catch (rechazo) {
      // La base dice por qué: se muestra tal cual y el formulario conserva
      // todo lo elegido para corregir solo lo que falla.
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = rechazo.motivo;
      });
    } on SlotTakenException {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = 'Ese horario lo acaban de tomar. Elige otro.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = 'No se pudo guardar. Revisa los datos e intenta de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editando ? 'EDITAR CITA' : 'NUEVA CITA')),
      body: _cliente == null && _clienteNuevo == null && !_editando
          ? _selectorDeCliente()
          : _formulario(),
    );
  }

  Future<void> _nuevoCliente() async {
    final nuevo = await pedirClienteNuevo(context);
    if (nuevo == null || !mounted) return;
    setState(() {
      _clienteNuevo = nuevo;
      _cliente = null;
      _mascotaId = null;
    });
  }

  Widget _selectorDeCliente() {
    final clientes = widget.customersRepository;
    if (clientes == null) {
      return _centrado('Falta el directorio de clientes.');
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _busqueda,
            onChanged: _buscar,
            decoration: const InputDecoration(
              labelText: 'Buscar cliente por nombre o teléfono',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _nuevoCliente,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Cliente nuevo'),
            ),
          ),
        ),
        if (_buscando) const LinearProgressIndicator(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _buscar(_busqueda.text),
            child: _resultados.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 48),
                      _centrado('No hay clientes con ese nombre o teléfono.'),
                    ],
                  )
                : ListView.separated(
                    itemCount: _resultados.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final cliente = _resultados[i];
                      return ListTile(
                        title: Text(cliente.nombreVisible),
                        subtitle: Text(
                          '${cliente.telefonoVisible} · '
                          '${cliente.citas} ${cliente.citas == 1 ? 'cita' : 'citas'}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => setState(() {
                          _cliente = cliente;
                          _mascotaId = null;
                        }),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _formulario() {
    final cliente = _cliente;
    final clienteNuevo = _clienteNuevo;
    final cita = widget.cita;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                clienteNuevo?.nombre ??
                    cliente?.nombreVisible ??
                    cita?.clienteNombre ??
                    'Cliente sin nombre',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                clienteNuevo != null
                    ? formatTelefono(clienteNuevo.telefono)
                    : cliente?.telefonoVisible ??
                          cita?.clienteTelefono ??
                          'Sin teléfono',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (clienteNuevo != null)
                Text(
                  // Si el celular ya es de alguien, la cita va a ese cliente.
                  'Cliente nuevo. Si el celular ya está registrado, la cita '
                  'queda a nombre de ese cliente.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (!_editando)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(() {
                      _cliente = null;
                      _clienteNuevo = null;
                    }),
                    child: const Text('Cambiar cliente'),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('MASCOTA', style: AppTheme.sectionLabel),
        const SizedBox(height: 8),
        if (clienteNuevo != null)
          Text(
            clienteNuevo.mascota,
            style: Theme.of(context).textTheme.bodyLarge,
          )
        else
          DropdownButtonFormField<String?>(
            initialValue: _mascotaId,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Sin perro registrado'),
              ),
              for (final mascota in _mascotasDisponibles())
                DropdownMenuItem<String?>(
                  value: mascota.id,
                  child: Text(mascota.nombre),
                ),
            ],
            onChanged: (valor) => setState(() => _mascotaId = valor),
          ),
        const SizedBox(height: 20),
        Text('SERVICIO PRINCIPAL', style: AppTheme.sectionLabel),
        const SizedBox(height: 8),
        RadioGroup<String>(
          groupValue: _principal?.id,
          onChanged: (valor) => setState(() {
            for (final servicio in ServiceCatalog.principales) {
              if (servicio.id == valor) _principal = servicio;
            }
          }),
          child: Column(
            children: [
              for (final servicio in ServiceCatalog.principales)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: RadioListTile<String>(
                    value: servicio.id,
                    title: Text(servicio.name),
                    subtitle: Text(
                      '${formatCop(servicio.price)} · '
                      '${formatDuration(servicio.minutes)}',
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text('EXTRAS', style: AppTheme.sectionLabel),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final extra in ServiceCatalog.extras)
              FilterChip(
                label: Text(extra.name),
                selected: _extras.contains(extra.id),
                onSelected: (marcado) => setState(() {
                  if (marcado) {
                    _extras.add(extra.id);
                  } else {
                    _extras.remove(extra.id);
                  }
                }),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text('DÍA', style: AppTheme.sectionLabel),
        const SizedBox(height: 8),
        _tiraDeDias(),
        const SizedBox(height: 16),
        Text('HORA', style: AppTheme.sectionLabel),
        const SizedBox(height: 8),
        _horasDisponibles(),
        if (_editando) ...[
          const SizedBox(height: 20),
          Text('ESTADO', style: AppTheme.sectionLabel),
          const SizedBox(height: 8),
          DropdownButtonFormField<EstadoCita>(
            initialValue: _estado,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: [
              for (final estado in EstadoCita.values)
                DropdownMenuItem(value: estado, child: Text(estado.rotulo)),
            ],
            onChanged: (valor) => setState(() => _estado = valor ?? _estado),
          ),
          const SizedBox(height: 20),
          Text('NOTA DE LA ESTILISTA', style: AppTheme.sectionLabel),
          const SizedBox(height: 8),
          TextField(
            controller: _notas,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Lo que conviene recordar de esta cita.',
              border: OutlineInputBorder(),
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(_error!, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
        const SizedBox(height: 20),
        _resumen(),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _guardando || _principal == null || _inicio == null
              ? null
              : _guardar,
          child: Text(_guardando ? 'Guardando…' : 'Guardar cita'),
        ),
      ],
    );
  }

  Widget _tiraDeDias() {
    final dias = _dias;
    if (_falloDias != null) {
      return _centrado(
        'No pudimos traer los horarios.',
        accion: TextButton(
          onPressed: _cargarDias,
          child: const Text('Reintentar'),
        ),
      );
    }
    if (dias == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: dias.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final dia = dias[i];
          final elegido = _dia != null && _mismoDia(_dia!.date, dia.date);
          final sirve = dia.hasRoomFor(_minutos > 0 ? _minutos : 60);
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: sirve || elegido
                ? () => setState(() {
                    _dia = dia;
                    if (!_esHorarioOriginal(dia, _inicio ?? -1)) _inicio = null;
                  })
                : null,
            child: Container(
              width: 64,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: elegido ? AppColors.navy : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: elegido ? AppColors.navy : AppColors.border,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    formatWeekdayShort(dia.date),
                    style: AppTheme.archivo(
                      size: 12,
                      weight: 600,
                      color: elegido ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${dia.date.day}',
                    style: AppTheme.archivo(
                      size: 18,
                      weight: 700,
                      color: elegido ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _horasDisponibles() {
    final dia = _dia;
    if (_principal == null) {
      return _centrado('Elige un servicio para ver las horas.');
    }
    if (dia == null) return _centrado('Ese día la estética no abre.');
    if (dia.isClosed) return _centrado('Ese día la estética no abre.');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final ventana in dia.windows) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              ventana.start < 12 * 60 ? 'MAÑANA' : 'TARDE',
              style: AppTheme.sectionLabel,
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final opcion in dia.slotsIn(ventana, _minutos))
                ChoiceChip(
                  label: Text(formatHour(opcion.start)),
                  selected: _inicio == opcion.start,
                  onSelected:
                      opcion.isFree || _esHorarioOriginal(dia, opcion.start)
                      ? (_) => setState(() => _inicio = opcion.start)
                      : null,
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _resumen() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TOTAL', style: AppTheme.sectionLabel),
              Text(
                formatCop(_total),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const Spacer(),
          Text(
            _minutos == 0 ? 'Sin servicios' : formatDuration(_minutos),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _centrado(String texto, {Widget? accion}) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            texto,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          ?accion,
        ],
      ),
    );
  }
}
