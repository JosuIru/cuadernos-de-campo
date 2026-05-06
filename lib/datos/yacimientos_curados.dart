class YacimientoCurado {
  final String id;
  final String nombre;
  final double latitud;
  final double longitud;
  final String periodoId;
  final String tituloEdad;
  final String descripcionCorta;
  final List<String> queBuscar;
  final String comoLlegar;
  final String emoji;
  final List<String> referencias;
  const YacimientoCurado({
    required this.id,
    required this.nombre,
    required this.latitud,
    required this.longitud,
    required this.periodoId,
    required this.tituloEdad,
    required this.descripcionCorta,
    required this.queBuscar,
    required this.comoLlegar,
    this.emoji = '🌋',
    this.referencias = const [],
  });
}

const List<YacimientoCurado> yacimientosCurados = [
  YacimientoCurado(
    id: 'zumaia-itzurun',
    nombre: 'Itzurun (Zumaia) — Flysch K-Pg',
    latitud: 43.301,
    longitud: -2.262,
    periodoId: 'cretacico-superior',
    tituloEdad: 'Maastrichtiense – Daniense (límite K-Pg)',
    descripcionCorta:
        'Sección continua del Cretácico Superior al Eoceno con el límite K-Pg expuesto en la playa. Bandas claras y oscuras de margocalizas y limolitas.',
    queBuscar: [
      'Foraminíferos planctónicos en margas',
      'Capa rojiza milimétrica del límite K-Pg (Ir)',
      'Inocerámidos y ammonites desplazados en bloques',
      'Trazas de Zoophycos y Chondrites',
    ],
    comoLlegar:
        'Playa de Itzurun, Zumaia. Acceso peatonal desde el centro. Mejor con marea baja.',
    emoji: '🌊',
    referencias: ['Geoparkea Costa Vasca · UNESCO Global Geopark'],
  ),
  YacimientoCurado(
    id: 'zumaia-sakoneta',
    nombre: 'Sakoneta (Deba)',
    latitud: 43.296,
    longitud: -2.343,
    periodoId: 'cretacico-superior',
    tituloEdad: 'Cretácico Superior – Eoceno',
    descripcionCorta:
        'Plataforma de abrasión con flysch espectacular. Continuación natural del flysch de Zumaia hacia el oeste.',
    queBuscar: [
      'Capas verticales en abanico',
      'Foraminíferos en margas',
      'Estructuras de turbidita (granoclasificación)',
    ],
    comoLlegar: 'Aparcamiento alto sobre Sakoneta y bajada a pie. Marea baja imprescindible.',
    emoji: '🌊',
  ),
  YacimientoCurado(
    id: 'sopelana-acantilados',
    nombre: 'Acantilados de Sopelana',
    latitud: 43.396,
    longitud: -2.985,
    periodoId: 'cretacico-superior',
    tituloEdad: 'Maastrichtiense',
    descripcionCorta:
        'Acantilados con flysch y nivel del límite K-Pg expuesto. Buen sitio alternativo a Itzurun.',
    queBuscar: [
      'Capa K-Pg arcillosa rojiza',
      'Foraminíferos planctónicos',
      'Bioturbación en margas',
    ],
    comoLlegar: 'Playa de Atxabiribil/Arrietara, Sopelana. Acceso por escalera. Marea baja.',
    emoji: '🌊',
  ),
  YacimientoCurado(
    id: 'loiola-jurasico',
    nombre: 'Loiola (Donostia) — Liásico',
    latitud: 43.291,
    longitud: -1.970,
    periodoId: 'jurasico',
    tituloEdad: 'Toarciense (Lías superior)',
    descripcionCorta:
        'Margas y calizas del Toarciense con ammonites locales. Clásico de la geología vasca.',
    queBuscar: [
      'Hildoceras, Harpoceras, Dactylioceras',
      'Belemnites en margas',
      'Pequeños bivalvos pelágicos',
    ],
    comoLlegar: 'Cortes en cuneta de la N-I y caminos del barrio de Loiola.',
  ),
  YacimientoCurado(
    id: 'cuevas-rojas-ozaeta',
    nombre: 'Sierra de Aralar — Calizas urgonianas',
    latitud: 43.020,
    longitud: -2.200,
    periodoId: 'cretacico-inferior',
    tituloEdad: 'Aptiense – Albiense (Urgoniano)',
    descripcionCorta:
        'Calizas masivas urgonianas con rudistas y corales. Forman las cumbres de Aralar.',
    queBuscar: [
      'Rudistas (Toucasia, Requienia)',
      'Orbitolinas',
      'Corales coloniales',
    ],
    comoLlegar: 'Senderos hacia Txindoki, Larrunarri y caminos de cumbre.',
    emoji: '⛰️',
  ),
  YacimientoCurado(
    id: 'salinas-anyana',
    nombre: 'Salinas de Añana — Diapiro triásico',
    latitud: 42.806,
    longitud: -2.984,
    periodoId: 'triasico',
    tituloEdad: 'Triásico (Keuper)',
    descripcionCorta:
        'Diapiro de materiales triásicos del Keuper que aflora en superficie. Yesos, halita y ofitas.',
    queBuscar: [
      'Yeso fibroso (selenita)',
      'Cristales de halita',
      'Arcillas rojas y verdes características',
      'Ofitas (rocas ígneas asociadas)',
    ],
    comoLlegar: 'Salinas de Añana, Araba. Visita guiada al valle salado.',
    emoji: '🧂',
  ),
  YacimientoCurado(
    id: 'praileaitz',
    nombre: 'Praileaitz (Deba) — Cueva paleolítica',
    latitud: 43.277,
    longitud: -2.341,
    periodoId: 'cuaternario',
    tituloEdad: 'Paleolítico superior',
    descripcionCorta:
        'Cueva con ocupación gravetiense-magdaleniense y arte mueble. Yacimiento arqueológico de primera magnitud.',
    queBuscar: [
      'Restos de fauna pleistocena en niveles',
      'Cantos pintados',
      'Industria lítica',
    ],
    comoLlegar: 'Acceso restringido. Información en el Geoparkea de la Costa Vasca.',
    emoji: '🏺',
  ),
  YacimientoCurado(
    id: 'ekain',
    nombre: 'Ekain (Zestoa) — Cueva con arte',
    latitud: 43.245,
    longitud: -2.252,
    periodoId: 'cuaternario',
    tituloEdad: 'Magdaleniense (~14.000 años)',
    descripcionCorta:
        'Cueva con uno de los conjuntos de arte rupestre más bellos de Iberia. Caballos, bisontes, ciervos.',
    queBuscar: [
      'Visita la réplica Ekainberri (la cueva original está cerrada)',
      'Estratigrafía de fauna pleistocena',
    ],
    comoLlegar: 'Ekainberri, Zestoa. Visita guiada.',
    emoji: '🏺',
  ),
  YacimientoCurado(
    id: 'estella-eoceno',
    nombre: 'Cuenca de Estella — Eoceno marino',
    latitud: 42.671,
    longitud: -2.030,
    periodoId: 'paleoceno-eoceno',
    tituloEdad: 'Luteciense – Bartoniense',
    descripcionCorta:
        'Margas y calizas eocenas con abundantes foraminíferos bentónicos grandes (Nummulites).',
    queBuscar: [
      'Nummulites (monedas de los discos)',
      'Assilinas',
      'Equinodermos',
    ],
    comoLlegar: 'Cortes de carretera en torno a Estella y Lizarra.',
    emoji: '💰',
  ),
  YacimientoCurado(
    id: 'bardenas-mioceno',
    nombre: 'Bardenas Reales — Mioceno continental',
    latitud: 42.180,
    longitud: -1.430,
    periodoId: 'oligoceno-mioceno',
    tituloEdad: 'Mioceno (Aragoniense)',
    descripcionCorta:
        'Series continentales del Mioceno con yesos, arcillas y areniscas. Ocasionales mamíferos fósiles.',
    queBuscar: [
      'Yesos en bandeo',
      'Concreciones carbonáticas (paleosuelos)',
      'Excepcionalmente, restos de mamíferos miocenos',
    ],
    comoLlegar: 'Parque Natural de las Bardenas Reales, Navarra. Múltiples accesos.',
    emoji: '🏜️',
  ),
  YacimientoCurado(
    id: 'arantzazu-urgoniano',
    nombre: 'Arantzazu (Aizkorri) — Urgoniano',
    latitud: 43.000,
    longitud: -2.391,
    periodoId: 'cretacico-inferior',
    tituloEdad: 'Aptiense superior – Albiense inferior',
    descripcionCorta:
        'Calizas urgonianas masivas que forman la sierra de Aizkorri. Plataforma carbonatada con rudistas.',
    queBuscar: [
      'Toucasia, Requienia (rudistas)',
      'Corales y briozoos',
      'Orbitolinas en calizas margosas',
    ],
    comoLlegar: 'Santuario de Arantzazu, Oñati. Senderos de Aizkorri-Aratz.',
    emoji: '⛰️',
  ),
];
