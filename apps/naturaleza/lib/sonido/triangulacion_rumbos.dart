import 'dart:math' as math;

/// «¿Dónde está?»: la persona apunta el móvil hacia el sonido desde dos o
/// más sitios («Viene de aquí») y se cruza cada rumbo, con su margen de
/// error, para estimar la zona donde está el animal.
///
/// Cada toma es una cuña: un vértice (la posición, retrasado lo necesario
/// para cubrir el error del GPS), el rumbo ± su incertidumbre y un alcance
/// máximo (a más distancia ya no se oye). La zona es la intersección de las
/// cuñas, un polígono convexo. Todo se calcula en un plano local en metros
/// (proyección equirrectangular alrededor de la primera toma), que a la
/// escala de lo que se oye (hasta 1-2 km) no se aparta del elipsoide.
///
/// Sin Flutter ni sensores: lógica pura, con tests.

/// Radio medio de la Tierra (IUGG), en metros.
const double radioTierraMetros = 6371008.8;

/// Semiapertura por defecto de cada toma: cuánto puede desviarse el rumbo
/// (brújula del móvil, pulso, eco del sonido). Configurable en la pantalla.
const double incertidumbrePorDefectoGrados = 10;

/// Semiapertura de una toma propuesta por el barrido (más dudosa).
const double incertidumbreBarridoGrados = 20;

/// Límites de la semiapertura: por encima de 80° la cuña deja de servir
/// (y de ser convexa a 90°).
const double incertidumbreMinimaGrados = 1;
const double incertidumbreMaximaGrados = 80;

double normalizarRumbo(double grados) {
  final resto = grados % 360;
  return resto < 0 ? resto + 360 : resto;
}

/// Diferencia con signo de [desde] a [hasta], en (−180, 180]: cuánto hay
/// que girar a la derecha (positivo) o a la izquierda. Cruza bien el norte
/// (de 350° a 10° son +20°).
double diferenciaAngular(double desde, double hasta) {
  var diferencia = normalizarRumbo(hasta - desde);
  if (diferencia > 180) diferencia -= 360;
  return diferencia;
}

/// Media de rumbos (circular: la de 350° y 10° es 0°, no 180°). Null si no
/// hay rumbos o se anulan entre sí.
double? mediaCircularGrados(List<double> rumbos) {
  if (rumbos.isEmpty) return null;
  var sumaSeno = 0.0;
  var sumaCoseno = 0.0;
  for (final rumbo in rumbos) {
    final radianes = rumbo * math.pi / 180;
    sumaSeno += math.sin(radianes);
    sumaCoseno += math.cos(radianes);
  }
  final longitudResultante = math.sqrt(sumaSeno * sumaSeno + sumaCoseno * sumaCoseno) / rumbos.length;
  if (longitudResultante < 1e-6) return null;
  return normalizarRumbo(math.atan2(sumaSeno, sumaCoseno) * 180 / math.pi);
}

/// Punto en el plano local: metros al este y al norte del origen.
class PuntoLocal {
  final double este;
  final double norte;
  const PuntoLocal(this.este, this.norte);

  PuntoLocal operator +(PuntoLocal otro) => PuntoLocal(este + otro.este, norte + otro.norte);
  PuntoLocal operator -(PuntoLocal otro) => PuntoLocal(este - otro.este, norte - otro.norte);
  PuntoLocal operator *(double factor) => PuntoLocal(este * factor, norte * factor);
  double get longitud => math.sqrt(este * este + norte * norte);

  @override
  String toString() => 'PuntoLocal(${este.toStringAsFixed(1)}, ${norte.toStringAsFixed(1)})';
}

/// Dirección unitaria de un rumbo (0° = norte, 90° = este).
PuntoLocal direccionDeRumbo(double rumboGrados) {
  final radianes = rumboGrados * math.pi / 180;
  return PuntoLocal(math.sin(radianes), math.cos(radianes));
}

/// Proyección equirrectangular alrededor de un origen.
class ProyeccionLocal {
  final double latitudOrigen;
  final double longitudOrigen;
  final double _metrosPorGradoLatitud;
  final double _metrosPorGradoLongitud;

  ProyeccionLocal(this.latitudOrigen, this.longitudOrigen)
      : _metrosPorGradoLatitud = radioTierraMetros * math.pi / 180,
        _metrosPorGradoLongitud = radioTierraMetros * math.pi / 180 * math.cos(latitudOrigen * math.pi / 180);

  PuntoLocal aLocal(double latitud, double longitud) => PuntoLocal(
        (longitud - longitudOrigen) * _metrosPorGradoLongitud,
        (latitud - latitudOrigen) * _metrosPorGradoLatitud,
      );

  ({double latitud, double longitud}) aGeografica(PuntoLocal punto) => (
        latitud: latitudOrigen + punto.norte / _metrosPorGradoLatitud,
        longitud: longitudOrigen + punto.este / _metrosPorGradoLongitud,
      );
}

/// Una toma de «Viene de aquí».
class TomaRumbo {
  final double latitud;
  final double longitud;

  /// Precisión del GPS (radio, en metros), si se conoce.
  final double? precisionMetros;

  /// Rumbo hacia el sonido, 0-360°. Verdadero si [declinacionCorregida];
  /// si no, magnético (en la península la diferencia es de 1-2°).
  final double rumboGrados;

  /// Semiapertura: el animal está entre rumbo − incertidumbre y rumbo +
  /// incertidumbre.
  final double incertidumbreGrados;

  /// Lo que dice el propio sensor de su precisión (Android solo da tres
  /// niveles, 15°, 30° o 45°), si lo dice.
  final double? precisionBrujulaGrados;
  final bool declinacionCorregida;

  /// Propuesta por el barrido (nivel frente a rumbo): orientativa.
  final bool orientativa;
  final DateTime momento;

  const TomaRumbo({
    required this.latitud,
    required this.longitud,
    required this.rumboGrados,
    required this.momento,
    this.precisionMetros,
    this.incertidumbreGrados = incertidumbrePorDefectoGrados,
    this.precisionBrujulaGrados,
    this.declinacionCorregida = false,
    this.orientativa = false,
  });

  Map<String, dynamic> aJson() => {
        'lat': latitud,
        'lng': longitud,
        if (precisionMetros != null) 'precision_m': _redondear(precisionMetros!, 1),
        'rumbo': _redondear(normalizarRumbo(rumboGrados), 1),
        'incertidumbre': _redondear(incertidumbreGrados, 1),
        if (precisionBrujulaGrados != null) 'precision_brujula': precisionBrujulaGrados,
        'rumbo_verdadero': declinacionCorregida,
        if (orientativa) 'orientativa': true,
        'momento_ms': momento.millisecondsSinceEpoch,
      };

  static TomaRumbo? desdeJson(Object? crudo) {
    if (crudo is! Map) return null;
    final latitud = crudo['lat'];
    final longitud = crudo['lng'];
    final rumbo = crudo['rumbo'];
    if (latitud is! num || longitud is! num || rumbo is! num) return null;
    return TomaRumbo(
      latitud: latitud.toDouble(),
      longitud: longitud.toDouble(),
      rumboGrados: rumbo.toDouble(),
      precisionMetros: (crudo['precision_m'] as num?)?.toDouble(),
      incertidumbreGrados: (crudo['incertidumbre'] as num?)?.toDouble() ?? incertidumbrePorDefectoGrados,
      precisionBrujulaGrados: (crudo['precision_brujula'] as num?)?.toDouble(),
      declinacionCorregida: crudo['rumbo_verdadero'] == true,
      orientativa: crudo['orientativa'] == true,
      momento: DateTime.fromMillisecondsSinceEpoch((crudo['momento_ms'] as num?)?.toInt() ?? 0),
    );
  }
}

double _redondear(double valor, int decimales) => double.parse(valor.toStringAsFixed(decimales));

/// Umbrales de los avisos. Orientativos: se pueden afinar con uso real.
class ParametrosTriangulacion {
  /// A más distancia no se oye un canto (casi ningún animal pequeño se oye a
  /// más de 1-2 km): cierra las cuñas.
  final double alcanceMaximoMetros;

  /// Dos tomas a menos de esto (o a menos que la suma de sus errores de
  /// GPS) están demasiado juntas para cruzar los rumbos.
  final double separacionMinimaMetros;

  /// Si dos rumbos se cruzan con un ángulo menor que este (casi paralelos),
  /// la zona sale larguísima: hay que moverse de lado.
  final double anguloMinimoCruceGrados;

  /// Pasos con que se dibuja el arco del final de cada cuña.
  final int segmentosArco;

  const ParametrosTriangulacion({
    this.alcanceMaximoMetros = 1500,
    this.separacionMinimaMetros = 15,
    this.anguloMinimoCruceGrados = 15,
    this.segmentosArco = 8,
  });
}

enum AvisoTriangulacion {
  /// Hace falta otra toma desde otro sitio.
  pocasTomas,

  /// Las tomas están demasiado cerca: muévete más.
  tomasDemasiadoJuntas,

  /// Los rumbos casi no se cruzan: muévete de lado respecto al sonido.
  rumbosCasiParalelos,

  /// Algún par de rumbos se cruza a la espalda de una de las tomas.
  rumbosNoSeCruzanDelante,

  /// Las cuñas no tienen ninguna zona en común (dentro del alcance).
  sinInterseccion,

  /// Alguna toma salió del barrido.
  hayTomasOrientativas,
}

class ZonaEstimada {
  /// Contorno de la zona, en el formato `[[lat, lng], …]` (el de los
  /// contornos de la suite). Vacío si no hay zona.
  final List<({double latitud, double longitud})> contorno;

  /// Centro de la zona (centroide), o null.
  final ({double latitud, double longitud})? centro;
  final double areaMetrosCuadrados;

  /// Distancia del centro a la toma más cercana.
  final double? distanciaMinimaMetros;
  final Set<AvisoTriangulacion> avisos;
  final int numeroTomas;

  const ZonaEstimada({
    required this.contorno,
    required this.centro,
    required this.areaMetrosCuadrados,
    required this.distanciaMinimaMetros,
    required this.avisos,
    required this.numeroTomas,
  });

  bool get hayZona => centro != null && contorno.length >= 3;

  /// Radio de un círculo de la misma área: «unos tantos metros alrededor».
  double get radioAproximadoMetros => math.sqrt(areaMetrosCuadrados / math.pi);

  /// Para `Hallazgo.atributos['zona_animal']`. Las tomas se guardan para
  /// poder rehacer el cálculo.
  Map<String, dynamic> aJson(List<TomaRumbo> tomas) => {
        if (centro != null) 'centro': [centro!.latitud, centro!.longitud],
        'contorno': [
          for (final vertice in contorno) [_redondear(vertice.latitud, 7), _redondear(vertice.longitud, 7)]
        ],
        'area_m2': areaMetrosCuadrados.round(),
        'avisos': [for (final aviso in avisos) aviso.name],
        'tomas': [for (final toma in tomas) toma.aJson()],
      };
}

/// Intersección de dos rectas (origen + t·dirección). Devuelve t y u (lo que
/// avanza cada una hasta el cruce) o null si son paralelas.
({double avanceA, double avanceB, PuntoLocal punto})? interseccionRectas(
  PuntoLocal origenA,
  double rumboA,
  PuntoLocal origenB,
  double rumboB,
) {
  final direccionA = direccionDeRumbo(rumboA);
  final direccionB = direccionDeRumbo(rumboB);
  final determinante = direccionA.este * direccionB.norte - direccionA.norte * direccionB.este;
  if (determinante.abs() < 1e-9) return null;
  final separacion = origenB - origenA;
  final avanceA = (separacion.este * direccionB.norte - separacion.norte * direccionB.este) / determinante;
  final avanceB = (separacion.este * direccionA.norte - separacion.norte * direccionA.este) / determinante;
  return (avanceA: avanceA, avanceB: avanceB, punto: origenA + direccionA * avanceA);
}

/// Ángulo con que se cruzan dos rumbos como rectas (0-90°): 0 si son
/// paralelos (en el mismo sentido o en el contrario), 90 si perpendiculares.
double anguloCruceGrados(double rumboA, double rumboB) {
  final diferencia = diferenciaAngular(rumboA, rumboB).abs();
  return math.min(diferencia, 180 - diferencia);
}

/// Cuña de una toma en el plano local: polígono convexo en sentido
/// antihorario. El vértice se retrasa [retrocesoMetros] para que la cuña
/// contenga las de cualquier punto dentro del error del GPS.
List<PuntoLocal> cunaDeToma({
  required PuntoLocal origen,
  required double rumboGrados,
  required double semiaperturaGrados,
  required double alcanceMetros,
  double retrocesoMetros = 0,
  int segmentosArco = 8,
}) {
  final semiapertura = semiaperturaGrados.clamp(incertidumbreMinimaGrados, incertidumbreMaximaGrados);
  final vertice = origen - direccionDeRumbo(rumboGrados) * retrocesoMetros;
  final radio = alcanceMetros + retrocesoMetros;
  final segmentos = math.max(1, segmentosArco);
  // El arco va de derecha a izquierda (rumbo + semiapertura → rumbo −
  // semiapertura): así el polígono queda en sentido antihorario.
  final puntos = <PuntoLocal>[vertice];
  for (var paso = 0; paso <= segmentos; paso++) {
    final rumboArco = rumboGrados + semiapertura - 2 * semiapertura * paso / segmentos;
    puntos.add(vertice + direccionDeRumbo(rumboArco) * radio);
  }
  return puntos;
}

double _productoCruzado(PuntoLocal origen, PuntoLocal a, PuntoLocal b) =>
    (a.este - origen.este) * (b.norte - origen.norte) - (a.norte - origen.norte) * (b.este - origen.este);

/// Área con signo (positiva en sentido antihorario).
double areaConSigno(List<PuntoLocal> poligono) {
  var suma = 0.0;
  for (var indice = 0; indice < poligono.length; indice++) {
    final actual = poligono[indice];
    final siguiente = poligono[(indice + 1) % poligono.length];
    suma += actual.este * siguiente.norte - siguiente.este * actual.norte;
  }
  return suma / 2;
}

PuntoLocal? centroidePoligono(List<PuntoLocal> poligono) {
  if (poligono.length < 3) return null;
  final area = areaConSigno(poligono);
  if (area.abs() < 1e-9) return null;
  var sumaEste = 0.0;
  var sumaNorte = 0.0;
  for (var indice = 0; indice < poligono.length; indice++) {
    final actual = poligono[indice];
    final siguiente = poligono[(indice + 1) % poligono.length];
    final factor = actual.este * siguiente.norte - siguiente.este * actual.norte;
    sumaEste += (actual.este + siguiente.este) * factor;
    sumaNorte += (actual.norte + siguiente.norte) * factor;
  }
  return PuntoLocal(sumaEste / (6 * area), sumaNorte / (6 * area));
}

/// Recorta [sujeto] con el polígono convexo [recorte] (Sutherland-Hodgman).
/// Admite el recorte en cualquier sentido.
List<PuntoLocal> recortarConPoligonoConvexo(List<PuntoLocal> sujeto, List<PuntoLocal> recorte) {
  if (sujeto.length < 3 || recorte.length < 3) return const [];
  final sentido = areaConSigno(recorte) >= 0 ? 1.0 : -1.0;
  var resultado = List<PuntoLocal>.of(sujeto);
  for (var indice = 0; indice < recorte.length && resultado.isNotEmpty; indice++) {
    final inicioBorde = recorte[indice];
    final finBorde = recorte[(indice + 1) % recorte.length];
    bool estaDentro(PuntoLocal punto) => sentido * _productoCruzado(inicioBorde, finBorde, punto) >= -1e-9;
    PuntoLocal corte(PuntoLocal desde, PuntoLocal hasta) {
      final ladoDesde = _productoCruzado(inicioBorde, finBorde, desde);
      final ladoHasta = _productoCruzado(inicioBorde, finBorde, hasta);
      final fraccion = ladoDesde / (ladoDesde - ladoHasta);
      return desde + (hasta - desde) * fraccion;
    }

    final entrada = resultado;
    resultado = [];
    for (var indicePunto = 0; indicePunto < entrada.length; indicePunto++) {
      final actual = entrada[indicePunto];
      final anterior = entrada[(indicePunto + entrada.length - 1) % entrada.length];
      final actualDentro = estaDentro(actual);
      final anteriorDentro = estaDentro(anterior);
      if (actualDentro) {
        if (!anteriorDentro) resultado.add(corte(anterior, actual));
        resultado.add(actual);
      } else if (anteriorDentro) {
        resultado.add(corte(anterior, actual));
      }
    }
  }
  return resultado;
}

/// Cuánto se retrasa el vértice de una cuña para cubrir el error del GPS:
/// a esa distancia detrás, la cuña contiene un círculo del radio del error
/// alrededor de la posición. Con poca apertura el retroceso se dispara; se
/// limita a la mitad del alcance.
double retrocesoPorPrecision(double? precisionMetros, double semiaperturaGrados, double alcanceMetros) {
  if (precisionMetros == null || precisionMetros <= 0) return 0;
  final semiapertura = semiaperturaGrados.clamp(incertidumbreMinimaGrados, incertidumbreMaximaGrados);
  final retroceso = precisionMetros / math.sin(semiapertura * math.pi / 180);
  return math.min(retroceso, alcanceMetros / 2);
}

/// Cruza las tomas y estima la zona del animal.
ZonaEstimada estimarZona(
  List<TomaRumbo> tomas, {
  ParametrosTriangulacion parametros = const ParametrosTriangulacion(),
}) {
  final avisos = <AvisoTriangulacion>{};
  if (tomas.any((toma) => toma.orientativa)) avisos.add(AvisoTriangulacion.hayTomasOrientativas);
  if (tomas.length < 2) {
    avisos.add(AvisoTriangulacion.pocasTomas);
    return ZonaEstimada(
      contorno: const [],
      centro: null,
      areaMetrosCuadrados: 0,
      distanciaMinimaMetros: null,
      avisos: avisos,
      numeroTomas: tomas.length,
    );
  }
  final proyeccion = ProyeccionLocal(tomas.first.latitud, tomas.first.longitud);
  final origenes = [for (final toma in tomas) proyeccion.aLocal(toma.latitud, toma.longitud)];

  // Avisos por pares.
  for (var indiceA = 0; indiceA < tomas.length; indiceA++) {
    for (var indiceB = indiceA + 1; indiceB < tomas.length; indiceB++) {
      final tomaA = tomas[indiceA];
      final tomaB = tomas[indiceB];
      final separacion = (origenes[indiceB] - origenes[indiceA]).longitud;
      final errorGpsConjunto = (tomaA.precisionMetros ?? 0) + (tomaB.precisionMetros ?? 0);
      if (separacion < parametros.separacionMinimaMetros || separacion < errorGpsConjunto) {
        avisos.add(AvisoTriangulacion.tomasDemasiadoJuntas);
      }
      if (anguloCruceGrados(tomaA.rumboGrados, tomaB.rumboGrados) < parametros.anguloMinimoCruceGrados) {
        avisos.add(AvisoTriangulacion.rumbosCasiParalelos);
        continue;
      }
      final cruce =
          interseccionRectas(origenes[indiceA], tomaA.rumboGrados, origenes[indiceB], tomaB.rumboGrados);
      if (cruce == null || cruce.avanceA <= 0 || cruce.avanceB <= 0) {
        avisos.add(AvisoTriangulacion.rumbosNoSeCruzanDelante);
      }
    }
  }

  // Intersección de las cuñas.
  List<PuntoLocal>? zona;
  for (var indice = 0; indice < tomas.length; indice++) {
    final toma = tomas[indice];
    final cuna = cunaDeToma(
      origen: origenes[indice],
      rumboGrados: toma.rumboGrados,
      semiaperturaGrados: toma.incertidumbreGrados,
      alcanceMetros: parametros.alcanceMaximoMetros,
      retrocesoMetros: retrocesoPorPrecision(
          toma.precisionMetros, toma.incertidumbreGrados, parametros.alcanceMaximoMetros),
      segmentosArco: parametros.segmentosArco,
    );
    zona = zona == null ? cuna : recortarConPoligonoConvexo(zona, cuna);
    if (zona.isEmpty) break;
  }
  final poligono = zona ?? const <PuntoLocal>[];
  final area = poligono.length >= 3 ? areaConSigno(poligono).abs() : 0.0;
  final centroLocal = area > 1e-3 ? centroidePoligono(poligono) : null;
  if (centroLocal == null) {
    avisos.add(AvisoTriangulacion.sinInterseccion);
    return ZonaEstimada(
      contorno: const [],
      centro: null,
      areaMetrosCuadrados: 0,
      distanciaMinimaMetros: null,
      avisos: avisos,
      numeroTomas: tomas.length,
    );
  }
  final distanciaMinima = origenes.map((origen) => (centroLocal - origen).longitud).reduce(math.min);
  return ZonaEstimada(
    contorno: [for (final vertice in poligono) proyeccion.aGeografica(vertice)],
    centro: proyeccion.aGeografica(centroLocal),
    areaMetrosCuadrados: area,
    distanciaMinimaMetros: distanciaMinima,
    avisos: avisos,
    numeroTomas: tomas.length,
  );
}

/// Punto a [distanciaMetros] de una posición siguiendo un rumbo (para
/// dibujar las líneas de rumbo en el mapa).
({double latitud, double longitud}) puntoEnRumbo(
    double latitud, double longitud, double rumboGrados, double distanciaMetros) {
  final proyeccion = ProyeccionLocal(latitud, longitud);
  return proyeccion.aGeografica(direccionDeRumbo(rumboGrados) * distanciaMetros);
}

/// Distancia aproximada entre dos posiciones cercanas, en metros.
double distanciaMetros(double latitudA, double longitudA, double latitudB, double longitudB) {
  final proyeccion = ProyeccionLocal(latitudA, longitudA);
  return proyeccion.aLocal(latitudB, longitudB).longitud;
}
