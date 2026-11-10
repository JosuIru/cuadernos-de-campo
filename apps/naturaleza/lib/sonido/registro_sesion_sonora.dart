import 'dart:convert';
import 'dart:math' as math;

import 'clasificacion_sonido.dart';

/// Sesiones largas de «¿Quién canta?»: «Escuchar mientras camino»
/// (recorrido con traza GPS) y «Coro del amanecer» (sesión estática con
/// hora de fin). Aquí solo hay lógica pura: modelos, a qué punto de la
/// traza corresponde cada detección, agrupación por especie y por franjas
/// de 15 minutos, hora de fin del coro y CSV.

enum TipoSesionSonora {
  recorrido('recorrido'),
  coro('coro');

  /// Valor guardado en la BD (no cambia con el idioma).
  final String clave;
  const TipoSesionSonora(this.clave);

  static TipoSesionSonora desdeClave(Object? clave) =>
      values.firstWhere((tipo) => tipo.clave == clave, orElse: () => TipoSesionSonora.recorrido);
}

/// Un punto de la traza GPS de un recorrido.
class PuntoTrazaSonora {
  final int momentoMs;
  final double latitud;
  final double longitud;
  final double? precisionMetros;

  const PuntoTrazaSonora({
    required this.momentoMs,
    required this.latitud,
    required this.longitud,
    this.precisionMetros,
  });

  /// `[ms, lat, lng, precisión]`: compacto, la traza de una hora son cientos.
  List<Object?> aJson() => [
        momentoMs,
        double.parse(latitud.toStringAsFixed(6)),
        double.parse(longitud.toStringAsFixed(6)),
        precisionMetros?.roundToDouble(),
      ];

  static PuntoTrazaSonora? desdeJson(Object? crudo) {
    if (crudo is! List || crudo.length < 3) return null;
    final momento = crudo[0], latitud = crudo[1], longitud = crudo[2];
    if (momento is! num || latitud is! num || longitud is! num) return null;
    final precision = crudo.length > 3 ? crudo[3] : null;
    return PuntoTrazaSonora(
      momentoMs: momento.toInt(),
      latitud: latitud.toDouble(),
      longitud: longitud.toDouble(),
      precisionMetros: precision is num ? precision.toDouble() : null,
    );
  }
}

String trazaAJson(List<PuntoTrazaSonora> traza) => jsonEncode([for (final punto in traza) punto.aJson()]);

List<PuntoTrazaSonora> trazaDesdeJson(String? texto) {
  if (texto == null || texto.isEmpty) return const [];
  try {
    final crudo = jsonDecode(texto);
    if (crudo is! List) return const [];
    return [
      for (final elemento in crudo)
        if (PuntoTrazaSonora.desdeJson(elemento) case final punto?) punto,
    ];
  } catch (_) {
    return const [];
  }
}

/// Distancia recorrida por la traza, en metros (aproximación
/// equirrectangular: de sobra para tramos de pocos metros).
double distanciaTrazaMetros(List<PuntoTrazaSonora> traza) {
  var total = 0.0;
  for (var indice = 1; indice < traza.length; indice++) {
    total += _distanciaAproximadaMetros(traza[indice - 1], traza[indice]);
  }
  return total;
}

double _distanciaAproximadaMetros(PuntoTrazaSonora a, PuntoTrazaSonora b) {
  const radioTierraMetros = 6371000.0;
  const gradosARadianes = math.pi / 180;
  final latitudMedia = (a.latitud + b.latitud) / 2 * gradosARadianes;
  final dx = (b.longitud - a.longitud) * gradosARadianes * math.cos(latitudMedia) * radioTierraMetros;
  final dy = (b.latitud - a.latitud) * gradosARadianes * radioTierraMetros;
  return math.sqrt(dx * dx + dy * dy);
}

/// Margen tras el primer punto de la traza en el que una detección anterior
/// (aún sin GPS) se coloca en ese primer punto.
const Duration toleranciaAntesDelPrimerPunto = Duration(minutes: 2);

/// Índice del punto de la traza que corresponde a [momentoMs]: el último
/// punto tomado antes (o a la vez). Con el filtro de distancia del GPS, si
/// la persona está quieta no llegan puntos nuevos y el último sigue siendo
/// válido. Si la detección es anterior al primer punto, el primero si llega
/// dentro de [toleranciaAntesDelPrimerPunto]; si no, null (sin posición).
int? indicePuntoTrazaPara(List<PuntoTrazaSonora> traza, int momentoMs) {
  if (traza.isEmpty) return null;
  if (momentoMs < traza.first.momentoMs) {
    final diferencia = traza.first.momentoMs - momentoMs;
    return diferencia <= toleranciaAntesDelPrimerPunto.inMilliseconds ? 0 : null;
  }
  // Búsqueda binaria del último punto con momento <= momentoMs.
  var bajo = 0, alto = traza.length - 1;
  while (bajo < alto) {
    final medio = (bajo + alto + 1) ~/ 2;
    if (traza[medio].momentoMs <= momentoMs) {
      bajo = medio;
    } else {
      alto = medio - 1;
    }
  }
  return bajo;
}

/// Una especie oída durante una sesión larga (un trozo de 5 s analizado).
class DeteccionSonora {
  final int? id;
  final int? sesionId;
  final int momentoMs;

  /// Nombre científico (etiqueta del manifiesto).
  final String etiqueta;
  final String nombreComun;

  /// Categoría de Naturaleza (`ave`, `anfibio`…).
  final String categoria;
  final double puntuacion;
  final double puntuacionModelo;
  final double? latitud;
  final double? longitud;
  final int? indicePuntoTraza;

  /// Mejor clip de la especie en la sesión (solo en una detección por
  /// especie), WAV en `audios/`.
  final String? rutaClip;

  /// Hallazgo creado con «Guardar como hallazgos», si lo hay.
  final int? hallazgoId;

  const DeteccionSonora({
    this.id,
    this.sesionId,
    required this.momentoMs,
    required this.etiqueta,
    required this.nombreComun,
    required this.categoria,
    required this.puntuacion,
    required this.puntuacionModelo,
    this.latitud,
    this.longitud,
    this.indicePuntoTraza,
    this.rutaClip,
    this.hallazgoId,
  });

  NivelConfianzaSonido get nivel => nivelConfianzaPara(puntuacion);
  bool get tienePosicion => latitud != null && longitud != null;
  DateTime get momento => DateTime.fromMillisecondsSinceEpoch(momentoMs);

  Map<String, Object?> aMapa() => {
        if (id != null) 'id': id,
        'sesion_id': sesionId,
        'momento_ms': momentoMs,
        'etiqueta': etiqueta,
        'nombre_comun': nombreComun,
        'categoria': categoria,
        'puntuacion': puntuacion,
        'puntuacion_modelo': puntuacionModelo,
        'nivel': nivel.name,
        'latitud': latitud,
        'longitud': longitud,
        'indice_punto': indicePuntoTraza,
        'ruta_clip': rutaClip,
        'hallazgo_id': hallazgoId,
      };

  factory DeteccionSonora.desdeMapa(Map<String, Object?> mapa) => DeteccionSonora(
        id: mapa['id'] as int?,
        sesionId: mapa['sesion_id'] as int?,
        momentoMs: (mapa['momento_ms'] as num).toInt(),
        etiqueta: (mapa['etiqueta'] as String?) ?? '',
        nombreComun: (mapa['nombre_comun'] as String?) ?? '',
        categoria: (mapa['categoria'] as String?) ?? 'animal',
        puntuacion: (mapa['puntuacion'] as num?)?.toDouble() ?? 0,
        puntuacionModelo: (mapa['puntuacion_modelo'] as num?)?.toDouble() ?? 0,
        latitud: (mapa['latitud'] as num?)?.toDouble(),
        longitud: (mapa['longitud'] as num?)?.toDouble(),
        indicePuntoTraza: mapa['indice_punto'] as int?,
        rutaClip: mapa['ruta_clip'] as String?,
        hallazgoId: mapa['hallazgo_id'] as int?,
      );
}

/// Una sesión larga guardada.
class SesionSonora {
  final int? id;
  final TipoSesionSonora tipo;
  final int inicioMs;
  final int? finMs;

  /// Coro: hora a la que estaba previsto terminar.
  final int? finPrevistoMs;
  final String versionModelo;
  final List<PuntoTrazaSonora> traza;
  final bool conFiltroDeZona;

  const SesionSonora({
    this.id,
    required this.tipo,
    required this.inicioMs,
    this.finMs,
    this.finPrevistoMs,
    required this.versionModelo,
    this.traza = const [],
    this.conFiltroDeZona = false,
  });

  bool get terminada => finMs != null;
  DateTime get inicio => DateTime.fromMillisecondsSinceEpoch(inicioMs);
  DateTime? get fin => finMs == null ? null : DateTime.fromMillisecondsSinceEpoch(finMs!);

  Map<String, Object?> aMapa() => {
        if (id != null) 'id': id,
        'tipo': tipo.clave,
        'inicio_ms': inicioMs,
        'fin_ms': finMs,
        'fin_previsto_ms': finPrevistoMs,
        'version_modelo': versionModelo,
        'traza_json': trazaAJson(traza),
        'con_filtro_zona': conFiltroDeZona ? 1 : 0,
      };

  factory SesionSonora.desdeMapa(Map<String, Object?> mapa) => SesionSonora(
        id: mapa['id'] as int?,
        tipo: TipoSesionSonora.desdeClave(mapa['tipo']),
        inicioMs: (mapa['inicio_ms'] as num).toInt(),
        finMs: (mapa['fin_ms'] as num?)?.toInt(),
        finPrevistoMs: (mapa['fin_previsto_ms'] as num?)?.toInt(),
        versionModelo: (mapa['version_modelo'] as String?) ?? '',
        traza: trazaDesdeJson(mapa['traza_json'] as String?),
        conFiltroDeZona: (mapa['con_filtro_zona'] as int?) == 1,
      );
}

/// Lo oído de una especie en una sesión.
class ResumenEspecieSesion {
  final String etiqueta;
  final String nombreComun;
  final String categoria;

  /// Detecciones de la especie, de la más antigua a la más reciente.
  final List<DeteccionSonora> detecciones;

  /// La de mejor puntuación (la que se usa para el hallazgo).
  final DeteccionSonora mejor;

  const ResumenEspecieSesion({
    required this.etiqueta,
    required this.nombreComun,
    required this.categoria,
    required this.detecciones,
    required this.mejor,
  });

  int get numeroDetecciones => detecciones.length;
  DeteccionSonora get primera => detecciones.first;
  DeteccionSonora get ultima => detecciones.last;
  NivelConfianzaSonido get nivelMejor => mejor.nivel;

  /// La ruta del clip de la especie (está en una sola detección).
  String? get rutaClip {
    for (final deteccion in detecciones) {
      if (deteccion.rutaClip != null) return deteccion.rutaClip;
    }
    return null;
  }

  /// Id del hallazgo, si ya se guardó alguna detección como hallazgo.
  int? get hallazgoId {
    for (final deteccion in detecciones) {
      if (deteccion.hallazgoId != null) return deteccion.hallazgoId;
    }
    return null;
  }

  /// La mejor detección con posición (para colocar el hallazgo), o null.
  DeteccionSonora? get mejorConPosicion {
    DeteccionSonora? elegida;
    for (final deteccion in detecciones) {
      if (!deteccion.tienePosicion) continue;
      if (elegida == null || deteccion.puntuacion > elegida.puntuacion) elegida = deteccion;
    }
    return elegida;
  }
}

/// Agrupa las detecciones por especie. Orden: por la primera vez que se
/// oyó cada una (el orden en que «entran» en el coro).
List<ResumenEspecieSesion> agruparDeteccionesPorEspecie(Iterable<DeteccionSonora> detecciones) {
  final porEspecie = <String, List<DeteccionSonora>>{};
  for (final deteccion in detecciones) {
    porEspecie.putIfAbsent(deteccion.etiqueta, () => []).add(deteccion);
  }
  final resumenes = <ResumenEspecieSesion>[];
  porEspecie.forEach((etiqueta, lista) {
    lista.sort((a, b) => a.momentoMs.compareTo(b.momentoMs));
    var mejor = lista.first;
    for (final deteccion in lista) {
      if (deteccion.puntuacion > mejor.puntuacion) mejor = deteccion;
    }
    final conNombre = lista.firstWhere((deteccion) => deteccion.nombreComun.isNotEmpty, orElse: () => lista.first);
    resumenes.add(ResumenEspecieSesion(
      etiqueta: etiqueta,
      nombreComun: conNombre.nombreComun,
      categoria: lista.first.categoria,
      detecciones: List.unmodifiable(lista),
      mejor: mejor,
    ));
  });
  resumenes.sort((a, b) {
    final porPrimera = a.primera.momentoMs.compareTo(b.primera.momentoMs);
    return porPrimera != 0 ? porPrimera : a.etiqueta.compareTo(b.etiqueta);
  });
  return resumenes;
}

/// Una franja de tiempo del resumen del coro.
class FranjaActividad {
  final DateTime inicio;
  final DateTime fin;

  /// Detecciones por especie (etiqueta) en la franja.
  final Map<String, int> deteccionesPorEspecie;

  const FranjaActividad({required this.inicio, required this.fin, required this.deteccionesPorEspecie});

  int get numeroDetecciones => deteccionesPorEspecie.values.fold(0, (suma, valor) => suma + valor);
  int get numeroEspecies => deteccionesPorEspecie.length;

  /// Especies de la franja, de la más oída a la menos.
  List<String> get especiesPorDetecciones => deteccionesPorEspecie.keys.toList()
    ..sort((a, b) {
      final porNumero = deteccionesPorEspecie[b]!.compareTo(deteccionesPorEspecie[a]!);
      return porNumero != 0 ? porNumero : a.compareTo(b);
    });
}

const int minutosPorFranjaCoro = 15;

/// Inicio de la franja que contiene [momento]: el cuarto de hora del reloj
/// (06:00, 06:15…), en hora local.
DateTime inicioDeFranja(DateTime momento, {int minutosFranja = minutosPorFranjaCoro}) {
  final local = momento.toLocal();
  final minutoInicio = local.minute - local.minute % minutosFranja;
  return DateTime(local.year, local.month, local.day, local.hour, minutoInicio);
}

/// Franjas de [minutosFranja] minutos alineadas al reloj, de la que contiene
/// [inicio] a la que contiene [fin] (también las vacías: son parte del
/// gráfico de actividad). Detecciones fuera de [inicio, fin] se ignoran.
List<FranjaActividad> franjasDeActividad(
  Iterable<DeteccionSonora> detecciones, {
  required DateTime inicio,
  required DateTime fin,
  int minutosFranja = minutosPorFranjaCoro,
}) {
  if (fin.isBefore(inicio)) return const [];
  final primeraFranja = inicioDeFranja(inicio, minutosFranja: minutosFranja);
  final duracionFranja = Duration(minutes: minutosFranja);
  final inicios = <DateTime>[];
  // Se avanza sumando minutos al reloj local (no milisegundos) para que un
  // cambio de hora no desalinee las franjas.
  for (var franja = primeraFranja; !franja.isAfter(fin); franja = franja.add(duracionFranja)) {
    inicios.add(franja);
    if (inicios.length > 24 * 60 ~/ minutosFranja * 2) break; // tope: dos días
  }
  final conteos = List.generate(inicios.length, (_) => <String, int>{});
  for (final deteccion in detecciones) {
    final momento = deteccion.momento;
    if (momento.isBefore(inicio) || momento.isAfter(fin)) continue;
    final diferenciaMinutos = momento.difference(primeraFranja).inMinutes;
    final indice = diferenciaMinutos ~/ minutosFranja;
    if (indice < 0 || indice >= inicios.length) continue;
    conteos[indice][deteccion.etiqueta] = (conteos[indice][deteccion.etiqueta] ?? 0) + 1;
  }
  return [
    for (var indice = 0; indice < inicios.length; indice++)
      FranjaActividad(
        inicio: inicios[indice],
        fin: inicios[indice].add(duracionFranja),
        deteccionesPorEspecie: Map.unmodifiable(conteos[indice]),
      ),
  ];
}

/// Hora de fin de un coro: [inicio] + [duracion], o la próxima vez que el
/// reloj marque [horaFin]:[minutoFin] después de [inicio] (si ya ha pasado
/// hoy, mañana).
DateTime finDelCoro({required DateTime inicio, Duration? duracion, int? horaFin, int? minutoFin}) {
  if (duracion != null) return inicio.add(duracion);
  if (horaFin == null) throw ArgumentError('Hace falta una duración o una hora de fin');
  return proximaHoraDelReloj(inicio, horaFin, minutoFin ?? 0);
}

/// La próxima vez (estrictamente después de [desde]) que el reloj local
/// marca [hora]:[minuto].
DateTime proximaHoraDelReloj(DateTime desde, int hora, int minuto) {
  final local = desde.toLocal();
  var candidata = DateTime(local.year, local.month, local.day, hora, minuto);
  if (!candidata.isAfter(local)) {
    candidata = DateTime(local.year, local.month, local.day + 1, hora, minuto);
  }
  return candidata;
}

/// Campo CSV (RFC 4180): entre comillas si lleva coma, comillas, punto y
/// coma o salto de línea; las comillas se doblan.
String campoCsv(Object? valor) {
  final texto = valor?.toString() ?? '';
  if (texto.contains(RegExp(r'[",;\n\r]'))) return '"${texto.replaceAll('"', '""')}"';
  return texto;
}

String _fechaHoraLocalIso(int momentoMs) {
  final local = DateTime.fromMillisecondsSinceEpoch(momentoMs);
  String dos(int numero) => numero.toString().padLeft(2, '0');
  return '${local.year}-${dos(local.month)}-${dos(local.day)}T${dos(local.hour)}:${dos(local.minute)}:${dos(local.second)}';
}

const String cabeceraCsvDetecciones =
    'sesion_id,tipo_sesion,fecha_hora,especie,nombre_comun,categoria,puntuacion,puntuacion_modelo,nivel,latitud,longitud,clip';

/// CSV con una fila por detección (hora local, sin zona: es la del móvil).
/// [nombreFicheroClip] da el nombre con el que va el clip (o vacío).
String csvDeteccionesSesion(
  SesionSonora sesion,
  Iterable<DeteccionSonora> detecciones, {
  String Function(String rutaClip)? nombreFicheroClip,
}) {
  final salida = StringBuffer()..write('$cabeceraCsvDetecciones\r\n');
  final ordenadas = detecciones.toList()..sort((a, b) => a.momentoMs.compareTo(b.momentoMs));
  for (final deteccion in ordenadas) {
    final rutaClip = deteccion.rutaClip;
    salida.write([
      campoCsv(sesion.id),
      campoCsv(sesion.tipo.clave),
      campoCsv(_fechaHoraLocalIso(deteccion.momentoMs)),
      campoCsv(deteccion.etiqueta),
      campoCsv(deteccion.nombreComun),
      campoCsv(deteccion.categoria),
      campoCsv(deteccion.puntuacion.toStringAsFixed(1)),
      campoCsv(deteccion.puntuacionModelo.toStringAsFixed(1)),
      campoCsv(deteccion.nivel.name),
      campoCsv(deteccion.latitud?.toStringAsFixed(6)),
      campoCsv(deteccion.longitud?.toStringAsFixed(6)),
      campoCsv(rutaClip == null ? '' : (nombreFicheroClip?.call(rutaClip) ?? rutaClip)),
    ].join(','));
    salida.write('\r\n');
  }
  return salida.toString();
}
