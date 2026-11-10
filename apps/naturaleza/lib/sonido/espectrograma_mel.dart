import 'dart:typed_data';

/// Pinta el espectrograma log-mel que devuelve el modelo (tramas × bandas
/// mel, trama a trama) en un búfer RGBA con el tiempo en horizontal y los
/// graves abajo. La escala de color se ajusta a cada trozo (percentiles),
/// porque los valores log-mel del modelo no están en dB calibrados. Portado
/// de `melSpectrogramPixels.ts`.

/// Percentiles que marcan el negro y el blanco de la paleta.
const double _percentilBajo = 0.05;
const double _percentilAlto = 0.995;

class RangoValores {
  final double minimo;
  final double maximo;
  const RangoValores(this.minimo, this.maximo);
}

RangoValores rangoPorPercentiles(List<double> valores) {
  final finitos = valores.where((valor) => valor.isFinite).toList()..sort();
  if (finitos.isEmpty) return const RangoValores(0, 1);
  double valorEn(double fraccion) {
    final indice = (fraccion * (finitos.length - 1)).round().clamp(0, finitos.length - 1);
    return finitos[indice];
  }

  final minimo = valorEn(_percentilBajo);
  final maximo = valorEn(_percentilAlto);
  return RangoValores(minimo, maximo > minimo ? maximo : minimo + 1);
}

/// Paleta de 256 colores RGB intercalados: de verde muy oscuro a amarillo
/// claro, legible sobre fondo claro y oscuro.
Uint8List paletaEspectrograma() {
  final paleta = Uint8List(256 * 3);
  for (var nivel = 0; nivel < 256; nivel++) {
    final fraccion = nivel / 255;
    paleta[nivel * 3] = (20 + 230 * fraccion * fraccion).round().clamp(0, 255);
    paleta[nivel * 3 + 1] = (30 + 215 * fraccion).round().clamp(0, 255);
    paleta[nivel * 3 + 2] = (35 + 90 * (1 - fraccion) * fraccion).round().clamp(0, 255);
  }
  return paleta;
}

/// Rellena [pixeles] (RGBA, [numeroTramas] de ancho × [numeroBandas] de alto)
/// con la paleta [paleta] (256 colores RGB intercalados).
void pintarEspectrogramaMel(
  List<double> espectrograma,
  int numeroTramas,
  int numeroBandas,
  Uint8List pixeles,
  Uint8List paleta,
) {
  final rango = rangoPorPercentiles(espectrograma);
  final nivelesPorUnidad = 255 / (rango.maximo - rango.minimo);
  for (var trama = 0; trama < numeroTramas; trama++) {
    for (var banda = 0; banda < numeroBandas; banda++) {
      final indiceValor = trama * numeroBandas + banda;
      final valor =
          indiceValor < espectrograma.length ? espectrograma[indiceValor] : rango.minimo;
      final nivelReal = (valor - rango.minimo) * nivelesPorUnidad;
      final nivel = nivelReal.isFinite ? nivelReal.round().clamp(0, 255) : 0;
      final fila = numeroBandas - 1 - banda;
      final desplazamiento = (fila * numeroTramas + trama) * 4;
      pixeles[desplazamiento] = paleta[nivel * 3];
      pixeles[desplazamiento + 1] = paleta[nivel * 3 + 1];
      pixeles[desplazamiento + 2] = paleta[nivel * 3 + 2];
      pixeles[desplazamiento + 3] = 255;
    }
  }
}
