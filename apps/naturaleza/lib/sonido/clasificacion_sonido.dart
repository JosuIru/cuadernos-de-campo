import 'manifiesto_modelo_fauna.dart';

/// Interpretación de las puntuaciones del modelo. Portado de
/// `classification.ts`. Perch no da probabilidades: da logits, que en los
/// aciertos de las pruebas iban de ≈6 a ≈15. Los umbrales de aquí son a ojo,
/// a partir de esas pruebas; sirven para orientar, no son una probabilidad
/// de acierto.

/// Por debajo: «dudoso».
const double puntuacionMinimaPosible = 7;

/// Por encima: «probable». Entre los dos: «posible».
const double puntuacionMinimaProbable = 10;

/// Extremos de la barra de confianza.
const double _puntuacionBarraVacia = 3;
const double _puntuacionBarraLlena = 15;

/// Umbral absoluto: una especie por debajo de «posible» es «dudosa» y no se
/// muestra como resultado (queda en «ver candidatas dudosas»).
const double puntuacionMinimaMostrar = puntuacionMinimaPosible;

/// Margen relativo: una especie solo se muestra si queda a menos de estos
/// puntos de la primera. Con una primera muy clara (14) no aparecen
/// acompañantes de 8 o 9, que suelen ser confusiones con especies parecidas;
/// con dos especies cantando a la vez y bien oídas, las dos suelen quedar a
/// 1-2 puntos.
const double margenRelativoPuntuacion = 3;

/// Un sonido general (viento, coche, perro…) se menciona como «también se
/// oye» si llega a esto.
const double puntuacionMinimaTambienSeOye = puntuacionMinimaProbable;

/// Privacidad: si una clase de voz humana está entre las 3 primeras con al
/// menos esta puntuación, el trozo no se identifica ni se guarda. Más baja
/// que «dudoso» a propósito: mejor perder alguna detección que guardar una
/// conversación.
const double puntuacionMinimaVozHumana = 4;
const int puestosRevisadosVozHumana = 3;

/// Clases que se muestran por trozo.
const int clasesMostradasPorTrozo = 5;

enum NivelConfianzaSonido { dudoso, posible, probable }

/// Una clase del top con la puntuación usada para ordenar ([puntuacion], ya
/// corregida por el filtro de zona si lo hay) y la del modelo
/// ([puntuacionModelo]).
class ClaseClasificada {
  final int indiceClase;
  final double puntuacion;
  final double puntuacionModelo;

  /// Solo en las especies penalizadas por el filtro de zona.
  final PlausibilidadEspecie? plausibilidad;

  const ClaseClasificada({
    required this.indiceClase,
    required this.puntuacion,
    double? puntuacionModelo,
    this.plausibilidad,
  }) : puntuacionModelo = puntuacionModelo ?? puntuacion;

  @override
  bool operator ==(Object other) =>
      other is ClaseClasificada &&
      other.indiceClase == indiceClase &&
      other.puntuacion == puntuacion &&
      other.puntuacionModelo == puntuacionModelo &&
      other.plausibilidad == plausibilidad;

  @override
  int get hashCode => Object.hash(indiceClase, puntuacion, puntuacionModelo, plausibilidad);

  @override
  String toString() => 'ClaseClasificada($indiceClase, $puntuacion, modelo $puntuacionModelo)';
}

/// Cómo de plausible es oír una especie aquí y ahora (ver filtro_ocurrencia).
class PlausibilidadEspecie {
  /// Sin registros en la celda ni en sus vecinas.
  final bool esImprobableAqui;

  /// Actividad del mes por debajo del umbral de temporada.
  final bool esFueraDeTemporada;

  const PlausibilidadEspecie({required this.esImprobableAqui, required this.esFueraDeTemporada});

  static const plausible = PlausibilidadEspecie(esImprobableAqui: false, esFueraDeTemporada: false);

  @override
  bool operator ==(Object other) =>
      other is PlausibilidadEspecie &&
      other.esImprobableAqui == esImprobableAqui &&
      other.esFueraDeTemporada == esFueraDeTemporada;

  @override
  int get hashCode => Object.hash(esImprobableAqui, esFueraDeTemporada);
}

/// Las [numeroResultados] clases de mayor puntuación, de mayor a menor.
List<ClaseClasificada> clasesMejorPuntuadas(List<double> puntuaciones, int numeroResultados) {
  final clasificadas = <ClaseClasificada>[];
  for (var indiceClase = 0; indiceClase < puntuaciones.length; indiceClase++) {
    final puntuacion = puntuaciones[indiceClase];
    if (!puntuacion.isFinite) continue;
    if (clasificadas.length < numeroResultados) {
      clasificadas.add(ClaseClasificada(indiceClase: indiceClase, puntuacion: puntuacion));
      clasificadas.sort((a, b) => b.puntuacion.compareTo(a.puntuacion));
    } else if (numeroResultados > 0 && puntuacion > clasificadas.last.puntuacion) {
      clasificadas[clasificadas.length - 1] =
          ClaseClasificada(indiceClase: indiceClase, puntuacion: puntuacion);
      clasificadas.sort((a, b) => b.puntuacion.compareTo(a.puntuacion));
    }
  }
  return clasificadas;
}

NivelConfianzaSonido nivelConfianzaPara(double puntuacion) {
  if (puntuacion >= puntuacionMinimaProbable) return NivelConfianzaSonido.probable;
  if (puntuacion >= puntuacionMinimaPosible) return NivelConfianzaSonido.posible;
  return NivelConfianzaSonido.dudoso;
}

/// Llenado de la barra de confianza, entre 0 y 1.
double fraccionBarraConfianza(double puntuacion) {
  final fraccion =
      (puntuacion - _puntuacionBarraVacia) / (_puntuacionBarraLlena - _puntuacionBarraVacia);
  if (!fraccion.isFinite) return 0;
  return fraccion.clamp(0.0, 1.0);
}

/// Idiomas de los nombres comunes, en el orden en que se prueban para cada
/// idioma de la app. El manifiesto trae es, eu y en: en catalán y gallego se
/// muestra el castellano.
const Map<String, List<String>> _ordenIdiomasNombre = {
  'es': ['es', 'en', 'eu'],
  'eu': ['eu', 'es', 'en'],
  'ca': ['es', 'en', 'eu'],
  'gl': ['es', 'en', 'eu'],
};

/// Nombre común en el idioma de la app; si no lo hay, en los otros por orden
/// y, como último recurso, la etiqueta (nombre científico o etiqueta de
/// sonido con espacios).
String nombreVisiblePara(ClaseSonido clase, String idioma) {
  final orden = _ordenIdiomasNombre[idioma] ?? const ['en', 'es', 'eu'];
  for (final idiomaNombre in orden) {
    final nombreComun = clase.nombres[idiomaNombre];
    if (nombreComun != null && nombreComun.isNotEmpty) return nombreComun;
  }
  return clase.etiqueta.replaceAll('_', ' ');
}

/// Reparto del top de un trozo entre lo que se muestra, lo que queda oculto
/// y el contexto.
class ResultadosMostrados {
  /// Especies que pasan el umbral absoluto y el margen relativo.
  final List<ClaseClasificada> especiesMostradas;

  /// Especies del top que no pasan alguno de los dos criterios.
  final List<ClaseClasificada> especiesDudosas;

  /// Sonidos generales con puntuación alta («también se oye: …»).
  final List<ClaseClasificada> sonidosTambienOidos;

  const ResultadosMostrados({
    this.especiesMostradas = const [],
    this.especiesDudosas = const [],
    this.sonidosTambienOidos = const [],
  });
}

/// Decide qué se muestra de un top ya ordenado de mayor a menor (con las
/// puntuaciones corregidas por el filtro de zona, si lo hay).
ResultadosMostrados seleccionarResultadosMostrados(
  List<ClaseClasificada> clasesTop,
  List<ClaseSonido> clases, {
  double puntuacionMinimaEspecie = puntuacionMinimaMostrar,
}) {
  final mostradas = <ClaseClasificada>[];
  final dudosas = <ClaseClasificada>[];
  final tambienOidos = <ClaseClasificada>[];
  double? mejorPuntuacionEspecie;
  for (final clasificada in clasesTop) {
    if (clasificada.indiceClase < 0 || clasificada.indiceClase >= clases.length) continue;
    final clase = clases[clasificada.indiceClase];
    if (!clase.esEspecie) {
      if (clasificada.puntuacion >= puntuacionMinimaTambienSeOye) tambienOidos.add(clasificada);
      continue;
    }
    mejorPuntuacionEspecie ??= clasificada.puntuacion;
    final superaUmbral = clasificada.puntuacion >= puntuacionMinimaEspecie;
    final dentroDelMargen =
        mejorPuntuacionEspecie - clasificada.puntuacion < margenRelativoPuntuacion;
    if (superaUmbral && dentroDelMargen) {
      mostradas.add(clasificada);
    } else {
      dudosas.add(clasificada);
    }
  }
  return ResultadosMostrados(
    especiesMostradas: mostradas,
    especiesDudosas: dudosas,
    sonidosTambienOidos: tambienOidos,
  );
}

/// ¿Hay voz humana entre las primeras clases? Entonces el trozo no se
/// identifica ni se guarda (aunque también cante un pájaro).
bool hayVozHumana(List<ClaseClasificada> clasesTop, List<ClaseSonido> clases) {
  return clasesTop.take(puestosRevisadosVozHumana).any((clasificada) {
    if (clasificada.indiceClase < 0 || clasificada.indiceClase >= clases.length) return false;
    return clases[clasificada.indiceClase].esVozHumana &&
        clasificada.puntuacion >= puntuacionMinimaVozHumana;
  });
}

enum TipoDecisionTrozo { apuntar, vozHumana, bajoUmbral }

class DecisionTrozo {
  final TipoDecisionTrozo tipo;
  final int? indiceClaseEspecie;
  final double? puntuacionEspecie;
  const DecisionTrozo._(this.tipo, [this.indiceClaseEspecie, this.puntuacionEspecie]);

  const DecisionTrozo.apuntar(int indiceClase, double puntuacion)
      : this._(TipoDecisionTrozo.apuntar, indiceClase, puntuacion);
  static const vozHumana = DecisionTrozo._(TipoDecisionTrozo.vozHumana);
  static const bajoUmbral = DecisionTrozo._(TipoDecisionTrozo.bajoUmbral);

  @override
  bool operator ==(Object other) =>
      other is DecisionTrozo &&
      other.tipo == tipo &&
      other.indiceClaseEspecie == indiceClaseEspecie &&
      other.puntuacionEspecie == puntuacionEspecie;

  @override
  int get hashCode => Object.hash(tipo, indiceClaseEspecie, puntuacionEspecie);

  @override
  String toString() => 'DecisionTrozo($tipo, $indiceClaseEspecie, $puntuacionEspecie)';
}

/// Decide si un trozo analizado cuenta para la sesión:
/// - no, si hay voz humana entre las primeras (privacidad);
/// - sí, si alguna especie se muestra como resultado (cuenta la mejor);
/// - no, en otro caso (solo sonidos generales o especies dudosas).
DecisionTrozo decidirTrozo(
  List<ClaseClasificada> clasesTop,
  List<ClaseSonido> clases, {
  double puntuacionMinimaEspecie = puntuacionMinimaMostrar,
}) {
  if (hayVozHumana(clasesTop, clases)) return DecisionTrozo.vozHumana;
  final mostradas = seleccionarResultadosMostrados(clasesTop, clases,
          puntuacionMinimaEspecie: puntuacionMinimaEspecie)
      .especiesMostradas;
  if (mostradas.isNotEmpty) {
    return DecisionTrozo.apuntar(mostradas.first.indiceClase, mostradas.first.puntuacion);
  }
  return DecisionTrozo.bajoUmbral;
}
