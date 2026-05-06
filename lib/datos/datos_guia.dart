import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../servicios/servicio_inaturalist.dart';

class CategoriaGuia {
  final String id; // 'animal' | 'insecto' | 'planta'
  final String nombre;
  final IconData icono;
  final Color color;
  const CategoriaGuia({
    required this.id,
    required this.nombre,
    required this.icono,
    required this.color,
  });
}

class EspecieGuia {
  final String id;
  final String nombreCientifico;
  final String nombreComun;
  final String categoriaId;
  final String descripcionCorta;
  final List<String> distintivos;
  final String habitat;
  final String tituloWikipedia;
  const EspecieGuia({
    required this.id,
    required this.nombreCientifico,
    required this.nombreComun,
    required this.categoriaId,
    required this.descripcionCorta,
    required this.distintivos,
    required this.habitat,
    required this.tituloWikipedia,
  });
}

const List<CategoriaGuia> categoriasGuia = [
  CategoriaGuia(id: 'animal', nombre: 'Animales', icono: Icons.pets, color: Color(0xFF8B5A3C)),
  CategoriaGuia(id: 'insecto', nombre: 'Insectos y artrópodos', icono: Icons.bug_report, color: Color(0xFFB8860B)),
  CategoriaGuia(id: 'planta', nombre: 'Plantas', icono: Icons.local_florist, color: Color(0xFF5E7D3A)),
];

const List<EspecieGuia> especiesGuia = [
  // ─── Animales ───────────────────────────────────────────
  EspecieGuia(
    id: 'turdus-merula',
    nombreCientifico: 'Turdus merula',
    nombreComun: 'Mirlo común',
    categoriaId: 'animal',
    descripcionCorta: 'Ave passeriforme negra (macho) o pardo oscuro (hembra), con pico naranja amarillento.',
    distintivos: ['Pico naranja', 'Anillo ocular amarillo en macho', 'Canto melodioso al amanecer y atardecer'],
    habitat: 'Bosques, parques urbanos, jardines y setos.',
    tituloWikipedia: 'Turdus_merula',
  ),
  EspecieGuia(
    id: 'sus-scrofa',
    nombreCientifico: 'Sus scrofa',
    nombreComun: 'Jabalí',
    categoriaId: 'animal',
    descripcionCorta: 'Mamífero artiodáctilo robusto con pelaje cerdoso oscuro y hocico alargado.',
    distintivos: ['Huellas con dos pezuñas más dos espolones', 'Hozaduras en suelo', 'Restos de pelo en árboles'],
    habitat: 'Bosques mediterráneos y atlánticos, dehesas, zonas agrícolas marginales.',
    tituloWikipedia: 'Sus_scrofa',
  ),
  EspecieGuia(
    id: 'vulpes-vulpes',
    nombreCientifico: 'Vulpes vulpes',
    nombreComun: 'Zorro rojo',
    categoriaId: 'animal',
    descripcionCorta: 'Cánido de pelaje rojizo, cola larga y tupida con punta blanca.',
    distintivos: ['Huellas en línea recta', 'Excrementos retorcidos con pelos y huesos', 'Hocico afilado'],
    habitat: 'Casi ubicuo: bosques, matorrales, campiñas, periferia urbana.',
    tituloWikipedia: 'Vulpes_vulpes',
  ),
  EspecieGuia(
    id: 'salamandra-salamandra',
    nombreCientifico: 'Salamandra salamandra',
    nombreComun: 'Salamandra común',
    categoriaId: 'animal',
    descripcionCorta: 'Anfibio urodelo negro con manchas amarillas brillantes muy variables.',
    distintivos: ['Coloración negra con manchas amarillas', 'Glándulas parótidas marcadas', 'Activa de noche y con lluvia'],
    habitat: 'Bosques húmedos caducifolios, cerca de arroyos limpios.',
    tituloWikipedia: 'Salamandra_salamandra',
  ),
  EspecieGuia(
    id: 'erithacus-rubecula',
    nombreCientifico: 'Erithacus rubecula',
    nombreComun: 'Petirrojo europeo',
    categoriaId: 'animal',
    descripcionCorta: 'Pequeña ave con pecho y cara de color rojo-anaranjado intenso, dorso pardo.',
    distintivos: ['Pecho naranja característico', 'Postura erguida en posaderos bajos', 'Canto fino y silbado'],
    habitat: 'Sotobosque de bosques, jardines, zonas con maleza.',
    tituloWikipedia: 'Erithacus_rubecula',
  ),
  EspecieGuia(
    id: 'capreolus-capreolus',
    nombreCientifico: 'Capreolus capreolus',
    nombreComun: 'Corzo',
    categoriaId: 'animal',
    descripcionCorta: 'Cérvido pequeño de pelaje pardo rojizo en verano y grisáceo en invierno, con espejuelo blanco.',
    distintivos: ['Tamaño pequeño (1 m a la cruz)', 'Espejuelo blanco en cuartos traseros', 'Cuernas cortas con 3 puntas en machos'],
    habitat: 'Bosques, sotos, cultivos cercanos a cobertura forestal.',
    tituloWikipedia: 'Capreolus_capreolus',
  ),
  EspecieGuia(
    id: 'sciurus-vulgaris',
    nombreCientifico: 'Sciurus vulgaris',
    nombreComun: 'Ardilla roja',
    categoriaId: 'animal',
    descripcionCorta: 'Roedor arborícola de pelaje rojizo a oscuro, con cola larga y espesa.',
    distintivos: ['Mechones de pelo en orejas (en invierno)', 'Cola larga y peluda', 'Saltos entre ramas'],
    habitat: 'Bosques de coníferas y mixtos, parques con árboles maduros.',
    tituloWikipedia: 'Sciurus_vulgaris',
  ),
  EspecieGuia(
    id: 'parus-major',
    nombreCientifico: 'Parus major',
    nombreComun: 'Carbonero común',
    categoriaId: 'animal',
    descripcionCorta: 'Pequeña ave con cabeza negra, mejillas blancas y franja negra ventral característica.',
    distintivos: ['Cabeza negra con mejillas blancas', 'Franja negra en pecho', 'Canto "tit-ti-tó"'],
    habitat: 'Bosques, parques, jardines, comederos urbanos.',
    tituloWikipedia: 'Parus_major',
  ),
  EspecieGuia(
    id: 'gallus-gallus-meleagris',
    nombreCientifico: 'Buteo buteo',
    nombreComun: 'Busardo ratonero',
    categoriaId: 'animal',
    descripcionCorta: 'Rapaz mediana de plumaje pardo variable, ancha cola y reclamo "kiao" característico.',
    distintivos: ['Vuelo cernido sobre campos', 'Tamaño mediano', 'Reclamo aflautado'],
    habitat: 'Campiñas, lindes de bosque, postes y árboles aislados.',
    tituloWikipedia: 'Buteo_buteo',
  ),
  EspecieGuia(
    id: 'rana-perezi',
    nombreCientifico: 'Pelophylax perezi',
    nombreComun: 'Rana común',
    categoriaId: 'animal',
    descripcionCorta: 'Rana verde-parda con línea vertebral clara y sacos vocales bien visibles en machos.',
    distintivos: ['Coloración variable verde-parda', 'Línea dorsal clara', 'Croar fuerte de noche'],
    habitat: 'Charcas, ríos lentos, balsas de riego.',
    tituloWikipedia: 'Pelophylax_perezi',
  ),
  EspecieGuia(
    id: 'lacerta-bilineata',
    nombreCientifico: 'Lacerta bilineata',
    nombreComun: 'Lagarto verde occidental',
    categoriaId: 'animal',
    descripcionCorta: 'Gran lagarto de tono verde brillante con macho de garganta azul en celo.',
    distintivos: ['Color verde intenso', 'Garganta azul (machos en primavera)', 'Tamaño hasta 40 cm'],
    habitat: 'Setos soleados, lindes de bosque, zonas con piedras.',
    tituloWikipedia: 'Lacerta_bilineata',
  ),
  EspecieGuia(
    id: 'meles-meles',
    nombreCientifico: 'Meles meles',
    nombreComun: 'Tejón europeo',
    categoriaId: 'animal',
    descripcionCorta: 'Mustélido robusto con cabeza blanca y dos bandas negras longitudinales.',
    distintivos: ['Cabeza blanca con bandas negras', 'Cuerpo bajo y fornido', 'Tejoneras con varias entradas'],
    habitat: 'Bosques, setos densos, laderas con suelo blando para excavar.',
    tituloWikipedia: 'Meles_meles',
  ),
  EspecieGuia(
    id: 'lutra-lutra',
    nombreCientifico: 'Lutra lutra',
    nombreComun: 'Nutria europea',
    categoriaId: 'animal',
    descripcionCorta: 'Mustélido acuático de pelaje pardo, cuerpo alargado y cola gruesa.',
    distintivos: ['Cola larga y gruesa en la base', 'Hocico achatado', 'Excrementos sobre piedras junto al agua'],
    habitat: 'Ríos limpios, marismas, costa rocosa.',
    tituloWikipedia: 'Lutra_lutra',
  ),

  // ─── Insectos y artrópodos ─────────────────────────────
  EspecieGuia(
    id: 'vanessa-atalanta',
    nombreCientifico: 'Vanessa atalanta',
    nombreComun: 'Mariposa almirante rojo',
    categoriaId: 'insecto',
    descripcionCorta: 'Mariposa diurna con bandas rojas sobre alas anteriores negras y zonas blancas.',
    distintivos: ['Banda roja en ala anterior', 'Manchas blancas en el ápice', 'Vuelo rápido y errático'],
    habitat: 'Jardines, lindes de bosque, riberas, cualquier zona con flores.',
    tituloWikipedia: 'Vanessa_atalanta',
  ),
  EspecieGuia(
    id: 'apis-mellifera',
    nombreCientifico: 'Apis mellifera',
    nombreComun: 'Abeja melífera',
    categoriaId: 'insecto',
    descripcionCorta: 'Abeja social de tamaño medio con pelaje pardo amarillento y bandas oscuras en abdomen.',
    distintivos: ['Cuerpo peludo', 'Cestillas de polen en patas traseras', 'Vuelo zumbante directo entre flores'],
    habitat: 'Cualquier zona con flores; muy abundante por colmenas gestionadas.',
    tituloWikipedia: 'Apis_mellifera',
  ),
  EspecieGuia(
    id: 'coccinella-septempunctata',
    nombreCientifico: 'Coccinella septempunctata',
    nombreComun: 'Mariquita de siete puntos',
    categoriaId: 'insecto',
    descripcionCorta: 'Coccinélido rojo con siete puntos negros sobre los élitros.',
    distintivos: ['Élitros rojo intenso', '7 puntos negros (3+3+1 escutelar)', 'Cabeza negra con dos manchas blancas'],
    habitat: 'Pastizales, cultivos, jardines; donde hay pulgones.',
    tituloWikipedia: 'Coccinella_septempunctata',
  ),
  EspecieGuia(
    id: 'argiope-bruennichi',
    nombreCientifico: 'Argiope bruennichi',
    nombreComun: 'Araña tigre',
    categoriaId: 'insecto',
    descripcionCorta: 'Araña con abdomen rayado en amarillo y negro, hembras grandes y vistosas.',
    distintivos: ['Bandas amarillas y negras en abdomen', 'Tela orbicular con estabilimento en zigzag', 'Hembra mucho mayor que macho'],
    habitat: 'Pastizales altos, zonas con vegetación herbácea soleada.',
    tituloWikipedia: 'Argiope_bruennichi',
  ),
  EspecieGuia(
    id: 'gryllus-campestris',
    nombreCientifico: 'Gryllus campestris',
    nombreComun: 'Grillo campestre',
    categoriaId: 'insecto',
    descripcionCorta: 'Grillo negro de cabeza grande, antenas largas y cantos potentes.',
    distintivos: ['Color negro brillante', 'Cabeza ancha y redonda', 'Cri-cri continuo desde madrigueras'],
    habitat: 'Pastizales secos, lindes de campos, zonas soleadas con suelo blando.',
    tituloWikipedia: 'Gryllus_campestris',
  ),
  EspecieGuia(
    id: 'pieris-rapae',
    nombreCientifico: 'Pieris rapae',
    nombreComun: 'Mariposa de la col',
    categoriaId: 'insecto',
    descripcionCorta: 'Mariposa blanca de tamaño medio con manchas negras en el ápice y oscuras en el centro del ala.',
    distintivos: ['Color blanco crema', '1-2 puntos negros en cara superior', 'Vuelo lento y aleteado'],
    habitat: 'Cultivos de crucíferas, jardines, prados, terrenos abiertos.',
    tituloWikipedia: 'Pieris_rapae',
  ),
  EspecieGuia(
    id: 'bombus-terrestris',
    nombreCientifico: 'Bombus terrestris',
    nombreComun: 'Abejorro común',
    categoriaId: 'insecto',
    descripcionCorta: 'Abejorro grande, peludo, con bandas amarillas y abdomen de punta blanca.',
    distintivos: ['Cuerpo grande y peludo', 'Banda torácica amarilla', 'Punta del abdomen blanca'],
    habitat: 'Praderas, jardines, lindes con flores; nidos subterráneos.',
    tituloWikipedia: 'Bombus_terrestris',
  ),
  EspecieGuia(
    id: 'libellula-depressa',
    nombreCientifico: 'Libellula depressa',
    nombreComun: 'Libélula deprimida',
    categoriaId: 'insecto',
    descripcionCorta: 'Libélula de abdomen ancho y aplanado; macho azul pruinoso, hembra ámbar.',
    distintivos: ['Abdomen ancho y aplanado', 'Manchas oscuras en base de las alas', 'Macho azul, hembra dorada'],
    habitat: 'Charcas y aguas lentas con vegetación; coloniza rápido balsas nuevas.',
    tituloWikipedia: 'Libellula_depressa',
  ),
  EspecieGuia(
    id: 'forficula-auricularia',
    nombreCientifico: 'Forficula auricularia',
    nombreComun: 'Tijereta común',
    categoriaId: 'insecto',
    descripcionCorta: 'Insecto pardo alargado con par de pinzas (cercos) en el extremo del abdomen.',
    distintivos: ['Cercos en forma de pinza', 'Color pardo rojizo', 'Activa de noche'],
    habitat: 'Bajo piedras, hojarasca, corteza, jardines.',
    tituloWikipedia: 'Forficula_auricularia',
  ),
  EspecieGuia(
    id: 'cetonia-aurata',
    nombreCientifico: 'Cetonia aurata',
    nombreComun: 'Escarabajo de las rosas',
    categoriaId: 'insecto',
    descripcionCorta: 'Escarabajo de élitros verde metálico brillante con manchas blancas, frecuente en flores.',
    distintivos: ['Verde metálico iridiscente', 'Manchas blancas dispersas', 'Vuelo zumbante con élitros cerrados'],
    habitat: 'Jardines, praderas con flores, márgenes de bosque.',
    tituloWikipedia: 'Cetonia_aurata',
  ),
  EspecieGuia(
    id: 'mantis-religiosa',
    nombreCientifico: 'Mantis religiosa',
    nombreComun: 'Mantis religiosa',
    categoriaId: 'insecto',
    descripcionCorta: 'Mantis verde o parda con patas anteriores raptoras plegadas en posición orante.',
    distintivos: ['Patas anteriores en posición de plegaria', 'Cuello largo y móvil', 'Cabeza triangular giratoria'],
    habitat: 'Pastizales secos, márgenes de cultivos, zonas con vegetación herbácea alta.',
    tituloWikipedia: 'Mantis_religiosa',
  ),
  EspecieGuia(
    id: 'oryctes-nasicornis',
    nombreCientifico: 'Oryctes nasicornis',
    nombreComun: 'Escarabajo rinoceronte',
    categoriaId: 'insecto',
    descripcionCorta: 'Escarabajo grande pardo rojizo; los machos llevan un cuerno frontal curvado.',
    distintivos: ['Cuerno frontal en machos', 'Tamaño 2,5-4 cm', 'Color caoba brillante'],
    habitat: 'Madera muerta, montones de compost, bosques caducifolios.',
    tituloWikipedia: 'Oryctes_nasicornis',
  ),
  EspecieGuia(
    id: 'tegenaria-domestica',
    nombreCientifico: 'Tegenaria domestica',
    nombreComun: 'Araña casera',
    categoriaId: 'insecto',
    descripcionCorta: 'Araña parda con bandas oscuras en patas, frecuente en interiores y trasteros.',
    distintivos: ['Patas largas con bandas', 'Tela en embudo en rincones', 'Cuerpo de 7-12 mm'],
    habitat: 'Casas, garajes, cuevas, refugios protegidos.',
    tituloWikipedia: 'Tegenaria_domestica',
  ),

  // ─── Plantas ───────────────────────────────────────────
  EspecieGuia(
    id: 'quercus-ilex',
    nombreCientifico: 'Quercus ilex',
    nombreComun: 'Encina',
    categoriaId: 'planta',
    descripcionCorta: 'Árbol perennifolio de copa densa y redondeada con hojas pequeñas, coriáceas y oscuras.',
    distintivos: ['Hoja perenne, dura y a veces espinosa', 'Envés de la hoja blanquecino', 'Bellotas dulces en otoño'],
    habitat: 'Bosques mediterráneos, dehesas, zonas calizas y silíceas.',
    tituloWikipedia: 'Quercus_ilex',
  ),
  EspecieGuia(
    id: 'rosmarinus-officinalis',
    nombreCientifico: 'Salvia rosmarinus',
    nombreComun: 'Romero',
    categoriaId: 'planta',
    descripcionCorta: 'Arbusto leñoso aromático con hojas lineares verde oscuro y flores azuladas.',
    distintivos: ['Olor intenso al frotar', 'Hojas tipo aguja, envés blanquecino', 'Flores de invierno-primavera azul claro'],
    habitat: 'Matorrales mediterráneos secos, suelos calizos.',
    tituloWikipedia: 'Salvia_rosmarinus',
  ),
  EspecieGuia(
    id: 'papaver-rhoeas',
    nombreCientifico: 'Papaver rhoeas',
    nombreComun: 'Amapola común',
    categoriaId: 'planta',
    descripcionCorta: 'Herbácea anual con grandes flores rojas de cuatro pétalos arrugados.',
    distintivos: ['Pétalos rojo intenso, a veces con mancha negra basal', 'Cápsula de semillas redondeada', 'Tallo y hojas con pelos'],
    habitat: 'Cultivos de cereal, barbechos, márgenes de caminos.',
    tituloWikipedia: 'Papaver_rhoeas',
  ),
  EspecieGuia(
    id: 'ulex-europaeus',
    nombreCientifico: 'Ulex europaeus',
    nombreComun: 'Tojo común',
    categoriaId: 'planta',
    descripcionCorta: 'Arbusto espinoso de la familia de las leguminosas con flores amarillo intenso.',
    distintivos: ['Espinas rígidas que sustituyen hojas', 'Flores amarillas con olor a coco', 'Forma matorrales densos'],
    habitat: 'Brezales y landas atlánticas, suelos ácidos.',
    tituloWikipedia: 'Ulex_europaeus',
  ),
  EspecieGuia(
    id: 'taraxacum-officinale',
    nombreCientifico: 'Taraxacum officinale',
    nombreComun: 'Diente de león',
    categoriaId: 'planta',
    descripcionCorta: 'Herbácea perenne con roseta basal de hojas dentadas y capítulos amarillos.',
    distintivos: ['Hojas profundamente dentadas', 'Capítulo amarillo solitario sobre tallo hueco', 'Vilano esférico al fructificar'],
    habitat: 'Praderas, céspedes, márgenes de caminos; muy ubicua.',
    tituloWikipedia: 'Taraxacum_officinale',
  ),
  EspecieGuia(
    id: 'pinus-pinaster',
    nombreCientifico: 'Pinus pinaster',
    nombreComun: 'Pino marítimo',
    categoriaId: 'planta',
    descripcionCorta: 'Pino de tronco rojizo, hojas en pares largas y gruesas y piñas grandes cónicas.',
    distintivos: ['Acículas en pares de 15-22 cm', 'Corteza rojiza muy resquebrajada', 'Piñas grandes (10-22 cm)'],
    habitat: 'Suelos arenosos del litoral atlántico y mediterráneo, repoblaciones.',
    tituloWikipedia: 'Pinus_pinaster',
  ),
  EspecieGuia(
    id: 'fagus-sylvatica',
    nombreCientifico: 'Fagus sylvatica',
    nombreComun: 'Haya',
    categoriaId: 'planta',
    descripcionCorta: 'Árbol caducifolio de corteza lisa gris plomiza y hojas ovales con bordes ondulados.',
    distintivos: ['Corteza lisa color elefante', 'Hojas ovales con bordes ondulados', 'Hayucos triangulares en cúpula espinosa'],
    habitat: 'Bosques húmedos de montaña, suelos frescos en zonas atlánticas.',
    tituloWikipedia: 'Fagus_sylvatica',
  ),
  EspecieGuia(
    id: 'quercus-robur',
    nombreCientifico: 'Quercus robur',
    nombreComun: 'Roble común',
    categoriaId: 'planta',
    descripcionCorta: 'Roble caducifolio de hoja lobulada con peciolo muy corto y bellotas en pedúnculo largo.',
    distintivos: ['Hoja con lóbulos redondeados', 'Bellotas con pedúnculo largo', 'Copa amplia'],
    habitat: 'Bosques caducifolios atlánticos, suelos profundos y frescos.',
    tituloWikipedia: 'Quercus_robur',
  ),
  EspecieGuia(
    id: 'rubus-ulmifolius',
    nombreCientifico: 'Rubus ulmifolius',
    nombreComun: 'Zarzamora',
    categoriaId: 'planta',
    descripcionCorta: 'Arbusto trepador espinoso, formando matorrales densos; flores blanco-rosadas y moras negras.',
    distintivos: ['Tallos arqueados con espinas curvadas', 'Hojas compuestas pinnadas', 'Frutos polidrupa que ennegrecen al madurar'],
    habitat: 'Setos, lindes, claros de bosque, terrenos abandonados.',
    tituloWikipedia: 'Rubus_ulmifolius',
  ),
  EspecieGuia(
    id: 'lavandula-stoechas',
    nombreCientifico: 'Lavandula stoechas',
    nombreComun: 'Cantueso',
    categoriaId: 'planta',
    descripcionCorta: 'Mata aromática con espigas terminales coronadas por brácteas violáceas conspicuas.',
    distintivos: ['Brácteas estériles violetas en lo alto', 'Hojas estrechas grisáceas', 'Olor intenso al frotarla'],
    habitat: 'Matorrales secos sobre suelos silíceos.',
    tituloWikipedia: 'Lavandula_stoechas',
  ),
  EspecieGuia(
    id: 'hedera-helix',
    nombreCientifico: 'Hedera helix',
    nombreComun: 'Hiedra común',
    categoriaId: 'planta',
    descripcionCorta: 'Trepadora perenne con hojas palmeado-lobuladas en ramas estériles y enteras en floríferas.',
    distintivos: ['Hojas brillantes de cinco lóbulos', 'Raíces adventicias adherentes', 'Bayas negras tóxicas'],
    habitat: 'Bosques sombríos, tapias, troncos de árboles.',
    tituloWikipedia: 'Hedera_helix',
  ),
  EspecieGuia(
    id: 'urtica-dioica',
    nombreCientifico: 'Urtica dioica',
    nombreComun: 'Ortiga mayor',
    categoriaId: 'planta',
    descripcionCorta: 'Herbácea perenne con tallo y hojas cubiertos de pelos urticantes; hojas opuestas dentadas.',
    distintivos: ['Pelos urticantes', 'Hojas opuestas con bordes muy dentados', 'Flores verdosas en racimos colgantes'],
    habitat: 'Lugares nitrogenados: bordes de cuadras, cunetas, ruinas.',
    tituloWikipedia: 'Urtica_dioica',
  ),
  EspecieGuia(
    id: 'plantago-lanceolata',
    nombreCientifico: 'Plantago lanceolata',
    nombreComun: 'Llantén menor',
    categoriaId: 'planta',
    descripcionCorta: 'Herbácea con roseta basal de hojas lanceoladas y espigas cilíndricas oscuras sobre tallo desnudo.',
    distintivos: ['Hojas lanceoladas con nervios paralelos', 'Espiga corta cilíndrica', 'Tallos sin hojas'],
    habitat: 'Praderas, céspedes, cunetas; muy ubicua.',
    tituloWikipedia: 'Plantago_lanceolata',
  ),
];

List<EspecieGuia> especiesPorCategoria(String categoriaId) =>
    especiesGuia.where((e) => e.categoriaId == categoriaId).toList();

CategoriaGuia? categoriaPorId(String id) {
  for (final c in categoriasGuia) {
    if (c.id == id) return c;
  }
  return null;
}

EspecieGuia? especiePorId(String id) {
  for (final especie in especiesGuia) {
    if (especie.id == id) return especie;
  }
  return null;
}

void abrirDetalleEspecieGuia(BuildContext context, String idEspecie) {
  final especie = especiePorId(idEspecie);
  if (especie == null) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Especie no encontrada'),
        content: Text('No hay datos para "$idEspecie".'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))],
      ),
    );
    return;
  }
  final categoria = categoriaPorId(especie.categoriaId);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, controladorScroll) => SingleChildScrollView(
        controller: controladorScroll,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<String?>(
              future: miniaturaPorNombreCientifico(especie.nombreCientifico),
              builder: (context, snapshot) {
                final url = snapshot.data;
                if (url == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      url,
                      width: double.infinity,
                      height: 220,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                );
              },
            ),
            Row(
              children: [
                if (categoria != null)
                  CircleAvatar(
                    backgroundColor: categoria.color.withValues(alpha: 0.2),
                    child: Icon(categoria.icono, color: categoria.color),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(especie.nombreComun, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text(
                        especie.nombreCientifico,
                        style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(especie.descripcionCorta),
            const SizedBox(height: 16),
            const Text('Distintivos', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            for (final distintivo in especie.distintivos)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  '),
                    Expanded(child: Text(distintivo)),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            const Text('Hábitat', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(especie.habitat),
            const SizedBox(height: 24),
            if (especie.tituloWikipedia.isNotEmpty)
              FilledButton.tonalIcon(
                icon: const Icon(Icons.open_in_new),
                onPressed: () => launchUrl(
                  Uri.parse('https://es.wikipedia.org/wiki/${especie.tituloWikipedia}'),
                  mode: LaunchMode.externalApplication,
                ),
                label: const Text('Abrir en Wikipedia'),
              ),
          ],
        ),
      ),
    ),
  );
}
