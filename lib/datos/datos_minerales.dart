import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' show launchUrl, LaunchMode;
import '../servicios/servicio_wikipedia.dart';

class ClaseMineralStrunz {
  final String id;
  final String nombre;
  final String descripcion;
  final Color color;
  const ClaseMineralStrunz({required this.id, required this.nombre, required this.descripcion, required this.color});
}

class MineralGuia {
  final String id;
  final String nombre;
  final String formulaQuimica;
  final String claseStrunzId;
  final String durezaMohs; // p.ej. "6 – 7"
  final String raya;
  final String brillo;
  final String colorTipico;
  final String descripcionCorta;
  final List<String> distintivos;
  final String dondeEncontrar;
  final String tituloWikipedia;
  const MineralGuia({
    required this.id,
    required this.nombre,
    required this.formulaQuimica,
    required this.claseStrunzId,
    required this.durezaMohs,
    required this.raya,
    required this.brillo,
    required this.colorTipico,
    required this.descripcionCorta,
    required this.distintivos,
    required this.dondeEncontrar,
    required this.tituloWikipedia,
  });
}

const List<ClaseMineralStrunz> clasesMinerales = [
  ClaseMineralStrunz(id: 'elementos', nombre: 'Elementos nativos', descripcion: 'Metales y no metales en estado puro.', color: Color(0xFFFFD700)),
  ClaseMineralStrunz(id: 'sulfuros', nombre: 'Sulfuros y sulfosales', descripcion: 'Combinaciones con azufre. Pirita, galena, esfalerita…', color: Color(0xFFB8B8B8)),
  ClaseMineralStrunz(id: 'halogenuros', nombre: 'Halogenuros', descripcion: 'Sales de cloro, flúor, etc. Halita, fluorita…', color: Color(0xFF87CEEB)),
  ClaseMineralStrunz(id: 'oxidos', nombre: 'Óxidos e hidróxidos', descripcion: 'Oxígeno o hidroxilo. Hematites, magnetita, cuarzo…', color: Color(0xFFCD5C5C)),
  ClaseMineralStrunz(id: 'carbonatos', nombre: 'Carbonatos y nitratos', descripcion: 'Calcita, aragonito, dolomita, malaquita…', color: Color(0xFFE6E6FA)),
  ClaseMineralStrunz(id: 'sulfatos', nombre: 'Sulfatos', descripcion: 'Yeso, baritina, celestina, anhidrita…', color: Color(0xFFFFE4B5)),
  ClaseMineralStrunz(id: 'fosfatos', nombre: 'Fosfatos y arseniatos', descripcion: 'Apatito y otros.', color: Color(0xFFDDA0DD)),
  ClaseMineralStrunz(id: 'silicatos', nombre: 'Silicatos', descripcion: 'La mayor familia: cuarzo, feldespatos, micas, granates…', color: Color(0xFF98D8C8)),
];

const List<MineralGuia> mineralesGuia = [
  // ─── ELEMENTOS NATIVOS ─────────────────────────────────────
  MineralGuia(
    id: 'azufre',
    nombre: 'Azufre nativo',
    formulaQuimica: 'S',
    claseStrunzId: 'elementos',
    durezaMohs: '1,5 – 2,5',
    raya: 'Blanca',
    brillo: 'Resinoso',
    colorTipico: 'Amarillo limón a amarillo verdoso',
    descripcionCorta: 'Azufre puro, asociado a yacimientos volcánicos y de evaporitas.',
    distintivos: ['Color amarillo intenso', 'Olor a azufre al frotarlo', 'Quebradizo, baja dureza'],
    dondeEncontrar: 'Diapiros y rocas evaporíticas (Salinas de Añana). Volcánicos.',
    tituloWikipedia: 'Azufre',
  ),
  MineralGuia(
    id: 'grafito',
    nombre: 'Grafito',
    formulaQuimica: 'C',
    claseStrunzId: 'elementos',
    durezaMohs: '1 – 2',
    raya: 'Negra brillante',
    brillo: 'Metálico mate',
    colorTipico: 'Gris a negro',
    descripcionCorta: 'Carbono cristalizado, blando y untuoso al tacto.',
    distintivos: ['Mancha los dedos al tocarlo', 'Hojas exfoliables', 'Conduce electricidad'],
    dondeEncontrar: 'Esquistos y mármoles metamórficos.',
    tituloWikipedia: 'Grafito',
  ),
  MineralGuia(
    id: 'cobre-nativo',
    nombre: 'Cobre nativo',
    formulaQuimica: 'Cu',
    claseStrunzId: 'elementos',
    durezaMohs: '2,5 – 3',
    raya: 'Roja cobriza',
    brillo: 'Metálico',
    colorTipico: 'Rojo cobre, oxidado a verde',
    descripcionCorta: 'Cobre en estado puro, raro pero llamativo.',
    distintivos: ['Color rojo cobre brillante recién partido', 'Maleable', 'Pesado'],
    dondeEncontrar: 'Vetas hidrotermales y zonas oxidadas de yacimientos de cobre.',
    tituloWikipedia: 'Cobre',
  ),
  MineralGuia(
    id: 'oro-nativo',
    nombre: 'Oro nativo',
    formulaQuimica: 'Au',
    claseStrunzId: 'elementos',
    durezaMohs: '2,5 – 3',
    raya: 'Amarilla',
    brillo: 'Metálico',
    colorTipico: 'Amarillo dorado',
    descripcionCorta: 'Oro elemental; pepitas en placeres aluviales y filones.',
    distintivos: ['Color y brillo inconfundible', 'Muy denso (19,3 g/cm³)', 'Maleable, no se oxida'],
    dondeEncontrar: 'Placeres aluviales (ríos), filones de cuarzo aurífero.',
    tituloWikipedia: 'Oro',
  ),
  MineralGuia(
    id: 'plata-nativa',
    nombre: 'Plata nativa',
    formulaQuimica: 'Ag',
    claseStrunzId: 'elementos',
    durezaMohs: '2,5 – 3',
    raya: 'Plata blanca',
    brillo: 'Metálico',
    colorTipico: 'Blanco plateado, suele estar oscuro por sulfuración',
    descripcionCorta: 'Plata pura; en filones hidrotermales.',
    distintivos: ['Forma a menudo dendrítica', 'Maleable', 'Densidad alta'],
    dondeEncontrar: 'Filones hidrotermales asociados a galena/argentita.',
    tituloWikipedia: 'Plata',
  ),

  // ─── SULFUROS ─────────────────────────────────────────────
  MineralGuia(
    id: 'pirita',
    nombre: 'Pirita',
    formulaQuimica: 'FeS₂',
    claseStrunzId: 'sulfuros',
    durezaMohs: '6 – 6,5',
    raya: 'Negro verdoso',
    brillo: 'Metálico',
    colorTipico: 'Amarillo latón',
    descripcionCorta: 'El "oro de los tontos". Cubos perfectos, muy común en margas y ammonites piritizados.',
    distintivos: ['Cubos o piritoedros con caras estriadas', 'Brillo metálico amarillo', 'Más dura que el oro'],
    dondeEncontrar: 'Margas cretácicas; reemplazo de fósiles (ammonites, bivalvos).',
    tituloWikipedia: 'Pirita',
  ),
  MineralGuia(
    id: 'marcasita',
    nombre: 'Marcasita',
    formulaQuimica: 'FeS₂',
    claseStrunzId: 'sulfuros',
    durezaMohs: '6 – 6,5',
    raya: 'Negro verdoso',
    brillo: 'Metálico',
    colorTipico: 'Amarillo latón claro, con pátina iridiscente',
    descripcionCorta: 'Mismo polimorfo que la pirita pero con formas planas, en crestas de gallo.',
    distintivos: ['Suele formar agregados radiales', 'Inestable: se descompone con humedad', 'Más clara que la pirita'],
    dondeEncontrar: 'Margas y arcillas; concreciones en el flysch.',
    tituloWikipedia: 'Marcasita',
  ),
  MineralGuia(
    id: 'galena',
    nombre: 'Galena',
    formulaQuimica: 'PbS',
    claseStrunzId: 'sulfuros',
    durezaMohs: '2,5 – 3',
    raya: 'Gris plomo',
    brillo: 'Metálico',
    colorTipico: 'Gris plomo brillante',
    descripcionCorta: 'Principal mena del plomo. Cubos perfectos, muy densa.',
    distintivos: ['Cubos brillantes', 'Exfoliación cúbica perfecta', 'Muy pesada (7,5 g/cm³)'],
    dondeEncontrar: 'Antiguas minas de Reocín, Karrantza, Aralar.',
    tituloWikipedia: 'Galena',
  ),
  MineralGuia(
    id: 'esfalerita',
    nombre: 'Esfalerita (blenda)',
    formulaQuimica: 'ZnS',
    claseStrunzId: 'sulfuros',
    durezaMohs: '3,5 – 4',
    raya: 'Marrón claro',
    brillo: 'Resinoso a adamantino',
    colorTipico: 'Pardo, miel, negro',
    descripcionCorta: 'Mena del cinc, asociada típicamente a galena.',
    distintivos: ['Brillo resinoso característico', 'Tetraedros o masas', 'Frecuente con galena'],
    dondeEncontrar: 'Mineralizaciones tipo MVT en calizas; antiguas minas de Bizkaia y Cantabria.',
    tituloWikipedia: 'Esfalerita',
  ),
  MineralGuia(
    id: 'calcopirita',
    nombre: 'Calcopirita',
    formulaQuimica: 'CuFeS₂',
    claseStrunzId: 'sulfuros',
    durezaMohs: '3,5 – 4',
    raya: 'Negro verdoso',
    brillo: 'Metálico',
    colorTipico: 'Amarillo latón con pátina iridiscente',
    descripcionCorta: 'Principal mena del cobre. Suele estar más oscura que la pirita.',
    distintivos: ['Color amarillo más oscuro que pirita', 'Más blanda que pirita (raya con cuchillo)', 'Pátina azul-violeta tornasol'],
    dondeEncontrar: 'Filones hidrotermales y skarns.',
    tituloWikipedia: 'Calcopirita',
  ),

  // ─── HALOGENUROS ──────────────────────────────────────────
  MineralGuia(
    id: 'halita',
    nombre: 'Halita (sal de roca)',
    formulaQuimica: 'NaCl',
    claseStrunzId: 'halogenuros',
    durezaMohs: '2 – 2,5',
    raya: 'Blanca',
    brillo: 'Vítreo',
    colorTipico: 'Incoloro, blanco, rosa, naranja',
    descripcionCorta: 'Sal común. Cubos exfoliables, sabor salado característico.',
    distintivos: ['Sabor salado (¡prueba con la lengua!)', 'Exfoliación cúbica', 'Soluble en agua'],
    dondeEncontrar: 'Diapiros triásicos: Salinas de Añana, valle del Ebro.',
    tituloWikipedia: 'Halita',
  ),
  MineralGuia(
    id: 'fluorita',
    nombre: 'Fluorita',
    formulaQuimica: 'CaF₂',
    claseStrunzId: 'halogenuros',
    durezaMohs: '4',
    raya: 'Blanca',
    brillo: 'Vítreo',
    colorTipico: 'Verde, violeta, amarilla, azul, incolora',
    descripcionCorta: 'Cubos y octaedros muy llamativos. Fluorescente bajo UV.',
    distintivos: ['Cubos con vértices truncados', 'Fluorescencia violeta bajo UV', 'Colores vivos en zonas'],
    dondeEncontrar: 'Filones hidrotermales (Berbes en Asturias está cerca).',
    tituloWikipedia: 'Fluorita',
  ),

  // ─── ÓXIDOS E HIDRÓXIDOS ──────────────────────────────────
  MineralGuia(
    id: 'cuarzo',
    nombre: 'Cuarzo',
    formulaQuimica: 'SiO₂',
    claseStrunzId: 'oxidos',
    durezaMohs: '7',
    raya: 'Blanca',
    brillo: 'Vítreo',
    colorTipico: 'Incoloro, blanco lechoso, rosa, ahumado',
    descripcionCorta: 'El mineral más abundante en filones. Cristales hexagonales bipiramidados.',
    distintivos: ['Cristales hexagonales con punta piramidal', 'No se exfolia, fractura concoidea', 'Raya el vidrio'],
    dondeEncontrar: 'Filones en cualquier roca; geodas.',
    tituloWikipedia: 'Cuarzo',
  ),
  MineralGuia(
    id: 'amatista',
    nombre: 'Amatista',
    formulaQuimica: 'SiO₂',
    claseStrunzId: 'oxidos',
    durezaMohs: '7',
    raya: 'Blanca',
    brillo: 'Vítreo',
    colorTipico: 'Violeta a púrpura',
    descripcionCorta: 'Variedad violeta del cuarzo. Geodas y filones tardíos.',
    distintivos: ['Color violeta zonado', 'Cristales hexagonales', 'Geodas tapizadas'],
    dondeEncontrar: 'Geodas en basaltos y filones tardíos.',
    tituloWikipedia: 'Amatista',
  ),
  MineralGuia(
    id: 'citrino',
    nombre: 'Citrino',
    formulaQuimica: 'SiO₂',
    claseStrunzId: 'oxidos',
    durezaMohs: '7',
    raya: 'Blanca',
    brillo: 'Vítreo',
    colorTipico: 'Amarillo dorado a anaranjado',
    descripcionCorta: 'Variedad amarilla del cuarzo, natural o tratado térmicamente.',
    distintivos: ['Amarillo transparente', 'Cristales hexagonales', 'Frecuentemente confundido con topacio'],
    dondeEncontrar: 'Asociado a amatista, geodas.',
    tituloWikipedia: 'Citrino',
  ),
  MineralGuia(
    id: 'calcedonia',
    nombre: 'Calcedonia / Sílex',
    formulaQuimica: 'SiO₂',
    claseStrunzId: 'oxidos',
    durezaMohs: '6,5 – 7',
    raya: 'Blanca',
    brillo: 'Céreo a mate',
    colorTipico: 'Gris, marrón, rojizo, azul',
    descripcionCorta: 'Cuarzo microcristalino. Sílex de los nódulos en calizas urgonianas.',
    distintivos: ['Fractura concoidea (filo cortante)', 'Sin cristales visibles a ojo', 'Suena con metal al golpear'],
    dondeEncontrar: 'Nódulos en calizas urgonianas y eocenas.',
    tituloWikipedia: 'Calcedonia',
  ),
  MineralGuia(
    id: 'agata',
    nombre: 'Ágata',
    formulaQuimica: 'SiO₂',
    claseStrunzId: 'oxidos',
    durezaMohs: '6,5 – 7',
    raya: 'Blanca',
    brillo: 'Céreo a vítreo',
    colorTipico: 'Bandeado de grises, blancos, marrones, rojos',
    descripcionCorta: 'Calcedonia bandeada con franjas concéntricas, frecuente en geodas.',
    distintivos: ['Bandas concéntricas claras y oscuras', 'Pulido brillante', 'Geodas en basaltos'],
    dondeEncontrar: 'Geodas en rocas volcánicas y filones.',
    tituloWikipedia: 'Ágata',
  ),
  MineralGuia(
    id: 'jaspe',
    nombre: 'Jaspe',
    formulaQuimica: 'SiO₂',
    claseStrunzId: 'oxidos',
    durezaMohs: '6,5 – 7',
    raya: 'Blanca',
    brillo: 'Céreo, mate',
    colorTipico: 'Rojo, marrón, amarillo, verde',
    descripcionCorta: 'Calcedonia opaca con tinte por óxidos de hierro.',
    distintivos: ['Opaco', 'Color uniforme o moteado', 'Fractura concoidea'],
    dondeEncontrar: 'Filones, jaspes ferruginosos en zonas mineralizadas.',
    tituloWikipedia: 'Jaspe',
  ),
  MineralGuia(
    id: 'opalo',
    nombre: 'Ópalo',
    formulaQuimica: 'SiO₂·nH₂O',
    claseStrunzId: 'oxidos',
    durezaMohs: '5,5 – 6,5',
    raya: 'Blanca',
    brillo: 'Vítreo, perlado',
    colorTipico: 'Lechoso, azulado, naranja, juega de colores',
    descripcionCorta: 'Sílice amorfa hidratada. El precioso muestra "fuego" iridiscente.',
    distintivos: ['Aspecto lechoso o gelatinoso', 'Iridiscencia en variedades nobles', 'Más blando que cuarzo'],
    dondeEncontrar: 'Geodas, suelos silicificados, hot springs fósiles.',
    tituloWikipedia: 'Ópalo',
  ),
  MineralGuia(
    id: 'hematites',
    nombre: 'Hematites',
    formulaQuimica: 'Fe₂O₃',
    claseStrunzId: 'oxidos',
    durezaMohs: '5,5 – 6,5',
    raya: 'Roja sangre',
    brillo: 'Metálico a mate',
    colorTipico: 'Gris acerado a rojo oscuro',
    descripcionCorta: 'Mena principal del hierro. La "vena de hierro" histórica de Bizkaia.',
    distintivos: ['Raya rojo sangre inconfundible', 'Densidad alta', 'A veces forma de "riñones"'],
    dondeEncontrar: 'Antiguas minas de Bizkaia (Triano, Somorrostro), Cantabria.',
    tituloWikipedia: 'Hematites',
  ),
  MineralGuia(
    id: 'goethita',
    nombre: 'Goethita',
    formulaQuimica: 'FeOOH',
    claseStrunzId: 'oxidos',
    durezaMohs: '5 – 5,5',
    raya: 'Pardo amarillenta',
    brillo: 'Adamantino, sedoso',
    colorTipico: 'Marrón oscuro a negro',
    descripcionCorta: 'Hidróxido de hierro. Componente principal de la limonita.',
    distintivos: ['Raya pardo amarillenta', 'Forma fibrosa o botrioidal', 'Asociada a alteración de pirita'],
    dondeEncontrar: 'Zonas oxidadas de yacimientos de hierro.',
    tituloWikipedia: 'Goethita',
  ),
  MineralGuia(
    id: 'limonita',
    nombre: 'Limonita',
    formulaQuimica: 'FeO(OH)·nH₂O',
    claseStrunzId: 'oxidos',
    durezaMohs: '4 – 5,5',
    raya: 'Pardo amarillenta',
    brillo: 'Mate, terroso',
    colorTipico: 'Marrón a amarillo ocre',
    descripcionCorta: 'Mezcla amorfa de óxidos hidratados de hierro. Tiñe rocas y suelos.',
    distintivos: ['Color ocre característico', 'Mancha los dedos', 'Mezcla amorfa, no cristalina'],
    dondeEncontrar: 'Zonas oxidadas de cualquier yacimiento de hierro o pirita.',
    tituloWikipedia: 'Limonita',
  ),
  MineralGuia(
    id: 'magnetita',
    nombre: 'Magnetita',
    formulaQuimica: 'Fe₃O₄',
    claseStrunzId: 'oxidos',
    durezaMohs: '5,5 – 6,5',
    raya: 'Negra',
    brillo: 'Metálico submetálico',
    colorTipico: 'Negro',
    descripcionCorta: 'Óxido de hierro magnético. Atrae al imán.',
    distintivos: ['Magnética: atrae al imán', 'Octaedros frecuentes', 'Densa'],
    dondeEncontrar: 'Skarns, rocas básicas, placeres negros en arenas costeras.',
    tituloWikipedia: 'Magnetita',
  ),

  // ─── CARBONATOS ───────────────────────────────────────────
  MineralGuia(
    id: 'calcita',
    nombre: 'Calcita',
    formulaQuimica: 'CaCO₃',
    claseStrunzId: 'carbonatos',
    durezaMohs: '3',
    raya: 'Blanca',
    brillo: 'Vítreo',
    colorTipico: 'Incoloro, blanco, miel',
    descripcionCorta: 'Constituyente principal de las calizas. Reacciona con HCl.',
    distintivos: ['Efervescencia con HCl frío', 'Doble refracción ("calcita óptica")', 'Romboedros perfectos'],
    dondeEncontrar: 'Calizas, vetas en grietas, espeleotemas en cuevas.',
    tituloWikipedia: 'Calcita',
  ),
  MineralGuia(
    id: 'aragonito',
    nombre: 'Aragonito',
    formulaQuimica: 'CaCO₃',
    claseStrunzId: 'carbonatos',
    durezaMohs: '3,5 – 4',
    raya: 'Blanca',
    brillo: 'Vítreo, resinoso',
    colorTipico: 'Incoloro, blanco, naranja',
    descripcionCorta: 'Polimorfo de la calcita: ortorrómbico. Forma "flores de hierro" en cuevas.',
    distintivos: ['Cristales aciculares o pseudohexagonales', 'Reacciona con HCl', 'Más duro que calcita'],
    dondeEncontrar: 'Espeleotemas (excéntricas), nácar, fumarolas frías.',
    tituloWikipedia: 'Aragonito',
  ),
  MineralGuia(
    id: 'dolomita',
    nombre: 'Dolomita',
    formulaQuimica: 'CaMg(CO₃)₂',
    claseStrunzId: 'carbonatos',
    durezaMohs: '3,5 – 4',
    raya: 'Blanca',
    brillo: 'Vítreo, perlado',
    colorTipico: 'Blanco, rosado, marrón',
    descripcionCorta: 'Constituyente de las dolomías. Reacción débil con HCl frío (sí en caliente).',
    distintivos: ['Romboedros con caras curvas (en silla de montar)', 'Efervescencia lenta con HCl', 'A veces rosa por hierro'],
    dondeEncontrar: 'Dolomías, vetas en calizas modificadas.',
    tituloWikipedia: 'Dolomita',
  ),
  MineralGuia(
    id: 'siderita',
    nombre: 'Siderita',
    formulaQuimica: 'FeCO₃',
    claseStrunzId: 'carbonatos',
    durezaMohs: '3,5 – 4,5',
    raya: 'Blanca',
    brillo: 'Vítreo, perlado',
    colorTipico: 'Marrón, amarillo miel, gris',
    descripcionCorta: 'Carbonato de hierro. Romboedros de caras curvadas, color miel.',
    distintivos: ['Romboedros con caras curvas color miel', 'Densa para un carbonato', 'Se altera a goethita'],
    dondeEncontrar: 'Mena del hierro en yacimientos sedimentarios.',
    tituloWikipedia: 'Siderita',
  ),
  MineralGuia(
    id: 'malaquita',
    nombre: 'Malaquita',
    formulaQuimica: 'Cu₂(CO₃)(OH)₂',
    claseStrunzId: 'carbonatos',
    durezaMohs: '3,5 – 4',
    raya: 'Verde claro',
    brillo: 'Adamantino, sedoso',
    colorTipico: 'Verde intenso bandeado',
    descripcionCorta: 'Carbonato de cobre verde, forma costras y nódulos botrioidales bandeados.',
    distintivos: ['Verde brillante bandeado', 'Forma de "piel de oso"', 'Asociada a cobre y azurita'],
    dondeEncontrar: 'Zonas de oxidación de yacimientos de cobre.',
    tituloWikipedia: 'Malaquita',
  ),
  MineralGuia(
    id: 'azurita',
    nombre: 'Azurita',
    formulaQuimica: 'Cu₃(CO₃)₂(OH)₂',
    claseStrunzId: 'carbonatos',
    durezaMohs: '3,5 – 4',
    raya: 'Azul claro',
    brillo: 'Adamantino',
    colorTipico: 'Azul intenso',
    descripcionCorta: 'Carbonato de cobre azul. Suele encontrarse junto a malaquita.',
    distintivos: ['Azul intenso inconfundible', 'Cristales pseudo-prismáticos', 'Se transforma en malaquita'],
    dondeEncontrar: 'Zonas de oxidación de yacimientos de cobre.',
    tituloWikipedia: 'Azurita',
  ),

  // ─── SULFATOS ─────────────────────────────────────────────
  MineralGuia(
    id: 'yeso',
    nombre: 'Yeso',
    formulaQuimica: 'CaSO₄·2H₂O',
    claseStrunzId: 'sulfatos',
    durezaMohs: '2',
    raya: 'Blanca',
    brillo: 'Vítreo, sedoso, perlado',
    colorTipico: 'Incoloro, blanco, miel',
    descripcionCorta: 'Sulfato de calcio hidratado. Variedades: selenita (cristales), fibroso, alabastro.',
    distintivos: ['Se raya con la uña', 'Selenita transparente como vidrio', 'Cristales tabulares o lenticulares'],
    dondeEncontrar: 'Diapiros del Keuper (Rioja Alavesa, Maeztu, Estella).',
    tituloWikipedia: 'Yeso',
  ),
  MineralGuia(
    id: 'selenita',
    nombre: 'Selenita (yeso transparente)',
    formulaQuimica: 'CaSO₄·2H₂O',
    claseStrunzId: 'sulfatos',
    durezaMohs: '2',
    raya: 'Blanca',
    brillo: 'Vítreo',
    colorTipico: 'Incoloro, transparente',
    descripcionCorta: 'Variedad cristalina del yeso, en placas o lentes transparentes.',
    distintivos: ['Cristales tabulares grandes', 'Se exfolia en láminas finas', 'Muy blando, se raya con uña'],
    dondeEncontrar: 'Margas yesíferas del Keuper.',
    tituloWikipedia: 'Yeso',
  ),
  MineralGuia(
    id: 'baritina',
    nombre: 'Baritina',
    formulaQuimica: 'BaSO₄',
    claseStrunzId: 'sulfatos',
    durezaMohs: '3 – 3,5',
    raya: 'Blanca',
    brillo: 'Vítreo, perlado',
    colorTipico: 'Blanco, miel, azul, rosa',
    descripcionCorta: 'Sulfato de bario. Tabular, sorprendentemente densa.',
    distintivos: ['Muy pesada para su aspecto (4,5 g/cm³)', 'Cristales tabulares', 'A menudo "rosa del desierto"'],
    dondeEncontrar: 'Filones hidrotermales en Iparralde y Pirineos.',
    tituloWikipedia: 'Baritina',
  ),
  MineralGuia(
    id: 'celestina',
    nombre: 'Celestina',
    formulaQuimica: 'SrSO₄',
    claseStrunzId: 'sulfatos',
    durezaMohs: '3 – 3,5',
    raya: 'Blanca',
    brillo: 'Vítreo, perlado',
    colorTipico: 'Azul cielo, blanco, incoloro',
    descripcionCorta: 'Sulfato de estroncio. Geodas con cristales azules en margas yesíferas.',
    distintivos: ['Color azul cielo característico', 'Tabular o prismática', 'Llama roja'],
    dondeEncontrar: 'Margas yesíferas miocenas y triásicas.',
    tituloWikipedia: 'Celestina',
  ),
  MineralGuia(
    id: 'anhidrita',
    nombre: 'Anhidrita',
    formulaQuimica: 'CaSO₄',
    claseStrunzId: 'sulfatos',
    durezaMohs: '3 – 3,5',
    raya: 'Blanca',
    brillo: 'Vítreo, perlado',
    colorTipico: 'Blanco, gris, azulado',
    descripcionCorta: 'Sulfato de calcio sin agua. Pasa a yeso al hidratarse.',
    distintivos: ['Tres direcciones de exfoliación perpendiculares', 'Más dura que el yeso', 'Aspecto granular'],
    dondeEncontrar: 'Diapiros y series evaporíticas profundas.',
    tituloWikipedia: 'Anhidrita',
  ),

  // ─── FOSFATOS ─────────────────────────────────────────────
  MineralGuia(
    id: 'apatito',
    nombre: 'Apatito',
    formulaQuimica: 'Ca₅(PO₄)₃(F,Cl,OH)',
    claseStrunzId: 'fosfatos',
    durezaMohs: '5',
    raya: 'Blanca',
    brillo: 'Vítreo a resinoso',
    colorTipico: 'Verde, azul, marrón, amarillo, incoloro',
    descripcionCorta: 'Constituyente de huesos y dientes. Cristales hexagonales prismáticos.',
    distintivos: ['Cristales hexagonales prismáticos', 'Dureza 5 (raya el vidrio justo)', 'Color verde frecuente'],
    dondeEncontrar: 'Pegmatitas, fosforitas, restos óseos fósiles.',
    tituloWikipedia: 'Apatito',
  ),

  // ─── SILICATOS ────────────────────────────────────────────
  MineralGuia(
    id: 'olivino',
    nombre: 'Olivino',
    formulaQuimica: '(Mg,Fe)₂SiO₄',
    claseStrunzId: 'silicatos',
    durezaMohs: '6,5 – 7',
    raya: 'Blanca',
    brillo: 'Vítreo',
    colorTipico: 'Verde oliva',
    descripcionCorta: 'Mineral verde de rocas básicas. Variedad gema: peridoto.',
    distintivos: ['Verde oliva característico', 'Granos redondeados en basaltos', 'Sin exfoliación clara'],
    dondeEncontrar: 'Basaltos y peridotitas.',
    tituloWikipedia: 'Olivino',
  ),
  MineralGuia(
    id: 'granate',
    nombre: 'Granate',
    formulaQuimica: 'X₃Y₂(SiO₄)₃',
    claseStrunzId: 'silicatos',
    durezaMohs: '6,5 – 7,5',
    raya: 'Blanca',
    brillo: 'Vítreo a resinoso',
    colorTipico: 'Rojo (almandino), verde (uvarovita), naranja',
    descripcionCorta: 'Familia con muchas especies. Dodecaedros característicos en esquistos.',
    distintivos: ['Cristales dodecaédricos perfectos', 'Sin exfoliación clara', 'Duros'],
    dondeEncontrar: 'Esquistos metamórficos, gneis.',
    tituloWikipedia: 'Almandino',
  ),
  MineralGuia(
    id: 'feldespato-potasico',
    nombre: 'Feldespato potásico',
    formulaQuimica: 'KAlSi₃O₈',
    claseStrunzId: 'silicatos',
    durezaMohs: '6 – 6,5',
    raya: 'Blanca',
    brillo: 'Vítreo',
    colorTipico: 'Rosa salmón, blanco, rojizo',
    descripcionCorta: 'Constituyente principal de granitos. Ortoclasa y microclina.',
    distintivos: ['Color rosa salmón frecuente', 'Dos exfoliaciones perpendiculares', 'Duro: raya el vidrio'],
    dondeEncontrar: 'Granitos, pegmatitas.',
    tituloWikipedia: 'Feldespato',
  ),
  MineralGuia(
    id: 'plagioclasa',
    nombre: 'Plagioclasa',
    formulaQuimica: '(Na,Ca)(Si,Al)₄O₈',
    claseStrunzId: 'silicatos',
    durezaMohs: '6 – 6,5',
    raya: 'Blanca',
    brillo: 'Vítreo, perlado',
    colorTipico: 'Blanco a gris',
    descripcionCorta: 'Otro grupo de feldespatos: albita-anortita. Maclas polisintéticas.',
    distintivos: ['Estrías paralelas finas en una cara', 'Color blanco-gris', 'Maclas en cuerpos ígneos'],
    dondeEncontrar: 'Rocas ígneas (basaltos, gabros, granitos).',
    tituloWikipedia: 'Plagioclasa',
  ),
  MineralGuia(
    id: 'moscovita',
    nombre: 'Moscovita (mica blanca)',
    formulaQuimica: 'KAl₂(AlSi₃O₁₀)(OH)₂',
    claseStrunzId: 'silicatos',
    durezaMohs: '2,5 – 3',
    raya: 'Blanca',
    brillo: 'Perlado, sedoso',
    colorTipico: 'Incoloro a plateado',
    descripcionCorta: 'Mica clara, exfoliable en láminas finísimas casi transparentes.',
    distintivos: ['Exfoliación basal perfecta', 'Láminas elásticas', 'Brillo plateado'],
    dondeEncontrar: 'Esquistos, gneis, pegmatitas.',
    tituloWikipedia: 'Moscovita',
  ),
  MineralGuia(
    id: 'biotita',
    nombre: 'Biotita (mica negra)',
    formulaQuimica: 'K(Mg,Fe)₃(AlSi₃O₁₀)(OH)₂',
    claseStrunzId: 'silicatos',
    durezaMohs: '2,5 – 3',
    raya: 'Gris',
    brillo: 'Perlado a submetálico',
    colorTipico: 'Negro, marrón oscuro',
    descripcionCorta: 'Mica oscura. Mismas propiedades que moscovita pero rica en hierro.',
    distintivos: ['Láminas oscuras flexibles', 'Exfoliación perfecta', 'Frecuente en granitos'],
    dondeEncontrar: 'Granitos, esquistos, gneis.',
    tituloWikipedia: 'Biotita',
  ),
  MineralGuia(
    id: 'hornblenda',
    nombre: 'Hornblenda (anfíbol)',
    formulaQuimica: 'Ca₂(Mg,Fe,Al)₅(Si,Al)₈O₂₂(OH)₂',
    claseStrunzId: 'silicatos',
    durezaMohs: '5 – 6',
    raya: 'Blanca a gris pardusco',
    brillo: 'Vítreo',
    colorTipico: 'Negro a verde oscuro',
    descripcionCorta: 'Anfíbol más común. Cristales prismáticos largos en rocas ígneas.',
    distintivos: ['Cristales prismáticos negros', 'Exfoliación a 56°/124°', 'Diferente del piroxeno por ángulos'],
    dondeEncontrar: 'Granitos, dioritas, anfibolitas.',
    tituloWikipedia: 'Hornblenda',
  ),
  MineralGuia(
    id: 'augita',
    nombre: 'Augita (piroxeno)',
    formulaQuimica: '(Ca,Na)(Mg,Fe,Al)(Si,Al)₂O₆',
    claseStrunzId: 'silicatos',
    durezaMohs: '5 – 6,5',
    raya: 'Gris verdosa',
    brillo: 'Vítreo',
    colorTipico: 'Verde oscuro a negro',
    descripcionCorta: 'Piroxeno más común. Cristales cortos y prismáticos en basaltos.',
    distintivos: ['Cristales cortos', 'Exfoliación a 87°/93° (casi recto)', 'Tipica en basaltos'],
    dondeEncontrar: 'Basaltos, gabros, peridotitas.',
    tituloWikipedia: 'Augita',
  ),
  MineralGuia(
    id: 'talco',
    nombre: 'Talco',
    formulaQuimica: 'Mg₃Si₄O₁₀(OH)₂',
    claseStrunzId: 'silicatos',
    durezaMohs: '1',
    raya: 'Blanca',
    brillo: 'Perlado, graso',
    colorTipico: 'Verde pálido a blanco',
    descripcionCorta: 'El mineral más blando. Untuoso al tacto.',
    distintivos: ['Se raya con la uña fácilmente', 'Tacto jabonoso', 'Color verdoso pálido'],
    dondeEncontrar: 'Rocas ultramáficas alteradas.',
    tituloWikipedia: 'Talco',
  ),
  MineralGuia(
    id: 'caolinita',
    nombre: 'Caolinita',
    formulaQuimica: 'Al₂Si₂O₅(OH)₄',
    claseStrunzId: 'silicatos',
    durezaMohs: '2 – 2,5',
    raya: 'Blanca',
    brillo: 'Mate, terroso',
    colorTipico: 'Blanco, amarillento',
    descripcionCorta: 'Arcilla de alteración de feldespatos. Materia prima de la cerámica.',
    distintivos: ['Tacto plástico al humedecer', 'Color blanco a crema', 'Olor a barro'],
    dondeEncontrar: 'Suelos arcillosos, alteraciones de granito.',
    tituloWikipedia: 'Caolinita',
  ),
  MineralGuia(
    id: 'turmalina',
    nombre: 'Turmalina',
    formulaQuimica: 'XY₃Z₆(BO₃)₃Si₆O₁₈(OH)₄',
    claseStrunzId: 'silicatos',
    durezaMohs: '7 – 7,5',
    raya: 'Blanca',
    brillo: 'Vítreo',
    colorTipico: 'Negro (chorlo), verde, rosa, multicolor',
    descripcionCorta: 'Cristales prismáticos triangulares. Variedades de muchos colores.',
    distintivos: ['Sección triangular del prisma', 'Estrías longitudinales', 'Piroeléctrica'],
    dondeEncontrar: 'Pegmatitas, granitos, esquistos.',
    tituloWikipedia: 'Turmalina',
  ),
  MineralGuia(
    id: 'berilo',
    nombre: 'Berilo',
    formulaQuimica: 'Be₃Al₂Si₆O₁₈',
    claseStrunzId: 'silicatos',
    durezaMohs: '7,5 – 8',
    raya: 'Blanca',
    brillo: 'Vítreo',
    colorTipico: 'Verde (esmeralda), azul (aguamarina), amarillo, rosa',
    descripcionCorta: 'Mineral gema. Cristales hexagonales prismáticos.',
    distintivos: ['Prisma hexagonal alargado', 'Esmeralda y aguamarina son variedades', 'Duro'],
    dondeEncontrar: 'Pegmatitas graníticas.',
    tituloWikipedia: 'Berilo',
  ),
  MineralGuia(
    id: 'topacio',
    nombre: 'Topacio',
    formulaQuimica: 'Al₂SiO₄(F,OH)₂',
    claseStrunzId: 'silicatos',
    durezaMohs: '8',
    raya: 'Blanca',
    brillo: 'Vítreo',
    colorTipico: 'Incoloro, miel, azul, rosa',
    descripcionCorta: 'Gema clásica. Cristales prismáticos terminados en pirámide.',
    distintivos: ['Cristales prismáticos rómbicos', 'Exfoliación basal perfecta', 'Dureza 8'],
    dondeEncontrar: 'Pegmatitas y vetas hidrotermales.',
    tituloWikipedia: 'Topacio',
  ),
];

List<MineralGuia> mineralesPorClase(String claseId) =>
    mineralesGuia.where((m) => m.claseStrunzId == claseId).toList();

const Map<String, List<String>> _palabrasClavePorMineral = {
  'calcita': ['caliza', 'mármol', 'travertino', 'caliche', 'espeleotema', 'estalactita'],
  'dolomita': ['dolomía', 'dolomita', 'dolomitic'],
  'aragonito': ['caliza', 'travertino', 'estalactita', 'evaporita'],
  'siderita': ['hierro', 'criadero', 'siderita', 'mineralizacion'],
  'malaquita': ['cobre', 'oxidacion', 'mineralizacion'],
  'azurita': ['cobre', 'oxidacion', 'mineralizacion'],
  'pirita': ['marga', 'lutita', 'flysch', 'pizarra', 'arcilla', 'hidrotermal', 'mineralizacion'],
  'marcasita': ['marga', 'arcilla', 'flysch', 'lutita'],
  'galena': ['hidrotermal', 'mineralizacion', 'caliza', 'filon', 'plomo', 'criadero'],
  'esfalerita': ['hidrotermal', 'mineralizacion', 'caliza', 'filon', 'cinc', 'criadero'],
  'calcopirita': ['hidrotermal', 'filon', 'cobre', 'mineralizacion'],
  'halita': ['evaporita', 'keuper', 'diapiro', 'triasic', 'sal'],
  'fluorita': ['hidrotermal', 'filon', 'fluorita'],
  'cuarzo': ['filon', 'granito', 'pegmatita', 'arenisc', 'cuarzo', 'cuarcita', 'metamorfic', 'volcan'],
  'amatista': ['geoda', 'volcan', 'basalto', 'cuarzo'],
  'citrino': ['geoda', 'pegmatita', 'cuarzo'],
  'calcedonia': ['caliza', 'silex', 'nodulo', 'silice', 'cret'],
  'agata': ['geoda', 'basalto', 'volcan'],
  'jaspe': ['silice', 'silex', 'filon'],
  'opalo': ['hidrotermal', 'silice', 'volcan'],
  'hematites': ['hierro', 'criadero', 'mineralizacion'],
  'goethita': ['hierro', 'oxidacion', 'limonita'],
  'limonita': ['hierro', 'oxidacion', 'arcilla'],
  'magnetita': ['skarn', 'basalto', 'gabro', 'ultramafic', 'placer'],
  'yeso': ['evaporita', 'keuper', 'yeso', 'yesifera', 'diapiro', 'triasic'],
  'selenita': ['evaporita', 'keuper', 'yesifera'],
  'baritina': ['hidrotermal', 'filon', 'baritina'],
  'celestina': ['evaporita', 'yesifera', 'mioceno', 'triasic'],
  'anhidrita': ['evaporita', 'keuper', 'diapiro'],
  'apatito': ['pegmatita', 'fosfato', 'hueso', 'fosforita'],
  'olivino': ['basalto', 'gabro', 'peridotit', 'ultramafic', 'volcan'],
  'granate': ['esquist', 'gneis', 'metamorfic', 'pegmatita'],
  'feldespato-potasico': ['granito', 'pegmatita', 'igne'],
  'plagioclasa': ['basalto', 'gabro', 'granito', 'diorit', 'igne'],
  'moscovita': ['esquist', 'pegmatita', 'gneis', 'metamorfic'],
  'biotita': ['granito', 'esquist', 'gneis', 'metamorfic'],
  'hornblenda': ['granito', 'diorit', 'anfibolit'],
  'augita': ['basalto', 'gabro', 'peridotit', 'volcan'],
  'talco': ['ultramafic', 'serpentinit'],
  'caolinita': ['arcilla', 'alteracion', 'granito', 'caolin'],
  'turmalina': ['pegmatita', 'granito'],
  'berilo': ['pegmatita'],
  'topacio': ['pegmatita', 'hidrotermal'],
  'azufre': ['evaporita', 'volcan', 'diapiro'],
  'grafito': ['esquist', 'metamorfic', 'marmol'],
  'cobre-nativo': ['hidrotermal', 'filon', 'cobre'],
  'oro-nativo': ['hidrotermal', 'filon', 'placer', 'aurifer'],
  'plata-nativa': ['hidrotermal', 'filon', 'galena'],
};

String _normalizarTextoMineral(String texto) {
  return texto
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n');
}

List<MineralGuia> mineralesProbablesEnContexto({String? edad, String? formacion, String? litologia}) {
  final partes = [edad, formacion, litologia].whereType<String>().where((s) => s.isNotEmpty).join(' ');
  if (partes.isEmpty) return const [];
  final texto = _normalizarTextoMineral(partes);
  final encontrados = <MineralGuia>[];
  for (final m in mineralesGuia) {
    final palabras = _palabrasClavePorMineral[m.id] ?? const [];
    if (palabras.any((p) => texto.contains(_normalizarTextoMineral(p)))) {
      encontrados.add(m);
    }
  }
  return encontrados;
}

ClaseMineralStrunz? buscarClaseMineral(String id) {
  for (final c in clasesMinerales) {
    if (c.id == id) return c;
  }
  return null;
}

MineralGuia? buscarMineralPorId(String id) {
  for (final m in mineralesGuia) {
    if (m.id == id) return m;
  }
  return null;
}

void abrirDetalleMineral(BuildContext context, String idMineral) {
  final mineral = buscarMineralPorId(idMineral);
  if (mineral == null) return;
  final clase = buscarClaseMineral(mineral.claseStrunzId);
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GaleriaMineralWikipedia(tituloWikipedia: mineral.tituloWikipedia),
            const SizedBox(height: 12),
            Text(mineral.nombre, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Wrap(spacing: 8, children: [
              Text(mineral.formulaQuimica, style: const TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.bold)),
              if (clase != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: clase.color, borderRadius: BorderRadius.circular(4)),
                  child: Text(clase.nombre, style: const TextStyle(color: Color(0xFF2D3A2E), fontSize: 12)),
                ),
            ]),
            const SizedBox(height: 12),
            _filaPropiedad(context, 'Dureza Mohs', mineral.durezaMohs),
            _filaPropiedad(context, 'Raya', mineral.raya),
            _filaPropiedad(context, 'Brillo', mineral.brillo),
            _filaPropiedad(context, 'Color típico', mineral.colorTipico),
            const SizedBox(height: 12),
            Text(mineral.descripcionCorta),
            const SizedBox(height: 16),
            Text('Distintivos para reconocerlo', style: Theme.of(context).textTheme.titleSmall),
            ...mineral.distintivos.map((d) => Padding(padding: const EdgeInsets.only(left: 8, top: 2), child: Text('• $d'))),
            const SizedBox(height: 16),
            Text('Dónde encontrarlo', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(mineral.dondeEncontrar),
            const SizedBox(height: 16),
            FutureBuilder<ResumenWikipedia?>(
              future: obtenerResumenWikipedia(mineral.tituloWikipedia),
              builder: (context, snapshot) {
                final extracto = snapshot.data?.extracto;
                final enlace = snapshot.data?.enlacePagina;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (extracto != null) Text(extracto, style: const TextStyle(fontSize: 13)),
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
        ),
      ),
    ),
  );
}

Widget _filaPropiedad(BuildContext context, String clave, String valor) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(clave, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          Expanded(child: Text(valor, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );

class _GaleriaMineralWikipedia extends StatefulWidget {
  final String tituloWikipedia;
  const _GaleriaMineralWikipedia({required this.tituloWikipedia});
  @override
  State<_GaleriaMineralWikipedia> createState() => _GaleriaMineralWikipediaState();
}

class _GaleriaMineralWikipediaState extends State<_GaleriaMineralWikipedia> {
  late final PageController _controlador = PageController();
  int _indiceActual = 0;

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: obtenerGaleriaWikipedia(widget.tituloWikipedia),
      builder: (context, snapshot) {
        final urls = snapshot.data ?? const <String>[];
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(height: 240, alignment: Alignment.center, color: Colors.black12, child: const CircularProgressIndicator());
        }
        if (urls.isEmpty) {
          return Container(height: 200, alignment: Alignment.center, color: Colors.black12, child: const Text('💎', style: TextStyle(fontSize: 64)));
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
                      itemBuilder: (_, i) => Image.network(
                        urls[i],
                        fit: BoxFit.cover,
                        headers: cabecerasImagenWiki,
                        cacheWidth: 1200,
                        loadingBuilder: (_, child, p) => p == null ? child : Container(color: Colors.black12, alignment: Alignment.center, child: const CircularProgressIndicator()),
                        errorBuilder: (_, __, ___) => Container(color: Colors.black12, alignment: Alignment.center, child: const Icon(Icons.broken_image, size: 48, color: Colors.white70)),
                      ),
                    ),
                    if (urls.length > 1)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                          child: Text('${_indiceActual + 1} / ${urls.length}', style: const TextStyle(color: Colors.white, fontSize: 12)),
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
                      decoration: BoxDecoration(color: activo ? Colors.black87 : Colors.black26, shape: BoxShape.circle),
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
