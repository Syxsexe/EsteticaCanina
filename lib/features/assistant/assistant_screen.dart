import 'package:flutter/material.dart';

import '../../core/navigation/flow_page_route.dart';
import '../../core/theme/app_colors.dart';
import '../booking/service_selection_screen.dart';
import 'data/asistente_repository.dart';

/// Agendar conversando con el asistente de IA.
///
/// La conversación vive solo en esta pantalla: al salir se pierde. La cita,
/// si se hace, queda en la base como cualquier otra reserva.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key, this.repository});

  final AsistenteRepository? repository;

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _Burbuja {
  const _Burbuja(this.texto, {required this.delCliente});

  final String texto;
  final bool delCliente;
}

class _AssistantScreenState extends State<AssistantScreen> {
  late final AsistenteRepository _repositorio =
      widget.repository ?? defaultAsistenteRepository();
  final _campo = TextEditingController();
  final _desplazamiento = ScrollController();

  final List<_Burbuja> _burbujas = [
    const _Burbuja(
      'Hola, soy el asistente de Perro Look. ¿Qué servicio quieres para tu '
      'perro y qué día te queda bien?',
      delCliente: false,
    ),
  ];

  /// Lo que devolvió el servidor la última vez; se reenvía sin tocar.
  List<dynamic> _historial = const [];

  bool _escribiendo = false;
  bool _noDisponible = false;

  /// El mensaje que no se pudo enviar, para reintentarlo sin reescribirlo.
  String? _pendiente;
  bool _terminada = false;

  @override
  void initState() {
    super.initState();
    // Para que el contador y el botón reaccionen al escribir.
    _campo.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _campo.dispose();
    _desplazamiento.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final texto = _campo.text.trim();
    if (texto.isEmpty || texto.length > maxTextoAsistente || _escribiendo) {
      return;
    }
    setState(() {
      _burbujas.add(_Burbuja(texto, delCliente: true));
      _campo.clear();
    });
    await _pedir(texto);
  }

  /// Reenvía el último mensaje que falló; su burbuja ya está en pantalla.
  Future<void> _reintentar() async {
    final texto = _pendiente;
    if (texto != null && !_escribiendo) await _pedir(texto);
  }

  Future<void> _pedir(String texto) async {
    setState(() {
      _escribiendo = true;
      _noDisponible = false;
      _pendiente = null;
    });
    _bajar();

    try {
      final respuesta = await _repositorio.enviar(_historial, texto);
      if (!mounted) return;
      setState(() {
        _historial = respuesta.historial;
        _burbujas.add(_Burbuja(respuesta.texto, delCliente: false));
        _terminada = respuesta.fin;
        _escribiendo = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _escribiendo = false;
        _noDisponible = true;
        _pendiente = texto;
      });
    }
    _bajar();
  }

  void _bajar() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_desplazamiento.hasClients) {
        _desplazamiento.jumpTo(_desplazamiento.position.maxScrollExtent);
      }
    });
  }

  void _reservaNormal() {
    Navigator.of(context).pushReplacement(
      FlowPageRoute<void>(builder: (_) => const ServiceSelectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final largo = _campo.text.length;
    final demasiadoLargo = largo > maxTextoAsistente;

    return Scaffold(
      appBar: AppBar(title: const Text('ASISTENTE')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _desplazamiento,
              padding: const EdgeInsets.all(16),
              children: [
                for (final burbuja in _burbujas) _BurbujaVista(burbuja),
                if (_escribiendo)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('Escribiendo…', style: textTheme.bodySmall),
                  ),
                if (_noDisponible || _terminada)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      children: [
                        if (_noDisponible) ...[
                          Text(
                            'El asistente no está disponible ahora.',
                            style: textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          TextButton(
                            onPressed: _reintentar,
                            child: const Text('Reintentar'),
                          ),
                        ],
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: _reservaNormal,
                          child: const Text('Usar la reserva normal'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('mensaje-asistente'),
                      controller: _campo,
                      enabled: !_terminada,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _enviar(),
                      decoration: InputDecoration(
                        hintText: 'Escribe tu mensaje',
                        border: const OutlineInputBorder(),
                        counterText: '$largo/$maxTextoAsistente',
                        errorText:
                            demasiadoLargo ? 'Máximo $maxTextoAsistente caracteres' : null,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: demasiadoLargo || _escribiendo || _terminada
                        ? null
                        : _enviar,
                    icon: const Icon(Icons.send),
                    tooltip: 'Enviar',
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

class _BurbujaVista extends StatelessWidget {
  const _BurbujaVista(this.burbuja);

  final _Burbuja burbuja;

  @override
  Widget build(BuildContext context) {
    final delCliente = burbuja.delCliente;
    return Align(
      alignment: delCliente ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: delCliente ? AppColors.navy : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: delCliente ? null : Border.all(color: AppColors.border),
        ),
        child: Text(
          burbuja.texto,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: delCliente ? Colors.white : AppColors.textPrimary,
              ),
        ),
      ),
    );
  }
}
