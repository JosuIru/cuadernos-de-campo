/// Manifiesto del modelo de fauna (`fauna-manifest.json`, publicado en la
/// release `modelo-fauna-europa-1` de Laboratorio de Bolsillo): qué fichero
/// descargar, cómo comprobarlo, cómo es la entrada, en qué orden salen los
/// resultados y qué es cada clase. Portado de `modelManifest.ts`.
library;

enum TipoClaseSonido { especie, sonido }

/// Grupo de la especie según el manifiesto (`bird`, `amphibian`…).
enum GrupoEspecieSonido {
  ave('bird', 'ave'),
  anfibio('amphibian', 'anfibio'),
  mamifero('mammal', 'mamifero'),
  insecto('insect', 'insecto'),
  reptil('reptile', 'reptil');

  /// Valor en el manifiesto.
  final String claveManifiesto;

  /// Categoría equivalente de Naturaleza (la de [Hallazgo.categoria]).
  final String categoriaNaturaleza;
  const GrupoEspecieSonido(this.claveManifiesto, this.categoriaNaturaleza);

  static GrupoEspecieSonido? desdeManifiesto(Object? valor) {
    for (final grupo in values) {
      if (grupo.claveManifiesto == valor) return grupo;
    }
    return null;
  }
}

class ClaseSonido {
  /// Nombre científico (especies) o etiqueta de AudioSet/FSD50K (sonidos
  /// generales).
  final String etiqueta;
  final TipoClaseSonido tipo;
  final GrupoEspecieSonido? grupo;

  /// Nombres comunes por idioma (`es`, `eu`, `en`); `null` si no hay.
  final Map<String, String?> nombres;

  /// Voz humana: estos trozos no se identifican ni se guardan.
  final bool esVozHumana;

  const ClaseSonido({
    required this.etiqueta,
    required this.tipo,
    this.grupo,
    this.nombres = const {},
    this.esVozHumana = false,
  });

  bool get esEspecie => tipo == TipoClaseSonido.especie;
}

class IndicesSalidaModelo {
  final int embedding;
  final int embeddingEspacial;
  final int espectrograma;
  final int logits;
  const IndicesSalidaModelo({
    required this.embedding,
    required this.embeddingEspacial,
    required this.espectrograma,
    required this.logits,
  });

  @override
  bool operator ==(Object other) =>
      other is IndicesSalidaModelo &&
      other.embedding == embedding &&
      other.embeddingEspacial == embeddingEspacial &&
      other.espectrograma == espectrograma &&
      other.logits == logits;

  @override
  int get hashCode => Object.hash(embedding, embeddingEspacial, espectrograma, logits);

  @override
  String toString() =>
      'IndicesSalidaModelo(embedding: $embedding, espacial: $embeddingEspacial, '
      'espectrograma: $espectrograma, logits: $logits)';
}

class ManifiestoFauna {
  final String versionModelo;
  final String ficheroModelo;
  final int bytesModelo;
  final String sha256Modelo;
  final int frecuenciaMuestreoHz;
  final int muestrasVentana;
  final IndicesSalidaModelo salidas;
  final String licencia;

  /// Fichero de presencia por lugar y época, en la misma release que el
  /// modelo. Si el manifiesto no lo trae, [ficheroOcurrenciaPorDefecto].
  final String ficheroOcurrencia;
  final List<ClaseSonido> clases;

  /// El JSON tal como llegó (se guarda en disco junto al modelo).
  final Map<String, dynamic> jsonOriginal;

  const ManifiestoFauna({
    required this.versionModelo,
    required this.ficheroModelo,
    required this.bytesModelo,
    required this.sha256Modelo,
    required this.frecuenciaMuestreoHz,
    required this.muestrasVentana,
    required this.salidas,
    required this.licencia,
    required this.ficheroOcurrencia,
    required this.clases,
    this.jsonOriginal = const {},
  });
}

const String ficheroOcurrenciaPorDefecto = 'fauna-occurrence-europa-1.json';

class ErrorFormatoManifiesto implements Exception {
  final String problema;
  const ErrorFormatoManifiesto(this.problema);
  @override
  String toString() => 'Manifiesto del modelo no válido: $problema';
}

num _numeroObligatorio(Map<String, dynamic> registro, String clave) {
  final valor = registro[clave];
  if (valor is! num || !valor.isFinite) {
    throw ErrorFormatoManifiesto('«$clave» debe ser un número');
  }
  return valor;
}

int _enteroObligatorio(Map<String, dynamic> registro, String clave) {
  final valor = _numeroObligatorio(registro, clave);
  if (valor != valor.roundToDouble()) {
    throw ErrorFormatoManifiesto('«$clave» debe ser un entero');
  }
  return valor.toInt();
}

String _textoObligatorio(Map<String, dynamic> registro, String clave) {
  final valor = registro[clave];
  if (valor is! String || valor.isEmpty) {
    throw ErrorFormatoManifiesto('«$clave» debe ser un texto');
  }
  return valor;
}

String? _nombreOpcional(Object? valor) =>
    valor is String && valor.trim().isNotEmpty ? valor : null;

final _patronSha256 = RegExp(r'^[0-9a-f]{64}$');
final _patronFicheroTflite = RegExp(r'^[\w.-]+\.tflite$');
final _patronFicheroJson = RegExp(r'^[\w.-]+\.json$');

ClaseSonido _leerClase(Object? claseCruda, int indiceClase) {
  if (claseCruda is! Map) {
    throw ErrorFormatoManifiesto('la clase $indiceClase no es un objeto');
  }
  final registro = claseCruda.cast<String, dynamic>();
  final etiqueta = _textoObligatorio(registro, 'label');
  final tipo = switch (registro['kind']) {
    'species' => TipoClaseSonido.especie,
    'sound' => TipoClaseSonido.sonido,
    _ => throw ErrorFormatoManifiesto('tipo desconocido en «$etiqueta»'),
  };
  final nombresCrudos = registro['names'] is Map
      ? (registro['names'] as Map).cast<String, dynamic>()
      : const <String, dynamic>{};
  return ClaseSonido(
    etiqueta: etiqueta,
    tipo: tipo,
    grupo: GrupoEspecieSonido.desdeManifiesto(registro['group']),
    nombres: {
      'es': _nombreOpcional(nombresCrudos['es']),
      'eu': _nombreOpcional(nombresCrudos['eu']),
      'en': _nombreOpcional(nombresCrudos['en']),
    },
    esVozHumana: registro['isHumanVoice'] == true,
  );
}

/// Comprueba y tipa el JSON descargado. Lanza [ErrorFormatoManifiesto] si no
/// encaja.
ManifiestoFauna leerManifiestoFauna(Object? manifiestoCrudo) {
  if (manifiestoCrudo is! Map) throw const ErrorFormatoManifiesto('no es un objeto');
  final registro = manifiestoCrudo.cast<String, dynamic>();
  if (registro['formatVersion'] != 1) {
    throw ErrorFormatoManifiesto(
        'versión de formato ${registro['formatVersion']} no admitida');
  }
  final sha256Modelo = _textoObligatorio(registro, 'modelSha256').toLowerCase();
  if (!_patronSha256.hasMatch(sha256Modelo)) {
    throw const ErrorFormatoManifiesto('«modelSha256» no es un SHA-256');
  }
  final ficheroModelo = _textoObligatorio(registro, 'modelFile');
  if (!_patronFicheroTflite.hasMatch(ficheroModelo)) {
    throw const ErrorFormatoManifiesto('«modelFile» no es un nombre de fichero .tflite');
  }
  final ficheroOcurrencia = registro['occurrenceFile'] == null
      ? ficheroOcurrenciaPorDefecto
      : _textoObligatorio(registro, 'occurrenceFile');
  if (!_patronFicheroJson.hasMatch(ficheroOcurrencia)) {
    throw const ErrorFormatoManifiesto('«occurrenceFile» no es un nombre de fichero .json');
  }
  final salidasCrudas = registro['outputs'];
  if (salidasCrudas is! Map) throw const ErrorFormatoManifiesto('faltan los índices de salida');
  final salidas = salidasCrudas.cast<String, dynamic>();
  final clasesCrudas = registro['classes'];
  if (clasesCrudas is! List || clasesCrudas.isEmpty) {
    throw const ErrorFormatoManifiesto('no hay clases');
  }
  return ManifiestoFauna(
    versionModelo: _textoObligatorio(registro, 'modelVersion'),
    ficheroModelo: ficheroModelo,
    bytesModelo: _enteroObligatorio(registro, 'modelBytes'),
    sha256Modelo: sha256Modelo,
    frecuenciaMuestreoHz: _enteroObligatorio(registro, 'sampleRateHz'),
    muestrasVentana: _enteroObligatorio(registro, 'windowSamples'),
    salidas: IndicesSalidaModelo(
      embedding: _enteroObligatorio(salidas, 'embedding'),
      embeddingEspacial: _enteroObligatorio(salidas, 'spatialEmbedding'),
      espectrograma: _enteroObligatorio(salidas, 'spectrogram'),
      logits: _enteroObligatorio(salidas, 'logits'),
    ),
    licencia: registro['license'] is String ? registro['license'] as String : '',
    ficheroOcurrencia: ficheroOcurrencia,
    clases: [
      for (final (indice, claseCruda) in clasesCrudas.indexed) _leerClase(claseCruda, indice),
    ],
    jsonOriginal: registro,
  );
}

int _producto(List<int> dimensiones) =>
    dimensiones.fold(1, (producto, dimension) => producto * dimension);

/// Decide qué salida del modelo es cada cosa. Se reconocen por su forma (más
/// robusto que el orden, que depende del conversor) y, si alguna no se
/// reconoce, se usa el orden del manifiesto.
IndicesSalidaModelo resolverIndicesSalida(
  List<List<int>> formasSalida,
  ManifiestoFauna manifiesto,
) {
  final numeroClases = manifiesto.clases.length;
  int buscarPorForma(bool Function(List<int> dimensiones) encaja) => formasSalida.indexWhere(
        (forma) => encaja(forma.where((dimension) => dimension != 1).toList()),
      );
  final indiceLogits = buscarPorForma((d) => d.length == 1 && d[0] == numeroClases);
  final indiceEmbedding = buscarPorForma((d) => d.length == 1 && d[0] == 1536);
  final indiceEspectrograma = buscarPorForma((d) => d.length == 2);
  final indiceEspacial = buscarPorForma((d) => d.length == 3);
  final indicesPorForma = [indiceEmbedding, indiceEspacial, indiceEspectrograma, indiceLogits];
  final estaCompleto = indicesPorForma.every((indice) => indice >= 0) &&
      indicesPorForma.toSet().length == 4;
  if (estaCompleto) {
    return IndicesSalidaModelo(
      embedding: indiceEmbedding,
      embeddingEspacial: indiceEspacial,
      espectrograma: indiceEspectrograma,
      logits: indiceLogits,
    );
  }
  final indicesManifiesto = manifiesto.salidas;
  final formaLogits = indicesManifiesto.logits < formasSalida.length
      ? formasSalida[indicesManifiesto.logits]
      : null;
  if (formaLogits == null || _producto(formaLogits) != numeroClases) {
    throw const ErrorFormatoManifiesto('las salidas del modelo no coinciden con el manifiesto');
  }
  return indicesManifiesto;
}

/// Error de integridad del fichero descargado (tamaño o SHA-256).
class ErrorIntegridadModelo implements Exception {
  final String problema;
  const ErrorIntegridadModelo(this.problema);
  @override
  String toString() => problema;
}

/// Comprueba que el fichero descargado es el del manifiesto. Lanza
/// [ErrorIntegridadModelo] si el tamaño o el SHA-256 no coinciden.
void comprobarIntegridadModelo({
  required ManifiestoFauna manifiesto,
  required int bytesDescargados,
  required String sha256Descargado,
}) {
  if (bytesDescargados != manifiesto.bytesModelo) {
    throw ErrorIntegridadModelo(
        'tamaño $bytesDescargados en vez de ${manifiesto.bytesModelo}');
  }
  if (sha256Descargado.toLowerCase() != manifiesto.sha256Modelo) {
    throw const ErrorIntegridadModelo('el SHA-256 no coincide');
  }
}
