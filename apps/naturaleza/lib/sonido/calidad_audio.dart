import 'dart:math' as math;

/// Aviso de calidad de «¿Quién canta?»: mientras se escucha se mira el
/// audio en bruto del micrófono, en tramas de 0,1 s, y se avisa si hay
/// mucho viento, saturación, ruido de tráfico continuo o la señal es
/// demasiado débil. Los umbrales son **orientativos** (no están medidos con
/// grabaciones de campo): están aquí, a la vista, para afinarlos.
///
/// Se hace con filtros biquad (fórmulas de Robert Bristow-Johnson, «Audio
/// EQ Cookbook»), sin FFT: es barato y va en el hilo principal.

/// Filtro IIR de segundo orden (forma directa I).
class FiltroBiquad {
  final double _b0, _b1, _b2, _a1, _a2;
  double _entrada1 = 0, _entrada2 = 0, _salida1 = 0, _salida2 = 0;

  FiltroBiquad._(double b0, double b1, double b2, double a0, double a1, double a2)
      : _b0 = b0 / a0,
        _b1 = b1 / a0,
        _b2 = b2 / a0,
        _a1 = a1 / a0,
        _a2 = a2 / a0;

  static double _alfa(double frecuenciaMuestreoHz, double frecuenciaHz, double factorCalidad) =>
      math.sin(2 * math.pi * frecuenciaHz / frecuenciaMuestreoHz) / (2 * factorCalidad);

  factory FiltroBiquad.pasoBajo(double frecuenciaMuestreoHz, double corteHz,
      {double factorCalidad = math.sqrt1_2}) {
    final omega = 2 * math.pi * corteHz / frecuenciaMuestreoHz;
    final coseno = math.cos(omega);
    final alfa = _alfa(frecuenciaMuestreoHz, corteHz, factorCalidad);
    return FiltroBiquad._((1 - coseno) / 2, 1 - coseno, (1 - coseno) / 2, 1 + alfa, -2 * coseno, 1 - alfa);
  }

  factory FiltroBiquad.pasoAlto(double frecuenciaMuestreoHz, double corteHz,
      {double factorCalidad = math.sqrt1_2}) {
    final omega = 2 * math.pi * corteHz / frecuenciaMuestreoHz;
    final coseno = math.cos(omega);
    final alfa = _alfa(frecuenciaMuestreoHz, corteHz, factorCalidad);
    return FiltroBiquad._((1 + coseno) / 2, -(1 + coseno), (1 + coseno) / 2, 1 + alfa, -2 * coseno, 1 - alfa);
  }

  double procesar(double muestra) {
    final salida = _b0 * muestra + _b1 * _entrada1 + _b2 * _entrada2 - _a1 * _salida1 - _a2 * _salida2;
    _entrada2 = _entrada1;
    _entrada1 = muestra;
    _salida2 = _salida1;
    _salida1 = salida;
    return salida;
  }

  void reiniciar() {
    _entrada1 = _entrada2 = _salida1 = _salida2 = 0;
  }
}

// ---------------------------------------------------------------- Umbrales

/// Duración de cada trama de medida.
const double duracionTramaCalidadSegundos = 0.1;

/// Se evalúan las últimas 3 s (30 tramas).
const int tramasEvaluacionCalidad = 30;

/// Una muestra con |valor| ≥ esto se cuenta como recortada (el conversor
/// llega a ±1).
const double umbralMuestraRecortada = 0.98;

/// Saturación: más del 0,1 % de las muestras recortadas.
const double fraccionRecortadasSaturacion = 0.001;

/// Viento: retumbo por debajo de 150 Hz…
const double corteMuyGravesHz = 150;

/// …que se lleva más del 60 % de la energía…
const double fraccionMuyGravesViento = 0.6;

/// …y va a rachas: variación (desviación / media) del nivel de esa banda
/// entre tramas de al menos 0,35.
const double variacionMinimaViento = 0.35;

/// Tráfico: más del 80 % de la energía por debajo de 1 kHz…
const double corteGravesHz = 1000;
const double fraccionGravesTrafico = 0.8;

/// …estable (variación ≤ 0,25)…
const double variacionMaximaTrafico = 0.25;

/// …y fuerte: esa banda por encima de −50 dBFS.
const double nivelMinimoTraficoDecibelios = -50;

/// Señal débil: todo el audio por debajo de −65 dBFS (el micrófono apenas
/// capta nada o está tapado).
const double nivelSenalDebilDecibelios = -65;

/// Banda del canto para el barrido de rumbo: 1-8 kHz.
const double inicioBandaCantoHz = 1000;
const double finBandaCantoHz = 8000;

enum AvisoCalidad { saturacion, viento, trafico, senalDebil }

/// Medidas de una trama (energías medias por muestra).
class TramaCalidad {
  final double energiaTotal;
  final double energiaMuyGraves;
  final double energiaGraves;
  final double energiaBandaCanto;
  final int muestrasRecortadas;
  final int numeroMuestras;

  const TramaCalidad({
    required this.energiaTotal,
    required this.energiaMuyGraves,
    required this.energiaGraves,
    required this.energiaBandaCanto,
    required this.muestrasRecortadas,
    required this.numeroMuestras,
  });

  double get nivelBandaCantoDecibelios => energiaADecibelios(energiaBandaCanto);
}

double energiaADecibelios(double energiaMedia) => 10 * math.log(math.max(1e-20, energiaMedia)) / math.ln10;

class EvaluacionCalidad {
  final Set<AvisoCalidad> avisos;
  final double nivelDecibelios;
  final double fraccionMuyGraves;
  final double fraccionGraves;
  final double variacionMuyGraves;
  final double variacionGraves;
  final double fraccionRecortadas;

  const EvaluacionCalidad({
    required this.avisos,
    required this.nivelDecibelios,
    required this.fraccionMuyGraves,
    required this.fraccionGraves,
    required this.variacionMuyGraves,
    required this.variacionGraves,
    required this.fraccionRecortadas,
  });

  static const sinDatos = EvaluacionCalidad(
    avisos: {},
    nivelDecibelios: -200,
    fraccionMuyGraves: 0,
    fraccionGraves: 0,
    variacionMuyGraves: 0,
    variacionGraves: 0,
    fraccionRecortadas: 0,
  );

  /// El aviso más importante, para el indicador (saturación > viento >
  /// tráfico > débil).
  AvisoCalidad? get principal {
    for (final aviso in AvisoCalidad.values) {
      if (avisos.contains(aviso)) return aviso;
    }
    return null;
  }
}

/// Coeficiente de variación del nivel (raíz de la energía) entre tramas.
double _variacion(Iterable<double> energias) {
  final niveles = [for (final energia in energias) math.sqrt(math.max(0, energia))];
  if (niveles.length < 2) return 0;
  final media = niveles.reduce((a, b) => a + b) / niveles.length;
  if (media <= 0) return 0;
  var sumaCuadrados = 0.0;
  for (final nivel in niveles) {
    sumaCuadrados += (nivel - media) * (nivel - media);
  }
  return math.sqrt(sumaCuadrados / niveles.length) / media;
}

/// Decide los avisos con unas tramas.
EvaluacionCalidad evaluarTramasCalidad(List<TramaCalidad> tramas) {
  if (tramas.isEmpty) return EvaluacionCalidad.sinDatos;
  var energiaTotal = 0.0, energiaMuyGraves = 0.0, energiaGraves = 0.0;
  var recortadas = 0, muestras = 0;
  for (final trama in tramas) {
    energiaTotal += trama.energiaTotal * trama.numeroMuestras;
    energiaMuyGraves += trama.energiaMuyGraves * trama.numeroMuestras;
    energiaGraves += trama.energiaGraves * trama.numeroMuestras;
    recortadas += trama.muestrasRecortadas;
    muestras += trama.numeroMuestras;
  }
  if (muestras == 0) return EvaluacionCalidad.sinDatos;
  final energiaMedia = energiaTotal / muestras;
  final nivel = energiaADecibelios(energiaMedia);
  final fraccionMuyGraves = energiaTotal > 0 ? (energiaMuyGraves / energiaTotal).clamp(0.0, 1.0) : 0.0;
  final fraccionGraves = energiaTotal > 0 ? (energiaGraves / energiaTotal).clamp(0.0, 1.0) : 0.0;
  final variacionMuyGraves = _variacion(tramas.map((trama) => trama.energiaMuyGraves));
  final variacionGraves = _variacion(tramas.map((trama) => trama.energiaGraves));
  final fraccionRecortadas = recortadas / muestras;
  final nivelGraves = energiaADecibelios(energiaGraves / muestras);

  final avisos = <AvisoCalidad>{};
  if (fraccionRecortadas > fraccionRecortadasSaturacion) avisos.add(AvisoCalidad.saturacion);
  final hayViento = nivel > nivelSenalDebilDecibelios &&
      fraccionMuyGraves >= fraccionMuyGravesViento &&
      variacionMuyGraves >= variacionMinimaViento;
  if (hayViento) avisos.add(AvisoCalidad.viento);
  if (!hayViento &&
      fraccionGraves >= fraccionGravesTrafico &&
      variacionGraves <= variacionMaximaTrafico &&
      nivelGraves >= nivelMinimoTraficoDecibelios) {
    avisos.add(AvisoCalidad.trafico);
  }
  if (nivel < nivelSenalDebilDecibelios) avisos.add(AvisoCalidad.senalDebil);
  return EvaluacionCalidad(
    avisos: avisos,
    nivelDecibelios: nivel,
    fraccionMuyGraves: fraccionMuyGraves,
    fraccionGraves: fraccionGraves,
    variacionMuyGraves: variacionMuyGraves,
    variacionGraves: variacionGraves,
    fraccionRecortadas: fraccionRecortadas,
  );
}

/// Recibe el audio del micrófono por bloques y va cerrando tramas.
class AnalizadorCalidadAudio {
  final double frecuenciaMuestreoHz;
  final int muestrasPorTrama;
  final int tramasGuardadas;

  /// Se llama al cerrar cada trama (el barrido de rumbo la usa).
  void Function(TramaCalidad trama)? alCerrarTrama;

  final FiltroBiquad _pasoBajoMuyGraves;
  final FiltroBiquad _pasoBajoGraves;
  final FiltroBiquad _pasoAltoCanto;
  final FiltroBiquad _pasoBajoCanto;
  final List<TramaCalidad> _tramas = [];
  double _sumaTotal = 0, _sumaMuyGraves = 0, _sumaGraves = 0, _sumaCanto = 0;
  int _recortadas = 0, _muestrasEnTrama = 0;

  AnalizadorCalidadAudio(
    this.frecuenciaMuestreoHz, {
    this.tramasGuardadas = tramasEvaluacionCalidad,
    this.alCerrarTrama,
  })  : muestrasPorTrama = math.max(1, (frecuenciaMuestreoHz * duracionTramaCalidadSegundos).round()),
        _pasoBajoMuyGraves = FiltroBiquad.pasoBajo(frecuenciaMuestreoHz, corteMuyGravesHz),
        _pasoBajoGraves = FiltroBiquad.pasoBajo(frecuenciaMuestreoHz, corteGravesHz),
        _pasoAltoCanto = FiltroBiquad.pasoAlto(frecuenciaMuestreoHz, inicioBandaCantoHz),
        _pasoBajoCanto = FiltroBiquad.pasoBajo(
            frecuenciaMuestreoHz, math.min(finBandaCantoHz, frecuenciaMuestreoHz * 0.45));

  List<TramaCalidad> get tramas => List.unmodifiable(_tramas);

  void procesar(List<double> bloque) {
    for (final muestra in bloque) {
      final muyGraves = _pasoBajoMuyGraves.procesar(muestra);
      final graves = _pasoBajoGraves.procesar(muestra);
      final canto = _pasoBajoCanto.procesar(_pasoAltoCanto.procesar(muestra));
      _sumaTotal += muestra * muestra;
      _sumaMuyGraves += muyGraves * muyGraves;
      _sumaGraves += graves * graves;
      _sumaCanto += canto * canto;
      if (muestra.abs() >= umbralMuestraRecortada) _recortadas++;
      _muestrasEnTrama++;
      if (_muestrasEnTrama >= muestrasPorTrama) _cerrarTrama();
    }
  }

  void _cerrarTrama() {
    final trama = TramaCalidad(
      energiaTotal: _sumaTotal / _muestrasEnTrama,
      energiaMuyGraves: _sumaMuyGraves / _muestrasEnTrama,
      energiaGraves: _sumaGraves / _muestrasEnTrama,
      energiaBandaCanto: _sumaCanto / _muestrasEnTrama,
      muestrasRecortadas: _recortadas,
      numeroMuestras: _muestrasEnTrama,
    );
    _tramas.add(trama);
    if (_tramas.length > tramasGuardadas) _tramas.removeAt(0);
    _sumaTotal = _sumaMuyGraves = _sumaGraves = _sumaCanto = 0;
    _recortadas = 0;
    _muestrasEnTrama = 0;
    alCerrarTrama?.call(trama);
  }

  EvaluacionCalidad evaluar() => evaluarTramasCalidad(_tramas);

  void reiniciar() {
    _tramas.clear();
    _sumaTotal = _sumaMuyGraves = _sumaGraves = _sumaCanto = 0;
    _recortadas = 0;
    _muestrasEnTrama = 0;
    for (final filtro in [_pasoBajoMuyGraves, _pasoBajoGraves, _pasoAltoCanto, _pasoBajoCanto]) {
      filtro.reiniciar();
    }
  }
}
