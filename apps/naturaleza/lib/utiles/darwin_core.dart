import 'dart:math';

import '../modelos/hallazgo.dart';
import '../sonido/registro_sesion_sonora.dart' show campoCsv;
import 'primeras_veces.dart';

/// Exportación de los hallazgos en Darwin Core (DwC): un CSV de ocurrencias
/// con los términos estándar (https://dwc.tdwg.org/terms/), y la plantilla de
/// importación CSV de iNaturalist.
///
/// Decisiones (documentadas también en el CLAUDE.md de la app):
/// - **basisOfRecord**: `HumanObservation` cuando una persona estaba allí y
///   decidió la identificación, aunque la sugiriera un modelo: un hallazgo
///   anotado en el alta (también desde «¿Quién canta?», donde la persona
///   escucha, elige la especie y guarda) o una identificación revisada
///   después (confirmada o corregida). `MachineObservation` solo para los
///   hallazgos creados en bloque desde una sesión larga de escucha
///   (recorrido o coro) cuya identificación no se ha revisado: ahí la
///   detección es del modelo y la persona solo eligió qué guardar. En los
///   dos casos `identificationRemarks` dice el modelo y la puntuación.
/// - **Especies sensibles** (protegidas de la guía y las que marque la
///   persona): coordenadas al centro de su celda de 0,1° (≈ 11 km),
///   `coordinateUncertaintyInMeters` = media diagonal de la celda (más la
///   precisión del GPS), `dataGeneralizations` e `informationWithheld`
///   rellenos, y sin fotos (pueden llevar la posición en el EXIF).

/// Paso de la cuadrícula para generalizar (grados).
const double pasoGeneralizacionGrados = 0.1;

/// Metros por grado de latitud (aprox. WGS84 medio).
const double metrosPorGradoLatitud = 111320;

enum LicenciaExportacion {
  cc0('CC0 1.0', 'http://creativecommons.org/publicdomain/zero/1.0/legalcode'),
  ccBy('CC BY 4.0', 'http://creativecommons.org/licenses/by/4.0/legalcode');

  final String nombre;

  /// URL que GBIF recomienda para `license`.
  final String url;
  const LicenciaExportacion(this.nombre, this.url);
}

/// Términos DwC del CSV, en este orden.
const List<String> terminosDarwinCore = [
  'occurrenceID',
  'basisOfRecord',
  'occurrenceStatus',
  'eventDate',
  'scientificName',
  'vernacularName',
  'kingdom',
  'decimalLatitude',
  'decimalLongitude',
  'geodeticDatum',
  'coordinateUncertaintyInMeters',
  'recordedBy',
  'identifiedBy',
  'occurrenceRemarks',
  'identificationRemarks',
  'associatedMedia',
  'dataGeneralizations',
  'informationWithheld',
  'license',
];

/// Cabecera de la plantilla CSV de importación de iNaturalist (las 8
/// columnas de su página de importación).
const List<String> columnasInaturalist = [
  'Taxon name',
  'Date observed',
  'Description',
  'Place name',
  'Latitude / y coord / northing',
  'Longitude / x coord / easting',
  'Tags',
  'Geoprivacy',
];

/// Opciones de la exportación.
class OpcionesExportacionDwc {
  /// Prefijo único de esta instalación para `occurrenceID`.
  final String identificadorInstalacion;
  final LicenciaExportacion licencia;

  /// Nombre de quien registró (opcional, `recordedBy`/`identifiedBy`).
  final String registradoPor;

  /// Claves de especie (`especieDeHallazgo(...).clave`) que se generalizan.
  final Set<String> clavesSensibles;

  /// Si se acompañan los ficheros: `associatedMedia` lleva sus rutas
  /// relativas dentro del ZIP.
  final bool conMedios;

  /// Con [conMedios]: deja fuera los ficheros que ya no existen.
  final bool Function(String ruta)? existeMedio;

  const OpcionesExportacionDwc({
    required this.identificadorInstalacion,
    required this.licencia,
    this.registradoPor = '',
    this.clavesSensibles = const {},
    this.conMedios = false,
    this.existeMedio,
  });
}

/// Fecha y hora ISO 8601 con la zona: `2026-03-23T07:15:00+01:00` (o `Z` en
/// UTC).
String fechaIso8601ConZona(DateTime fecha) {
  String dos(int numero) => numero.toString().padLeft(2, '0');
  final base = '${fecha.year.toString().padLeft(4, '0')}-${dos(fecha.month)}-${dos(fecha.day)}'
      'T${dos(fecha.hour)}:${dos(fecha.minute)}:${dos(fecha.second)}';
  if (fecha.isUtc) return '${base}Z';
  final desfase = fecha.timeZoneOffset;
  final signo = desfase.isNegative ? '-' : '+';
  final minutos = desfase.inMinutes.abs();
  return '$base$signo${dos(minutos ~/ 60)}:${dos(minutos % 60)}';
}

/// Coordenadas generalizadas: centro de la celda y su incertidumbre.
class CoordenadasGeneralizadas {
  final double latitud;
  final double longitud;
  final int incertidumbreMetros;

  const CoordenadasGeneralizadas(this.latitud, this.longitud, this.incertidumbreMetros);
}

double _redondear(double valor, int decimales) {
  final factor = pow(10, decimales);
  return (valor * factor).roundToDouble() / factor;
}

/// Lleva el punto al centro de su celda de [paso] grados. La incertidumbre
/// es la distancia del centro a la esquina más lejana (en el borde de la
/// celda más cercano al ecuador, donde el grado de longitud es más largo)
/// más la precisión original, redondeada hacia arriba a 100 m.
CoordenadasGeneralizadas generalizarCoordenadas(
  double latitud,
  double longitud, {
  double paso = pasoGeneralizacionGrados,
  double? precisionOriginalMetros,
}) {
  final filaCelda = (latitud / paso).floor();
  final columnaCelda = (longitud / paso).floor();
  final latitudCentro = _redondear((filaCelda + 0.5) * paso, 4);
  final longitudCentro = _redondear((columnaCelda + 0.5) * paso, 4);
  final latitudBordeEcuador = min((filaCelda * paso).abs(), ((filaCelda + 1) * paso).abs());
  final mitadLatitudMetros = paso / 2 * metrosPorGradoLatitud;
  final mitadLongitudMetros = paso / 2 * metrosPorGradoLatitud * cos(latitudBordeEcuador * pi / 180);
  final diagonal = sqrt(mitadLatitudMetros * mitadLatitudMetros + mitadLongitudMetros * mitadLongitudMetros);
  final total = diagonal + (precisionOriginalMetros ?? 0);
  return CoordenadasGeneralizadas(latitudCentro, longitudCentro, ((total / 100).ceil() * 100));
}

String _reinoDeCategoria(String categoria) => switch (categoria) {
      'planta' => 'Plantae',
      'seta' => 'Fungi',
      _ => 'Animalia',
    };

/// basisOfRecord según cómo se identificó (ver la cabecera del fichero).
String basisOfRecordDe(Hallazgo hallazgo) {
  final vieneDeSesion = hallazgo.atributos['sesion_sonora'] is Map;
  final revisada = hallazgo.identificacionValidada != EstadoIdentificacion.sinRevisar;
  return vieneDeSesion && !revisada ? 'MachineObservation' : 'HumanObservation';
}

String _numeroLegible(Object? valor) {
  if (valor is num) return valor.toStringAsFixed(1);
  return '$valor';
}

/// Comentario de identificación: la hipótesis de la persona, el modelo de
/// sonido con su puntuación y si se revisó después.
String comentarioIdentificacion(Hallazgo hallazgo) {
  final partes = <String>[];
  final sonido = hallazgo.atributos['identificacion_sonido'];
  if (sonido is Map) {
    final modelo = sonido['modelo'] ?? 'Perch 2.0';
    final nivel = sonido['nivel'];
    final puntuacion = sonido['puntuacion'];
    final filtro = sonido['filtro_zona'] == true ? ', con filtro por lugar y época' : '';
    final sesion = hallazgo.atributos['sesion_sonora'];
    final origen = sesion is Map
        ? 'sesión automática de escucha (${sesion['tipo'] ?? ''}, ${sesion['detecciones'] ?? '?'} detecciones)'
        : 'elegida por la persona mientras escuchaba';
    partes.add('Identificado por el sonido con el modelo $modelo (puntuación ${_numeroLegible(puntuacion)}'
        '${nivel == null ? '' : ', nivel $nivel'}$filtro); $origen');
  }
  if (hallazgo.identificacionValidada == EstadoIdentificacion.confirmada) {
    partes.add('Identificación revisada y confirmada por la persona');
  } else if (hallazgo.identificacionValidada == EstadoIdentificacion.corregida) {
    partes.add('Identificación corregida por la persona (al principio: ${hallazgo.especie})');
  }
  if (hallazgo.confianzaIdentificacion != null) {
    partes.add('Confianza de la persona: ${hallazgo.confianzaIdentificacion}');
  }
  if (hallazgo.hipotesis.trim().isNotEmpty) partes.add('Hipótesis de la persona: ${hallazgo.hipotesis.trim()}');
  return partes.join('. ');
}

String _textoUnaLinea(String texto) => texto.replaceAll(RegExp(r'\s*[\r\n]+\s*'), ' ').trim();

/// Ficheros propios de un hallazgo dentro del ZIP: clip y nota de voz
/// siempre; fotos propias (no las de archivo con atribución) solo si no es
/// sensible.
List<({String rutaOrigen, String rutaEnZip})> mediosDeHallazgo(Hallazgo hallazgo, {required bool sensible}) {
  final medios = <({String rutaOrigen, String rutaEnZip})>[];
  String nombre(String ruta) => ruta.split(RegExp(r'[/\\]')).last;
  final id = hallazgo.id ?? 0;
  if (!sensible) {
    for (final (indice, ruta) in hallazgo.rutasFotos.indexed) {
      if (hallazgo.atribucionEnPosicion(indice) != null) continue;
      medios.add((rutaOrigen: ruta, rutaEnZip: 'media/${id}_${nombre(ruta)}'));
    }
  }
  final audio = hallazgo.rutaAudio;
  if (audio != null) medios.add((rutaOrigen: audio, rutaEnZip: 'media/${id}_${nombre(audio)}'));
  final nota = hallazgo.rutaNotaVoz;
  if (nota != null) medios.add((rutaOrigen: nota, rutaEnZip: 'media/${id}_${nombre(nota)}'));
  return medios;
}

/// Una ocurrencia DwC (término → valor) o null si el hallazgo no se exporta
/// (sin nombre científico: GBIF e iNaturalist lo necesitan).
Map<String, String>? ocurrenciaDarwinCore(Hallazgo hallazgo, OpcionesExportacionDwc opciones) {
  final especie = especieDeHallazgo(hallazgo);
  if (especie == null || especie.nombreCientifico.isEmpty) return null;
  final sensible = opciones.clavesSensibles.contains(especie.clave);
  final String latitud;
  final String longitud;
  String incertidumbre = hallazgo.precision == null ? '' : '${hallazgo.precision!.ceil()}';
  var generalizaciones = '';
  var retenido = '';
  if (sensible) {
    final generalizadas =
        generalizarCoordenadas(hallazgo.latitud, hallazgo.longitud, precisionOriginalMetros: hallazgo.precision);
    latitud = generalizadas.latitud.toStringAsFixed(2);
    longitud = generalizadas.longitud.toStringAsFixed(2);
    incertidumbre = '${generalizadas.incertidumbreMetros}';
    generalizaciones = 'Coordenadas generalizadas al centro de una celda de 0,1° (especie sensible)';
    retenido = 'Coordenadas exactas no publicadas y fotos no incluidas (especie sensible)';
  } else {
    latitud = _redondear(hallazgo.latitud, 6).toString();
    longitud = _redondear(hallazgo.longitud, 6).toString();
  }
  final medios = opciones.conMedios
      ? [
          for (final medio in mediosDeHallazgo(hallazgo, sensible: sensible))
            if (opciones.existeMedio?.call(medio.rutaOrigen) ?? true) medio,
        ]
      : const <({String rutaOrigen, String rutaEnZip})>[];
  return {
    'occurrenceID': 'urn:naturaleza:${opciones.identificadorInstalacion}:hallazgo:${hallazgo.id ?? 0}',
    'basisOfRecord': basisOfRecordDe(hallazgo),
    'occurrenceStatus': 'present',
    'eventDate': fechaIso8601ConZona(DateTime.fromMillisecondsSinceEpoch(hallazgo.fechaMs)),
    'scientificName': especie.nombreCientifico,
    'vernacularName': especie.nombreComun,
    'kingdom': _reinoDeCategoria(hallazgo.categoria),
    'decimalLatitude': latitud,
    'decimalLongitude': longitud,
    'geodeticDatum': 'WGS84',
    'coordinateUncertaintyInMeters': incertidumbre,
    'recordedBy': opciones.registradoPor.trim(),
    'identifiedBy': opciones.registradoPor.trim(),
    'occurrenceRemarks': _textoUnaLinea(hallazgo.notas),
    'identificationRemarks': _textoUnaLinea(comentarioIdentificacion(hallazgo)),
    'associatedMedia': medios.map((medio) => medio.rutaEnZip).join(' | '),
    'dataGeneralizations': generalizaciones,
    'informationWithheld': retenido,
    'license': opciones.licencia.url,
  };
}

/// Resultado de generar el CSV.
class ExportacionDwc {
  final String csv;
  final int exportados;
  final int sinNombreCientifico;
  final int generalizados;

  const ExportacionDwc({
    required this.csv,
    required this.exportados,
    required this.sinNombreCientifico,
    required this.generalizados,
  });
}

/// CSV DwC (UTF-8, RFC 4180, fin de línea CRLF) de los hallazgos.
ExportacionDwc generarCsvDarwinCore(Iterable<Hallazgo> hallazgos, OpcionesExportacionDwc opciones) {
  final lineas = <String>[terminosDarwinCore.join(',')];
  var exportados = 0;
  var sinNombre = 0;
  var generalizados = 0;
  for (final hallazgo in hallazgos) {
    final ocurrencia = ocurrenciaDarwinCore(hallazgo, opciones);
    if (ocurrencia == null) {
      sinNombre++;
      continue;
    }
    exportados++;
    if (ocurrencia['dataGeneralizations']!.isNotEmpty) generalizados++;
    lineas.add(terminosDarwinCore.map((termino) => campoCsv(ocurrencia[termino])).join(','));
  }
  return ExportacionDwc(
    csv: '${lineas.join('\r\n')}\r\n',
    exportados: exportados,
    sinNombreCientifico: sinNombre,
    generalizados: generalizados,
  );
}

/// CSV con la plantilla de importación de iNaturalist. Las sensibles van
/// con las coordenadas ya generalizadas y `Geoprivacy` = `obscured`.
ExportacionDwc generarCsvInaturalist(Iterable<Hallazgo> hallazgos, OpcionesExportacionDwc opciones) {
  final lineas = <String>[columnasInaturalist.map(campoCsv).join(',')];
  var exportados = 0;
  var sinNombre = 0;
  var generalizados = 0;
  String dos(int numero) => numero.toString().padLeft(2, '0');
  for (final hallazgo in hallazgos) {
    final ocurrencia = ocurrenciaDarwinCore(hallazgo, opciones);
    if (ocurrencia == null) {
      sinNombre++;
      continue;
    }
    exportados++;
    final sensible = ocurrencia['dataGeneralizations']!.isNotEmpty;
    if (sensible) generalizados++;
    final fecha = DateTime.fromMillisecondsSinceEpoch(hallazgo.fechaMs);
    final descripcion = [
      if (ocurrencia['occurrenceRemarks']!.isNotEmpty) ocurrencia['occurrenceRemarks'],
      if (ocurrencia['identificationRemarks']!.isNotEmpty) ocurrencia['identificationRemarks'],
    ].join(' — ');
    lineas.add([
      ocurrencia['scientificName'],
      '${fecha.year}-${dos(fecha.month)}-${dos(fecha.day)} ${dos(fecha.hour)}:${dos(fecha.minute)}',
      descripcion,
      '',
      ocurrencia['decimalLatitude'],
      ocurrencia['decimalLongitude'],
      hallazgo.tipoEvidencia == TipoEvidencia.sonido ? 'naturaleza-app, sonido' : 'naturaleza-app',
      sensible ? 'obscured' : '',
    ].map(campoCsv).join(','));
  }
  return ExportacionDwc(
    csv: '${lineas.join('\r\n')}\r\n',
    exportados: exportados,
    sinNombreCientifico: sinNombre,
    generalizados: generalizados,
  );
}

/// Identificador aleatorio de la instalación (32 caracteres hexadecimales).
String nuevoIdentificadorInstalacion([Random? azar]) {
  final generador = azar ?? Random.secure();
  return [for (var indice = 0; indice < 16; indice++) generador.nextInt(256).toRadixString(16).padLeft(2, '0')].join();
}
