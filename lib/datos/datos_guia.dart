import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../servicios/servicio_wikipedia.dart';
import 'package:url_launcher/url_launcher.dart' show launchUrl, LaunchMode;

class PeriodoGeologico {
  final String id;
  final String nombre;
  final String edadMa;
  final Color color;
  const PeriodoGeologico({required this.id, required this.nombre, required this.edadMa, required this.color});
}

class FosilGuia {
  final String id;
  final String nombre;
  final String grupo;
  final String periodoId;
  final String descripcionCorta;
  final List<String> distintivos;
  final String dondeEncontrar;
  final String tituloWikipedia;
  /// Ambientes sedimentarios donde es plausible encontrar este fósil.
  /// Valores válidos: 'marino', 'continental', 'fluvial', 'lacustre',
  /// 'eolico', 'transicional' (deltas, estuarios). Por defecto 'marino'
  /// porque la mayoría del catálogo son fósiles marinos.
  final List<String> ambientes;
  const FosilGuia({
    required this.id,
    required this.nombre,
    required this.grupo,
    required this.periodoId,
    required this.descripcionCorta,
    required this.distintivos,
    required this.dondeEncontrar,
    required this.tituloWikipedia,
    this.ambientes = const ['marino'],
  });
}

const List<PeriodoGeologico> periodos = [
  PeriodoGeologico(id: 'triasico', nombre: 'Triásico', edadMa: '252 – 201 Ma', color: Color(0xFFA87F9C)),
  PeriodoGeologico(id: 'jurasico', nombre: 'Jurásico', edadMa: '201 – 145 Ma', color: Color(0xFF34B2C9)),
  PeriodoGeologico(id: 'cretacico-inferior', nombre: 'Cretácico Inferior (Urgoniano)', edadMa: '145 – 100 Ma', color: Color(0xFF7FC64E)),
  PeriodoGeologico(id: 'cretacico-superior', nombre: 'Cretácico Superior', edadMa: '100 – 66 Ma', color: Color(0xFFA6D84A)),
  PeriodoGeologico(id: 'paleoceno-eoceno', nombre: 'Paleoceno – Eoceno', edadMa: '66 – 34 Ma', color: Color(0xFFFDB462)),
  PeriodoGeologico(id: 'oligoceno-mioceno', nombre: 'Oligoceno – Mioceno', edadMa: '34 – 5 Ma', color: Color(0xFFFFE45E)),
  PeriodoGeologico(id: 'cuaternario', nombre: 'Cuaternario', edadMa: '2,6 Ma – hoy', color: Color(0xFFFFF7C2)),
];

const List<FosilGuia> fosilesGuia = [
  // ─── TRIÁSICO ─────────────────────────────────────────
  FosilGuia(
    id: 'ceratites',
    nombre: 'Ceratites',
    grupo: 'Ammonoidea (ammonites primitivos)',
    periodoId: 'triasico',
    descripcionCorta: 'Ammonites del Muschelkalk con suturas ceratíticas (lóbulos dentados, sillas lisas).',
    distintivos: ['Concha enrollada', 'Suturas con dientes en los lóbulos', 'Tamaño 5–15 cm'],
    dondeEncontrar: 'Muschelkalk del Triásico Medio en afloramientos de Bizkaia.',
    tituloWikipedia: 'Ceratites',
  ),
  FosilGuia(
    id: 'esquemas-keuper',
    nombre: 'Yesos y minerales del Keuper',
    grupo: 'Mineralogía sedimentaria',
    periodoId: 'triasico',
    descripcionCorta: 'No son fósiles, pero suelen aparecer cuando hay materiales del Keuper.',
    distintivos: ['Yeso fibroso (selenita)', 'Arcillas rojas y verdes', 'Halita en algunas zonas'],
    dondeEncontrar: 'Diapiros triásicos de la Rioja Alavesa, Maeztu y Estella (Salinas de Añana).',
    tituloWikipedia: 'Keuper',
    ambientes: ['marino', 'lacustre'], // evaporitas: lagunas marinas restringidas o lagos endorreicos
  ),
  FosilGuia(
    id: 'encrinus',
    nombre: 'Encrinus (lirio de mar)',
    grupo: 'Crinoidea',
    periodoId: 'triasico',
    descripcionCorta: 'Crinoideo del Muschelkalk; restos de tallos columnares en placas circulares.',
    distintivos: ['Plaquitas en forma de moneda con orificio central', 'Tallo articulado', 'Cáliz pentaradial cuando se conserva'],
    dondeEncontrar: 'Muschelkalk del Triásico Medio de Bizkaia.',
    tituloWikipedia: 'Encrinus',
  ),
  FosilGuia(
    id: 'equisetum',
    nombre: 'Equisetum (cola de caballo fósil)',
    grupo: 'Pteridófita – Equisetales',
    periodoId: 'triasico',
    descripcionCorta: 'Plantas con tallos articulados, abundantes en facies continentales triásicas y jurásicas.',
    distintivos: ['Tallos huecos con nudos visibles', 'Verticilos de hojas en cada nudo', 'Acanaladuras longitudinales finas'],
    dondeEncontrar: 'Niveles continentales del Triásico-Jurásico (zonas con facies Keuper o Wealdiense).',
    tituloWikipedia: 'Equisetum',
    ambientes: ['continental', 'fluvial', 'lacustre'],
  ),

  // ─── JURÁSICO ────────────────────────────────────────
  FosilGuia(
    id: 'hildoceras',
    nombre: 'Hildoceras',
    grupo: 'Ammonoidea (ammonites)',
    periodoId: 'jurasico',
    descripcionCorta: 'Ammonites del Toarciense con costillas radiales y carena ventral marcada.',
    distintivos: ['Concha discoidal aplanada', 'Costillas falciformes', 'Surcos paralelos a la quilla'],
    dondeEncontrar: 'Margas toarcienses de Bizkaia y Cantabria oriental.',
    tituloWikipedia: 'Hildoceras',
  ),
  FosilGuia(
    id: 'harpoceras',
    nombre: 'Harpoceras',
    grupo: 'Ammonoidea',
    periodoId: 'jurasico',
    descripcionCorta: 'Ammonites del Jurásico Inferior, conchas finas con costulación delicada.',
    distintivos: ['Concha muy comprimida', 'Costillas finas en forma de hoz', 'Quilla central'],
    dondeEncontrar: 'Margas y calizas margosas del Toarciense de Bizkaia.',
    tituloWikipedia: 'Harpoceras',
  ),
  FosilGuia(
    id: 'dactylioceras',
    nombre: 'Dactylioceras',
    grupo: 'Ammonoidea',
    periodoId: 'jurasico',
    descripcionCorta: 'Ammonites pequeño, evoluto, con costillas que se bifurcan en el vientre.',
    distintivos: ['Enrollamiento abierto', 'Costillas radiales bifurcadas', '2–8 cm'],
    dondeEncontrar: 'Toarciense inferior de Bizkaia, asociado a Hildoceras.',
    tituloWikipedia: 'Dactylioceras',
  ),
  FosilGuia(
    id: 'belemnites',
    nombre: 'Belemnites',
    grupo: 'Coleoidea (cefalópodos extintos)',
    periodoId: 'jurasico',
    descripcionCorta: 'Rostros (puntas) de cefalópodos extintos parecidos a calamares.',
    distintivos: ['Forma de bala', 'Sección circular', 'Estrías longitudinales finas'],
    dondeEncontrar: 'Frecuentes en Lías y Dogger, sueltos en arroyos.',
    tituloWikipedia: 'Belemnitida',
  ),
  FosilGuia(
    id: 'pentacrinites',
    nombre: 'Pentacrinites (lirios de mar)',
    grupo: 'Crinoidea',
    periodoId: 'jurasico',
    descripcionCorta: 'Crinoideos pedunculados. Se encuentran los discos del tallo.',
    distintivos: ['Trozos cilíndricos articulados', 'Sección estrellada', '"Monedas con agujero"'],
    dondeEncontrar: 'Calizas y margas del Lías de Bizkaia y Araba.',
    tituloWikipedia: 'Pentacrinites',
  ),
  FosilGuia(
    id: 'gryphaea',
    nombre: 'Gryphaea (uña del diablo)',
    grupo: 'Bivalvia – ostras',
    periodoId: 'jurasico',
    descripcionCorta: 'Ostra extinta con valva inferior fuertemente arqueada.',
    distintivos: ['Valva inferior gruesa en cuerno', 'Valva superior plana', 'Líneas concéntricas'],
    dondeEncontrar: 'Lías inferior y medio en margas y calizas.',
    tituloWikipedia: 'Gryphaea',
  ),
  FosilGuia(
    id: 'pholadomya',
    nombre: 'Pholadomya',
    grupo: 'Bivalvia',
    periodoId: 'jurasico',
    descripcionCorta: 'Bivalvo infaunal abundante en margas mesozoicas.',
    distintivos: ['Concha alargada y delgada', 'Costillas radiales suaves', 'Valvas iguales'],
    dondeEncontrar: 'Margas del Lías y Dogger.',
    tituloWikipedia: 'Pholadomya',
  ),
  FosilGuia(
    id: 'trigonia',
    nombre: 'Trigonia',
    grupo: 'Bivalvia',
    periodoId: 'jurasico',
    descripcionCorta: 'Bivalvo de concha gruesa con costillas oblicuas.',
    distintivos: ['Forma triangular', 'Ornamentación en zig-zag', 'Concha gruesa nacarada'],
    dondeEncontrar: 'Calizas y arenas del Jurásico Superior y Cretácico basal.',
    tituloWikipedia: 'Trigonia',
  ),
  FosilGuia(
    id: 'promicroceras',
    nombre: 'Promicroceras',
    grupo: 'Ammonoidea (ammonites)',
    periodoId: 'jurasico',
    descripcionCorta: 'Ammonites pequeño y ornamentado del Sinemuriense, frecuente en margocalizas del Lías.',
    distintivos: ['Pequeño (1–3 cm)', 'Costillas marcadas radiales', 'Concha aplanada'],
    dondeEncontrar: 'Lías inferior de la Cuenca Vasco-Cantábrica.',
    tituloWikipedia: 'Promicroceras',
  ),
  FosilGuia(
    id: 'phylloceras',
    nombre: 'Phylloceras',
    grupo: 'Ammonoidea (ammonites)',
    periodoId: 'jurasico',
    descripcionCorta: 'Ammonites de aguas profundas con concha lisa y suturas muy complejas.',
    distintivos: ['Concha lisa o casi lisa', 'Sección elíptica alta', 'Suturas muy ramificadas'],
    dondeEncontrar: 'Margas del Jurásico medio y superior de la cuenca vascocantábrica.',
    tituloWikipedia: 'Phylloceras',
  ),
  FosilGuia(
    id: 'lytoceras',
    nombre: 'Lytoceras',
    grupo: 'Ammonoidea (ammonites)',
    periodoId: 'jurasico',
    descripcionCorta: 'Ammonites con vueltas evolutas y costillas finas; frecuente en facies pelágicas.',
    distintivos: ['Vueltas no recubiertas (evoluto)', 'Sección redonda', 'Suturas filiformes complejas'],
    dondeEncontrar: 'Calizas pelágicas del Jurásico de Bizkaia y Nafarroa.',
    tituloWikipedia: 'Lytoceras',
  ),
  FosilGuia(
    id: 'megateuthis',
    nombre: 'Megateuthis (belemnite gigante)',
    grupo: 'Cephalopoda – Belemnoidea',
    periodoId: 'jurasico',
    descripcionCorta: 'Belemnite de gran tamaño con rostro fusiforme alargado.',
    distintivos: ['Rostro fusiforme grande (10–40 cm)', 'Cristal calcítico fibroso radial', 'Sección con punta cónica'],
    dondeEncontrar: 'Bajociense–Bathoniense de la Cuenca Vasco-Cantábrica.',
    tituloWikipedia: 'Megateuthis',
  ),
  FosilGuia(
    id: 'plesiosaurus',
    nombre: 'Plesiosaurus (reptil marino)',
    grupo: 'Sauropterygia – Plesiosauria',
    periodoId: 'jurasico',
    descripcionCorta: 'Reptil marino jurásico con cuello largo y aletas; restos esporádicos en margas.',
    distintivos: ['Vértebras anficélicas grandes', 'Costillas paquiostóticas', 'Dientes cónicos finos'],
    dondeEncontrar: 'Lías de la Cuenca Vasco-Cantábrica (hallazgos puntuales).',
    tituloWikipedia: 'Plesiosaurus',
  ),
  FosilGuia(
    id: 'pliosaurus',
    nombre: 'Pliosaurus',
    grupo: 'Sauropterygia – Pliosauridae',
    periodoId: 'jurasico',
    descripcionCorta: 'Reptil marino jurásico de cuello corto y mandíbulas masivas; superdepredador del Jurásico Superior.',
    distintivos: ['Vértebras gigantes anficélicas', 'Dientes cónicos estriados grandes', 'Cráneo elongado'],
    dondeEncontrar: 'Jurásico Superior; hallazgos en Europa occidental.',
    tituloWikipedia: 'Pliosaurus',
  ),
  FosilGuia(
    id: 'idoceras',
    nombre: 'Idoceras',
    grupo: 'Ammonoidea (ammonites)',
    periodoId: 'jurasico',
    descripcionCorta: 'Ammonites del Kimmeridgiense, costulado y de tamaño medio.',
    distintivos: ['Costillas marcadas radiales', 'Concha aplanada', 'Sección oval'],
    dondeEncontrar: 'Calizas y margas del Kimmeridgiense en cuencas pelágicas.',
    tituloWikipedia: 'Idoceras',
  ),
  FosilGuia(
    id: 'hecticoceras',
    nombre: 'Hecticoceras',
    grupo: 'Ammonoidea (ammonites)',
    periodoId: 'jurasico',
    descripcionCorta: 'Ammonites del Calloviense con concha aplanada y quilla fina.',
    distintivos: ['Concha discoidal muy aplanada', 'Costillas finas curvadas', 'Quilla central marcada'],
    dondeEncontrar: 'Margas del Calloviense en cuencas pelágicas (Cordillera Vasco-Cantábrica).',
    tituloWikipedia: 'Hecticoceras',
  ),
  FosilGuia(
    id: 'megalosaurus',
    nombre: 'Megalosaurus (terópodo)',
    grupo: 'Dinosauria – Theropoda',
    periodoId: 'jurasico',
    descripcionCorta: 'Dinosaurio carnívoro grande del Jurásico Medio-Superior; conocido por dientes y huesos sueltos.',
    distintivos: ['Dientes de borde aserrado curvados', 'Vértebras grandes', 'Huellas tridáctilas grandes (icnitas)'],
    dondeEncontrar: 'Jurásico Superior continental; restos esporádicos en Europa.',
    tituloWikipedia: 'Megalosaurus',
    ambientes: ['continental'],
  ),

  // ─── CRETÁCICO INFERIOR ─────────────────────────────
  FosilGuia(
    id: 'toucasia',
    nombre: 'Toucasia',
    grupo: 'Bivalvia – Rudistas requiénidos',
    periodoId: 'cretacico-inferior',
    descripcionCorta: 'Rudista enrollado del Urgoniano, sustituyó a los corales en arrecifes someros.',
    distintivos: ['Concha enrollada espiralada', 'Pared gruesa', '5–15 cm'],
    dondeEncontrar: 'Caliza urgoniana de Bizkaia: Ereño, Atxarte, Jata.',
    // Toucasia carece de artículo propio en Wikipedia; usamos su
    // familia (Caprinidae) que sí tiene foto del grupo en EN. Distinto
    // de Requienia para que las miniaturas no se compartan.
    tituloWikipedia: 'Caprinidae',
  ),
  FosilGuia(
    id: 'requienia',
    nombre: 'Requienia',
    grupo: 'Bivalvia – Rudistas',
    periodoId: 'cretacico-inferior',
    descripcionCorta: 'Rudista característico del Aptiense-Albiense urgoniano.',
    distintivos: ['Forma de cuerno enrollado', 'Asimétrica', 'Rugosa'],
    dondeEncontrar: 'Calizas urgonianas de Bizkaia y Iparralde.',
    // Requienia tiene artículo en Wikipedia pero sin foto; Diceras
    // (rudista emparentado del Diceratidae) sí trae miniatura en EN.
    tituloWikipedia: 'Diceras',
  ),
  FosilGuia(
    id: 'orbitolina',
    nombre: 'Orbitolina',
    grupo: 'Foraminifera bentónico',
    periodoId: 'cretacico-inferior',
    descripcionCorta: 'Foraminífero discoidal grande, marcador del Cretácico Inferior.',
    distintivos: ['Forma de moneda o cono bajo', '2–10 mm', 'Sección con cámaras'],
    dondeEncontrar: 'Margas urgonianas del Aptiense en Bizkaia y Araba.',
    tituloWikipedia: 'Orbitolina',
  ),
  FosilGuia(
    id: 'corales-coloniales',
    nombre: 'Corales coloniales',
    grupo: 'Anthozoa – Scleractinia',
    periodoId: 'cretacico-inferior',
    descripcionCorta: 'Corales constructores de arrecifes urgonianos.',
    distintivos: ['Estructura ramificada o masiva', 'Cálices poligonales', 'Asociados a rudistas'],
    dondeEncontrar: 'Caliza urgoniana de Bizkaia, en bancos masivos.',
    tituloWikipedia: 'Scleractinia',
  ),
  FosilGuia(
    id: 'choffatella',
    nombre: 'Choffatella',
    grupo: 'Foraminifera bentónico',
    periodoId: 'cretacico-inferior',
    descripcionCorta: 'Foraminífero alargado característico del Urgoniano.',
    distintivos: ['Forma de cápsula alargada', '1–4 mm', 'Sección con cámaras planas'],
    dondeEncontrar: 'Margas y calizas urgonianas de Bizkaia y Iparralde.',
    tituloWikipedia: 'Choffatella',
  ),
  FosilGuia(
    id: 'braquiopodos',
    nombre: 'Braquiópodos (Rhynchonella, Terebratula)',
    grupo: 'Brachiopoda',
    periodoId: 'cretacico-inferior',
    descripcionCorta: 'Animales con dos valvas como bivalvos, pero de un grupo distinto.',
    distintivos: ['Dos valvas asimétricas', 'Pico marcado', '1–5 cm redondeado'],
    dondeEncontrar: 'Calizas y margas mesozoicas, especialmente Jurásico y Cretácico Inferior.',
    tituloWikipedia: 'Brachiopoda',
  ),
  FosilGuia(
    id: 'esponjas-silicicas',
    nombre: 'Espículas y esponjas silíceas',
    grupo: 'Porifera',
    periodoId: 'cretacico-inferior',
    descripcionCorta: 'Restos de esponjas que a veces forman nódulos de sílex.',
    distintivos: ['Espículas en aguja', 'Nódulos de sílex', 'A veces en bancos'],
    dondeEncontrar: 'Calizas urgonianas de Bizkaia, en bandas con sílex.',
    tituloWikipedia: 'Porifera',
  ),
  FosilGuia(
    id: 'iguanodon',
    nombre: 'Iguanodon (icnitas e impresiones)',
    grupo: 'Dinosauria – Ornithopoda',
    periodoId: 'cretacico-inferior',
    descripcionCorta: 'Dinosaurio herbívoro del Cretácico Inferior; en EH se conocen sobre todo huellas (icnitas).',
    distintivos: ['Huellas tridáctilas grandes (30–60 cm)', 'Dedos con falanges marcadas', 'Suelen aparecer alineadas formando rastros'],
    dondeEncontrar: 'Yacimientos de icnitas en La Rioja y Burgos, prolongables a Bizkaia oriental.',
    tituloWikipedia: 'Iguanodon',
    ambientes: ['continental', 'fluvial', 'lacustre'], // icnitas en facies Wealdiense fluvio-lacustres
  ),
  FosilGuia(
    id: 'crioceratites',
    nombre: 'Crioceratites',
    grupo: 'Ammonoidea – ammonites desenrollados',
    periodoId: 'cretacico-inferior',
    descripcionCorta: 'Ammonites heteromorfo con la concha desenrollada, característico del Hauteriviense-Barremiense.',
    distintivos: ['Concha en espiral abierta (no contigua)', 'Costillas espinosas o tuberculadas', 'Morfología llamativa'],
    dondeEncontrar: 'Margas del Cretácico Inferior de la cuenca vascocantábrica.',
    tituloWikipedia: 'Crioceratites',
  ),
  FosilGuia(
    id: 'acanthohoplites',
    nombre: 'Acanthohoplites',
    grupo: 'Ammonoidea (ammonites)',
    periodoId: 'cretacico-inferior',
    descripcionCorta: 'Ammonites del Aptiense superior con costillas tuberculadas.',
    distintivos: ['Costillas robustas con tubérculos', 'Sección rectangular', 'Tamaño 5–15 cm'],
    dondeEncontrar: 'Margas del Aptiense en Araba (Salinillas, Nograro).',
    tituloWikipedia: 'Acanthohoplites',
  ),
  FosilGuia(
    id: 'douvilleiceras',
    nombre: 'Douvilleiceras',
    grupo: 'Ammonoidea (ammonites)',
    periodoId: 'cretacico-inferior',
    descripcionCorta: 'Ammonites del Albiense con vueltas gruesas y tubérculos en filas.',
    distintivos: ['Concha gruesa y baja', 'Tres a siete filas de tubérculos', 'Tamaño 4–12 cm'],
    dondeEncontrar: 'Albiense de Araba (Cuenca Vasco-Cantábrica).',
    tituloWikipedia: 'Douvilleiceras',
  ),
  FosilGuia(
    id: 'ambar',
    nombre: 'Ámbar (resina fósil con inclusiones)',
    grupo: 'Resina fósil',
    periodoId: 'cretacico-inferior',
    descripcionCorta: 'Resina endurecida del Cretácico Inferior; el ámbar de Peñacerrada (Álava) es uno de los mejores yacimientos del mundo con inclusiones de insectos.',
    distintivos: ['Resina amarilla-ambarina semitransparente', 'A veces con burbujas, fragmentos vegetales o insectos', 'Fluorescente bajo UV'],
    dondeEncontrar: 'Cretácico Inferior de Peñacerrada (Álava), Moraza (Burgos) y otras cuencas albienses.',
    tituloWikipedia: 'Amber',
    ambientes: ['transicional', 'continental'], // paleobosques cercanos a costa, deltas/estuarios
  ),
  FosilGuia(
    id: 'ginkgo',
    nombre: 'Ginkgo (hojas fósiles)',
    grupo: 'Gimnospermas – Ginkgoales',
    periodoId: 'cretacico-inferior',
    descripcionCorta: 'Árbol mesozoico con hojas en abanico, todavía representado por Ginkgo biloba.',
    distintivos: ['Hojas en abanico con nervios paralelos dicotómicos', 'Lámina hendida', 'Frecuentes en facies continentales'],
    dondeEncontrar: 'Wealdiense del Cretácico Inferior continental (Cameros, La Rioja).',
    tituloWikipedia: 'Ginkgo',
    ambientes: ['continental', 'fluvial', 'lacustre'],
  ),

  // ─── CRETÁCICO SUPERIOR ─────────────────────────────
  FosilGuia(
    id: 'hippurites',
    nombre: 'Hippurites',
    grupo: 'Bivalvia – Rudistas hipuritidos',
    periodoId: 'cretacico-superior',
    descripcionCorta: 'Rudista cilíndrico que formó arrecifes en el Cretácico Superior.',
    distintivos: ['Forma cilíndrica o cónica', 'Pared gruesa con canales', 'Tapa pequeña con poros'],
    dondeEncontrar: 'Maastrichtiense de Iparralde y Bizkaia oriental.',
    tituloWikipedia: 'Hippurites',
  ),
  FosilGuia(
    id: 'inoceramus',
    nombre: 'Inoceramus',
    grupo: 'Bivalvia',
    periodoId: 'cretacico-superior',
    descripcionCorta: 'Bivalvo de gran tamaño con pliegues concéntricos. Marcador bioestratigráfico.',
    distintivos: ['Concha grande (10–50 cm)', 'Pliegues concéntricos', 'Conservación nacarada'],
    dondeEncontrar: 'Flysch de Zumaia–Deba.',
    tituloWikipedia: 'Inoceramus',
  ),
  FosilGuia(
    id: 'echinocorys',
    nombre: 'Echinocorys',
    grupo: 'Echinoidea (erizos)',
    periodoId: 'cretacico-superior',
    descripcionCorta: 'Erizo irregular en forma de casco, típico del Maastrichtiense.',
    distintivos: ['Forma de casco hemisférico', 'Boca ventral', 'Sin púas conservadas'],
    dondeEncontrar: 'Calizas y margas del Maastrichtiense.',
    tituloWikipedia: 'Echinocorys',
  ),
  FosilGuia(
    id: 'ammonites-cretacico',
    nombre: 'Ammonites del Cretácico',
    grupo: 'Ammonoidea',
    periodoId: 'cretacico-superior',
    descripcionCorta: 'Diversidad final de ammonites antes de su extinción en el K-Pg.',
    distintivos: ['Concha enrollada planispirada', 'Suturas complejas', 'Tamaños variables'],
    dondeEncontrar: 'Albiense de Araba (Salinillas, Nograro). Maastrichtiense del flysch.',
    tituloWikipedia: 'Ammonoidea',
  ),
  FosilGuia(
    id: 'foraminiferos-planctonicos',
    nombre: 'Foraminíferos planctónicos',
    grupo: 'Foraminifera',
    periodoId: 'cretacico-superior',
    descripcionCorta: 'Microfósiles que solo se ven al microscopio; clave del límite K-Pg.',
    distintivos: ['Tamaño microscópico (<1 mm)', 'Necesitas lupa o microscopio', 'En margas grises del flysch'],
    dondeEncontrar: 'Flysch de Zumaia: límite K-Pg, GSSP del Daniense.',
    tituloWikipedia: 'Foraminifera',
  ),
  FosilGuia(
    id: 'globotruncana',
    nombre: 'Globotruncana',
    grupo: 'Foraminifera planctónico',
    periodoId: 'cretacico-superior',
    descripcionCorta: 'Foraminífero planctónico clave para datar el Cretácico Superior.',
    distintivos: ['Forma trocoespiral aplanada', 'Quillas en el borde', '<1 mm'],
    dondeEncontrar: 'Margas del Cretácico Superior del flysch de Zumaia.',
    tituloWikipedia: 'Globotruncana',
  ),
  FosilGuia(
    id: 'pycnodonte',
    nombre: 'Pycnodonte',
    grupo: 'Bivalvia – Ostras',
    periodoId: 'cretacico-superior',
    descripcionCorta: 'Ostras grandes y arqueadas, parientes lejanos de las actuales.',
    distintivos: ['Valvas asimétricas, una muy cóncava', 'Concha gruesa rugosa', '5–20 cm'],
    dondeEncontrar: 'Maastrichtiense de Bizkaia y Iparralde.',
    tituloWikipedia: 'Pycnodonte',
  ),
  FosilGuia(
    id: 'icnofosiles',
    nombre: 'Icnofósiles (huellas y galerías)',
    grupo: 'Trazas fósiles',
    periodoId: 'cretacico-superior',
    descripcionCorta: 'Pistas, galerías y huellas de organismos en el sustrato.',
    distintivos: ['Surcos, túneles o impresiones', 'Patrones repetitivos', 'En areniscas y margas'],
    dondeEncontrar: 'Flysch de Zumaia (Zoophycos, Thalassinoides).',
    tituloWikipedia: 'Icnología',
  ),
  FosilGuia(
    id: 'conchas-bivalvos',
    nombre: 'Bivalvos diversos',
    grupo: 'Bivalvia',
    periodoId: 'cretacico-superior',
    descripcionCorta: 'Conchas de almejas y ostras, los más frecuentes.',
    distintivos: ['Dos valvas iguales o desiguales', 'Líneas concéntricas', 'A menudo solo una valva'],
    dondeEncontrar: 'Cualquier serie marina mesozoica o terciaria.',
    tituloWikipedia: 'Bivalvia',
  ),
  FosilGuia(
    id: 'mortoniceras',
    nombre: 'Mortoniceras',
    grupo: 'Ammonoidea (ammonites)',
    periodoId: 'cretacico-superior',
    descripcionCorta: 'Ammonites del Albiense superior con quilla ventral y costillas marcadas.',
    distintivos: ['Quilla ventral muy clara', 'Costillas radiales con tubérculos', 'Sección rectangular'],
    dondeEncontrar: 'Cretácico Superior basal (Albiense superior – Cenomaniense) de Araba.',
    tituloWikipedia: 'Mortoniceras',
  ),
  FosilGuia(
    id: 'mosasaurus',
    nombre: 'Mosasaurus (reptil marino)',
    grupo: 'Squamata – Mosasauridae',
    periodoId: 'cretacico-superior',
    descripcionCorta: 'Reptil marino depredador del Cretácico Superior; restos esporádicos en Maastrichtiense.',
    distintivos: ['Vértebras grandes anficélicas', 'Dientes cónicos curvos con estrías', 'Hueso compacto'],
    dondeEncontrar: 'Hallazgos puntuales en el Maastrichtiense del flysch.',
    tituloWikipedia: 'Mosasaurus',
  ),
  FosilGuia(
    id: 'mammites',
    nombre: 'Mammites',
    grupo: 'Ammonoidea (ammonites)',
    periodoId: 'cretacico-superior',
    descripcionCorta: 'Ammonites del Cenomaniense-Turoniense; concha gruesa con costillas robustas.',
    distintivos: ['Costillas radiales fuertes', 'Vientre con quilla baja', 'Tamaño 10–25 cm'],
    dondeEncontrar: 'Cretácico Superior basal en cuencas marinas peripenibéticas.',
    tituloWikipedia: 'Mammites',
  ),
  FosilGuia(
    id: 'hoploparia',
    nombre: 'Hoploparia (langostino fósil)',
    grupo: 'Crustacea – Decapoda',
    periodoId: 'cretacico-superior',
    descripcionCorta: 'Langostino fósil con grandes pinzas; muy común en margas cretácicas y paleógenas.',
    distintivos: ['Caparazón estriado con surcos cervicales', 'Pinzas con tubérculos', 'Conservado en nódulos'],
    dondeEncontrar: 'Margas del Cretácico Superior y Eoceno del flysch y cuencas pirenaicas.',
    tituloWikipedia: 'Hoploparia',
  ),

  // ─── PALEOCENO – EOCENO ─────────────────────────────
  FosilGuia(
    id: 'nummulites',
    nombre: 'Nummulites',
    grupo: 'Foraminifera bentónico',
    periodoId: 'paleoceno-eoceno',
    descripcionCorta: 'Foraminífero discoidal del Eoceno, en forma de moneda.',
    distintivos: ['Forma de lenteja', '0,5–4 cm', 'Espiral interna visible al partir'],
    dondeEncontrar: 'Eoceno de Iparralde (Bidart, Gaintxurizketa).',
    tituloWikipedia: 'Nummulites',
  ),
  FosilGuia(
    id: 'alveolina',
    nombre: 'Alveolina',
    grupo: 'Foraminifera bentónico',
    periodoId: 'paleoceno-eoceno',
    descripcionCorta: 'Foraminífero fusiforme parecido a un grano de arroz grande.',
    distintivos: ['Forma alargada fusiforme', '2–10 mm', 'Cámaras helicoidales'],
    dondeEncontrar: 'Calizas del Ilerdiense de Araba y Nafarroa.',
    tituloWikipedia: 'Alveolina',
  ),
  FosilGuia(
    id: 'discocyclina',
    nombre: 'Discocyclina',
    grupo: 'Foraminifera bentónico',
    periodoId: 'paleoceno-eoceno',
    descripcionCorta: 'Foraminífero discoidal grande del Eoceno, contemporáneo de Nummulites.',
    distintivos: ['Forma de disco aplanado', '1–5 cm', 'Más fino que Nummulites'],
    dondeEncontrar: 'Eoceno de Iparralde.',
    tituloWikipedia: 'Foraminifera',
  ),
  FosilGuia(
    id: 'dientes-tiburon',
    nombre: 'Dientes de tiburón',
    grupo: 'Chondrichthyes',
    periodoId: 'paleoceno-eoceno',
    descripcionCorta: 'Dientes triangulares de selacios. Comunes en arenas marinas terciarias.',
    distintivos: ['Forma triangular', 'Esmalte brillante', 'Bordes dentados o lisos'],
    dondeEncontrar: 'Eoceno de Iparralde y depósitos miocenos.',
    tituloWikipedia: 'Selachimorpha',
  ),
  FosilGuia(
    id: 'briozoos',
    nombre: 'Briozoos',
    grupo: 'Bryozoa',
    periodoId: 'paleoceno-eoceno',
    descripcionCorta: 'Pequeños invertebrados coloniales con esqueleto reticulado.',
    distintivos: ['Aspecto de red o encaje', 'Celdillas milimétricas', 'Forma de abanico, costra o ramificada'],
    dondeEncontrar: 'Calizas eocenas de Iparralde y bancos miocenos.',
    tituloWikipedia: 'Bryozoa',
  ),
  FosilGuia(
    id: 'schizaster',
    nombre: 'Schizaster (erizo irregular)',
    grupo: 'Echinoidea',
    periodoId: 'paleoceno-eoceno',
    descripcionCorta: 'Erizo irregular en forma de corazón, infaunal.',
    distintivos: ['Forma de corazón', 'Surco anterior marcado', 'Pétalos con poros visibles'],
    dondeEncontrar: 'Margas eocenas de Iparralde y cuenca surpirenaica.',
    tituloWikipedia: 'Schizaster',
  ),
  FosilGuia(
    id: 'crustaceos-decapodos',
    nombre: 'Cangrejos y crustáceos decápodos',
    grupo: 'Decapoda',
    periodoId: 'paleoceno-eoceno',
    descripcionCorta: 'Cangrejos fósiles, conservados como pinzas o caparazones aplastados.',
    distintivos: ['Caparazón segmentado', 'Pinzas rugosas', 'En nódulos calcáreos'],
    dondeEncontrar: 'Eoceno de Iparralde y cuenca alavesa.',
    tituloWikipedia: 'Decapoda',
  ),
  FosilGuia(
    id: 'otodus',
    nombre: 'Otodus (diente de tiburón)',
    grupo: 'Chondrichthyes – Lamniformes',
    periodoId: 'paleoceno-eoceno',
    descripcionCorta: 'Diente triangular grande con cúspides laterales; ancestro de los tiburones megadientes.',
    distintivos: ['Triángulo robusto, 3–8 cm', 'Cúspides laterales pequeñas', 'Bordes lisos o ligeramente serrados'],
    dondeEncontrar: 'Eoceno de Iparralde y depósitos cuenca alavesa.',
    tituloWikipedia: 'Otodus',
  ),
  FosilGuia(
    id: 'galeocerdo',
    nombre: 'Galeocerdo (tiburón tigre fósil)',
    grupo: 'Chondrichthyes – Carcharhiniformes',
    periodoId: 'paleoceno-eoceno',
    descripcionCorta: 'Tiburón con dientes triangulares fuertemente serrados, presente desde el Eoceno.',
    distintivos: ['Diente triangular curvado', 'Bordes serrados muy marcados', 'Talón distal aserrado'],
    dondeEncontrar: 'Eoceno de Iparralde y miocenos costeros.',
    tituloWikipedia: 'Galeocerdo',
  ),
  FosilGuia(
    id: 'pleurotomariidae',
    nombre: 'Pleurotomariidae',
    grupo: 'Gastropoda',
    periodoId: 'paleoceno-eoceno',
    descripcionCorta: 'Caracoles marinos con la característica banda perforada espiral.',
    distintivos: ['Concha cónica espiralada', 'Banda con hendidura paralela a la espira', 'Tamaño 2–10 cm'],
    dondeEncontrar: 'Calizas y margas eocenas de Iparralde.',
    tituloWikipedia: 'Pleurotomariidae',
  ),

  // ─── OLIGOCENO – MIOCENO ────────────────────────────
  FosilGuia(
    id: 'pecten',
    nombre: 'Pecten / Chlamys (vieiras)',
    grupo: 'Bivalvia – pectínidos',
    periodoId: 'oligoceno-mioceno',
    descripcionCorta: 'Vieiras fósiles muy parecidas a las actuales.',
    distintivos: ['Forma de abanico', 'Costillas radiales marcadas', 'Orejas a los lados'],
    dondeEncontrar: 'Mioceno marino de la cuenca del Ebro y Iparralde.',
    tituloWikipedia: 'Pectinidae',
  ),
  FosilGuia(
    id: 'gasteropodos-mioceno',
    nombre: 'Gasterópodos miocenos',
    grupo: 'Gastropoda',
    periodoId: 'oligoceno-mioceno',
    descripcionCorta: 'Caracoles fósiles en sedimentos continentales y marinos miocenos.',
    distintivos: ['Concha enrollada espiralada', 'A veces conserva nácar', 'Tamaños variables'],
    dondeEncontrar: 'Cuencas continentales del Mioceno de la Rioja Alavesa y Nafarroa.',
    tituloWikipedia: 'Gastropoda',
    ambientes: ['marino', 'continental', 'lacustre'],
  ),
  FosilGuia(
    id: 'ostras-mioceno',
    nombre: 'Ostras (Ostrea, Crassostrea)',
    grupo: 'Bivalvia',
    periodoId: 'oligoceno-mioceno',
    descripcionCorta: 'Ostras fósiles, a menudo en bancos densos en sedimentos costeros.',
    distintivos: ['Valvas asimétricas', 'Aspecto rugoso laminar', 'En bloques cementados'],
    dondeEncontrar: 'Mioceno de Iparralde.',
    tituloWikipedia: 'Ostreidae',
  ),
  FosilGuia(
    id: 'heterostegina',
    nombre: 'Heterostegina',
    grupo: 'Foraminifera bentónico',
    periodoId: 'oligoceno-mioceno',
    descripcionCorta: 'Foraminífero discoidal del Oligo-Mioceno, sucesor evolutivo de Nummulites.',
    distintivos: ['Forma de disco aplanado', 'Cámaras al borde', '0,5–2 cm'],
    dondeEncontrar: 'Mioceno marino de Iparralde.',
    tituloWikipedia: 'Heterostegina',
  ),
  FosilGuia(
    id: 'dientes-mamiferos',
    nombre: 'Dientes y huesos de mamíferos',
    grupo: 'Mammalia',
    periodoId: 'oligoceno-mioceno',
    descripcionCorta: 'Restos de mamíferos terrestres miocenos: rinocerontes, équidos, roedores.',
    distintivos: ['Esmalte brillante', 'Coronas con relieve', 'Hueso poroso'],
    dondeEncontrar: 'Yacimientos miocenos del Bardenas y Rioja.',
    tituloWikipedia: 'Mammalia',
    ambientes: ['continental', 'fluvial', 'lacustre'],
  ),
  FosilGuia(
    id: 'anchitherium',
    nombre: 'Anchitherium (équido tridáctilo)',
    grupo: 'Mammalia – Equidae',
    periodoId: 'oligoceno-mioceno',
    descripcionCorta: 'Équido primitivo de tres dedos del Mioceno inferior.',
    distintivos: ['Molares con coronas bajas', 'Tres dedos visibles en la huella', 'Tamaño de poni pequeño'],
    dondeEncontrar: 'Yacimientos del Mioceno inferior de la Rioja Alavesa.',
    tituloWikipedia: 'Anchitherium',
    ambientes: ['continental', 'fluvial', 'lacustre'],
  ),
  FosilGuia(
    id: 'hipparion',
    nombre: 'Hipparion',
    grupo: 'Mammalia – Equidae',
    periodoId: 'oligoceno-mioceno',
    descripcionCorta: 'Caballo tridáctilo del Mioceno superior, marcador de la fauna de mamíferos.',
    distintivos: ['Molares con esmalte plegado', 'Tres dedos (los laterales no tocan suelo)', 'Tamaño de poni'],
    dondeEncontrar: 'Mioceno superior de las Bardenas y Rioja Alavesa.',
    tituloWikipedia: 'Hipparion',
    ambientes: ['continental', 'fluvial', 'lacustre'],
  ),
  FosilGuia(
    id: 'mastodon',
    nombre: 'Mastodon (proboscídeo fósil)',
    grupo: 'Mammalia – Proboscidea',
    periodoId: 'oligoceno-mioceno',
    descripcionCorta: 'Pariente extinto de los elefantes, con molares de cúspides cónicas.',
    distintivos: ['Molares con cúspides redondeadas en pares', 'Defensas largas y curvadas', 'Tamaño elefantino'],
    dondeEncontrar: 'Yacimientos del Mioceno medio-superior del Ebro y Bardenas.',
    // El título 'Mastodon' en es.wikipedia es la banda de metal —
    // el género taxonómico se redacta como 'Mammut'. La galería
    // estaba sacando fotos del grupo de música.
    tituloWikipedia: 'Mammut',
    ambientes: ['continental', 'fluvial', 'lacustre'],
  ),
  FosilGuia(
    id: 'aequipecten-opercularis',
    nombre: 'Aequipecten opercularis (volandeira)',
    grupo: 'Bivalvia – Pectinidae',
    periodoId: 'oligoceno-mioceno',
    descripcionCorta: 'Vieira de aguas frías, abundante en sedimentos costeros miocenos.',
    distintivos: ['Concha redondeada con orejas asimétricas', '15–22 costillas radiales', 'Tamaño 4–8 cm'],
    dondeEncontrar: 'Mioceno marino de Iparralde y depósitos costeros.',
    tituloWikipedia: 'Aequipecten_opercularis',
  ),
  FosilGuia(
    id: 'carcharodon-carcharias',
    nombre: 'Carcharodon (tiburón blanco fósil)',
    grupo: 'Chondrichthyes – Lamniformes',
    periodoId: 'oligoceno-mioceno',
    descripcionCorta: 'Tiburón blanco fósil; sus dientes triangulares serrados aparecen desde el Mioceno.',
    distintivos: ['Diente triangular grande (3–6 cm)', 'Bordes finamente serrados', 'Esmalte muy brillante'],
    dondeEncontrar: 'Mioceno marino del entorno costero.',
    tituloWikipedia: 'Carcharodon_carcharias',
  ),

  // ─── CUATERNARIO ────────────────────────────────────
  FosilGuia(
    id: 'oso-cavernas',
    nombre: 'Ursus spelaeus (oso de las cavernas)',
    grupo: 'Mammalia – Carnivora',
    periodoId: 'cuaternario',
    descripcionCorta: 'Oso pleistoceno extinto, herbívoro, abundante en cuevas vascas.',
    distintivos: ['Cráneo masivo, frente alta', 'Caninos pequeños', 'Molares anchos'],
    dondeEncontrar: 'Cuevas de Bizkaia (Santimamiñe, Arrikrutz), Aralar.',
    tituloWikipedia: 'Ursus_spelaeus',
    ambientes: ['continental'],
  ),
  FosilGuia(
    id: 'megaloceros',
    nombre: 'Megaloceros (ciervo gigante)',
    grupo: 'Mammalia – Cervidae',
    periodoId: 'cuaternario',
    descripcionCorta: 'Ciervo extinto con cuernos enormes (hasta 3,6 m).',
    distintivos: ['Astas palmeadas masivas', 'Hueso poroso', 'Tamaño grande'],
    dondeEncontrar: 'Hallazgos esporádicos en yacimientos de cuevas pleistocenas.',
    tituloWikipedia: 'Megaloceros',
    ambientes: ['continental'],
  ),
  FosilGuia(
    id: 'huesos-cuaternario',
    nombre: 'Huesos de fauna cuaternaria diversa',
    grupo: 'Mammalia',
    periodoId: 'cuaternario',
    descripcionCorta: 'Restos óseos en cuevas y abrigos: hiena, ciervo, cabra, lobo.',
    distintivos: ['Hueso poroso', 'Mineralización parcial', 'Frecuente en cuevas con sedimento rojizo'],
    dondeEncontrar: 'Cuevas kársticas de Bizkaia, Nafarroa e Iparralde.',
    tituloWikipedia: 'Mammuthus',
    ambientes: ['continental'],
  ),
  FosilGuia(
    id: 'glycymeris',
    nombre: 'Glycymeris (terraza marina)',
    grupo: 'Bivalvia',
    periodoId: 'cuaternario',
    descripcionCorta: 'Bivalvo común en terrazas marinas pleistocenas.',
    distintivos: ['Concha redondeada gruesa', 'Costillas radiales muy finas', 'Charnela con dientes en arco'],
    dondeEncontrar: 'Terrazas marinas pleistocenas de la costa de Bizkaia y Iparralde.',
    tituloWikipedia: 'Glycymeris',
  ),
  FosilGuia(
    id: 'mammuthus-primigenius',
    nombre: 'Mammuthus primigenius (mamut lanudo)',
    grupo: 'Mammalia – Proboscidea',
    periodoId: 'cuaternario',
    descripcionCorta: 'Mamut adaptado al frío del Pleistoceno superior, con largas defensas curvadas.',
    distintivos: ['Molares en placas paralelas de esmalte', 'Defensas curvadas en espiral', 'Hueso compacto pesado'],
    dondeEncontrar: 'Yacimientos pleistocenos de cuevas y depósitos kársticos.',
    tituloWikipedia: 'Mammuthus_primigenius',
    ambientes: ['continental'],
  ),
  FosilGuia(
    id: 'bison-priscus',
    nombre: 'Bison priscus (bisonte estepario)',
    grupo: 'Mammalia – Bovidae',
    periodoId: 'cuaternario',
    descripcionCorta: 'Bisonte de la estepa pleistocena, ancestro del bisonte europeo actual.',
    distintivos: ['Cuernos grandes proyectados lateralmente', 'Cráneo con frente ancha', 'Dientes molares hipsodontos'],
    dondeEncontrar: 'Cuevas con arte rupestre (Santimamiñe) y yacimientos kársticos.',
    tituloWikipedia: 'Bison_priscus',
    ambientes: ['continental'],
  ),
  FosilGuia(
    id: 'panthera-spelaea',
    nombre: 'Panthera spelaea (león de las cavernas)',
    grupo: 'Mammalia – Felidae',
    periodoId: 'cuaternario',
    descripcionCorta: 'León pleistoceno de gran tamaño que habitó las cavernas europeas.',
    distintivos: ['Cráneo grande con caninos cónicos', 'Mayor que el león actual', 'Restos en sedimentos de cueva'],
    dondeEncontrar: 'Hallazgos en cuevas pleistocenas (Aralar, Bizkaia).',
    tituloWikipedia: 'Panthera_spelaea',
    ambientes: ['continental'],
  ),
  FosilGuia(
    id: 'crocuta',
    nombre: 'Crocuta (hiena de las cavernas)',
    grupo: 'Mammalia – Carnivora',
    periodoId: 'cuaternario',
    descripcionCorta: 'Hiena pleistocena pariente de la moteada actual; sus marcas de mordisco son comunes en cuevas.',
    distintivos: ['Premolares masivos para romper hueso', 'Cráneo robusto', 'Coprolitos blancos en cuevas'],
    dondeEncontrar: 'Cuevas pleistocenas de Bizkaia y Aralar.',
    tituloWikipedia: 'Crocuta',
    ambientes: ['continental'],
  ),
  FosilGuia(
    id: 'coelodonta',
    nombre: 'Coelodonta (rinoceronte lanudo)',
    grupo: 'Mammalia – Rhinocerotidae',
    periodoId: 'cuaternario',
    descripcionCorta: 'Rinoceronte adaptado al frío pleistoceno, con doble cuerno.',
    distintivos: ['Molares de coronas altas', 'Vértebras y costillas masivas', 'A veces se conservan cuernos queratinizados'],
    dondeEncontrar: 'Yacimientos pleistocenos en cuevas vasco-cantábricas.',
    tituloWikipedia: 'Coelodonta',
    ambientes: ['continental'],
  ),
  FosilGuia(
    id: 'rangifer',
    nombre: 'Rangifer (reno)',
    grupo: 'Mammalia – Cervidae',
    periodoId: 'cuaternario',
    descripcionCorta: 'Cérvido del Pleistoceno superior, marcador climático frío.',
    distintivos: ['Astas ramificadas con palas', 'Dientes molares hipsodontos', 'Hueso compacto'],
    dondeEncontrar: 'Cuevas magdalenienses con fauna fría (Iparralde, Aralar).',
    tituloWikipedia: 'Rangifer',
    ambientes: ['continental'],
  ),
  FosilGuia(
    id: 'cervus',
    nombre: 'Cervus elaphus (ciervo común fósil)',
    grupo: 'Mammalia – Cervidae',
    periodoId: 'cuaternario',
    descripcionCorta: 'Ciervo común; muy abundante como resto óseo y de astas en cuevas.',
    distintivos: ['Astas ramificadas no palmeadas', 'Dientes molares en cresta', 'Hueso fresco poco mineralizado'],
    dondeEncontrar: 'Cuevas con fauna pleistocena y holocena en toda EH.',
    tituloWikipedia: 'Cervus',
    ambientes: ['continental'],
  ),
  FosilGuia(
    id: 'bos-primigenius',
    nombre: 'Bos primigenius (uro)',
    grupo: 'Mammalia – Bovidae',
    periodoId: 'cuaternario',
    descripcionCorta: 'Bóvido salvaje gigante extinto en el Holoceno; ancestro del ganado vacuno.',
    distintivos: ['Cuernos grandes en lira', 'Cráneo robusto', 'Dientes molares hipsodontos'],
    dondeEncontrar: 'Yacimientos del Pleistoceno final y Holoceno en cuevas.',
    tituloWikipedia: 'Bos_primigenius',
    ambientes: ['continental'],
  ),
  FosilGuia(
    id: 'capra-pyrenaica',
    nombre: 'Capra pyrenaica (sarrio/cabra)',
    grupo: 'Mammalia – Bovidae',
    periodoId: 'cuaternario',
    descripcionCorta: 'Cabra montés ibérica, abundante como resto en yacimientos pleistocenos.',
    distintivos: ['Cuernos curvados', 'Huesos esbeltos adaptados al monte', 'Dientes molares hipsodontos'],
    dondeEncontrar: 'Cuevas y abrigos del Pirineo navarro y montes vasco-cantábricos.',
    tituloWikipedia: 'Capra_pyrenaica',
    ambientes: ['continental'],
  ),
];

String _normalizar(String texto) {
  const acentos = 'áéíóúüñàèìòùâêîôûäëïö';
  const sinAcentos = 'aeiouunaeiouaeiouaeio';
  final mapa = <String, String>{};
  for (var i = 0; i < acentos.length; i++) {
    mapa[acentos[i]] = sinAcentos[i];
  }
  var resultado = texto.toLowerCase();
  mapa.forEach((k, v) => resultado = resultado.replaceAll(k, v));
  return resultado;
}

const _palabrasClavePorPeriodo = <(String, List<String>)>[
  ('cretacico-superior', ['cretacico superior', 'maastrichtiense', 'campaniense', 'santoniense', 'coniaciense', 'turoniense', 'cenomaniense', 'senoniense']),
  ('cretacico-inferior', ['cretacico inferior', 'urgoniano', 'urgon', 'aptiense', 'albiense', 'barremiense', 'hauteriviense', 'valanginiense', 'berriasiense', 'neocomiense']),
  ('paleoceno-eoceno', ['paleoceno', 'eoceno', 'daniense', 'thanetiense', 'ilerdiense', 'cuisiense', 'luteciense', 'bartoniense', 'priaboniense', 'ypresiense']),
  ('oligoceno-mioceno', ['oligoceno', 'mioceno', 'rupeliense', 'chatiense', 'aquitaniense', 'burdigaliense', 'langhiense', 'serravaliense', 'tortoniense', 'messiniense', 'agenian', 'ageniense', 'rambliense', 'aragoniense', 'vallesiense', 'turoliense']),
  ('jurasico', ['jurasico', 'lias ', 'liasico', 'dogger', 'malm', 'hettangiense', 'sinemuriense', 'pliensbachiense', 'toarciense', 'aaleniense', 'bajociense', 'bathoniense', 'caloviense', 'oxfordiense', 'kimmeridgiense', 'tithoniense', 'portlandiense']),
  ('triasico', ['triasico', 'muschelkalk', 'keuper', 'buntsandstein', 'anisiense', 'ladiniense', 'carniense', 'noriense', 'rhaetiense']),
  ('cuaternario', ['cuaternario', 'holoceno', 'pleistoceno', 'plioceno', 'rusciniense', 'villafranquiense', 'villafranchiense', 'gelasiense', 'calabriense']),
  ('cretacico-superior', ['cretacico']),
];

String? inferirPeriodoDesdeEdad(String? edad) {
  if (edad == null || edad.trim().isEmpty) return null;
  final norm = _normalizar(edad);
  for (final (periodoId, palabras) in _palabrasClavePorPeriodo) {
    if (palabras.any((p) => norm.contains(p))) return periodoId;
  }
  return null;
}

PeriodoGeologico? buscarPeriodo(String id) {
  for (final p in periodos) {
    if (p.id == id) return p;
  }
  return null;
}

List<FosilGuia> fosilesPorPeriodo(String periodoId) =>
    fosilesGuia.where((f) => f.periodoId == periodoId).toList();

/// Devuelve la lista de ambientes sedimentarios plausibles para una
/// litología dada, en castellano y minúsculas (normalizado).
///
/// Si la litología es ígnea o metamórfica, devuelve `[]` para indicar
/// que **no hay ambiente sedimentario** y por tanto no debe sugerirse
/// ningún fósil.
///
/// Si no se reconoce, también devuelve `[]` (no se asume): es mejor
/// callar que sugerir ammonites en un granito.
List<String> ambientesProbablesPorLitologia(String? litologia) {
  if (litologia == null) return const [];
  final textoNormalizado = _normalizar(litologia.trim());
  if (textoNormalizado.isEmpty) return const [];

  // Rocas ígneas y metamórficas: sin ambiente sedimentario → sin fósiles.
  const palabrasIgneasMetamorficas = [
    'granito',
    'granitoide',
    'gneis',
    'esquisto',
    'pizarra',
    'basalto',
    'andesita',
    'riolita',
    'dacita',
    'traquita',
    'gabro',
    'diorita',
    'monzonita',
    'sienita',
    'diabasa',
    'ofita',
    'peridotit', // peridotita
    'serpentinit',
    'marmol',
    'cuarcita',
    'migmatit',
    'corneana',
    'anfibolit',
    'eclogit',
  ];
  for (final palabra in palabrasIgneasMetamorficas) {
    if (textoNormalizado.contains(palabra)) return const [];
  }

  // Evaporitas: lagunas marinas restringidas o lagos endorreicos.
  const palabrasEvaporiticas = ['evaporita', 'yeso', 'halita', 'sal '];
  if (textoNormalizado.contains('evaporita') ||
      textoNormalizado.endsWith(' sal') ||
      palabrasEvaporiticas.any((p) => textoNormalizado.contains(p))) {
    return const ['marino', 'lacustre'];
  }

  // Arenas eólicas / dunares.
  if (textoNormalizado.contains('duna') ||
      textoNormalizado.contains('eolic')) {
    return const ['eolico'];
  }

  // Aluviales y fluviales explícitos.
  if (textoNormalizado.contains('aluvi') ||
      textoNormalizado.contains('fluvial') ||
      textoNormalizado.contains('gravas de rio') ||
      textoNormalizado.contains('gravas fluvi') ||
      textoNormalizado.contains('terraza fluvi')) {
    return const ['fluvial', 'continental'];
  }

  // Turbas, lacustres, lignitos.
  if (textoNormalizado.contains('turba') ||
      textoNormalizado.contains('lacustre') ||
      textoNormalizado.contains('lignito')) {
    return const ['lacustre', 'continental'];
  }

  // Carbonatos marinos: caliza, marga, dolomía sedimentaria, calcarenita, creta.
  // Importante: 'dolomita' como mineral en filón no implica ambiente
  // marino, pero 'dolomia' como roca sí.
  const palabrasMarinasCarbonaticas = [
    'caliza',
    'marga',
    'calcarenit',
    'creta',
    'dolomia',
    'calcilutit',
    'biocalcarenit',
    'biomicrit',
    'wackestone',
    'packstone',
    'grainstone',
    'mudstone calc',
  ];
  if (palabrasMarinasCarbonaticas.any((p) => textoNormalizado.contains(p))) {
    return const ['marino'];
  }

  // Areniscas, lutitas, limolitas sin pista de medio: ambiguo entre
  // marino somero y continental.
  const palabrasSiliciclasticasAmbiguas = [
    'arenisca',
    'lutita',
    'limolita',
    'conglomerado',
    'arcilla',
  ];
  if (palabrasSiliciclasticasAmbiguas.any((p) => textoNormalizado.contains(p))) {
    return const ['marino', 'continental'];
  }

  // No se reconoce: no asumimos.
  return const [];
}

/// Devuelve los fósiles plausibles para un período dado filtrando por
/// los ambientes sedimentarios indicados. Si `ambientes` viene vacía,
/// devuelve `[]` (caso típico: roca ígnea o metamórfica).
List<FosilGuia> fosilesPorPeriodoYAmbiente(
    String periodoId, List<String> ambientes) {
  if (ambientes.isEmpty) return const [];
  return fosilesGuia.where((f) {
    if (f.periodoId != periodoId) return false;
    return f.ambientes.any((a) => ambientes.contains(a));
  }).toList();
}

FosilGuia? buscarFosilPorId(String id) {
  for (final f in fosilesGuia) {
    if (f.id == id) return f;
  }
  return null;
}

void abrirDetalleFosilGuia(BuildContext context, String idFosil,
    {List<FosilGuia>? lista, int? indiceInicial}) {
  if (lista != null && lista.isNotEmpty && indiceInicial != null) {
    _abrirFichaFosilNavegable(context, lista, indiceInicial);
    return;
  }
  final fosil = buscarFosilPorId(idFosil);
  if (fosil == null) return;
  _mostrarFichaFosil(context, fosil);
}

void _mostrarFichaFosil(BuildContext context, FosilGuia fosil) {
  final periodo = buscarPeriodo(fosil.periodoId);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        child: _contenidoFosil(context, fosil, periodo),
      ),
    ),
  );
}

void _abrirFichaFosilNavegable(BuildContext context, List<FosilGuia> lista, int indiceInicial) {
  final controladorPagina = PageController(initialPage: indiceInicial);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (_, setStateLocal) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, scrollController) => Column(
          children: [
            if (lista.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('${indiceInicial + 1} / ${lista.length}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black54)),
              ),
            Expanded(
              child: PageView.builder(
                controller: controladorPagina,
                itemCount: lista.length,
                onPageChanged: (i) => setStateLocal(() => indiceInicial = i),
                itemBuilder: (_, i) {
                  final f = lista[i];
                  final p = buscarPeriodo(f.periodoId);
                  return SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    child: _contenidoFosil(context, f, p),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _contenidoFosil(BuildContext context, FosilGuia fosil, PeriodoGeologico? periodo) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _GaleriaFosilWikipedia(tituloWikipedia: fosil.tituloWikipedia),
      const SizedBox(height: 12),
      Text(fosil.nombre, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 4),
      Wrap(
        spacing: 8,
        children: [
          Text(fosil.grupo, style: Theme.of(context).textTheme.bodySmall),
          if (periodo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: periodo.color, borderRadius: BorderRadius.circular(4)),
              child: Text(periodo.nombre, style: const TextStyle(color: Color(0xFF2D3A2E), fontSize: 12)),
            ),
        ],
      ),
      const SizedBox(height: 12),
      Text(fosil.descripcionCorta),
      const SizedBox(height: 16),
      Text('Distintivos para reconocerlo', style: Theme.of(context).textTheme.titleSmall),
      ...fosil.distintivos.map((d) => Padding(padding: const EdgeInsets.only(left: 8, top: 2), child: Text('• $d'))),
      const SizedBox(height: 16),
      Text('Dónde encontrarlo', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 4),
      Text(fosil.dondeEncontrar),
      const SizedBox(height: 16),
      FutureBuilder<ResumenWikipedia?>(
        future: obtenerResumenWikipedia(fosil.tituloWikipedia),
        builder: (context, snapshot) {
          final extracto = snapshot.data?.extracto;
          final enlace = snapshot.data?.enlacePagina;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (extracto != null)
                Text(extracto, style: const TextStyle(fontSize: 13, color: Colors.black54)),
              if (enlace != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Center(
                    child: OutlinedButton.icon(
                      onPressed: () => launchUrl(Uri.parse(enlace), mode: LaunchMode.externalApplication),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Leer más en Wikipedia'),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );
}

class _GaleriaFosilWikipedia extends StatefulWidget {
  final String tituloWikipedia;
  const _GaleriaFosilWikipedia({required this.tituloWikipedia});
  @override
  State<_GaleriaFosilWikipedia> createState() => _GaleriaFosilWikipediaState();
}

class _GaleriaFosilWikipediaState extends State<_GaleriaFosilWikipedia> {
  late final PageController _controlador = PageController();
  late Future<List<String>> _futuroGaleria;
  int _indiceActual = 0;

  @override
  void initState() {
    super.initState();
    // Resolver el future UNA SOLA VEZ en initState. Antes vivía dentro
    // del build del FutureBuilder, así que cada setState (cambio de
    // página) volvía a pedir las URLs y el FutureBuilder podía pasar
    // por ConnectionState.waiting → spinner: el slider parpadeaba al
    // deslizar.
    _futuroGaleria = obtenerGaleriaWikipedia(widget.tituloWikipedia);
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _futuroGaleria,
      builder: (context, snapshot) {
        final urls = snapshot.data ?? const <String>[];
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 240,
            alignment: Alignment.center,
            color: Colors.black12,
            child: const CircularProgressIndicator(),
          );
        }
        if (urls.isEmpty) {
          return Container(
            height: 200,
            alignment: Alignment.center,
            color: Colors.black12,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🦴', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => setState(() {
                    _futuroGaleria = obtenerGaleriaWikipedia(widget.tituloWikipedia);
                  }),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 260,
                child: Stack(
                  children: [
                    PageView.builder(
                      controller: _controlador,
                      itemCount: urls.length,
                      onPageChanged: (i) => setState(() => _indiceActual = i),
                      itemBuilder: (_, i) => CachedNetworkImage(
                        imageUrl: urls[i],
                        fit: BoxFit.cover,
                        httpHeaders: cabecerasImagenWiki,
                        memCacheWidth: 1200,
                        fadeInDuration: const Duration(milliseconds: 150),
                        placeholder: (_, __) => Container(
                          color: Colors.black12,
                          alignment: Alignment.center,
                          child: const CircularProgressIndicator(),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: Colors.black12,
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image, size: 48, color: Colors.white70),
                        ),
                      ),
                    ),
                    if (urls.length > 1)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_indiceActual + 1} / ${urls.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (urls.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(urls.length, (i) {
                    final activo = i == _indiceActual;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: activo ? 10 : 6,
                      height: activo ? 10 : 6,
                      decoration: BoxDecoration(
                        color: activo ? Colors.black87 : Colors.black26,
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                ),
              ),
          ],
        );
      },
    );
  }
}
