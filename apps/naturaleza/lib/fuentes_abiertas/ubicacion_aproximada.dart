/// Ubicación redondeada que se envía a GBIF. La exacta nunca sale del
/// móvil ni se guarda.
///
/// - Escala normal: cuadrícula de 0,1° (≈ 11 km) y radio de 20 km.
/// - Escala amplia (especies protegidas o con coordenadas generalizadas en
///   GBIF): cuadrícula de 0,5° (≈ 55 km) y radio de 75 km.
class UbicacionAproximada {
  const UbicacionAproximada._({
    required this.latitud,
    required this.longitud,
    required this.radioKm,
    required this.escalaAmplia,
  });

  final double latitud;
  final double longitud;
  final int radioKm;
  final bool escalaAmplia;

  static const double pasoNormalGrados = 0.1;
  static const double pasoAmplioGrados = 0.5;
  static const int radioNormalKm = 20;
  static const int radioAmplioKm = 75;

  /// Redondea [latitudExacta] y [longitudExacta] a la cuadrícula de la
  /// escala pedida.
  factory UbicacionAproximada.desde(
    double latitudExacta,
    double longitudExacta, {
    bool escalaAmplia = false,
  }) {
    final paso = escalaAmplia ? pasoAmplioGrados : pasoNormalGrados;
    return UbicacionAproximada._(
      latitud: redondearACuadricula(latitudExacta.clamp(-90.0, 90.0), paso),
      longitud: redondearACuadricula(_normalizarLongitud(longitudExacta), paso),
      radioKm: escalaAmplia ? radioAmplioKm : radioNormalKm,
      escalaAmplia: escalaAmplia,
    );
  }

  /// La misma zona a escala amplia.
  UbicacionAproximada aEscalaAmplia() =>
      escalaAmplia ? this : UbicacionAproximada.desde(latitud, longitud, escalaAmplia: true);

  /// `lat,lon` con los decimales justos de la cuadrícula (para la URL y la
  /// clave de caché).
  String get textoCoordenadas => '${latitud.toStringAsFixed(1)},${longitud.toStringAsFixed(1)}';

  /// Valor del parámetro `geoDistance` de GBIF.
  String get parametroDistanciaGbif => '$textoCoordenadas,${radioKm}km';

  @override
  bool operator ==(Object other) =>
      other is UbicacionAproximada &&
      other.textoCoordenadas == textoCoordenadas &&
      other.radioKm == radioKm &&
      other.escalaAmplia == escalaAmplia;

  @override
  int get hashCode => Object.hash(textoCoordenadas, radioKm, escalaAmplia);
}

/// Redondea [grados] al múltiplo de [paso] más cercano, sin restos de coma
/// flotante (0.30000000000000004 → 0.3).
double redondearACuadricula(double grados, double paso) {
  final multiplo = (grados / paso).round() * paso;
  return double.parse(multiplo.toStringAsFixed(4));
}

double _normalizarLongitud(double longitud) {
  var normalizada = longitud;
  while (normalizada > 180) {
    normalizada -= 360;
  }
  while (normalizada < -180) {
    normalizada += 360;
  }
  return normalizada;
}
