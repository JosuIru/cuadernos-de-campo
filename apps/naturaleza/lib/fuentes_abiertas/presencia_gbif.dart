import 'licencias_abiertas.dart';
import 'ubicacion_aproximada.dart';

const String baseApiGbif = 'https://api.gbif.org/v1';

/// Países de la vista «sin ubicación» de «Cuándo se ve».
const List<String> paisesPeninsulaIberica = ['ES', 'PT'];

/// Recuento de registros de GBIF de una especie en una zona y su reparto
/// por meses.
class PresenciaGbif {
  const PresenciaGbif({
    required this.claveEspecie,
    required this.total,
    required this.porMes,
    required this.consultadoEn,
    this.ubicacion,
    this.coordenadasGeneralizadas = false,
  });

  final int claveEspecie;
  final int total;

  /// 12 valores, enero primero.
  final List<int> porMes;
  final DateTime consultadoEn;

  /// Zona consultada; null = España y Portugal.
  final UbicacionAproximada? ubicacion;

  /// GBIF ha devuelto algún registro con las coordenadas generalizadas o
  /// retenidas por el publicador (especie sensible).
  final bool coordenadasGeneralizadas;

  int get totalPorMes => porMes.fold(0, (suma, valor) => suma + valor);

  Map<String, Object?> toJson() => {
        'clave': claveEspecie,
        'total': total,
        'meses': porMes,
        'fecha': consultadoEn.toIso8601String(),
        'generalizadas': coordenadasGeneralizadas,
        if (ubicacion != null) 'zona': ubicacion!.textoCoordenadas,
        if (ubicacion != null) 'amplia': ubicacion!.escalaAmplia,
      };

  static PresenciaGbif? fromJson(Object? crudo) {
    if (crudo is! Map) return null;
    final meses = (crudo['meses'] as List?)?.whereType<num>().map((valor) => valor.toInt()).toList();
    final fecha = DateTime.tryParse((crudo['fecha'] as String?) ?? '');
    final clave = crudo['clave'];
    if (meses == null || meses.length != 12 || fecha == null || clave is! int) return null;
    UbicacionAproximada? ubicacion;
    final zona = (crudo['zona'] as String?)?.split(',');
    if (zona != null && zona.length == 2) {
      final latitud = double.tryParse(zona[0]);
      final longitud = double.tryParse(zona[1]);
      if (latitud != null && longitud != null) {
        ubicacion = UbicacionAproximada.desde(latitud, longitud, escalaAmplia: crudo['amplia'] == true);
      }
    }
    return PresenciaGbif(
      claveEspecie: clave,
      total: (crudo['total'] as num?)?.toInt() ?? 0,
      porMes: meses,
      consultadoEn: fecha,
      ubicacion: ubicacion,
      coordenadasGeneralizadas: crudo['generalizadas'] == true,
    );
  }
}

/// `species/match` estricto para un nombre científico.
Uri uriEmparejarEspecieGbif(String nombreCientifico) =>
    Uri.parse('$baseApiGbif/species/match').replace(queryParameters: {
      'name': nombreCientifico.trim(),
      'strict': 'true',
    });

/// Clave de especie (`speciesKey`) de una respuesta de `species/match`, o
/// null si no hay coincidencia o no llega a especie.
int? claveEspecieDeEmparejamiento(Map<String, dynamic> respuesta) {
  if (respuesta['matchType'] == 'NONE') return null;
  final claveEspecie = (respuesta['speciesKey'] as num?)?.toInt();
  if (claveEspecie != null) return claveEspecie;
  if (respuesta['rank'] == 'SPECIES') return (respuesta['usageKey'] as num?)?.toInt();
  return null;
}

/// Parámetros comunes: solo registros con coordenadas sin problemas, de
/// licencia CC0 o CC BY (sin NC).
Map<String, Object> _parametrosBase() => {
      'hasCoordinate': 'true',
      'hasGeospatialIssue': 'false',
      'occurrenceStatus': 'PRESENT',
      'license': licenciasRegistrosGbif,
    };

/// Recuento + faceta por mes de una especie. Pide además
/// [registrosDeMuestra] registros (sin enseñarlos nunca) solo para ver si
/// GBIF ha generalizado sus coordenadas. Con [ubicacion] null, España y
/// Portugal.
Uri uriPresenciaGbif(int claveEspecie, UbicacionAproximada? ubicacion, {int registrosDeMuestra = 20}) =>
    Uri.parse('$baseApiGbif/occurrence/search').replace(queryParameters: {
      ..._parametrosBase(),
      'taxonKey': '$claveEspecie',
      if (ubicacion != null) 'geoDistance': ubicacion.parametroDistanciaGbif,
      if (ubicacion == null) 'country': paisesPeninsulaIberica,
      'limit': '$registrosDeMuestra',
      'facet': 'month',
      'facetLimit': '12',
    });

/// Recuento por especie (faceta `speciesKey`) de las [claves] dadas en la
/// zona. Sin registros sueltos (`limit=0`).
Uri uriEspeciesCercaGbif(UbicacionAproximada ubicacion, Iterable<int> claves) {
  final listaClaves = claves.toSet().toList()..sort();
  return Uri.parse('$baseApiGbif/occurrence/search').replace(queryParameters: {
    ..._parametrosBase(),
    'geoDistance': ubicacion.parametroDistanciaGbif,
    'taxonKey': [for (final clave in listaClaves) '$clave'],
    'limit': '0',
    'facet': 'speciesKey',
    'facetLimit': '${listaClaves.length}',
  });
}

/// Lee la respuesta de [uriPresenciaGbif].
PresenciaGbif parsearPresenciaGbif(
  Map<String, dynamic> respuesta, {
  required int claveEspecie,
  required UbicacionAproximada? ubicacion,
  required DateTime consultadoEn,
}) {
  final porMes = List<int>.filled(12, 0);
  for (final faceta in (respuesta['facets'] as List?) ?? const []) {
    if (faceta is! Map || faceta['field'] != 'MONTH') continue;
    for (final cuenta in (faceta['counts'] as List?) ?? const []) {
      if (cuenta is! Map) continue;
      final mes = int.tryParse('${cuenta['name']}');
      final numero = (cuenta['count'] as num?)?.toInt() ?? 0;
      if (mes != null && mes >= 1 && mes <= 12) porMes[mes - 1] += numero;
    }
  }
  return PresenciaGbif(
    claveEspecie: claveEspecie,
    total: (respuesta['count'] as num?)?.toInt() ?? 0,
    porMes: porMes,
    consultadoEn: consultadoEn,
    ubicacion: ubicacion,
    coordenadasGeneralizadas: hayCoordenadasGeneralizadas(respuesta),
  );
}

/// ¿Algún registro de la muestra trae las coordenadas generalizadas o
/// retenidas? (`dataGeneralizations` o `informationWithheld` con texto).
bool hayCoordenadasGeneralizadas(Map<String, dynamic> respuesta) {
  for (final registro in (respuesta['results'] as List?) ?? const []) {
    if (registro is! Map) continue;
    for (final campo in const ['dataGeneralizations', 'informationWithheld']) {
      final valor = registro[campo];
      if (valor is String && valor.trim().isNotEmpty) return true;
    }
  }
  return false;
}

/// Lee la faceta `speciesKey`: clave de especie → número de registros.
Map<int, int> parsearEspeciesCercaGbif(Map<String, dynamic> respuesta) {
  final recuentos = <int, int>{};
  for (final faceta in (respuesta['facets'] as List?) ?? const []) {
    if (faceta is! Map || faceta['field'] != 'SPECIES_KEY') continue;
    for (final cuenta in (faceta['counts'] as List?) ?? const []) {
      if (cuenta is! Map) continue;
      final clave = int.tryParse('${cuenta['name']}');
      final numero = (cuenta['count'] as num?)?.toInt() ?? 0;
      if (clave != null && numero > 0) recuentos[clave] = numero;
    }
  }
  return recuentos;
}

/// Meses (1-12) con al menos la mitad de registros que el mes con más.
/// Vacío si no hay ninguno.
List<int> mesesConMasRegistros(List<int> porMes, {double fraccionDelMaximo = 0.5}) {
  if (porMes.isEmpty) return const [];
  final maximo = porMes.reduce((a, b) => a > b ? a : b);
  if (maximo <= 0) return const [];
  return [
    for (var indice = 0; indice < porMes.length; indice++)
      if (porMes[indice] >= maximo * fraccionDelMaximo) indice + 1,
  ];
}

/// Agrupa meses consecutivos (diciembre y enero también lo son) en tramos
/// `[inicio, fin]`: [12, 1, 2, 5] → [[12, 2], [5, 5]].
List<List<int>> tramosDeMeses(List<int> meses) {
  if (meses.isEmpty) return const [];
  final presentes = List<bool>.filled(13, false);
  for (final mes in meses) {
    if (mes >= 1 && mes <= 12) presentes[mes] = true;
  }
  if (presentes.skip(1).every((presente) => presente)) {
    return const [
      [1, 12]
    ];
  }
  // Empieza a recorrer justo después de un mes ausente para no partir un
  // tramo que cruza el año.
  var inicioRecorrido = 1;
  while (presentes[inicioRecorrido]) {
    inicioRecorrido++;
  }
  final tramos = <List<int>>[];
  List<int>? actual;
  for (var paso = 1; paso <= 12; paso++) {
    final mes = (inicioRecorrido + paso - 1) % 12 + 1;
    if (presentes[mes]) {
      if (actual == null) {
        actual = [mes, mes];
        tramos.add(actual);
      } else {
        actual[1] = mes;
      }
    } else {
      actual = null;
    }
  }
  tramos.sort((a, b) => a[0].compareTo(b[0]));
  return tramos;
}

/// Cita simple que pide GBIF para datos consultados en su web o su API:
/// «GBIF.org (10 November 2026) GBIF Occurrence Data».
String textoCitaGbif(DateTime fecha) {
  const meses = [
    'January', 'February', 'March', 'April', 'May', 'June', //
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return 'GBIF.org (${fecha.day} ${meses[fecha.month - 1]} ${fecha.year}) GBIF Occurrence Data';
}

/// Búsqueda de registros de la especie en gbif.org (enlace de la cita).
Uri uriBusquedaRegistrosGbif(int claveEspecie) =>
    Uri.parse('https://www.gbif.org/occurrence/search').replace(queryParameters: {'taxon_key': '$claveEspecie'});

/// Ficha de la especie en gbif.org («Ver en GBIF»).
Uri uriPaginaEspecieGbif(int claveEspecie) => Uri.parse('https://www.gbif.org/species/$claveEspecie');
