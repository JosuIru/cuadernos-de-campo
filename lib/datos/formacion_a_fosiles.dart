// Catálogo de formaciones geológicas ibéricas con sus fósiles
// característicos.
//
// Cada entrada lista los IDs de `FosilGuia` (ver `datos_guia.dart`) que
// son razonablemente esperables en la formación, según literatura
// geológica/paleontológica accesible (hojas MAGNA del IGME, guías de
// divulgación, monografías).
//
// IMPORTANTE: todas las entradas llevan el sufijo
// `PENDIENTE_VALIDACION_PALEONTOLOGICA` en el campo `fuente`. Es
// candidato a revisión por el comité científico (B1 del cuaderno)
// antes de retirar el sello.
//
// Política conservadora: si no hay seguridad >90% de la asociación
// formación↔fósil, la entrada se omite. Mejor catálogo pequeño y
// correcto que grande y dudoso.

import 'datos_guia.dart';

class CatalogoFormacion {
  /// Identificador interno estable (slug).
  final String id;

  /// Patrones de nombre que pueden aparecer en el texto que devuelve
  /// el WMS de GEODE 50 / IGME (campo de formación). Se hace match por
  /// substring case-insensitive y sin acentos.
  final List<String> patronesNombre;

  /// Período geológico al que pertenece la formación (id válido en
  /// `periodos` de `datos_guia.dart`).
  final String periodoId;

  /// Ambiente sedimentario dominante. Valores orientativos:
  /// 'marino-plataforma', 'marino-pelagico', 'marino-arrecifal',
  /// 'transicional', 'continental-fluvial', 'continental-lacustre',
  /// 'continental-aluvial', 'evaporitico', 'flysch'.
  final String ambientePrincipal;

  /// IDs de fósiles esperables. Deben existir en `fosilesGuia`.
  final List<String> fosilesIds;

  /// Descripción breve de la formación (1-2 frases).
  final String descripcionCorta;

  /// Regiones geológicas o administrativas donde aflora la formación.
  /// Ejemplos: 'Pirineos', 'Cordillera Vasco-Cantábrica',
  /// 'Sistema Ibérico', 'Cordilleras Béticas', 'Cuenca del Ebro'.
  final List<String> regiones;

  /// Referencia bibliográfica + marcador de validación pendiente.
  /// Por convención termina en ' · PENDIENTE_VALIDACION_PALEONTOLOGICA'.
  final String fuente;

  const CatalogoFormacion({
    required this.id,
    required this.patronesNombre,
    required this.periodoId,
    required this.ambientePrincipal,
    required this.fosilesIds,
    required this.descripcionCorta,
    required this.regiones,
    required this.fuente,
  });
}

const String _selloPendiente = ' · PENDIENTE_VALIDACION_PALEONTOLOGICA';

/// Catálogo de formaciones ibéricas documentadas.
///
/// Cobertura priorizada: Cordillera Vasco-Cantábrica y Pirineos (donde
/// hay más solapamiento con los yacimientos curados de la app y mejor
/// bibliografía accesible), seguido de Sistema Ibérico, Cordillera
/// Bética y Cuenca del Ebro.
const List<CatalogoFormacion> formacionesIbericas = [
  // ═══════════════ TRIÁSICO ═══════════════════════════════════════════

  CatalogoFormacion(
    id: 'buntsandstein',
    patronesNombre: [
      'buntsandstein',
      'areniscas rojas',
      'facies buntsandstein',
    ],
    periodoId: 'triasico',
    ambientePrincipal: 'continental-fluvial',
    fosilesIds: [
      // Triásico inferior continental: prácticamente sin macrofósiles
      // significativos en Iberia. Solo plantas ocasionales.
      'equisetum',
    ],
    descripcionCorta:
        'Areniscas y lutitas rojas continentales del Triásico Inferior, base de la sucesión germánica ibérica.',
    regiones: [
      'Cordillera Ibérica',
      'Cordillera Vasco-Cantábrica',
      'Pirineos',
    ],
    fuente:
        'IGME, Mapa Geológico de España E. 1:50.000 (varias hojas) · Sopeña & Sánchez-Moya 2004$_selloPendiente',
  ),

  CatalogoFormacion(
    id: 'muschelkalk',
    patronesNombre: [
      'muschelkalk',
      'facies muschelkalk',
      'calizas y dolomias del muschelkalk',
    ],
    periodoId: 'triasico',
    ambientePrincipal: 'marino-plataforma',
    fosilesIds: [
      'ceratites',
      'encrinus',
      'conchas-bivalvos',
    ],
    descripcionCorta:
        'Calizas y dolomías de plataforma marina somera del Triásico Medio (Anisiense-Ladiniense).',
    regiones: [
      'Cordillera Ibérica',
      'Cordillera Vasco-Cantábrica',
      'Cordilleras Costeras Catalanas',
    ],
    fuente:
        'IGME, MAGNA hojas Bilbao y Vitoria · Calvet & Marzo 1994$_selloPendiente',
  ),

  CatalogoFormacion(
    id: 'keuper',
    patronesNombre: [
      'keuper',
      'facies keuper',
      'arcillas y yesos del keuper',
      'diapiro triasico',
    ],
    periodoId: 'triasico',
    ambientePrincipal: 'evaporitico',
    fosilesIds: [
      'esquemas-keuper',
      'equisetum',
    ],
    descripcionCorta:
        'Arcillas abigarradas con yesos y halita, depositadas en lagunas marinas restringidas del Triásico Superior. Núcleos de diapiros en Iberia.',
    regiones: [
      'Cordillera Ibérica',
      'Cordillera Vasco-Cantábrica',
      'Rioja Alavesa',
      'Pirineos',
    ],
    fuente:
        'IGME, MAGNA hoja Salinas de Añana · Ortí 1974$_selloPendiente',
  ),

  // ═══════════════ JURÁSICO ═══════════════════════════════════════════

  CatalogoFormacion(
    id: 'calizas-aralar-lias',
    patronesNombre: [
      'calizas de aralar',
      'formacion aralar',
      'lias de aralar',
    ],
    periodoId: 'jurasico',
    ambientePrincipal: 'marino-plataforma',
    fosilesIds: [
      'gryphaea',
      'promicroceras',
      'pentacrinites',
      'belemnites',
      'braquiopodos',
    ],
    descripcionCorta:
        'Calizas y margocalizas del Lías inferior y medio (Sinemuriense-Pliensbachiense) de la Sierra de Aralar.',
    regiones: [
      'Cordillera Vasco-Cantábrica',
      'Pirineo navarro',
    ],
    fuente:
        'IGME, MAGNA hoja Tolosa · Floquet et al. 1982$_selloPendiente',
  ),

  CatalogoFormacion(
    id: 'margas-toarcienses-bizkaia',
    patronesNombre: [
      'margas toarcienses',
      'toarciense de bizkaia',
      'margas y margocalizas del toarciense',
    ],
    periodoId: 'jurasico',
    ambientePrincipal: 'marino-pelagico',
    fosilesIds: [
      'hildoceras',
      'harpoceras',
      'dactylioceras',
      'belemnites',
      'pholadomya',
    ],
    descripcionCorta:
        'Margas y margocalizas del Toarciense con abundantes ammonites y belemnites, depositadas en cuenca pelágica.',
    regiones: [
      'Cordillera Vasco-Cantábrica',
      'Bizkaia',
    ],
    fuente:
        'IGME, MAGNA hojas Bilbao y Lekeitio · Quesada et al. 1991$_selloPendiente',
  ),

  CatalogoFormacion(
    id: 'calizas-lias-camero',
    patronesNombre: [
      'lias de camero',
      'calizas del lias de cameros',
      'jurasico marino de cameros',
    ],
    periodoId: 'jurasico',
    ambientePrincipal: 'marino-plataforma',
    fosilesIds: [
      'gryphaea',
      'belemnites',
      'pentacrinites',
      'pholadomya',
      'braquiopodos',
    ],
    descripcionCorta:
        'Calizas y margas marinas del Jurásico Inferior y Medio de la Sierra de Cameros.',
    regiones: [
      'Sistema Ibérico',
      'La Rioja',
    ],
    fuente:
        'IGME, MAGNA hoja Logroño · Mas et al. 1993$_selloPendiente',
  ),

  CatalogoFormacion(
    id: 'calizas-dogger-iberica',
    patronesNombre: [
      'dogger',
      'calizas del dogger',
      'jurasico medio iberico',
      'bajociense-bathoniense',
    ],
    periodoId: 'jurasico',
    ambientePrincipal: 'marino-plataforma',
    fosilesIds: [
      'belemnites',
      'megateuthis',
      'pholadomya',
      'trigonia',
      'braquiopodos',
    ],
    descripcionCorta:
        'Calizas y calizas margosas del Jurásico Medio (Bajociense-Bathoniense) de plataforma carbonatada.',
    regiones: [
      'Sistema Ibérico',
      'Cordillera Vasco-Cantábrica',
    ],
    fuente:
        'IGME, MAGNA hojas Calatayud y Teruel · Gómez & Fernández-López 2006$_selloPendiente',
  ),

  CatalogoFormacion(
    id: 'calizas-pelagicas-kimmeridgiense',
    patronesNombre: [
      'kimmeridgiense',
      'malm pelagico',
      'calizas pelagicas del jurasico superior',
    ],
    periodoId: 'jurasico',
    ambientePrincipal: 'marino-pelagico',
    fosilesIds: [
      'idoceras',
      'phylloceras',
      'lytoceras',
      'belemnites',
    ],
    descripcionCorta:
        'Calizas y margas pelágicas del Jurásico Superior (Kimmeridgiense-Tithoniense).',
    regiones: [
      'Cordillera Vasco-Cantábrica',
      'Cordilleras Béticas',
    ],
    fuente:
        'Aurell et al. 2003, "Transgressive-regressive cycles and Jurassic palaeogeography of NE Iberia"$_selloPendiente',
  ),

  // ═══════════════ CRETÁCICO INFERIOR ═════════════════════════════════

  CatalogoFormacion(
    id: 'wealdiense-cameros',
    patronesNombre: [
      'wealdiense',
      'wealdense',
      'facies weald',
      'grupo enciso',
      'grupo oncala',
      'cretacico continental de cameros',
    ],
    periodoId: 'cretacico-inferior',
    ambientePrincipal: 'continental-fluvial',
    fosilesIds: [
      'iguanodon',
      'ginkgo',
      'equisetum',
      'icnofosiles',
    ],
    descripcionCorta:
        'Sucesión continental fluvio-lacustre del Cretácico Inferior de Cameros, famosa por icnitas de dinosaurios.',
    regiones: [
      'Sistema Ibérico',
      'La Rioja',
      'Soria',
      'Burgos',
    ],
    fuente:
        'IGME, MAGNA hojas Enciso y Préjano · Mas et al. 2002$_selloPendiente',
  ),

  CatalogoFormacion(
    id: 'calizas-urgonianas-aralar',
    patronesNombre: [
      'calizas urgonianas de aralar',
      'urgoniano de aralar',
      'caliza de aralar',
    ],
    periodoId: 'cretacico-inferior',
    ambientePrincipal: 'marino-arrecifal',
    fosilesIds: [
      'toucasia',
      'requienia',
      'orbitolina',
      'corales-coloniales',
      'choffatella',
      'esponjas-silicicas',
    ],
    descripcionCorta:
        'Calizas masivas con rudistas y corales del Aptiense-Albiense en la Sierra de Aralar (facies Urgoniana).',
    regiones: [
      'Cordillera Vasco-Cantábrica',
      'Pirineo navarro',
    ],
    fuente:
        'IGME, MAGNA hojas Tolosa y Alsasua · García-Mondéjar 1990$_selloPendiente',
  ),

  CatalogoFormacion(
    id: 'urgoniano-bizkaia',
    patronesNombre: [
      'urgoniano de bizkaia',
      'caliza urgoniana',
      'urgon de bizkaia',
      'urgoniano de ereño',
      'urgoniano de jata',
      'urgoniano de atxarte',
      'complejo urgoniano',
    ],
    periodoId: 'cretacico-inferior',
    ambientePrincipal: 'marino-arrecifal',
    fosilesIds: [
      'toucasia',
      'requienia',
      'orbitolina',
      'corales-coloniales',
      'choffatella',
      'esponjas-silicicas',
      'braquiopodos',
    ],
    descripcionCorta:
        'Complejo de calizas arrecifales con rudistas y corales del Aptiense-Albiense en Bizkaia (Ereño, Jata, Atxarte).',
    regiones: [
      'Cordillera Vasco-Cantábrica',
      'Bizkaia',
    ],
    fuente:
        'IGME, MAGNA hojas Bermeo, Bilbao y Markina · García-Mondéjar et al. 2004$_selloPendiente',
  ),

  CatalogoFormacion(
    id: 'urgoniano-cantabria',
    patronesNombre: [
      'urgoniano de cantabria',
      'caliza urgoniana de cantabria',
      'complejo urgoniano cantabro',
    ],
    periodoId: 'cretacico-inferior',
    ambientePrincipal: 'marino-arrecifal',
    fosilesIds: [
      'toucasia',
      'requienia',
      'orbitolina',
      'corales-coloniales',
      'choffatella',
    ],
    descripcionCorta:
        'Calizas con rudistas y orbitolínidos del Aptiense-Albiense en Cantabria oriental.',
    regiones: [
      'Cordillera Vasco-Cantábrica',
      'Cantabria',
    ],
    fuente:
        'IGME, MAGNA hojas Ramales y Castro Urdiales · Hines 1985$_selloPendiente',
  ),

  CatalogoFormacion(
    id: 'margas-aptienses-araba',
    patronesNombre: [
      'margas aptienses',
      'aptiense de araba',
      'margas del aptiense',
      'margas de salinillas',
      'margas de nograro',
    ],
    periodoId: 'cretacico-inferior',
    ambientePrincipal: 'marino-plataforma',
    fosilesIds: [
      'acanthohoplites',
      'douvilleiceras',
      'orbitolina',
      'ammonites-cretacico',
      'crioceratites',
      'braquiopodos',
    ],
    descripcionCorta:
        'Margas y margocalizas del Aptiense-Albiense de Araba, con ammonites abundantes (Salinillas, Nograro).',
    regiones: [
      'Cordillera Vasco-Cantábrica',
      'Álava',
    ],
    fuente:
        'IGME, MAGNA hoja Miranda de Ebro · García-Mondéjar & Fernández-Mendiola 1993$_selloPendiente',
  ),

  CatalogoFormacion(
    id: 'ambar-penacerrada',
    patronesNombre: [
      'peñacerrada',
      'penacerrada',
      'ambar de penacerrada',
      'moraza',
    ],
    periodoId: 'cretacico-inferior',
    ambientePrincipal: 'transicional',
    fosilesIds: [
      'ambar',
      'equisetum',
      'ginkgo',
    ],
    descripcionCorta:
        'Niveles con ámbar fosilífero del Albiense en facies deltaicas; uno de los mejores yacimientos de ámbar con inclusiones del mundo.',
    regiones: [
      'Montes Obarenes',
      'Álava',
      'Burgos',
    ],
    fuente:
        'Alonso et al. 2000, "A new fossil resin with biological inclusions in Lower Cretaceous deposits from Álava"$_selloPendiente',
  ),

  CatalogoFormacion(
    id: 'formacion-escucha',
    patronesNombre: [
      'formacion escucha',
      'escucha',
      'fm escucha',
    ],
    periodoId: 'cretacico-inferior',
    ambientePrincipal: 'transicional',
    fosilesIds: [
      'ginkgo',
      'equisetum',
      'iguanodon',
      'icnofosiles',
    ],
    descripcionCorta:
        'Lutitas y areniscas con niveles de carbón del Albiense del Maestrazgo, en facies deltaicas y pantanosas.',
    regiones: [
      'Cordillera Ibérica',
      'Maestrazgo',
      'Teruel',
    ],
    fuente:
        'Pardo 1979, "Estratigrafía y sedimentología de la Formación Escucha"$_selloPendiente',
  ),

  // ═══════════════ CRETÁCICO SUPERIOR ═════════════════════════════════

  CatalogoFormacion(
    id: 'calizas-cenomaniense-cuenca',
    patronesNombre: [
      'cenomaniense de cuenca',
      'calizas del cenomaniense',
      'cenomaniense iberico',
    ],
    periodoId: 'cretacico-superior',
    ambientePrincipal: 'marino-plataforma',
    fosilesIds: [
      'mortoniceras',
      'mammites',
      'conchas-bivalvos',
      'braquiopodos',
    ],
    descripcionCorta:
        'Calizas y dolomías de plataforma carbonatada somera del Cenomaniense en la Cordillera Ibérica.',
    regiones: [
      'Cordillera Ibérica',
      'Cuenca',
    ],
    fuente:
        'IGME, MAGNA hojas Cuenca y Tragacete · Segura et al. 2002$_selloPendiente',
  ),

  CatalogoFormacion(
    id: 'maastrichtiense-zumaia',
    patronesNombre: [
      'maastrichtiense de zumaia',
      'flysch de zumaia maastrichtiense',
      'calizas y margas del maastrichtiense',
      'limite k-pg de zumaia',
      'limite kpg',
    ],
    periodoId: 'cretacico-superior',
    ambientePrincipal: 'flysch',
    fosilesIds: [
      'inoceramus',
      'foraminiferos-planctonicos',
      'globotruncana',
      'ammonites-cretacico',
      'icnofosiles',
      'hoploparia',
    ],
    descripcionCorta:
        'Alternancia rítmica de margas y margocalizas del Maastrichtiense que contiene el GSSP del límite Cretácico-Paleógeno.',
    regiones: [
      'Cordillera Vasco-Cantábrica',
      'Gipuzkoa',
    ],
    fuente:
        'IGME, MAGNA hoja Zumaia · Molina et al. 1996, GSSP K-Pg$_selloPendiente',
  ),

  CatalogoFormacion(
    id: 'calizas-lekeitio',
    patronesNombre: [
      'calizas de lekeitio',
      'lekeitio',
      'fm lekeitio',
    ],
    periodoId: 'cretacico-superior',
    ambientePrincipal: 'marino-plataforma',
    fosilesIds: [
      'hippurites',
      'pycnodonte',
      'echinocorys',
      'conchas-bivalvos',
    ],
    descripcionCorta:
        'Calizas con rudistas hipuritidos del Maastrichtiense en la costa de Bizkaia oriental.',
    regiones: [
      'Cordillera Vasco-Cantábrica',
      'Bizkaia',
    ],
    fuente:
        'IGME, MAGNA hoja Lekeitio · Mathey 1987$_selloPendiente',
  ),

  CatalogoFormacion(
    id: 'margas-plentzia',
    patronesNombre: [
      'margas de plentzia',
      'plentzia',
      'fm plentzia',
    ],
    periodoId: 'cretacico-superior',
    ambientePrincipal: 'marino-pelagico',
    fosilesIds: [
      'inoceramus',
      'foraminiferos-planctonicos',
      'globotruncana',
      'ammonites-cretacico',
    ],
    descripcionCorta:
        'Margas pelágicas del Campaniense-Maastrichtiense en el arco vizcaíno.',
    regiones: [
      'Cordillera Vasco-Cantábrica',
      'Bizkaia',
    ],
    fuente:
        'IGME, MAGNA hoja Bermeo · Lamolda 1990$_selloPendiente',
  ),

  // ═══════════════ PALEOCENO – EOCENO ═════════════════════════════════

  CatalogoFormacion(
    id: 'flysch-zumaia-paleogeno',
    patronesNombre: [
      'flysch de zumaia',
      'flysch paleogeno',
      'flysch de zumaia-bizkaia',
      'flysch de deba',
      'daniense de zumaia',
      'ypresiense de zumaia',
    ],
    periodoId: 'paleoceno-eoceno',
    ambientePrincipal: 'flysch',
    fosilesIds: [
      'foraminiferos-planctonicos',
      'icnofosiles',
      'hoploparia',
      'nummulites',
    ],
    descripcionCorta:
        'Alternancia turbidítica margo-calcárea del Daniense al Ypresiense en la costa guipuzcoana; sección de referencia internacional.',
    regiones: [
      'Cordillera Vasco-Cantábrica',
      'Gipuzkoa',
    ],
    fuente:
        'IGME, MAGNA hoja Zumaia · Pujalte et al. 2003, Schmitz et al. 2011$_selloPendiente',
  ),

  CatalogoFormacion(
    id: 'calizas-pamplona-eoceno',
    patronesNombre: [
      'calizas de pamplona',
      'caliza de pamplona',
      'eoceno de pamplona',
    ],
    periodoId: 'paleoceno-eoceno',
    ambientePrincipal: 'marino-plataforma',
    fosilesIds: [
      'nummulites',
      'alveolina',
      'discocyclina',
      'briozoos',
      'pleurotomariidae',
    ],
    descripcionCorta:
        'Calizas con grandes foraminíferos bentónicos (nummulites, alveolinas) del Eoceno medio en la Cuenca de Pamplona.',
    regiones: [
      'Pirineos',
      'Cuenca de Pamplona',
      'Navarra',
    ],
    fuente:
        'IGME, MAGNA hoja Pamplona · Payros et al. 1999$_selloPendiente',
  ),

  CatalogoFormacion(
    id: 'margas-pamplona-eoceno',
    patronesNombre: [
      'margas de pamplona',
      'marga de pamplona',
      'margas grises de pamplona',
    ],
    periodoId: 'paleoceno-eoceno',
    ambientePrincipal: 'marino-pelagico',
    fosilesIds: [
      'foraminiferos-planctonicos',
      'icnofosiles',
      'briozoos',
      'hoploparia',
    ],
    descripcionCorta:
        'Margas hemipelágicas grises del Eoceno superior de la Cuenca de Pamplona, sobre las calizas con nummulites.',
    regiones: [
      'Pirineos',
      'Cuenca de Pamplona',
      'Navarra',
    ],
    fuente:
        'IGME, MAGNA hoja Pamplona · Payros et al. 1999$_selloPendiente',
  ),

  CatalogoFormacion(
    id: 'eoceno-iparralde',
    patronesNombre: [
      'eoceno de bidart',
      'eoceno de iparralde',
      'eoceno de bidache',
      'gaintxurizketa',
      'eoceno de gaintxurizketa',
    ],
    periodoId: 'paleoceno-eoceno',
    ambientePrincipal: 'marino-plataforma',
    fosilesIds: [
      'nummulites',
      'alveolina',
      'discocyclina',
      'dientes-tiburon',
      'otodus',
      'galeocerdo',
      'briozoos',
      'schizaster',
      'crustaceos-decapodos',
      'pleurotomariidae',
    ],
    descripcionCorta:
        'Calizas y margas eocenas de la costa labortana y de la divisoria pirenaica con nummulítidos y selacios.',
    regiones: [
      'Pirineos',
      'Iparralde',
      'Gipuzkoa',
    ],
    fuente:
        'BRGM, carte géologique Bayonne · Razin 1989$_selloPendiente',
  ),

  // ═══════════════ OLIGOCENO – MIOCENO ════════════════════════════════

  CatalogoFormacion(
    id: 'mioceno-rioja-alavesa',
    patronesNombre: [
      'mioceno de la rioja alavesa',
      'mioceno continental de la rioja',
      'calizas y margas del mioceno de la rioja',
      'mioceno de haro',
      'mioceno de logroño',
    ],
    periodoId: 'oligoceno-mioceno',
    ambientePrincipal: 'continental-lacustre',
    fosilesIds: [
      'gasteropodos-mioceno',
      'dientes-mamiferos',
      'anchitherium',
      'hipparion',
      'mastodon',
    ],
    descripcionCorta:
        'Calizas, margas y areniscas continentales del Mioceno medio-superior de la cuenca terciaria del Ebro en la Rioja Alavesa.',
    regiones: [
      'Cuenca del Ebro',
      'La Rioja',
      'Rioja Alavesa',
    ],
    fuente:
        'IGME, MAGNA hojas Haro y Logroño · Muñoz et al. 1997$_selloPendiente',
  ),

  CatalogoFormacion(
    id: 'mioceno-bardenas',
    patronesNombre: [
      'mioceno de bardenas',
      'mioceno continental de las bardenas',
      'mioceno superior del ebro',
      'turoliense de las bardenas',
    ],
    periodoId: 'oligoceno-mioceno',
    ambientePrincipal: 'continental-fluvial',
    fosilesIds: [
      'hipparion',
      'mastodon',
      'dientes-mamiferos',
      'gasteropodos-mioceno',
    ],
    descripcionCorta:
        'Sucesión continental del Mioceno superior (Vallesiense-Turoliense) con fauna de grandes mamíferos en las Bardenas Reales.',
    regiones: [
      'Cuenca del Ebro',
      'Navarra',
    ],
    fuente:
        'IGME, MAGNA hoja Tudela · Pérez-Rivarés et al. 2002$_selloPendiente',
  ),

  CatalogoFormacion(
    id: 'calizas-sastago-ebro',
    patronesNombre: [
      'calizas de sastago',
      'calizas miocenas del ebro',
      'caliza de zaragoza',
      'caliza de alcubierre',
    ],
    periodoId: 'oligoceno-mioceno',
    ambientePrincipal: 'continental-lacustre',
    fosilesIds: [
      'gasteropodos-mioceno',
      'dientes-mamiferos',
    ],
    descripcionCorta:
        'Calizas y margas lacustres del Mioceno medio del sector central de la Cuenca del Ebro.',
    regiones: [
      'Cuenca del Ebro',
      'Zaragoza',
    ],
    fuente:
        'IGME, MAGNA hoja Zaragoza · Arenas & Pardo 1999$_selloPendiente',
  ),

  CatalogoFormacion(
    id: 'mioceno-marino-iparralde',
    patronesNombre: [
      'mioceno marino de iparralde',
      'mioceno costero de iparralde',
      'mioceno de bidart',
      'helveciense de iparralde',
    ],
    periodoId: 'oligoceno-mioceno',
    ambientePrincipal: 'marino-plataforma',
    fosilesIds: [
      'pecten',
      'aequipecten-opercularis',
      'ostras-mioceno',
      'heterostegina',
      'briozoos',
      'carcharodon-carcharias',
      'galeocerdo',
    ],
    descripcionCorta:
        'Calcarenitas, margas y arenas miocenas de la franja costera labortana, con macrofauna marina abundante.',
    regiones: [
      'Pirineos',
      'Iparralde',
    ],
    fuente:
        'BRGM, carte géologique Bayonne · Cahuzac & Janin 1991$_selloPendiente',
  ),

  // ═══════════════ CUATERNARIO ════════════════════════════════════════

  CatalogoFormacion(
    id: 'terrazas-marinas-pleistocenas',
    patronesNombre: [
      'terraza marina',
      'terrazas marinas pleistocenas',
      'rasa litoral pleistocena',
      'rasa cantabrica',
    ],
    periodoId: 'cuaternario',
    ambientePrincipal: 'marino-plataforma',
    fosilesIds: [
      'glycymeris',
      'conchas-bivalvos',
      'pecten',
    ],
    descripcionCorta:
        'Niveles de terrazas marinas pleistocenas escalonadas a lo largo de la costa cantábrica, con macrofauna marina retrabajada.',
    regiones: [
      'Costa Cantábrica',
      'Bizkaia',
      'Cantabria',
      'Iparralde',
    ],
    fuente:
        'IGME, MAGNA hojas costeras Bilbao-Castro · Mary 1983$_selloPendiente',
  ),

  CatalogoFormacion(
    id: 'rellenos-karsticos-pleistoceno',
    patronesNombre: [
      'relleno karstico',
      'sedimentos de cueva',
      'deposito de cueva',
      'pleistoceno de cuevas',
      'breccia osifera',
    ],
    periodoId: 'cuaternario',
    ambientePrincipal: 'continental-aluvial',
    fosilesIds: [
      'oso-cavernas',
      'megaloceros',
      'huesos-cuaternario',
      'panthera-spelaea',
      'crocuta',
      'bison-priscus',
      'coelodonta',
      'rangifer',
      'cervus',
      'capra-pyrenaica',
      'bos-primigenius',
      'mammuthus-primigenius',
    ],
    descripcionCorta:
        'Rellenos sedimentarios pleistocenos de cuevas y abrigos kársticos con fauna fósil abundante.',
    regiones: [
      'Cordillera Vasco-Cantábrica',
      'Pirineos',
      'Aralar',
      'Bizkaia',
    ],
    fuente:
        'Castaños 1986, "Estudio de los macromamíferos del Pleistoceno superior del País Vasco"$_selloPendiente',
  ),
];

/// Normaliza el texto: minúsculas y reemplazo simple de acentos.
String _normalizarTextoFormacion(String texto) {
  const acentosOriginales = 'áéíóúüñàèìòùâêîôûäëïö';
  const acentosReemplazados = 'aeiouunaeiouaeiouaeio';
  var resultado = texto.toLowerCase();
  for (var indice = 0; indice < acentosOriginales.length; indice++) {
    resultado = resultado.replaceAll(
      acentosOriginales[indice],
      acentosReemplazados[indice],
    );
  }
  return resultado;
}

/// Busca una formación cuyos patrones de nombre coincidan (por
/// substring case-insensitive y sin acentos) con el texto que devuelve
/// el WMS de GEODE 50 / IGME para el campo de formación.
///
/// Devuelve la primera coincidencia (en el orden de declaración de
/// [formacionesIbericas]), o `null` si no se reconoce.
CatalogoFormacion? buscarFormacionEnTexto(String? formacionTextoIgme) {
  if (formacionTextoIgme == null) return null;
  final textoLimpio = formacionTextoIgme.trim();
  if (textoLimpio.isEmpty) return null;

  final textoNormalizado = _normalizarTextoFormacion(textoLimpio);

  for (final formacion in formacionesIbericas) {
    for (final patron in formacion.patronesNombre) {
      final patronNormalizado = _normalizarTextoFormacion(patron);
      if (patronNormalizado.isEmpty) continue;
      if (textoNormalizado.contains(patronNormalizado)) {
        return formacion;
      }
    }
  }
  return null;
}

/// Recupera la lista de [FosilGuia] correspondiente a los IDs
/// declarados en [formacion]. Filtra silenciosamente los IDs que no
/// existan en `fosilesGuia` (en condiciones normales no debería pasar:
/// el catálogo se mantiene en sincronía con `datos_guia.dart`).
List<FosilGuia> fosilesPorFormacion(CatalogoFormacion formacion) {
  final resultado = <FosilGuia>[];
  for (final idFosil in formacion.fosilesIds) {
    FosilGuia? encontrado;
    for (final candidato in fosilesGuia) {
      if (candidato.id == idFosil) {
        encontrado = candidato;
        break;
      }
    }
    // Si el ID no existe en fosilesGuia se ignora. Esto NO debería
    // ocurrir en runtime: indica desincronía entre este catálogo y
    // datos_guia.dart y debería detectarse en revisión de código.
    if (encontrado != null) {
      resultado.add(encontrado);
    }
  }
  return resultado;
}
