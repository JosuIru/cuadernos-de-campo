import 'dart:convert';

import 'atribucion_foto.dart';

/// Tipo de evidencia del hallazgo. La práctica real del aficionado
/// mezcla "vi el bicho" con "encontré una huella suya" o "oí su canto"
/// en la misma página del cuaderno. Aquí los tratamos como ciudadanos
/// de primera clase, no como casi-especies.
///
/// La persistencia es texto plano (no índice numérico) para que la
/// base de datos sea legible y los valores fácil de leer en SQL.
enum TipoEvidencia {
  avistamiento('avistamiento', 'Avistamiento'),
  huella('huella', 'Huella'),
  pluma('pluma', 'Pluma'),
  excremento('excremento', 'Excremento'),
  restosAlimentacion('restos_alimentacion', 'Restos de alimentación'),
  marcaCorteza('marca_corteza', 'Marca en corteza'),
  nidoVacio('nido_vacio', 'Nido vacío'),
  refugio('refugio', 'Refugio o madriguera'),
  sonido('sonido', 'Sonido o canto'),
  interaccion('interaccion', 'Interacción');

  final String clave;
  final String etiqueta;
  const TipoEvidencia(this.clave, this.etiqueta);

  static TipoEvidencia desdeClave(String? clave) {
    if (clave == null) return TipoEvidencia.avistamiento;
    return TipoEvidencia.values.firstWhere(
      (e) => e.clave == clave,
      orElse: () => TipoEvidencia.avistamiento,
    );
  }
}

/// Cuánta confianza tiene el aficionado en su propia identificación
/// en el momento de anotar. Texto libre (no enum estricto) permite
/// añadir valores en el futuro sin migrar la BD.
class ConfianzaIdentificacion {
  static const String segura = 'segura';
  static const String probable = 'probable';
  static const String tentativa = 'tentativa';
}

/// Estado de validación posterior de la identificación. Permite
/// calcular la propia tasa de acierto del aficionado a lo largo del
/// tiempo, sin depender de comunidad externa.
class EstadoIdentificacion {
  static const int sinRevisar = 0;
  static const int confirmada = 1;
  static const int corregida = 2;
}

class Hallazgo {
  final int? id;
  final int fechaMs;
  final double latitud;
  final double longitud;
  final double? precision;
  final String categoria;
  final String especie;
  final String nombreComun;
  final String taxonomia;
  final String habitat;
  final String notas;
  final List<String> rutasFotos;

  /// Atribución por foto, paralela a [rutasFotos]: misma longitud,
  /// `null` en la posición = foto del usuario (sin atribución), no-null
  /// = foto de archivo descargada de Wikipedia/iNaturalist con su
  /// licencia. Se persiste dentro de [atributos] bajo la clave
  /// `atribuciones_fotos` — sin migración del esquema sqlite.
  ///
  /// Lista vacía o longitud distinta a `rutasFotos` se trata como
  /// "ninguna foto tiene atribución" (todas del usuario).
  final List<AtribucionFoto?> atribucionesFotos;

  final Map<String, dynamic> atributos;

  /// Si pertenece a una salida (v3), su id. Null para hallazgos
  /// sueltos (incluidos todos los previos a la migración v3).
  final int? salidaId;

  /// Tipo de evidencia que sustenta el hallazgo (v3).
  final TipoEvidencia tipoEvidencia;

  /// Razonamiento del aficionado en el momento de anotar (v3):
  /// "creo que es Saxicola rubicola por el babero blanco". Permite
  /// revisar a posteriori la propia capacidad de identificación.
  final String hipotesis;

  /// Una de las constantes de [ConfianzaIdentificacion] o null. Texto
  /// libre por simplicidad en la BD (no enum).
  final String? confianzaIdentificacion;

  /// Estado de validación, ver [EstadoIdentificacion].
  final int identificacionValidada;

  /// Especie real tras revisión, si difiere de [especie] original.
  /// Sólo se rellena cuando [identificacionValidada] == corregida.
  final String especieCorregida;

  Hallazgo({
    this.id,
    required this.fechaMs,
    required this.latitud,
    required this.longitud,
    this.precision,
    this.categoria = 'animal',
    this.especie = '',
    this.nombreComun = '',
    this.taxonomia = '',
    this.habitat = '',
    this.notas = '',
    this.rutasFotos = const [],
    this.atribucionesFotos = const [],
    this.atributos = const {},
    this.salidaId,
    this.tipoEvidencia = TipoEvidencia.avistamiento,
    this.hipotesis = '',
    this.confianzaIdentificacion,
    this.identificacionValidada = EstadoIdentificacion.sinRevisar,
    this.especieCorregida = '',
  });

  bool get esAnimal => categoria == 'animal';
  bool get esInsecto => categoria == 'insecto';
  bool get esPlanta => categoria == 'planta';

  String? get rutaFoto => rutasFotos.isEmpty ? null : rutasFotos.first;

  /// Atribución de la foto en posición [indice], o `null` si:
  /// - el índice está fuera de rango,
  /// - la lista paralela no se rellenó (foto del usuario).
  AtribucionFoto? atribucionEnPosicion(int indice) {
    if (indice < 0 || indice >= atribucionesFotos.length) return null;
    return atribucionesFotos[indice];
  }

  Map<String, Object?> toMap() {
    final atributosCompleto = <String, dynamic>{...atributos};
    // Sólo persistimos la lista paralela si alguna foto tiene
    // atribución — evita ensuciar registros antiguos con un campo
    // vacío que no aporta nada.
    final hayAtribucion = atribucionesFotos.any((a) => a != null);
    if (hayAtribucion) {
      atributosCompleto['atribuciones_fotos'] = atribucionesFotos
          .map((a) => a?.toJson())
          .toList();
    }
    return {
      'id': id,
      'fecha_ms': fechaMs,
      'latitud': latitud,
      'longitud': longitud,
      'precision': precision,
      'categoria': categoria,
      'especie': especie,
      'nombre_comun': nombreComun,
      'taxonomia': taxonomia,
      'habitat': habitat,
      'notas': notas,
      'rutas_fotos_json':
          rutasFotos.isEmpty ? null : jsonEncode(rutasFotos),
      'atributos_json':
          atributosCompleto.isEmpty ? null : jsonEncode(atributosCompleto),
      'salida_id': salidaId,
      'tipo_evidencia': tipoEvidencia.clave,
      'hipotesis': hipotesis.isEmpty ? null : hipotesis,
      'confianza_identificacion': confianzaIdentificacion,
      'identificacion_validada': identificacionValidada,
      'especie_corregida':
          especieCorregida.isEmpty ? null : especieCorregida,
    };
  }

  factory Hallazgo.fromMap(Map<String, Object?> mapa) {
    final rutasJson = mapa['rutas_fotos_json'] as String?;
    List<String> rutas = const [];
    if (rutasJson != null && rutasJson.isNotEmpty) {
      try {
        rutas = (jsonDecode(rutasJson) as List).cast<String>();
      } catch (_) {
        rutas = const [];
      }
    }
    final atributosJson = mapa['atributos_json'] as String?;
    Map<String, dynamic> atributos = const {};
    if (atributosJson != null && atributosJson.isNotEmpty) {
      try {
        atributos =
            (jsonDecode(atributosJson) as Map).cast<String, dynamic>();
      } catch (_) {
        atributos = const {};
      }
    }
    // Extraemos la lista paralela de atribuciones del Map atributos
    // y la sacamos de allí para no duplicar cuando se vuelva a
    // serializar — toMap la regenera desde el campo `atribucionesFotos`.
    List<AtribucionFoto?> atribuciones = const [];
    final atribsRaw = atributos['atribuciones_fotos'];
    if (atribsRaw is List) {
      atribuciones = atribsRaw.map(AtribucionFoto.fromJson).toList();
      atributos = Map<String, dynamic>.from(atributos)
        ..remove('atribuciones_fotos');
    }
    return Hallazgo(
      id: mapa['id'] as int?,
      fechaMs: mapa['fecha_ms'] as int,
      latitud: (mapa['latitud'] as num).toDouble(),
      longitud: (mapa['longitud'] as num).toDouble(),
      precision: (mapa['precision'] as num?)?.toDouble(),
      categoria: (mapa['categoria'] as String?) ?? 'animal',
      especie: (mapa['especie'] as String?) ?? '',
      nombreComun: (mapa['nombre_comun'] as String?) ?? '',
      taxonomia: (mapa['taxonomia'] as String?) ?? '',
      habitat: (mapa['habitat'] as String?) ?? '',
      notas: (mapa['notas'] as String?) ?? '',
      rutasFotos: rutas,
      atribucionesFotos: atribuciones,
      atributos: atributos,
      salidaId: mapa['salida_id'] as int?,
      tipoEvidencia:
          TipoEvidencia.desdeClave(mapa['tipo_evidencia'] as String?),
      hipotesis: (mapa['hipotesis'] as String?) ?? '',
      confianzaIdentificacion: mapa['confianza_identificacion'] as String?,
      identificacionValidada:
          (mapa['identificacion_validada'] as int?) ??
              EstadoIdentificacion.sinRevisar,
      especieCorregida: (mapa['especie_corregida'] as String?) ?? '',
    );
  }

  Hallazgo copyWith({
    String? categoria,
    String? especie,
    String? nombreComun,
    String? taxonomia,
    String? habitat,
    String? notas,
    List<String>? rutasFotos,
    List<AtribucionFoto?>? atribucionesFotos,
    Map<String, dynamic>? atributos,
    int? salidaId,
    bool desasociarSalida = false,
    TipoEvidencia? tipoEvidencia,
    String? hipotesis,
    String? confianzaIdentificacion,
    bool limpiarConfianza = false,
    int? identificacionValidada,
    String? especieCorregida,
  }) =>
      Hallazgo(
        id: id,
        fechaMs: fechaMs,
        latitud: latitud,
        longitud: longitud,
        precision: precision,
        categoria: categoria ?? this.categoria,
        especie: especie ?? this.especie,
        nombreComun: nombreComun ?? this.nombreComun,
        taxonomia: taxonomia ?? this.taxonomia,
        habitat: habitat ?? this.habitat,
        notas: notas ?? this.notas,
        rutasFotos: rutasFotos ?? this.rutasFotos,
        atribucionesFotos: atribucionesFotos ?? this.atribucionesFotos,
        atributos: atributos ?? this.atributos,
        salidaId: desasociarSalida ? null : (salidaId ?? this.salidaId),
        tipoEvidencia: tipoEvidencia ?? this.tipoEvidencia,
        hipotesis: hipotesis ?? this.hipotesis,
        confianzaIdentificacion: limpiarConfianza
            ? null
            : (confianzaIdentificacion ?? this.confianzaIdentificacion),
        identificacionValidada:
            identificacionValidada ?? this.identificacionValidada,
        especieCorregida: especieCorregida ?? this.especieCorregida,
      );
}
