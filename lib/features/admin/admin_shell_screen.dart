import 'package:flutter/material.dart';

import '../../core/time/salon_time.dart';
import '../booking/data/availability_repository.dart';
import 'admin_analytics_screen.dart';
import 'admin_customers_screen.dart';
import 'admin_history_screen.dart';
import 'agenda_screen.dart';
import 'data/admin_appointment_repository.dart';
import 'data/admin_session.dart';
import 'data/agenda_repository.dart';
import 'data/analytics_repository.dart';
import 'data/customer_directory_repository.dart';
import 'pestana_recargable.dart';

/// El panel de la estética, con sus cuatro pestañas.
///
/// `IndexedStack` conserva el estado de cada pestaña: cambiar a Clientes y
/// volver a Historial no vuelve a pedir la lista ni pierde el filtro.
class AdminShellScreen extends StatefulWidget {
  const AdminShellScreen({
    super.key,
    this.analyticsRepository,
    this.appointmentsRepository,
    this.customersRepository,
    this.agendaRepository,
    this.availabilityRepository,
    this.session,
    this.today,
    this.now,
  });

  final AnalyticsRepository? analyticsRepository;
  final AdminAppointmentRepository? appointmentsRepository;
  final CustomerDirectoryRepository? customersRepository;
  final AgendaRepository? agendaRepository;
  final AvailabilityRepository? availabilityRepository;
  final AdminSession? session;
  final DateTime? today;
  final DateTime? now;

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  late final AnalyticsRepository _analiticas;
  late final AdminAppointmentRepository _citas;
  late final CustomerDirectoryRepository _clientes;
  late final AgendaRepository _agenda;
  late final AvailabilityRepository _disponibilidad;
  late final DateTime _hoy;

  int _indice = 0;

  /// Una llave por pestaña, para pedirle que recargue al entrar. Clientes no
  /// lleva: su detalle se abre aparte y ya carga cada vez.
  final _resumen = GlobalKey();
  final _agendaKey = GlobalKey();
  final _historial = GlobalKey();

  static const _titulos = ['RESUMEN', 'AGENDA', 'HISTORIAL', 'CLIENTES'];

  /// Al entrar a una pestaña se vuelven a pedir sus datos. El `IndexedStack`
  /// la mantiene viva y sin esto mostraría lo que había antes de los cambios
  /// hechos en otra pestaña.
  void _irA(int indice) {
    if (indice == _indice) return;
    setState(() => _indice = indice);
    final llave = switch (indice) {
      0 => _resumen,
      1 => _agendaKey,
      2 => _historial,
      _ => null,
    };
    final pestana = llave?.currentState;
    if (pestana is PestanaRecargable) {
      (pestana as PestanaRecargable).recargar();
    }
  }

  @override
  void initState() {
    super.initState();
    _analiticas = widget.analyticsRepository ?? defaultAnalyticsRepository();
    _citas =
        widget.appointmentsRepository ?? defaultAdminAppointmentRepository();
    _clientes =
        widget.customersRepository ?? defaultCustomerDirectoryRepository();
    _agenda = widget.agendaRepository ?? defaultAgendaRepository();
    _disponibilidad =
        widget.availabilityRepository ?? defaultAvailabilityRepository();
    _hoy = widget.today ?? hoyEnLaEstetica();
  }

  Future<void> _salir() async {
    final sesion = widget.session ?? defaultAdminSession();
    await sesion.salir();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titulos[_indice]),
        actions: [
          IconButton(
            onPressed: _salir,
            icon: const Icon(Icons.logout),
            tooltip: 'Salir',
          ),
        ],
      ),
      body: IndexedStack(
        index: _indice,
        children: [
          AdminAnalyticsScreen(
            key: _resumen,
            repository: _analiticas,
            hoy: _hoy,
          ),
          AgendaScreen(
            key: _agendaKey,
            repository: _agenda,
            session: widget.session,
            today: _hoy,
            embedded: true,
            appointmentsRepository: _citas,
            availabilityRepository: _disponibilidad,
            customersRepository: _clientes,
          ),
          AdminHistoryScreen(
            key: _historial,
            appointmentsRepository: _citas,
            customersRepository: _clientes,
            availabilityRepository: _disponibilidad,
            today: _hoy,
            now: widget.now,
          ),
          AdminCustomersScreen(
            customersRepository: _clientes,
            appointmentsRepository: _citas,
            availabilityRepository: _disponibilidad,
            today: _hoy,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: _irA,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Resumen',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'Agenda',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            selectedIcon: Icon(Icons.history_toggle_off),
            label: 'Historial',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Clientes',
          ),
        ],
      ),
    );
  }
}
