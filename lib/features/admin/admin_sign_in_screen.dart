import 'package:flutter/material.dart';

import '../../core/navigation/flow_page_route.dart';
import '../../core/theme/app_colors.dart';
import 'agenda_screen.dart';
import 'data/admin_session.dart';

/// Entrada de la estética.
///
/// Correo y contraseña, no el OTP de los clientes: la dueña entra a diario
/// desde su propio dispositivo, así que no la olvida, y no cuesta un
/// mensaje cada vez.
class AdminSignInScreen extends StatefulWidget {
  const AdminSignInScreen({super.key, this.session});

  final AdminSession? session;

  @override
  State<AdminSignInScreen> createState() => _AdminSignInScreenState();
}

class _AdminSignInScreenState extends State<AdminSignInScreen> {
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();

  bool _entrando = false;
  String? _error;

  @override
  void dispose() {
    _correo.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    setState(() {
      _entrando = true;
      _error = null;
    });

    final sesion = widget.session ?? defaultAdminSession();
    final navegador = Navigator.of(context);

    try {
      final esAdmin = await sesion.entrar(
        correo: _correo.text.trim(),
        contrasena: _contrasena.text,
      );
      if (!mounted) return;

      if (!esAdmin) {
        // La cuenta existe pero no manda. Se dice tal cual: fingir que la
        // contraseña está mal confundiría a quien se equivocó de cuenta.
        setState(() {
          _entrando = false;
          _error = 'Esa cuenta no tiene acceso a la agenda.';
        });
        await sesion.salir();
        return;
      }

      navegador.pushReplacement(
        FlowPageRoute<void>(builder: (_) => const AgendaScreen()),
      );
    } on CredencialesInvalidas {
      if (!mounted) return;
      setState(() {
        _entrando = false;
        _error = 'Correo o contraseña incorrectos.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _entrando = false;
        _error = 'No pudimos conectar. Revisa tu conexión.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('ESTÉTICA')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          Text('Entra a tu\nagenda.', style: textTheme.displaySmall),
          const SizedBox(height: 12),
          Text(
            'Esta parte es solo para la estética. Los clientes no la '
            'necesitan.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _correo,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            enabled: !_entrando,
            decoration: const InputDecoration(
              labelText: 'Correo',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _contrasena,
            obscureText: true,
            enabled: !_entrando,
            onSubmitted: (_) => _entrando ? null : _entrar(),
            decoration: const InputDecoration(
              labelText: 'Contraseña',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_error!, style: textTheme.bodyMedium),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _entrando ? null : _entrar,
            child: Text(_entrando ? 'Entrando…' : 'Entrar'),
          ),
        ],
      ),
    );
  }
}
