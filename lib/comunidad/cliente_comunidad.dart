import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'feature_flag_comunidad.dart';
import 'identidad_dispositivo.dart';
import 'modelo_foto_comunidad.dart';

/// Cliente HTTP del backend de aportaciones a la comunidad.
///
/// Solo opera si [kFeatureComunidadHabilitada] está `true`. En modo
/// inactivo todas las llamadas devuelven listas vacías o lanzan
/// `EstadoComunidadInactivo` sin tocar la red.
class ClienteComunidad {
  static const Duration _timeout = Duration(seconds: 15);

  /// Sube una aportación: foto + metadatos declarados + datos de contacto.
  /// El backend la guarda en estado `'pendiente'` hasta que un curador
  /// la revise.
  ///
  /// Parámetros:
  /// - [rutaFoto]: ruta absoluta a la foto en disco (sin reducir; el
  ///   pipeline de `formato_fos_card` la reduce a 1600px JPEG q75 antes
  ///   de subir, igual que los `.fos-card` exportados).
  /// - [tipo]: `'fosil'` o `'mineral'`.
  /// - [especie], [edad], [formacion]: declaración del aficionado, texto
  ///   crudo. El curador puede editarlos al aprobar.
  /// - [notas]: contexto adicional libre.
  /// - [email]: contacto opcional pero recomendado para que el curador
  ///   notifique aprobación/rechazo. Se valida formato pero NO se hace
  ///   double opt-in (evitar barreras a la participación casual).
  /// - [nombre]: opcional, solo lo verá el curador, nunca se publica.
  /// - [consentimientoExplicito]: debe ser `true` (validado en backend
  ///   también). El usuario marcó el checkbox de privacidad / patrimonio.
  Future<ResultadoSubidaAportacion> subirAportacion({
    required String rutaFoto,
    required String tipo,
    required String especie,
    required String edad,
    required String formacion,
    String notas = '',
    required String email,
    String nombre = '',
    required bool consentimientoExplicito,
  }) async {
    if (!kFeatureComunidadHabilitada) {
      throw const EstadoComunidadInactivo();
    }
    if (!consentimientoExplicito) {
      throw const ExcepcionComunidad('Falta consentimiento explícito.');
    }
    final tokenDispositivo = await IdentidadDispositivo.obtenerToken();
    final solicitud = http.MultipartRequest(
      'POST',
      Uri.parse('$urlBaseComunidad/aportaciones'),
    );
    solicitud.fields['datos'] = jsonEncode({
      'tipo': tipo,
      'especie': especie,
      'edad': edad,
      'formacion': formacion,
      'notas': notas,
      'email': email,
      'nombre': nombre,
      'token_dispositivo': tokenDispositivo,
      'consentimiento': true,
    });
    solicitud.files.add(await http.MultipartFile.fromPath(
      'foto',
      rutaFoto,
      filename: 'aportacion.jpg',
    ));
    try {
      final respuestaStream = await solicitud.send().timeout(_timeout);
      final respuesta = await http.Response.fromStream(respuestaStream);
      if (respuesta.statusCode == 200 || respuesta.statusCode == 201) {
        final json = jsonDecode(utf8.decode(respuesta.bodyBytes))
            as Map<String, dynamic>;
        return ResultadoSubidaAportacion.desdeJson(json);
      }
      if (respuesta.statusCode == 429) {
        throw const ExcepcionComunidad(
            'Has alcanzado el límite diario de subidas. Inténtalo mañana.');
      }
      throw ExcepcionComunidad(
          'El servidor rechazó la subida (HTTP ${respuesta.statusCode}).');
    } on TimeoutException {
      throw const ExcepcionComunidad(
          'El servidor tardó demasiado en responder. Revisa la conexión.');
    } on SocketException {
      throw const ExcepcionComunidad(
          'No hay conexión con el servidor. Inténtalo más tarde.');
    }
  }

  /// Lista las fotos aprobadas para una formación catalogada. Devuelve
  /// lista vacía si el flag está apagado, si no hay conexión o si la
  /// formación no tiene aportaciones aprobadas todavía.
  Future<List<FotoComunidad>> listarFotosPorFormacion(
      String formacionCodigo) async {
    if (!kFeatureComunidadHabilitada) return const [];
    try {
      final respuesta = await http
          .get(Uri.parse('$urlBaseComunidad/fotos-comunidad/por-formacion/'
              '$formacionCodigo'))
          .timeout(_timeout);
      if (respuesta.statusCode != 200) return const [];
      final cuerpo = jsonDecode(utf8.decode(respuesta.bodyBytes));
      if (cuerpo is! List) return const [];
      return cuerpo
          .whereType<Map<String, dynamic>>()
          .map(FotoComunidad.desdeJson)
          .toList();
    } catch (_) {
      // Silencioso: si falla, simplemente no aparece la sección de
      // comunidad. No es información crítica.
      return const [];
    }
  }

  /// Inicia el flujo RGPD de borrado: el backend manda un email con un
  /// enlace de un solo uso. Cuando el usuario hace click, se borran
  /// todas sus aportaciones (pendientes y aprobadas).
  Future<void> solicitarBorradoPorEmail(String email) async {
    if (!kFeatureComunidadHabilitada) {
      throw const EstadoComunidadInactivo();
    }
    final respuesta = await http
        .post(
          Uri.parse('$urlBaseComunidad/aportaciones/borrar-mis-aportaciones'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email}),
        )
        .timeout(_timeout);
    if (respuesta.statusCode != 200 && respuesta.statusCode != 202) {
      throw ExcepcionComunidad(
          'El servidor no pudo procesar la solicitud '
          '(HTTP ${respuesta.statusCode}).');
    }
  }
}

/// Lanzada cuando el feature flag está apagado y se intenta una llamada
/// que sí toca red. Las llamadas de SOLO LECTURA (listar fotos) no
/// lanzan esta excepción — devuelven lista vacía silenciosa.
class EstadoComunidadInactivo implements Exception {
  const EstadoComunidadInactivo();
  @override
  String toString() => 'La función "comunidad" no está activada en esta build.';
}

/// Error de comunicación con el backend de comunidad, mensaje listo para
/// mostrarse al usuario en un SnackBar.
class ExcepcionComunidad implements Exception {
  final String mensaje;
  const ExcepcionComunidad(this.mensaje);
  @override
  String toString() => mensaje;
}
