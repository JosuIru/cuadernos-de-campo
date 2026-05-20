import 'package:flutter/foundation.dart';

import '../datos/base_datos.dart';
import '../modelos/salida.dart';

/// Mantiene en memoria la salida abierta (si la hay) y notifica a las
/// pantallas que la observan: el inicio (banner sticky), la pantalla
/// de nuevo hallazgo (auto-asociar al guardar) y la lista de salidas.
///
/// Singleton porque sólo puede existir una salida en curso a la vez
/// (la UI lo refuerza, y la BD no impide múltiples cerrada=0 — la
/// salida_en_curso() devuelve la más reciente).
///
/// Se cablea desde main() llamando a [recargarDesdeBD] al arrancar.
class EstadoSalidaEnCurso extends ChangeNotifier {
  EstadoSalidaEnCurso._interno();
  static final EstadoSalidaEnCurso instancia = EstadoSalidaEnCurso._interno();

  Salida? _salida;

  /// La salida activa, o null si no hay ninguna abierta.
  Salida? get salida => _salida;

  bool get hayActiva => _salida != null;

  /// Releee de la BD. Se llama al arrancar la app y tras cualquier
  /// operación que pueda haber tocado salidas desde otra pantalla.
  Future<void> recargarDesdeBD() async {
    final actual = await BaseDatosNaturaleza.instancia.salidaEnCurso();
    if (actual?.id != _salida?.id) {
      _salida = actual;
      notifyListeners();
    } else {
      // Mismo id pero campos pueden haber cambiado (renombrado, etc.).
      _salida = actual;
      notifyListeners();
    }
  }

  /// Inicia una salida nueva en este instante. Si ya había una abierta,
  /// la cierra antes de empezar la nueva — no se permiten dos a la
  /// vez. Devuelve la salida recién creada (con id ya asignado).
  Future<Salida> iniciar({
    String titulo = '',
    String zona = '',
    String hipotesisJornada = '',
  }) async {
    final ahora = DateTime.now().millisecondsSinceEpoch;
    if (_salida != null && _salida!.id != null) {
      await BaseDatosNaturaleza.instancia.cerrarSalida(
        _salida!.id!,
        fechaFinMs: ahora,
      );
    }
    final salidaNueva = Salida(
      fechaInicioMs: ahora,
      titulo: titulo,
      zona: zona,
      hipotesisJornada: hipotesisJornada,
    );
    final id = await BaseDatosNaturaleza.instancia.guardarSalida(salidaNueva);
    final guardada = await BaseDatosNaturaleza.instancia.obtenerSalida(id);
    _salida = guardada;
    notifyListeners();
    return guardada!;
  }

  /// Cierra la salida activa, si la hay. No hace nada si no hay
  /// ninguna abierta.
  Future<void> cerrar() async {
    final actual = _salida;
    if (actual?.id == null) return;
    await BaseDatosNaturaleza.instancia.cerrarSalida(actual!.id!);
    _salida = null;
    notifyListeners();
  }

  /// Aplica un parche de campos a la salida activa, persiste y
  /// notifica. Si no hay activa, no hace nada.
  Future<void> actualizarActiva({
    String? titulo,
    String? zona,
    double? meteoTemperaturaC,
    String? meteoResumen,
    int? altitudAproximada,
    String? notasGenerales,
    String? hipotesisJornada,
  }) async {
    final actual = _salida;
    if (actual?.id == null) return;
    final cambios = <String, Object?>{};
    if (titulo != null) cambios['titulo'] = titulo.isEmpty ? null : titulo;
    if (zona != null) cambios['zona'] = zona.isEmpty ? null : zona;
    if (meteoTemperaturaC != null) {
      cambios['meteo_temperatura_c'] = meteoTemperaturaC;
    }
    if (meteoResumen != null) {
      cambios['meteo_resumen'] = meteoResumen.isEmpty ? null : meteoResumen;
    }
    if (altitudAproximada != null) {
      cambios['altitud_aproximada'] = altitudAproximada;
    }
    if (notasGenerales != null) {
      cambios['notas_generales'] =
          notasGenerales.isEmpty ? null : notasGenerales;
    }
    if (hipotesisJornada != null) {
      cambios['hipotesis_jornada'] =
          hipotesisJornada.isEmpty ? null : hipotesisJornada;
    }
    if (cambios.isEmpty) return;
    await BaseDatosNaturaleza.instancia.actualizarSalida(actual!.id!, cambios);
    await recargarDesdeBD();
  }
}
