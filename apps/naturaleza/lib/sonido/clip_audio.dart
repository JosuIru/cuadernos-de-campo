import 'dart:math' as math;
import 'dart:typed_data';

/// Clip de audio que se adjunta a un hallazgo identificado por el sonido.
///
/// Se guarda el trozo analizado (5 s a 32 kHz) y, si el trozo anterior era
/// inmediatamente anterior y limpio (sin voz humana), también la parte de
/// él que no se solapa: 7,5 s con solape, 10 s sin él. Nunca se juntan
/// trozos con voz humana: esos se descartan sin guardar nada.

/// Duración máxima del clip (dos ventanas del modelo).
const double duracionMaximaClipSegundos = 10;

/// Muestras en −1…1 a PCM de 16 bits con signo (con recorte).
Int16List flotanteAPcm16(List<double> muestras) {
  final resultado = Int16List(muestras.length);
  for (var indice = 0; indice < muestras.length; indice++) {
    final valor = (muestras[indice] * 32767).round();
    resultado[indice] = valor.clamp(-32768, 32767);
  }
  return resultado;
}

/// Une la parte nueva del trozo anterior con el actual. [separacionMuestras]
/// es cuánto avanzó el audio entre el final de uno y el del otro (a la
/// frecuencia de los trozos). Si no hay anterior, o la separación es mayor
/// que un trozo (se saltaron trozos), o no es positiva, el clip es solo el
/// trozo actual.
Int16List componerClip({
  required Int16List trozoActual,
  Int16List? trozoAnterior,
  int separacionMuestras = 0,
}) {
  if (trozoAnterior == null ||
      separacionMuestras <= 0 ||
      separacionMuestras > trozoActual.length ||
      separacionMuestras > trozoAnterior.length) {
    return Int16List.fromList(trozoActual);
  }
  // Las primeras `separacionMuestras` del anterior son las que no están en
  // el actual.
  final clip = Int16List(separacionMuestras + trozoActual.length);
  clip.setRange(0, separacionMuestras, trozoAnterior);
  clip.setRange(separacionMuestras, clip.length, trozoActual);
  return clip;
}

/// Fichero WAV (RIFF, PCM 16 bits, mono) con [muestras] a [frecuenciaHz].
Uint8List codificarWavMono16(Int16List muestras, int frecuenciaHz) {
  const bytesCabecera = 44;
  const bytesPorMuestra = 2;
  final bytesDatos = muestras.length * bytesPorMuestra;
  final bytes = Uint8List(bytesCabecera + bytesDatos);
  final datos = ByteData.sublistView(bytes);
  void escribirTexto(int posicion, String texto) {
    for (var indice = 0; indice < texto.length; indice++) {
      bytes[posicion + indice] = texto.codeUnitAt(indice);
    }
  }

  escribirTexto(0, 'RIFF');
  datos.setUint32(4, 36 + bytesDatos, Endian.little);
  escribirTexto(8, 'WAVE');
  escribirTexto(12, 'fmt ');
  datos.setUint32(16, 16, Endian.little); // tamaño del bloque fmt
  datos.setUint16(20, 1, Endian.little); // PCM
  datos.setUint16(22, 1, Endian.little); // mono
  datos.setUint32(24, frecuenciaHz, Endian.little);
  datos.setUint32(28, frecuenciaHz * bytesPorMuestra, Endian.little); // bytes por segundo
  datos.setUint16(32, bytesPorMuestra, Endian.little); // alineación de bloque
  datos.setUint16(34, 16, Endian.little); // bits por muestra
  escribirTexto(36, 'data');
  datos.setUint32(40, bytesDatos, Endian.little);
  for (var indice = 0; indice < muestras.length; indice++) {
    datos.setInt16(bytesCabecera + indice * bytesPorMuestra, muestras[indice], Endian.little);
  }
  return bytes;
}

/// Duración en segundos de [numeroMuestras] a [frecuenciaHz].
double duracionSegundos(int numeroMuestras, int frecuenciaHz) =>
    frecuenciaHz <= 0 ? 0 : numeroMuestras / frecuenciaHz;

/// Convierte la separación entre trozos medida a la frecuencia del micrófono
/// a la de los trozos remuestreados.
int separacionEnFrecuenciaModelo(
  int separacionMuestrasMicrofono,
  int frecuenciaMicrofonoHz,
  int frecuenciaModeloHz,
) {
  if (frecuenciaMicrofonoHz <= 0) return 0;
  return math.max(
      0, (separacionMuestrasMicrofono * frecuenciaModeloHz / frecuenciaMicrofonoHz).round());
}
