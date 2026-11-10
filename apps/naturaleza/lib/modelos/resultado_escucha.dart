import '../datos/datos_guia.dart';
import '../sonido/clasificacion_sonido.dart';

/// Lo que devuelve «¿Quién canta?» al elegir una especie: con esto se
/// rellena el alta de hallazgo (especie, hora, categoría, evidencia
/// «sonido» y el clip de audio).
class ResultadoEscucha {
  final String nombreCientifico;
  final String nombreComun;

  /// Categoría de Naturaleza (`ave`, `anfibio`, `mamifero`, `insecto`,
  /// `reptil`); si la especie está en la guía, la de la guía.
  final String categoria;

  /// Cuándo se oyó (el trozo de la mejor puntuación).
  final DateTime momento;

  /// WAV en `audios/`, o null si no se pudo guardar el clip.
  final String? rutaAudio;
  final double duracionAudioSegundos;

  /// Puntuación usada para ordenar (con el filtro de zona, si estaba) y la
  /// del modelo.
  final double puntuacion;
  final double puntuacionModelo;
  final String versionModelo;
  final bool conFiltroDeZona;

  /// El clip es lo último oído (búfer de 10 s) y no el trozo analizado.
  final bool clipDeLoUltimoOido;

  /// Zona estimada del animal («¿Dónde está?»), para
  /// `Hallazgo.atributos['zona_animal']`; null si no se estimó.
  final Map<String, dynamic>? zonaAnimal;

  const ResultadoEscucha({
    required this.nombreCientifico,
    required this.nombreComun,
    required this.categoria,
    required this.momento,
    required this.rutaAudio,
    required this.duracionAudioSegundos,
    required this.puntuacion,
    required this.puntuacionModelo,
    required this.versionModelo,
    required this.conFiltroDeZona,
    this.clipDeLoUltimoOido = false,
    this.zonaAnimal,
  });

  NivelConfianzaSonido get nivelConfianza => nivelConfianzaPara(puntuacion);

  /// Ficha de la guía de la app con el mismo nombre científico, si la hay.
  EspecieGuia? get especieGuia => especieGuiaPorNombreCientifico(nombreCientifico);

  /// Se guarda en `Hallazgo.atributos['identificacion_sonido']` para saber
  /// después de dónde salió la identificación.
  Map<String, dynamic> aAtributo() => {
        'modelo': 'Perch 2.0 · $versionModelo',
        'puntuacion': double.parse(puntuacion.toStringAsFixed(1)),
        'puntuacion_modelo': double.parse(puntuacionModelo.toStringAsFixed(1)),
        'nivel': nivelConfianza.name,
        'filtro_zona': conFiltroDeZona,
        'momento_ms': momento.millisecondsSinceEpoch,
        if (clipDeLoUltimoOido) 'clip_ultimo_oido': true,
      };
}
