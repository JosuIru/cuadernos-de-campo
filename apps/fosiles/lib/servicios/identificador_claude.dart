import 'dart:io';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import '../datos/configuracion.dart';

class ContextoIdentificacion {
  final double? latitud;
  final double? longitud;
  final String? edad;
  final String? formacion;
  final String? litologia;
  final String? notas;
  final String? especieTentativa;
  final String? monedaReferencia;
  final String tipoEsperado; // 'fosil', 'mineral', 'auto'

  ContextoIdentificacion({
    this.latitud,
    this.longitud,
    this.edad,
    this.formacion,
    this.litologia,
    this.notas,
    this.especieTentativa,
    this.monedaReferencia,
    this.tipoEsperado = 'auto',
  });
}

class IdentificacionFosil {
  final String grupoTaxonomico;
  final String identificacionTentativa;
  final String confianza;
  final String descripcion;
  final String razonamiento;
  final String? edadEstimada;
  final List<String> alternativas;
  final String comoConfirmar;
  final String? tamanoEstimado;
  final String tipoDetectado; // 'fosil' | 'mineral' | 'desconocido'
  final String? durezaMohsEstimada;
  final String modeloUsado;

  IdentificacionFosil({
    required this.grupoTaxonomico,
    required this.identificacionTentativa,
    required this.confianza,
    required this.descripcion,
    required this.razonamiento,
    this.edadEstimada,
    required this.alternativas,
    required this.comoConfirmar,
    this.tamanoEstimado,
    this.tipoDetectado = 'fosil',
    this.durezaMohsEstimada,
    required this.modeloUsado,
  });
}

const Map<String, double> _diametroMonedaMm = {
  '€2': 25.75,
  '€1': 23.25,
  '€0,50': 24.25,
  '€0,20': 22.25,
  '€0,10': 19.75,
};

String _diametrosComoTexto() {
  return _diametroMonedaMm.entries.map((e) => '${e.key} = ${e.value} mm').join(', ');
}

const List<String> monedasReferenciaDisponibles = ['€2', '€1', '€0,50', '€0,20', '€0,10'];

const String _systemPrompt = '''
Eres un experto en paleontología y mineralogía de cualquier región del mundo, con experiencia profunda en la cuenca Vasco-Cantábrica y los Pirineos.
Recibirás una foto de un posible fósil O un mineral, opcionalmente con contexto geológico (edad, formación, litología, coordenadas).
Detecta primero si la imagen muestra un fósil o un mineral, y rellena tipo_detectado en consecuencia.
- Si es fósil: rellena grupo_taxonomico, identificacion_tentativa (género/especie tentativa) y edad_estimada cronoestratigráfica.
- Si es mineral: rellena grupo_taxonomico con la clase Strunz (sulfuros, óxidos, silicatos, carbonatos, sulfatos, halogenuros, fosfatos, elementos), identificacion_tentativa con el nombre del mineral, y dureza_mohs_estimada con un valor o rango aproximado.
Usa las coordenadas para situar la zona y razonar sobre la geología regional probable.
Responde SIEMPRE en español neutro. Sé honesto sobre la confianza: si no estás seguro, dilo.
Si la foto no contiene un fósil/mineral reconocible o es de muy mala calidad, indícalo en grupo_taxonomico="No identificable" y explica por qué en razonamiento.
''';

Future<IdentificacionFosil> identificarFosil({
  required File archivoFoto,
  required ContextoIdentificacion contexto,
}) async {
  final apiKey = await Configuracion.obtenerApiKey();
  if (apiKey.trim().isEmpty) {
    throw ErrorClaude(
      MotivoErrorClaude.sinClave,
      'Falta la API key de Anthropic. Configúrala en Ajustes → Inteligencia artificial.',
    );
  }
  final modelo = await Configuracion.obtenerModelo();

  final foto = await ImagenClaude.desdeFichero(archivoFoto.path);

  final monedaTexto = contexto.monedaReferencia;
  final lineasContexto = <String>[
    if (contexto.tipoEsperado == 'fosil') 'El usuario espera identificar un FÓSIL.',
    if (contexto.tipoEsperado == 'mineral') 'El usuario espera identificar un MINERAL.',
    if (contexto.latitud != null && contexto.longitud != null)
      'Coordenadas (lat, lon): ${contexto.latitud!.toStringAsFixed(5)}, ${contexto.longitud!.toStringAsFixed(5)}',
    if (contexto.edad != null && contexto.edad!.isNotEmpty) 'Edad geológica IGME: ${contexto.edad}',
    if (contexto.formacion != null && contexto.formacion!.isNotEmpty) 'Formación: ${contexto.formacion}',
    if (contexto.litologia != null && contexto.litologia!.isNotEmpty) 'Litología: ${contexto.litologia}',
    if (contexto.especieTentativa != null && contexto.especieTentativa!.isNotEmpty) 'Sospecha del usuario: ${contexto.especieTentativa}',
    if (contexto.notas != null && contexto.notas!.isNotEmpty) 'Notas del usuario: ${contexto.notas}',
    if (monedaTexto != null && monedaTexto.isNotEmpty)
      'En la foto hay una moneda de $monedaTexto como referencia (diámetros: ${_diametrosComoTexto()}). Usa la moneda visible para estimar el tamaño real del fósil/mineral en mm o cm.',
  ];

  final mensajeUsuario = MensajeClaude.usuario(
    lineasContexto.isNotEmpty
        ? 'Contexto disponible:\n${lineasContexto.join("\n")}\n\nIdentifica el fósil de la foto.'
        : 'Identifica el fósil de la foto.',
    imagenes: [foto],
  );

  // La salida estructurada exige `additionalProperties: false` en cada objeto.
  final esquema = {
    'type': 'object',
    'additionalProperties': false,
    'properties': {
      'grupo_taxonomico': {'type': 'string', 'description': 'Grupo amplio: Ammonoidea, Bivalvia, Foraminifera, etc.'},
      'identificacion_tentativa': {'type': 'string', 'description': 'Nombre concreto: género o especie tentativa.'},
      'confianza': {'type': 'string', 'enum': ['alta', 'media', 'baja']},
      'descripcion': {'type': 'string'},
      'razonamiento': {'type': 'string'},
      'edad_estimada': {'type': 'string'},
      'alternativas': {'type': 'array', 'items': {'type': 'string'}},
      'como_confirmar': {'type': 'string'},
      'tamano_estimado': {'type': 'string', 'description': 'Tamaño aproximado en mm/cm si hay moneda de referencia.'},
      'tipo_detectado': {'type': 'string', 'enum': ['fosil', 'mineral', 'desconocido'], 'description': 'Si la imagen es un fósil o un mineral.'},
      'dureza_mohs_estimada': {'type': 'string', 'description': 'Si es mineral, dureza estimada en escala Mohs.'},
    },
    'required': ['grupo_taxonomico', 'identificacion_tentativa', 'confianza', 'descripcion', 'razonamiento', 'como_confirmar', 'tipo_detectado'],
  };

  // Salida estructurada (`output_config.format`) con el esquema de arriba.
  // Los modelos 5.5 razonan antes de contestar y ese razonamiento cuenta en
  // `max_tokens`: 4096 deja sitio a razonamiento + JSON. Esfuerzo medio en
  // todos: identificar por foto pide algo de razonamiento, y en Haiku el
  // coste extra es despreciable (medio es además su valor por defecto).
  final clienteClaude = ClienteClaude(claveApi: apiKey);
  final datos = await clienteClaude.pedirJson(
    modelo: modelo,
    sistema: _systemPrompt,
    mensajes: [mensajeUsuario],
    maxTokens: 4096,
    esfuerzo: EsfuerzoClaude.medio,
    esquemaJson: esquema,
  );
  return IdentificacionFosil(
    grupoTaxonomico: datos['grupo_taxonomico'] as String? ?? 'Desconocido',
    identificacionTentativa: datos['identificacion_tentativa'] as String? ?? 'Sin identificación',
    confianza: datos['confianza'] as String? ?? 'baja',
    descripcion: datos['descripcion'] as String? ?? '',
    razonamiento: datos['razonamiento'] as String? ?? '',
    edadEstimada: datos['edad_estimada'] as String?,
    alternativas: ((datos['alternativas'] as List?) ?? const []).cast<String>(),
    comoConfirmar: datos['como_confirmar'] as String? ?? '',
    tamanoEstimado: datos['tamano_estimado'] as String?,
    tipoDetectado: datos['tipo_detectado'] as String? ?? 'fosil',
    durezaMohsEstimada: datos['dureza_mohs_estimada'] as String?,
    modeloUsado: modelo,
  );
}
