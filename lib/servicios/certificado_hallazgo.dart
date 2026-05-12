import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../modelos/hallazgo.dart';

/// Hash verificable de un hallazgo. Se calcula sobre una cadena canónica
/// determinista que incluye los datos inmutables del hallazgo + el nombre
/// del descubridor. Si alguien modifica cualquier campo, el hash cambia.
String calcularHashHallazgo(Hallazgo h, String nombreDescubridor) {
  final canonico = [
    h.latitud.toStringAsFixed(6),
    h.longitud.toStringAsFixed(6),
    h.fechaMs.toString(),
    h.especie.trim(),
    h.edad.trim(),
    h.formacion.trim(),
    h.tipo,
    nombreDescubridor.trim(),
  ].join('|');
  return sha256.convert(utf8.encode(canonico)).toString();
}

Map<String, dynamic> generarCertificadoJson(
  Hallazgo h,
  String nombreDescubridor, {
  String emailDescubridor = '',
  String organizacionDescubridor = '',
}) {
  final hash = calcularHashHallazgo(h, nombreDescubridor);
  final ahora = DateTime.now().toUtc();
  return {
    'tipo': 'certificado_hallazgo_fosiles',
    'version': '1.0',
    'hash': 'sha256:$hash',
    'hallazgo': {
      'especie': h.especie,
      'edad': h.edad,
      'formacion': h.formacion,
      'tipo': h.tipo,
      'fecha_descubrimiento_ms': h.fechaMs,
      'fecha_descubrimiento_iso':
          DateTime.fromMillisecondsSinceEpoch(h.fechaMs, isUtc: true).toIso8601String(),
      'coordenadas_aproximadas': '${h.latitud.toStringAsFixed(3)}, ${h.longitud.toStringAsFixed(3)}',
      'strike_grados': h.strikeGrados,
      'dip_grados': h.dipGrados,
      'notas': h.notas,
      'num_fotos': h.rutasFotos.length,
    },
    'descubridor': {
      'nombre': nombreDescubridor,
      if (emailDescubridor.isNotEmpty) 'email': emailDescubridor,
      if (organizacionDescubridor.isNotEmpty) 'organizacion': organizacionDescubridor,
    },
    'fecha_certificacion_iso': ahora.toIso8601String(),
    'instrucciones_verificacion':
        'Para verificar este certificado, recalcula el hash SHA-256 de la '
        'cadena canónica: lat|lon|fechaMs|especie|edad|formacion|tipo|descubridor. '
        'Si coincide con el hash arriba, el certificado es auténtico.',
  };
}

/// Verifica un certificado JSON. Devuelve true si el hash es correcto.
bool verificarCertificado(Map<String, dynamic> certificado) {
  try {
    final hashDeclarado = (certificado['hash'] as String?) ?? '';
    if (!hashDeclarado.startsWith('sha256:')) return false;
    final h = certificado['hallazgo'] as Map<String, dynamic>?;
    final d = certificado['descubridor'] as Map<String, dynamic>?;
    if (h == null || d == null) return false;

    final hallazgoTemporal = Hallazgo(
      fechaMs: (h['fecha_descubrimiento_ms'] as num).toInt(),
      latitud: double.parse(
          (h['coordenadas_aproximadas'] as String).split(',')[0].trim()),
      longitud: double.parse(
          (h['coordenadas_aproximadas'] as String).split(',')[1].trim()),
      especie: (h['especie'] as String?) ?? '',
      edad: (h['edad'] as String?) ?? '',
      formacion: (h['formacion'] as String?) ?? '',
      tipo: (h['tipo'] as String?) ?? 'fosil',
      notas: (h['notas'] as String?) ?? '',
    );

    final nombreDescubridor = (d['nombre'] as String?) ?? '';
    final hashRecalculado = calcularHashHallazgo(hallazgoTemporal, nombreDescubridor);
    return 'sha256:$hashRecalculado' == hashDeclarado;
  } catch (_) {
    return false;
  }
}
