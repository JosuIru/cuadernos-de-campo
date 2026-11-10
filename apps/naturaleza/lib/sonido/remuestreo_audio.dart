import 'dart:math' as math;
import 'dart:typed_data';

/// Remuestreo de audio con filtro antialias (interpolación sinc con ventana
/// de Blackman). Portado de «¿Quién canta?» de Laboratorio de Bolsillo
/// (`audioResampling.ts`).
///
/// El micrófono da 48 kHz (o 44,1 kHz) y el modelo quiere 32 kHz. Interpolar
/// sin filtrar dejaría pasar como «fantasmas» graves lo que hay por encima de
/// 16 kHz (insectos, ultrasonidos de murciélagos, ruido eléctrico): el filtro
/// corta un poco por debajo de la nueva frecuencia de Nyquist antes de
/// interpolar. Es un remuestreador de ventana entera (no de flujo): se aplica
/// a cada trozo de 5 s por separado.

/// Pasos por cero del sinc a cada lado: más, mejor corte pero más cálculo.
const int _pasosPorCeroPorLado = 10;

/// Fracción de la nueva frecuencia de Nyquist donde empieza el corte.
const double _fraccionCorteDeNyquist = 0.92;

/// Resolución de la tabla del núcleo: posiciones por muestra de origen.
const int _pasosTablaPorMuestra = 256;

class _NucleoRemuestreo {
  final int semiAnchoMuestras;
  final Float32List tablaNucleo;
  const _NucleoRemuestreo(this.semiAnchoMuestras, this.tablaNucleo);
}

final Map<String, _NucleoRemuestreo> _cacheNucleos = {};

double _ventanaBlackman(double posicionNormalizada) {
  // posicionNormalizada en [-1, 1]; 0 en el centro.
  final fase = math.pi * (posicionNormalizada + 1);
  return 0.42 - 0.5 * math.cos(fase) + 0.08 * math.cos(2 * fase);
}

_NucleoRemuestreo _construirNucleo(int frecuenciaOrigenHz, int frecuenciaDestinoHz) {
  final claveCache = '$frecuenciaOrigenHz-$frecuenciaDestinoHz';
  final nucleoGuardado = _cacheNucleos[claveCache];
  if (nucleoGuardado != null) return nucleoGuardado;
  // Frecuencia de corte relativa a la de Nyquist de origen (1 = sin filtrar).
  final razonCorte =
      math.min(1.0, frecuenciaDestinoHz / frecuenciaOrigenHz) * _fraccionCorteDeNyquist;
  final semiAnchoMuestras = (_pasosPorCeroPorLado / razonCorte).ceil();
  final longitudTabla = semiAnchoMuestras * _pasosTablaPorMuestra + 2;
  final tablaNucleo = Float32List(longitudTabla);
  for (var indiceTabla = 0; indiceTabla < longitudTabla; indiceTabla++) {
    final distanciaMuestras = indiceTabla / _pasosTablaPorMuestra;
    if (distanciaMuestras >= semiAnchoMuestras) continue;
    final argumentoSinc = math.pi * razonCorte * distanciaMuestras;
    final valorSinc = argumentoSinc == 0 ? 1.0 : math.sin(argumentoSinc) / argumentoSinc;
    tablaNucleo[indiceTabla] =
        razonCorte * valorSinc * _ventanaBlackman(distanciaMuestras / semiAnchoMuestras);
  }
  final nucleo = _NucleoRemuestreo(semiAnchoMuestras, tablaNucleo);
  _cacheNucleos[claveCache] = nucleo;
  return nucleo;
}

/// Remuestrea [muestrasEntrada] de [frecuenciaOrigenHz] a
/// [frecuenciaDestinoHz]. Fuera del trozo se supone silencio.
/// [longitudSalida] fija la longitud de salida (se rellena con ceros si falta
/// audio); por defecto, la que corresponde a la duración de la entrada.
Float32List remuestrearConPasoBajo(
  List<double> muestrasEntrada,
  int frecuenciaOrigenHz,
  int frecuenciaDestinoHz, {
  int? longitudSalida,
}) {
  if (frecuenciaOrigenHz <= 0 || frecuenciaDestinoHz <= 0) {
    throw RangeError('Las frecuencias deben ser positivas');
  }
  final longitudFinal = longitudSalida ??
      (muestrasEntrada.length * frecuenciaDestinoHz) ~/ frecuenciaOrigenHz;
  final muestrasSalida = Float32List(longitudFinal);
  final longitudEntrada = muestrasEntrada.length;
  if (frecuenciaOrigenHz == frecuenciaDestinoHz) {
    final copiables = math.min(longitudFinal, longitudEntrada);
    for (var indice = 0; indice < copiables; indice++) {
      muestrasSalida[indice] = muestrasEntrada[indice];
    }
    return muestrasSalida;
  }
  final nucleo = _construirNucleo(frecuenciaOrigenHz, frecuenciaDestinoHz);
  final semiAncho = nucleo.semiAnchoMuestras;
  final tablaNucleo = nucleo.tablaNucleo;
  final pasoOrigenPorSalida = frecuenciaOrigenHz / frecuenciaDestinoHz;

  for (var indiceSalida = 0; indiceSalida < longitudFinal; indiceSalida++) {
    final posicionOrigen = indiceSalida * pasoOrigenPorSalida;
    final indiceCentral = posicionOrigen.floor();
    final primerIndice = math.max(0, indiceCentral - semiAncho + 1);
    final ultimoIndice = math.min(longitudEntrada - 1, indiceCentral + semiAncho);
    var sumaPonderada = 0.0;
    var sumaPesos = 0.0;
    for (var indiceOrigen = primerIndice; indiceOrigen <= ultimoIndice; indiceOrigen++) {
      final posicionTabla = (posicionOrigen - indiceOrigen).abs() * _pasosTablaPorMuestra;
      final indiceTablaInferior = posicionTabla.floor();
      final fraccionTabla = posicionTabla - indiceTablaInferior;
      final pesoNucleo = tablaNucleo[indiceTablaInferior] +
          fraccionTabla * (tablaNucleo[indiceTablaInferior + 1] - tablaNucleo[indiceTablaInferior]);
      sumaPonderada += pesoNucleo * muestrasEntrada[indiceOrigen];
      sumaPesos += pesoNucleo;
    }
    // Dentro del trozo la suma de pesos es ≈1 (ganancia unidad en continua).
    // En los bordes, donde falta la mitad del núcleo, no se normaliza: el
    // silencio de fuera cuenta como tal.
    final esInterior =
        indiceCentral - semiAncho + 1 >= 0 && indiceCentral + semiAncho < longitudEntrada;
    muestrasSalida[indiceSalida] =
        esInterior && sumaPesos != 0 ? sumaPonderada / sumaPesos : sumaPonderada;
  }
  return muestrasSalida;
}
