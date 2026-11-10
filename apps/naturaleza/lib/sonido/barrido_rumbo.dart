import 'dart:math' as math;

import 'triangulacion_rumbos.dart';

/// Modo barrido de «¿Dónde está?»: la persona gira despacio sobre sí misma
/// con el móvil pegado al pecho (el cuerpo hace de pantalla: el micrófono
/// del móvil no tiene dirección) y se apunta el nivel de la banda del canto
/// frente al rumbo. El rumbo de más nivel se propone como toma,
/// **orientativa**.
///
/// Se usa la energía de la banda (1-8 kHz) en tramas de 0,1 s y no la
/// puntuación del modelo: el modelo da un valor cada 2,5-5 s, demasiado
/// poco para una vuelta.

/// Ancho de cada sector del histograma de rumbos.
const double anchoSectorBarridoGrados = 10;

/// Hay que haber barrido al menos esto para proponer un rumbo.
const double coberturaMinimaBarridoGrados = 180;

/// El sector de más nivel debe superar la mediana en esto.
const double contrasteMinimoBarridoDecibelios = 3;

class MuestraBarrido {
  final double rumboGrados;
  final double nivelDecibelios;
  const MuestraBarrido(this.rumboGrados, this.nivelDecibelios);
}

class ResultadoBarrido {
  /// Rumbo propuesto, o null si no hay un máximo claro.
  final double? rumboMaximoGrados;
  final double coberturaGrados;

  /// Nivel del máximo menos la mediana de los sectores.
  final double contrasteDecibelios;

  /// Nivel medio por sector (null donde no hay muestras), para dibujarlo.
  final List<double?> nivelPorSectorDecibelios;

  const ResultadoBarrido({
    required this.rumboMaximoGrados,
    required this.coberturaGrados,
    required this.contrasteDecibelios,
    required this.nivelPorSectorDecibelios,
  });

  bool get coberturaSuficiente => coberturaGrados >= coberturaMinimaBarridoGrados;
  bool get hayMaximoClaro => rumboMaximoGrados != null;
}

double _decibeliosAPotencia(double decibelios) => math.pow(10, decibelios / 10).toDouble();
double _potenciaADecibelios(double potencia) => 10 * math.log(math.max(1e-20, potencia)) / math.ln10;

ResultadoBarrido analizarBarrido(
  List<MuestraBarrido> muestras, {
  double anchoSectorGrados = anchoSectorBarridoGrados,
  double coberturaMinimaGrados = coberturaMinimaBarridoGrados,
  double contrasteMinimoDecibelios = contrasteMinimoBarridoDecibelios,
}) {
  final numeroSectores = math.max(1, (360 / anchoSectorGrados).round());
  final anchoReal = 360 / numeroSectores;
  final sumaPotencia = List<double>.filled(numeroSectores, 0);
  final cuentas = List<int>.filled(numeroSectores, 0);
  for (final muestra in muestras) {
    if (!muestra.nivelDecibelios.isFinite || !muestra.rumboGrados.isFinite) continue;
    // Sector centrado en múltiplos del ancho: el 0 va de −5° a 5°.
    final sector =
        ((normalizarRumbo(muestra.rumboGrados) + anchoReal / 2) / anchoReal).floor() % numeroSectores;
    sumaPotencia[sector] += _decibeliosAPotencia(muestra.nivelDecibelios);
    cuentas[sector]++;
  }
  final nivelPorSector = <double?>[
    for (var sector = 0; sector < numeroSectores; sector++)
      cuentas[sector] == 0 ? null : _potenciaADecibelios(sumaPotencia[sector] / cuentas[sector]),
  ];
  final sectoresConDatos = cuentas.where((cuenta) => cuenta > 0).length;
  final cobertura = sectoresConDatos * anchoReal;
  if (sectoresConDatos == 0) {
    return ResultadoBarrido(
      rumboMaximoGrados: null,
      coberturaGrados: 0,
      contrasteDecibelios: 0,
      nivelPorSectorDecibelios: nivelPorSector,
    );
  }
  // Suavizado circular con los vecinos (pesos 1-2-1) para que un golpe suelto
  // no gane.
  final potenciaSuavizada = List<double?>.filled(numeroSectores, null);
  for (var sector = 0; sector < numeroSectores; sector++) {
    if (nivelPorSector[sector] == null) continue;
    var suma = 0.0;
    var pesos = 0.0;
    for (final (desplazamiento, peso) in const [(-1, 1.0), (0, 2.0), (1, 1.0)]) {
      final vecino = (sector + desplazamiento + numeroSectores) % numeroSectores;
      final nivel = nivelPorSector[vecino];
      if (nivel == null) continue;
      suma += peso * _decibeliosAPotencia(nivel);
      pesos += peso;
    }
    potenciaSuavizada[sector] = suma / pesos;
  }
  var sectorMaximo = -1;
  for (var sector = 0; sector < numeroSectores; sector++) {
    final potencia = potenciaSuavizada[sector];
    if (potencia == null) continue;
    if (sectorMaximo < 0 || potencia > potenciaSuavizada[sectorMaximo]!) sectorMaximo = sector;
  }
  final nivelesOrdenados = [
    for (final potencia in potenciaSuavizada)
      if (potencia != null) _potenciaADecibelios(potencia)
  ]..sort();
  final mediana = nivelesOrdenados[nivelesOrdenados.length ~/ 2];
  final contraste = _potenciaADecibelios(potenciaSuavizada[sectorMaximo]!) - mediana;

  double? rumboMaximo;
  if (cobertura >= coberturaMinimaGrados && contraste >= contrasteMinimoDecibelios) {
    // Afinado: media circular de los centros del máximo y sus vecinos,
    // pesada por la potencia sin suavizar.
    var sumaSeno = 0.0;
    var sumaCoseno = 0.0;
    for (final desplazamiento in const [-1, 0, 1]) {
      final vecino = (sectorMaximo + desplazamiento + numeroSectores) % numeroSectores;
      final nivel = nivelPorSector[vecino];
      if (nivel == null) continue;
      final peso = _decibeliosAPotencia(nivel);
      final radianes = vecino * anchoReal * math.pi / 180;
      sumaSeno += peso * math.sin(radianes);
      sumaCoseno += peso * math.cos(radianes);
    }
    rumboMaximo = normalizarRumbo(math.atan2(sumaSeno, sumaCoseno) * 180 / math.pi);
  }
  return ResultadoBarrido(
    rumboMaximoGrados: rumboMaximo,
    coberturaGrados: cobertura,
    contrasteDecibelios: contraste,
    nivelPorSectorDecibelios: nivelPorSector,
  );
}
