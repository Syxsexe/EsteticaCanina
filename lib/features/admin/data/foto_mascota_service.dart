import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

/// El lado mayor de una foto guardada, en píxeles.
const int ladoMaximoFoto = 1280;

/// El archivo elegido no se pudo leer como imagen: no es una imagen, está
/// dañado, o es un formato que este equipo no sabe abrir (HEIC en Chrome).
class ArchivoNoLegibleException implements Exception {
  const ArchivoNoLegibleException();

  @override
  String toString() => 'El archivo no se pudo leer como imagen.';
}

/// El equipo no supo generar WebP. Pasa en Safari: su `canvas` no codifica
/// WebP y devuelve otro formato sin avisar.
class WebpNoDisponibleException implements Exception {
  const WebpNoDisponibleException();

  @override
  String toString() => 'Este equipo no puede generar WebP.';
}

/// Elegir una foto del equipo y dejarla lista para guardar.
///
/// Es una interfaz para que las pruebas no dependan de los plugins nativos.
abstract interface class FotoMascotaService {
  /// Abre el selector. Devuelve los bytes tal como vienen, o nulo si se
  /// cerró sin elegir.
  Future<Uint8List?> elegir();

  /// Reduce la imagen a [ladoMaximoFoto] por lado como mucho y la convierte
  /// a WebP. Lanza [ArchivoNoLegibleException] o [WebpNoDisponibleException].
  Future<Uint8List> aWebp(Uint8List original);
}

/// El tamaño al que se reduce una imagen de [ancho] x [alto]: el lado mayor
/// queda en [ladoMaximo] como mucho, conservando la proporción. Nunca agranda.
(int, int) tamanoDestino(int ancho, int alto, {int ladoMaximo = ladoMaximoFoto}) {
  final mayor = ancho > alto ? ancho : alto;
  if (mayor <= ladoMaximo) return (ancho, alto);
  final escala = ladoMaximo / mayor;
  return ((ancho * escala).round(), (alto * escala).round());
}

/// Si [bytes] son un WebP: cabecera `RIFF`, cuatro bytes de tamaño y `WEBP`.
bool esWebp(Uint8List bytes) =>
    bytes.length >= 12 &&
    bytes[0] == 0x52 && // R
    bytes[1] == 0x49 && // I
    bytes[2] == 0x46 && // F
    bytes[3] == 0x46 && // F
    bytes[8] == 0x57 && // W
    bytes[9] == 0x45 && // E
    bytes[10] == 0x42 && // B
    bytes[11] == 0x50; // P

/// La implementación de verdad: `image_picker` y `flutter_image_compress`.
class PluginFotoMascotaService implements FotoMascotaService {
  const PluginFotoMascotaService();

  @override
  Future<Uint8List?> elegir() async {
    // Galería en Android, diálogo de archivos en web. Sin redimensionar
    // aquí: eso lo hace `aWebp`, que sabe el tamaño exacto que quiere.
    final archivo = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (archivo == null) return null;
    return archivo.readAsBytes();
  }

  @override
  Future<Uint8List> aWebp(Uint8List original) async {
    final int ancho;
    final int alto;
    try {
      // Solo para saber las dimensiones: el equipo decodifica lo que sepa
      // (JPG, PNG, GIF, WebP, y HEIC en Android).
      final codec = await ui.instantiateImageCodec(original);
      final cuadro = await codec.getNextFrame();
      ancho = cuadro.image.width;
      alto = cuadro.image.height;
      cuadro.image.dispose();
      codec.dispose();
    } catch (_) {
      throw const ArchivoNoLegibleException();
    }

    final (destinoAncho, destinoAlto) = tamanoDestino(ancho, alto);

    final Uint8List resultado;
    try {
      // El paquete toma `minWidth`/`minHeight` como cota inferior y escala
      // por el lado que menos reduce; pasándole el tamaño exacto, sale ese.
      resultado = await FlutterImageCompress.compressWithList(
        original,
        minWidth: destinoAncho,
        minHeight: destinoAlto,
        quality: 80,
        format: CompressFormat.webp,
      );
    } on UnsupportedError {
      throw const WebpNoDisponibleException();
    } catch (_) {
      throw const ArchivoNoLegibleException();
    }

    // Safari devuelve PNG o JPEG cuando se le pide WebP, sin error. Se
    // comprueba la cabecera en vez de fiarse del formato pedido.
    if (!esWebp(resultado)) throw const WebpNoDisponibleException();
    return resultado;
  }
}

FotoMascotaService defaultFotoMascotaService() =>
    const PluginFotoMascotaService();
