import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../datos/base_datos.dart';
import '../sonido/sonidos_propios.dart';

/// «Tus sonidos» en la pantalla de escucha: lee los sonidos propios de la BD,
/// los tiene preparados para comparar cada trozo y guarda los ejemplos.

const _clavePreferenciaSensibilidad = 'nat.quien_canta.sensibilidad_sonidos_propios';

class ControladorSonidosPropios extends ChangeNotifier {
  final String versionModelo;
  final BaseDatosNaturaleza _baseDatos;
  List<SonidoPropio> _sonidos = const [];
  List<EjemploSonidoPropio> _ejemplos = const [];
  List<SonidoPreparado> _preparados = const [];
  SensibilidadSonidosPropios _sensibilidad = SensibilidadSonidosPropios.normal;
  String? _error;
  bool _liberado = false;

  ControladorSonidosPropios({required this.versionModelo, BaseDatosNaturaleza? baseDatos})
      : _baseDatos = baseDatos ?? BaseDatosNaturaleza.instancia;

  /// Sonidos que se pueden reconocer (sin el de fondo), por orden de creación.
  List<SonidoPropio> get sonidos => [
        for (final sonido in _sonidos)
          if (!sonido.esFondo) sonido,
      ];
  SonidoPropio? get sonidoFondo {
    for (final sonido in _sonidos) {
      if (sonido.esFondo) return sonido;
    }
    return null;
  }

  SensibilidadSonidosPropios get sensibilidad => _sensibilidad;
  String? get error => _error;
  bool get hayAlgunoReconocible => _preparados
      .any((sonido) => !sonido.esFondo && sonido.ejemplosNormalizados.length >= ejemplosMinimosParaReconocer);

  /// Ejemplos de [idSonido] con el modelo actual.
  int ejemplosDe(int idSonido) => _ejemplos
      .where((ejemplo) => ejemplo.idSonido == idSonido && ejemplo.versionModelo == versionModelo)
      .length;

  /// Ejemplos de otros modelos (no se usan).
  int ejemplosDeOtroModelo(int idSonido) => _ejemplos
      .where((ejemplo) => ejemplo.idSonido == idSonido && ejemplo.versionModelo != versionModelo)
      .length;

  Future<void> cargar() async {
    try {
      final preferencias = await SharedPreferences.getInstance();
      final guardada = preferencias.getString(_clavePreferenciaSensibilidad);
      _sensibilidad = SensibilidadSonidosPropios.values.firstWhere(
        (valor) => valor.name == guardada,
        orElse: () => SensibilidadSonidosPropios.normal,
      );
    } catch (_) {}
    await _releer();
  }

  Future<void> _releer() async {
    try {
      _sonidos = await _baseDatos.listarSonidosPropios();
      _ejemplos = await _baseDatos.listarEjemplosSonidosPropios();
      _preparados = prepararSonidosPropios(_sonidos, _ejemplos, versionModelo: versionModelo);
      _error = null;
    } catch (error) {
      _error = error.toString();
    }
    if (!_liberado) notifyListeners();
  }

  void cambiarSensibilidad(SensibilidadSonidosPropios sensibilidad) {
    _sensibilidad = sensibilidad;
    notifyListeners();
    unawaited(() async {
      try {
        final preferencias = await SharedPreferences.getInstance();
        await preferencias.setString(_clavePreferenciaSensibilidad, sensibilidad.name);
      } catch (_) {}
    }());
  }

  /// Compara el embedding de un trozo con los sonidos propios.
  ResultadoSonidosPropios comparar(List<double> embedding) {
    if (embedding.isEmpty || _preparados.isEmpty) return ResultadoSonidosPropios.vacio;
    return compararConSonidosPropios(embedding, _preparados,
        umbralSimilitud: umbralPorSensibilidad[_sensibilidad]!);
  }

  /// Crea un sonido y devuelve su id.
  Future<int?> crear(String nombreCrudo) async {
    final nombre = limpiarNombreSonido(nombreCrudo);
    if (nombre == null) return null;
    final id = await _baseDatos.crearSonidoPropio(nombre);
    await _releer();
    return id;
  }

  Future<void> renombrar(int idSonido, String nombreCrudo) async {
    final nombre = limpiarNombreSonido(nombreCrudo);
    if (nombre == null) return;
    await _baseDatos.renombrarSonidoPropio(idSonido, nombre);
    await _releer();
  }

  Future<void> borrar(int idSonido) async {
    await _baseDatos.borrarSonidoPropio(idSonido);
    await _releer();
  }

  /// Añade un ejemplo. Devuelve false si ya tiene el máximo.
  Future<bool> anadirEjemplo(int idSonido, List<double> embedding) async {
    if (embedding.isEmpty || ejemplosDe(idSonido) >= ejemplosMaximosPorSonido) return false;
    await _baseDatos.anadirEjemploSonidoPropio(
        idSonido: idSonido, versionModelo: versionModelo, embedding: embedding);
    await _releer();
    return true;
  }

  Future<bool> anadirEjemploFondo(String nombreFondo, List<double> embedding) async {
    final idFondo = await _baseDatos.idSonidoFondo(nombreFondo);
    return anadirEjemplo(idFondo, embedding);
  }

  Future<void> quitarUltimoEjemplo(int idSonido) async {
    await _baseDatos.borrarUltimoEjemploSonidoPropio(idSonido);
    await _releer();
  }

  @override
  void dispose() {
    _liberado = true;
    super.dispose();
  }
}
