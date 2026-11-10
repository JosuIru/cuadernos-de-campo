import 'dart:typed_data';

import 'clasificacion_sonido.dart';

/// Lista de la sesión de escucha: cada especie que se ha mostrado como
/// resultado desde que se abrió la pantalla, con su mejor puntuación y el
/// clip de ese momento (en memoria; solo se escribe a disco el de la especie
/// que se elige para el hallazgo). Al salir de la pantalla se pierde todo.

/// Tope de especies con clip en memoria (≈0,5 MB cada una).
const int maximoEspeciesConClip = 40;

class EspecieOidaEnSesion {
  final int indiceClase;
  int vecesOida;
  final DateTime primeraVez;
  DateTime ultimaVez;
  double mejorPuntuacion;
  double mejorPuntuacionModelo;
  DateTime momentoMejor;
  Int16List? clipMejor;

  EspecieOidaEnSesion({
    required this.indiceClase,
    required this.primeraVez,
    required this.mejorPuntuacion,
    required this.mejorPuntuacionModelo,
    this.clipMejor,
  })  : vecesOida = 1,
        ultimaVez = primeraVez,
        momentoMejor = primeraVez;
}

class SesionEscucha {
  final Map<int, EspecieOidaEnSesion> _especiesPorClase = {};
  int trozosAnalizados = 0;
  int trozosConVozHumana = 0;

  /// Especies de la sesión, de la mejor puntuación a la peor.
  List<EspecieOidaEnSesion> get especiesPorPuntuacion => _especiesPorClase.values.toList()
    ..sort((a, b) => b.mejorPuntuacion.compareTo(a.mejorPuntuacion));

  EspecieOidaEnSesion? especie(int indiceClase) => _especiesPorClase[indiceClase];

  int get numeroEspecies => _especiesPorClase.length;

  /// Apunta un trozo con voz humana: solo se cuenta, no se guarda nada.
  void registrarTrozoConVozHumana() {
    trozosAnalizados++;
    trozosConVozHumana++;
  }

  /// Apunta un trozo limpio con las especies que se mostraron como
  /// resultado. Cada especie se queda con el clip de su mejor puntuación.
  void registrarTrozo({
    required List<ClaseClasificada> especiesMostradas,
    required DateTime momento,
    Int16List? clip,
  }) {
    trozosAnalizados++;
    for (final clasificada in especiesMostradas) {
      final existente = _especiesPorClase[clasificada.indiceClase];
      if (existente == null) {
        final hayHuecoParaClip = _especiesConClip() < maximoEspeciesConClip;
        _especiesPorClase[clasificada.indiceClase] = EspecieOidaEnSesion(
          indiceClase: clasificada.indiceClase,
          primeraVez: momento,
          mejorPuntuacion: clasificada.puntuacion,
          mejorPuntuacionModelo: clasificada.puntuacionModelo,
          clipMejor: hayHuecoParaClip ? clip : null,
        );
        continue;
      }
      existente.vecesOida++;
      existente.ultimaVez = momento;
      if (clasificada.puntuacion > existente.mejorPuntuacion) {
        existente.mejorPuntuacion = clasificada.puntuacion;
        existente.mejorPuntuacionModelo = clasificada.puntuacionModelo;
        existente.momentoMejor = momento;
        if (clip != null &&
            (existente.clipMejor != null || _especiesConClip() < maximoEspeciesConClip)) {
          existente.clipMejor = clip;
        }
      }
    }
  }

  int _especiesConClip() =>
      _especiesPorClase.values.where((especie) => especie.clipMejor != null).length;

  void vaciar() {
    _especiesPorClase.clear();
    trozosAnalizados = 0;
    trozosConVozHumana = 0;
  }
}
