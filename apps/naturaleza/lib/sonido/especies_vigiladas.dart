import 'clasificacion_sonido.dart';
import 'manifiesto_modelo_fauna.dart';

/// «Avísame si lo oye»: especies del manifiesto que la persona quiere que
/// la app le avise si las oye (solo durante una sesión de escucha abierta).

/// Tras avisar de una especie, no se vuelve a avisar de ella hasta pasado
/// este tiempo (un pájaro que canta sin parar daría un aviso cada 2,5 s).
const Duration intervaloMinimoEntreAvisos = Duration(minutes: 5);

/// Máximo de especies vigiladas (la lista es para unas pocas buscadas).
const int maximoEspeciesVigiladas = 30;

/// Decide de qué especies vigiladas avisar en cada trozo: solo las
/// mostradas como resultado con nivel «probable» y que no se hayan avisado
/// hace menos de [intervaloMinimo].
class VigilanteEspecies {
  final Set<String> etiquetasVigiladas;
  final Duration intervaloMinimo;
  final Map<String, DateTime> _ultimoAviso = {};

  VigilanteEspecies(Iterable<String> etiquetas, {this.intervaloMinimo = intervaloMinimoEntreAvisos})
      : etiquetasVigiladas = etiquetas.toSet();

  bool get vacio => etiquetasVigiladas.isEmpty;

  /// Especies de [especiesMostradas] de las que hay que avisar ahora. Las
  /// devueltas quedan apuntadas como avisadas en [momento].
  List<ClaseClasificada> avisosPara(
    List<ClaseClasificada> especiesMostradas,
    List<ClaseSonido> clases,
    DateTime momento,
  ) {
    if (etiquetasVigiladas.isEmpty) return const [];
    final avisos = <ClaseClasificada>[];
    for (final clasificada in especiesMostradas) {
      if (clasificada.indiceClase < 0 || clasificada.indiceClase >= clases.length) continue;
      final clase = clases[clasificada.indiceClase];
      if (!clase.esEspecie || !etiquetasVigiladas.contains(clase.etiqueta)) continue;
      if (nivelConfianzaPara(clasificada.puntuacion) != NivelConfianzaSonido.probable) continue;
      final ultimo = _ultimoAviso[clase.etiqueta];
      if (ultimo != null && momento.difference(ultimo) < intervaloMinimo) continue;
      _ultimoAviso[clase.etiqueta] = momento;
      avisos.add(clasificada);
    }
    return avisos;
  }

  /// Olvida los avisos ya dados (al empezar otra escucha).
  void reiniciar() => _ultimoAviso.clear();
}

/// Minúsculas y sin tildes, para buscar «petirrojo» o «Erithacus».
String normalizarParaBuscar(String texto) {
  const conTilde = 'áàäâãéèëêíìïîóòöôõúùüûñçÁÀÄÂÃÉÈËÊÍÌÏÎÓÒÖÔÕÚÙÜÛÑÇ';
  const sinTilde = 'aaaaaeeeeiiiiooooouuuuncAAAAAEEEEIIIIOOOOOUUUUNC';
  final salida = StringBuffer();
  for (final caracter in texto.split('')) {
    final posicion = conTilde.indexOf(caracter);
    salida.write(posicion >= 0 ? sinTilde[posicion] : caracter);
  }
  return salida.toString().toLowerCase().replaceAll('_', ' ').trim();
}

/// Especies del manifiesto que se pueden vigilar (no los sonidos generales
/// ni la voz humana) que casan con [consulta] en el nombre científico o en
/// cualquier nombre común. Sin consulta, todas. Orden: por nombre visible.
List<ClaseSonido> clasesVigilables(List<ClaseSonido> clases, String consulta, {required String idioma}) {
  final buscada = normalizarParaBuscar(consulta);
  final encontradas = <ClaseSonido>[];
  for (final clase in clases) {
    if (!clase.esEspecie || clase.esVozHumana) continue;
    if (buscada.isNotEmpty) {
      final textos = [clase.etiqueta, ...clase.nombres.values.whereType<String>()];
      if (!textos.any((texto) => normalizarParaBuscar(texto).contains(buscada))) continue;
    }
    encontradas.add(clase);
  }
  encontradas.sort((a, b) =>
      normalizarParaBuscar(nombreVisiblePara(a, idioma)).compareTo(normalizarParaBuscar(nombreVisiblePara(b, idioma))));
  return encontradas;
}
