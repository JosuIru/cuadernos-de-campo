import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// User-Agent de la app para iNaturalist y GBIF: nombre y web, sin correo
/// personal (GBIF pide una URL o un correo para poder avisar).
const String agenteUsuarioNaturaleza =
    'Naturaleza/1.0 (cuaderno de campo de la Coleccion Nuevo Ser; https://coleccion-nuevo-ser.com/)';

/// Error de una API abierta (red, código HTTP o JSON).
class ErrorApiAbierta implements Exception {
  const ErrorApiAbierta(this.mensaje, {this.codigo});

  final String mensaje;
  final int? codigo;

  @override
  String toString() => 'ErrorApiAbierta($codigo): $mensaje';
}

/// Cliente HTTP educado para una API pública:
/// - peticiones **en serie** (una cola) y separadas al menos
///   [intervaloMinimo] (1,1 s: por debajo de 1 petición por segundo);
/// - User-Agent identificativo;
/// - ante un 429 espera lo que diga `Retry-After` (o [esperaPor429]) y
///   reintenta hasta [reintentosPor429] veces; la espera también frena las
///   peticiones que vienen detrás.
///
/// El [http.Client], el reloj y la espera se sustituyen en los tests.
class ClienteApiAbierta {
  ClienteApiAbierta({
    required http.Client cliente,
    this.intervaloMinimo = const Duration(milliseconds: 1100),
    this.reintentosPor429 = 2,
    this.esperaPor429 = const Duration(seconds: 30),
    this.esperaMaximaPor429 = const Duration(minutes: 2),
    this.tiempoLimite = const Duration(seconds: 15),
    DateTime Function()? reloj,
    Future<void> Function(Duration)? esperar,
  })  : _cliente = cliente,
        _reloj = reloj ?? DateTime.now,
        _esperar = esperar ?? Future<void>.delayed;

  final http.Client _cliente;
  final Duration intervaloMinimo;
  final int reintentosPor429;
  final Duration esperaPor429;
  final Duration esperaMaximaPor429;
  final Duration tiempoLimite;
  final DateTime Function() _reloj;
  final Future<void> Function(Duration) _esperar;

  Future<void> _cola = Future.value();
  DateTime? _siguientePermitida;

  /// Número de peticiones enviadas (para tests y depuración).
  int peticionesEnviadas = 0;

  /// GET que devuelve el JSON como mapa. Lanza [ErrorApiAbierta].
  Future<Map<String, dynamic>> obtenerJson(Uri uri) {
    final resultado = Completer<Map<String, dynamic>>();
    _cola = _cola.then((_) async {
      try {
        resultado.complete(await _obtenerConReintentos(uri));
      } catch (error) {
        resultado.completeError(error is ErrorApiAbierta ? error : ErrorApiAbierta('$error'));
      }
    });
    return resultado.future;
  }

  Future<Map<String, dynamic>> _obtenerConReintentos(Uri uri) async {
    for (var intento = 0;; intento++) {
      await _esperarTurno();
      peticionesEnviadas++;
      final http.Response respuesta;
      try {
        respuesta = await _cliente.get(uri, headers: const {
          'User-Agent': agenteUsuarioNaturaleza,
          'Accept': 'application/json',
        }).timeout(tiempoLimite);
      } on TimeoutException {
        throw const ErrorApiAbierta('tiempo agotado');
      } finally {
        _siguientePermitida = _reloj().add(intervaloMinimo);
      }
      if (respuesta.statusCode == 429) {
        final espera = esperaTras429(respuesta.headers['retry-after']);
        _siguientePermitida = _reloj().add(espera);
        if (intento >= reintentosPor429) {
          throw const ErrorApiAbierta('demasiadas peticiones', codigo: 429);
        }
        continue;
      }
      if (respuesta.statusCode != 200) {
        throw ErrorApiAbierta('HTTP ${respuesta.statusCode}', codigo: respuesta.statusCode);
      }
      final decodificado = jsonDecode(utf8.decode(respuesta.bodyBytes));
      if (decodificado is! Map<String, dynamic>) {
        throw const ErrorApiAbierta('respuesta que no es un objeto JSON');
      }
      return decodificado;
    }
  }

  Future<void> _esperarTurno() async {
    final permitida = _siguientePermitida;
    if (permitida == null) return;
    final falta = permitida.difference(_reloj());
    if (falta > Duration.zero) await _esperar(falta);
  }

  /// Espera tras un 429: los segundos de `Retry-After` (entre 1 s y
  /// [esperaMaximaPor429]) o [esperaPor429] si no viene o es una fecha.
  Duration esperaTras429(String? cabeceraRetryAfter) {
    final segundos = int.tryParse(cabeceraRetryAfter?.trim() ?? '');
    if (segundos == null) return esperaPor429;
    final espera = Duration(seconds: segundos < 1 ? 1 : segundos);
    return espera > esperaMaximaPor429 ? esperaMaximaPor429 : espera;
  }
}
