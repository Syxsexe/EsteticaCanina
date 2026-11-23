import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';

/// Lo más largo que puede escribir el cliente en un mensaje. El servidor
/// comprueba lo mismo.
const int maxTextoAsistente = 1000;

/// Una respuesta del asistente de reservas.
class RespuestaAsistente {
  const RespuestaAsistente({
    required this.historial,
    required this.texto,
    this.fin = false,
  });

  /// La conversación tal como la devolvió el servidor. Es opaca: se reenvía
  /// sin tocarla en el siguiente mensaje, porque el proveedor de IA exige
  /// recibir de vuelta exactamente lo que mandó.
  final List<dynamic> historial;

  final String texto;

  /// La conversación llegó a su máximo y hay que empezar otra.
  final bool fin;
}

/// El servidor no tiene el asistente configurado, el proveedor falló o se
/// agotó la cuota.
class AsistenteNoDisponible implements Exception {
  const AsistenteNoDisponible();

  @override
  String toString() => 'El asistente no está disponible ahora.';
}

/// El asistente de IA. Vive en la Edge Function `asistente`: la clave del
/// proveedor nunca está en la app.
abstract interface class AsistenteRepository {
  /// Envía [texto] del cliente con la conversación anterior.
  Future<RespuestaAsistente> enviar(List<dynamic> historial, String texto);

  /// El parte de la administradora. Exige una sesión de admin.
  Future<String> resumen();
}

/// Respuestas fijas, para las pruebas y para la app sin credenciales.
class SampleAsistenteRepository implements AsistenteRepository {
  const SampleAsistenteRepository();

  @override
  Future<RespuestaAsistente> enviar(List<dynamic> historial, String texto) async =>
      RespuestaAsistente(
        historial: [...historial, texto, 'respuesta'],
        texto: 'Soy el asistente de muestra. Con Supabase configurado, '
            'te ayudo a agendar de verdad.',
      );

  @override
  Future<String> resumen() async =>
      'Resumen de muestra: hoy tienes 2 citas por la mañana y la tarde libre.';
}

class SupabaseAsistenteRepository implements AsistenteRepository {
  const SupabaseAsistenteRepository(this._db);

  final SupabaseClient _db;

  Future<Map<String, dynamic>> _llamar(Map<String, dynamic> cuerpo) async {
    try {
      final respuesta = await _db.functions.invoke('asistente', body: cuerpo);
      return respuesta.data as Map<String, dynamic>;
    } catch (_) {
      // Sin función desplegada, sin clave, cuota agotada o sin red: para la
      // app es lo mismo, y el resto sigue funcionando.
      throw const AsistenteNoDisponible();
    }
  }

  @override
  Future<RespuestaAsistente> enviar(List<dynamic> historial, String texto) async {
    final datos = await _llamar({
      'modo': 'cliente',
      'historial': historial,
      'texto': texto,
    });
    return RespuestaAsistente(
      historial: datos['historial'] as List<dynamic>,
      texto: datos['texto'] as String,
      fin: datos['fin'] == true,
    );
  }

  /// El cliente de Supabase manda el JWT de la sesión: el servidor comprueba
  /// `es_admin()` con él.
  @override
  Future<String> resumen() async =>
      (await _llamar({'modo': 'resumen'}))['texto'] as String;
}

AsistenteRepository defaultAsistenteRepository() {
  if (!AppConfig.hasSupabase) return const SampleAsistenteRepository();
  return SupabaseAsistenteRepository(Supabase.instance.client);
}
