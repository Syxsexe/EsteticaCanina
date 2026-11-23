import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../booking/data/availability_repository.dart';
import 'admin_customer_detail_screen.dart';
import 'data/admin_appointment_repository.dart';
import 'data/customer_directory_repository.dart';
import 'models/customer_entry.dart';

/// La pestaña Clientes: el directorio de tutores, en orden alfabético.
class AdminCustomersScreen extends StatefulWidget {
  const AdminCustomersScreen({
    super.key,
    required this.customersRepository,
    required this.appointmentsRepository,
    required this.availabilityRepository,
    this.today,
  });

  final CustomerDirectoryRepository customersRepository;
  final AdminAppointmentRepository appointmentsRepository;
  final AvailabilityRepository availabilityRepository;
  final DateTime? today;

  @override
  State<AdminCustomersScreen> createState() => _AdminCustomersScreenState();
}

class _AdminCustomersScreenState extends State<AdminCustomersScreen> {
  List<CustomerEntry>? _clientes;
  Object? _fallo;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _clientes = null;
      _fallo = null;
    });
    try {
      final clientes = await widget.customersRepository.clientes();
      if (!mounted) return;
      setState(() => _clientes = clientes);
    } catch (error) {
      if (!mounted) return;
      setState(() => _fallo = error);
    }
  }

  Future<void> _abrir(CustomerEntry cliente) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AdminCustomerDetailScreen(
          cliente: cliente,
          customersRepository: widget.customersRepository,
          appointmentsRepository: widget.appointmentsRepository,
          availabilityRepository: widget.availabilityRepository,
          today: widget.today,
        ),
      ),
    );
    if (mounted) await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    if (_fallo != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'No pudimos traer los clientes.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: _cargar, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    final clientes = _clientes;
    if (clientes == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      child: clientes.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 64),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Todavía no hay clientes registrados.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: clientes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final cliente = clientes[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _abrir(cliente),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.primarySoft,
                          child: Text(
                            cliente.nombreVisible.isEmpty
                                ? '?'
                                : cliente.nombreVisible.substring(0, 1).toUpperCase(),
                            style: const TextStyle(color: AppColors.navy),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cliente.nombreVisible,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                cliente.telefonoVisible,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${cliente.citas} ${cliente.citas == 1 ? 'cita' : 'citas'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
