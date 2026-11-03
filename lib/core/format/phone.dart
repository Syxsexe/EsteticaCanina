/// Normaliza un celular colombiano al formato E.164 (`+573001112233`).
///
/// Devuelve `null` si lo escrito no parece un celular colombiano. Se guarda
/// normalizado y no tal cual lo escribió el cliente por dos motivos: el
/// mismo número no puede quedar escrito de cinco maneras distintas en la
/// base, y cualquier servicio de mensajería —WhatsApp o SMS— pide E.164.
///
/// Acepta las formas en que la gente escribe su número de verdad:
/// `300 111 2233`, `3001112233`, `+57 300 111 2233`, `0057 3001112233`.
///
/// Rechaza los fijos a propósito. La estética avisa la tarde anterior por
/// mensaje, y a un fijo no le llega: guardarlo sería guardar un número al
/// que nunca se va a escribir.
String? normalizarTelefono(String entrada) {
  final digitos = entrada.replaceAll(RegExp(r'[^0-9]'), '');

  // 3001112233
  if (digitos.length == 10 && digitos.startsWith('3')) {
    return '+57$digitos';
  }
  // 573001112233, que es lo que queda de +57 300 111 2233
  if (digitos.length == 12 && digitos.startsWith('573')) {
    return '+$digitos';
  }
  // 00573001112233, el prefijo internacional a la antigua
  if (digitos.length == 14 && digitos.startsWith('00573')) {
    return '+${digitos.substring(2)}';
  }
  return null;
}

/// `+573001112233` como `300 111 2233`, para enseñarlo.
///
/// Guardar en E.164 y mostrar separado: la base necesita una forma
/// canónica y las personas leemos mejor por grupos.
String formatTelefono(String e164) {
  final digitos = e164.replaceAll(RegExp(r'[^0-9]'), '');
  if (digitos.length != 12 || !digitos.startsWith('57')) return e164;
  final n = digitos.substring(2);
  return '${n.substring(0, 3)} ${n.substring(3, 6)} ${n.substring(6)}';
}
