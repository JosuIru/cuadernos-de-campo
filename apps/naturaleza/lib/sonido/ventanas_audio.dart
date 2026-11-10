import 'dart:math' as math;
import 'dart:typed_data';

/// Trocea el audio continuo del micrófono en ventanas de duración fija (5 s
/// para el modelo), con solape opcional. Guarda solo la última ventana en un
/// búfer circular: si el análisis va más lento que el audio, se salta
/// ventanas y siempre entrega la más reciente. Portado de `audioWindowing.ts`.

/// Salto entre ventanas con solape (la mitad de la ventana del modelo).
const double saltoConSolapeSegundos = 2.5;

/// Sin solape: una ventana detrás de otra.
const double saltoSinSolapeSegundos = 5;

/// Con solape, cada ventana hay que analizarla en 2,5 s. Si remuestrear y
/// pasar el modelo tarda más de esta fracción del salto, se quita el solape
/// para no saturar el móvil (ni calentarlo).
const double _fraccionMaximaOcupadaParaSolapar = 0.6;

/// Elige el salto entre ventanas según lo que tardó el último análisis (null
/// si aún no hay).
double elegirSaltoSegundos(int? milisegundosUltimoAnalisis) {
  if (milisegundosUltimoAnalisis == null) return saltoConSolapeSegundos;
  return milisegundosUltimoAnalisis <=
          _fraccionMaximaOcupadaParaSolapar * saltoConSolapeSegundos * 1000
      ? saltoConSolapeSegundos
      : saltoSinSolapeSegundos;
}

class RecolectorVentanasAudio {
  final int muestrasPorVentana;
  final Float32List _bufferCircular;
  int _indiceEscritura = 0;
  int _muestrasGuardadas = 0;
  int _muestrasDesdeUltimaVentana = 0;
  int _muestrasRecibidasTotales = 0;

  RecolectorVentanasAudio(this.muestrasPorVentana)
      : _bufferCircular = Float32List(muestrasPorVentana > 0 ? muestrasPorVentana : 1) {
    if (muestrasPorVentana <= 0) {
      throw RangeError('La ventana debe tener un número positivo de muestras');
    }
  }

  /// Muestras recibidas desde el principio (o desde [reiniciar]): sirve para
  /// saber cuánto separa dos ventanas entregadas.
  int get muestrasRecibidasTotales => _muestrasRecibidasTotales;

  /// Añade un bloque de muestras (se copian).
  void anadirMuestras(List<double> muestrasEntrantes) {
    final longitudEntrante = muestrasEntrantes.length;
    // Si el bloque es más largo que la ventana, solo cuentan sus últimas muestras.
    final saltadas = math.max(0, longitudEntrante - muestrasPorVentana);
    for (var indice = saltadas; indice < longitudEntrante; indice++) {
      _bufferCircular[_indiceEscritura] = muestrasEntrantes[indice];
      _indiceEscritura = (_indiceEscritura + 1) % muestrasPorVentana;
    }
    _muestrasGuardadas = math.min(muestrasPorVentana, _muestrasGuardadas + longitudEntrante);
    _muestrasDesdeUltimaVentana += longitudEntrante;
    _muestrasRecibidasTotales += longitudEntrante;
  }

  /// Devuelve una copia de la última ventana completa si desde la anterior han
  /// llegado al menos [muestrasSalto] muestras nuevas; si no, `null`.
  Float32List? tomarVentanaSiLista(int muestrasSalto) {
    if (_muestrasGuardadas < muestrasPorVentana || _muestrasDesdeUltimaVentana < muestrasSalto) {
      return null;
    }
    _muestrasDesdeUltimaVentana = 0;
    // El búfer está lleno: la muestra más antigua es la que toca sobrescribir.
    final ventana = Float32List(muestrasPorVentana);
    ventana.setRange(0, muestrasPorVentana - _indiceEscritura, _bufferCircular, _indiceEscritura);
    ventana.setRange(muestrasPorVentana - _indiceEscritura, muestrasPorVentana, _bufferCircular);
    return ventana;
  }

  void reiniciar() {
    _bufferCircular.fillRange(0, _bufferCircular.length, 0);
    _indiceEscritura = 0;
    _muestrasGuardadas = 0;
    _muestrasDesdeUltimaVentana = 0;
    _muestrasRecibidasTotales = 0;
  }
}

/// Nivel RMS en dBFS de un trozo (para avisar si el micrófono no capta nada).
double nivelRmsDecibelios(List<double> muestras) {
  var sumaCuadrados = 0.0;
  for (final muestra in muestras) {
    sumaCuadrados += muestra * muestra;
  }
  final media = sumaCuadrados / math.max(1, muestras.length);
  return 10 * math.log(math.max(1e-20, media)) / math.ln10;
}

/// Convierte PCM de 16 bits con signo, little-endian (lo que da el
/// micrófono), a muestras en −1…1. Un byte suelto al final se ignora.
Float32List pcm16ABloqueFlotante(Uint8List bytesPcm) {
  final numeroMuestras = bytesPcm.length ~/ 2;
  final datos = ByteData.sublistView(bytesPcm);
  final muestras = Float32List(numeroMuestras);
  for (var indice = 0; indice < numeroMuestras; indice++) {
    muestras[indice] = datos.getInt16(indice * 2, Endian.little) / 32768.0;
  }
  return muestras;
}
