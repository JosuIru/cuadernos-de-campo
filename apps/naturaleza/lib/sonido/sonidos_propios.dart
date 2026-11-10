import 'dart:math' as math;
import 'dart:typed_data';

/// «Tus sonidos»: sonidos con nombre propio («El cárabo del roble», «Mi
/// perro») a partir de unos pocos ejemplos, sin entrenar nada. De cada
/// ejemplo se guarda solo el embedding de Perch 2.0 (1536 números), nunca el
/// audio, y cada trozo nuevo se compara con ellos por similitud coseno.
/// Portado de Laboratorio de Bolsillo (`customSounds.ts`, commits 1c73831 y
/// 96a4eb4). Sin Flutter ni base de datos.

/// Similitud mínima por defecto, medida en el Laboratorio con embeddings
/// reales de Perch 2.0 (fp16) sobre 7 grabaciones de especies distintas, 4
/// trozos de 5 s de cada una:
/// - trozos de la misma grabación: coseno de 0,33 a 0,98 (mediana 0,77);
/// - grabaciones distintas: de −0,05 a 0,34 (mediana 0,09); ruido de fondo,
///   hasta 0,27.
/// 0,5 queda por encima de todo lo distinto y acepta la mayoría de
/// repeticiones del mismo sonido. Con más datos reales habrá que afinarlo:
/// por eso hay un control de sensibilidad.
const double umbralSimilitudPorDefecto = 0.5;

enum SensibilidadSonidosPropios { estricta, normal, sensible }

const Map<SensibilidadSonidosPropios, double> umbralPorSensibilidad = {
  SensibilidadSonidosPropios.estricta: 0.6,
  SensibilidadSonidosPropios.normal: umbralSimilitudPorDefecto,
  SensibilidadSonidosPropios.sensible: 0.4,
};

/// Similitud de un sonido = media de sus 2 ejemplos más parecidos. Con el
/// máximo a secas, un ejemplo malo daría falsos positivos; con la media de
/// todos, un perro que ladra de dos maneras no llegaría nunca al umbral.
const int ejemplosMasParecidos = 2;

/// Ejemplos necesarios para que un sonido empiece a reconocerse.
const int ejemplosMinimosParaReconocer = 3;

/// Más ejemplos apenas mejoran y hacen más lenta la comparación.
const int ejemplosMaximosPorSonido = 10;
const int longitudMaximaNombreSonido = 40;

/// Dimensiones del embedding de Perch 2.0.
const int dimensionesEmbeddingPerch = 1536;

class SonidoPropio {
  final int id;
  final String nombre;

  /// Sonido «de fondo» (el ruido del sitio): no se reconoce nunca; sirve
  /// para descartar coincidencias que se parecen más al fondo que al sonido.
  final bool esFondo;
  final DateTime creado;

  const SonidoPropio({required this.id, required this.nombre, required this.esFondo, required this.creado});
}

class EjemploSonidoPropio {
  final int id;
  final int idSonido;
  final DateTime creado;
  final String versionModelo;
  final Float32List embedding;

  const EjemploSonidoPropio({
    required this.id,
    required this.idSonido,
    required this.creado,
    required this.versionModelo,
    required this.embedding,
  });
}

/// Sonido listo para comparar: ejemplos normalizados (norma 1).
class SonidoPreparado {
  final int idSonido;
  final String nombre;
  final bool esFondo;
  final List<Float32List> ejemplosNormalizados;

  const SonidoPreparado({
    required this.idSonido,
    required this.nombre,
    required this.esFondo,
    required this.ejemplosNormalizados,
  });
}

// ---------------------------------------------------------------- Vectores

/// Copia con norma 1. Un vector nulo (o con valores no finitos) se queda
/// nulo: similitud 0 con todo.
Float32List normalizarEmbedding(List<double> valores) {
  var normaCuadrado = 0.0;
  for (final valor in valores) {
    normaCuadrado += valor * valor;
  }
  final normalizado = Float32List(valores.length);
  if (!(normaCuadrado > 0) || !normaCuadrado.isFinite) return normalizado;
  final inversaNorma = 1 / math.sqrt(normaCuadrado);
  for (var indice = 0; indice < valores.length; indice++) {
    normalizado[indice] = valores[indice] * inversaNorma;
  }
  return normalizado;
}

/// Producto escalar; con vectores normalizados es la similitud coseno.
/// Longitudes distintas: 0.
double productoEscalar(List<double> izquierda, List<double> derecha) {
  if (izquierda.length != derecha.length) return 0;
  var suma = 0.0;
  for (var indice = 0; indice < izquierda.length; indice++) {
    suma += izquierda[indice] * derecha[indice];
  }
  return suma;
}

double similitudCoseno(List<double> izquierda, List<double> derecha) =>
    productoEscalar(normalizarEmbedding(izquierda), normalizarEmbedding(derecha));

/// Media de los [cuantos] ejemplos más parecidos (o de todos, si hay menos).
double similitudConSonido(
  Float32List embeddingNormalizado,
  List<Float32List> ejemplosNormalizados, {
  int cuantos = ejemplosMasParecidos,
}) {
  if (ejemplosNormalizados.isEmpty) return 0;
  final similitudes = [
    for (final ejemplo in ejemplosNormalizados) productoEscalar(embeddingNormalizado, ejemplo),
  ]..sort((a, b) => b.compareTo(a));
  final mejores = similitudes.take(math.max(1, cuantos)).toList();
  return mejores.reduce((a, b) => a + b) / mejores.length;
}

/// Agrupa los ejemplos por sonido y normaliza. Solo cuentan los ejemplos de
/// [versionModelo] (los embeddings de otro modelo no son comparables). Se
/// hace al cambiar los sonidos, no en cada trozo.
List<SonidoPreparado> prepararSonidosPropios(
  List<SonidoPropio> sonidos,
  List<EjemploSonidoPropio> ejemplos, {
  required String versionModelo,
}) =>
    [
      for (final sonido in sonidos)
        SonidoPreparado(
          idSonido: sonido.id,
          nombre: sonido.nombre,
          esFondo: sonido.esFondo,
          ejemplosNormalizados: [
            for (final ejemplo in ejemplos)
              if (ejemplo.idSonido == sonido.id && ejemplo.versionModelo == versionModelo)
                normalizarEmbedding(ejemplo.embedding),
          ],
        ),
    ];

// ---------------------------------------------------------------- Decisión

class CoincidenciaSonidoPropio {
  final int idSonido;
  final String nombre;
  final double similitud;

  /// Llega al umbral y se parece más al sonido que al fondo.
  final bool coincide;

  /// Llegaba al umbral, pero el fondo se parece todavía más.
  final bool ganaElFondo;

  const CoincidenciaSonidoPropio({
    required this.idSonido,
    required this.nombre,
    required this.similitud,
    required this.coincide,
    required this.ganaElFondo,
  });
}

class ResultadoSonidosPropios {
  /// Sonidos con ejemplos suficientes, del más al menos parecido.
  final List<CoincidenciaSonidoPropio> sonidos;

  /// Similitud con el fondo, o null si no hay ejemplos de fondo.
  final double? similitudFondo;

  const ResultadoSonidosPropios({required this.sonidos, required this.similitudFondo});

  static const vacio = ResultadoSonidosPropios(sonidos: [], similitudFondo: null);

  List<CoincidenciaSonidoPropio> get coincidencias => [
        for (final sonido in sonidos)
          if (sonido.coincide) sonido,
      ];
}

/// Compara el embedding de un trozo con los sonidos propios. Los que tienen
/// menos de [ejemplosMinimosParaReconocer] ejemplos no se tienen en cuenta.
ResultadoSonidosPropios compararConSonidosPropios(
  List<double> embedding,
  List<SonidoPreparado> sonidos, {
  double umbralSimilitud = umbralSimilitudPorDefecto,
}) {
  final normalizado = normalizarEmbedding(embedding);
  double? similitudFondo;
  for (final sonido in sonidos) {
    if (!sonido.esFondo || sonido.ejemplosNormalizados.isEmpty) continue;
    final similitud = similitudConSonido(normalizado, sonido.ejemplosNormalizados);
    similitudFondo = similitudFondo == null ? similitud : math.max(similitudFondo, similitud);
  }
  final resultado = <CoincidenciaSonidoPropio>[];
  for (final sonido in sonidos) {
    if (sonido.esFondo || sonido.ejemplosNormalizados.length < ejemplosMinimosParaReconocer) continue;
    final similitud = similitudConSonido(normalizado, sonido.ejemplosNormalizados);
    final llegaAlUmbral = similitud >= umbralSimilitud;
    final ganaElFondo = llegaAlUmbral && similitudFondo != null && similitudFondo >= similitud;
    resultado.add(CoincidenciaSonidoPropio(
      idSonido: sonido.idSonido,
      nombre: sonido.nombre,
      similitud: similitud,
      coincide: llegaAlUmbral && !ganaElFondo,
      ganaElFondo: ganaElFondo,
    ));
  }
  resultado.sort((a, b) => b.similitud.compareTo(a.similitud));
  return ResultadoSonidosPropios(sonidos: resultado, similitudFondo: similitudFondo);
}

/// Nombre limpio para un sonido nuevo o renombrado, o null si queda vacío.
String? limpiarNombreSonido(String nombreCrudo) {
  final limpio = nombreCrudo.replaceAll(RegExp(r'\s+'), ' ').trim();
  final recortado =
      (limpio.length > longitudMaximaNombreSonido ? limpio.substring(0, longitudMaximaNombreSonido) : limpio)
          .trim();
  return recortado.isEmpty ? null : recortado;
}

// ---------------------------------------------------------------- Persistencia

/// Embedding a bytes (float32 little-endian) para guardarlo en la BD.
Uint8List embeddingABytes(List<double> embedding) {
  final bytes = Uint8List(embedding.length * 4);
  final datos = ByteData.sublistView(bytes);
  for (var indice = 0; indice < embedding.length; indice++) {
    datos.setFloat32(indice * 4, embedding[indice], Endian.little);
  }
  return bytes;
}

Float32List bytesAEmbedding(Uint8List bytes) {
  final datos = ByteData.sublistView(bytes);
  final embedding = Float32List(bytes.length ~/ 4);
  for (var indice = 0; indice < embedding.length; indice++) {
    embedding[indice] = datos.getFloat32(indice * 4, Endian.little);
  }
  return embedding;
}

/// Similitud para mostrar: «0,87».
String textoSimilitud(double similitud) => similitud.toStringAsFixed(2).replaceAll('.', ',');
