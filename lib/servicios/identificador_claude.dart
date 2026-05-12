import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../datos/configuracion.dart';

class ContextoIdentificacion {
  final double? latitud;
  final double? longitud;
  final String? habitat;
  final String? notas;
  final String? especieTentativa;
  final String categoriaEsperada; // 'animal' | 'insecto' | 'planta' | 'auto'

  ContextoIdentificacion({
    this.latitud,
    this.longitud,
    this.habitat,
    this.notas,
    this.especieTentativa,
    this.categoriaEsperada = 'auto',
  });
}

class IdentificacionEspecie {
  final String categoriaDetectada; // 'animal' | 'insecto' | 'planta' | 'desconocido'
  final String nombreCientifico;
  final String nombreComun;
  final String taxonomia; // p.ej. "Animalia › Chordata › Aves › Passeriformes › Turdidae › Turdus › T. merula"
  final String confianza; // 'alta' | 'media' | 'baja'
  final String descripcion;
  final String razonamiento;
  final List<String> alternativas;
  final String comoConfirmar;
  final String? habitatTipico;
  final String? estadoConservacion;
  final String modeloUsado;

  IdentificacionEspecie({
    required this.categoriaDetectada,
    required this.nombreCientifico,
    required this.nombreComun,
    required this.taxonomia,
    required this.confianza,
    required this.descripcion,
    required this.razonamiento,
    required this.alternativas,
    required this.comoConfirmar,
    this.habitatTipico,
    this.estadoConservacion,
    required this.modeloUsado,
  });
}

const String _systemPrompt = '''
Eres un naturalista experto en identificación de animales (vertebrados), insectos (y otros artrópodos) y plantas, con conocimiento profundo de la fauna y flora del Paleártico occidental, incluida la península ibérica y los Pirineos.
Recibirás una foto de un ser vivo (animal, insecto/artrópodo o planta), opcionalmente con contexto (coordenadas, hábitat, notas).
Detecta primero la categoría: 'animal' (vertebrado: mamífero, ave, reptil, anfibio, pez), 'insecto' (todos los artrópodos: insectos, arácnidos, miriápodos, crustáceos terrestres) o 'planta' (incluye hongos y líquenes a falta de categoría propia).
Devuelve nombre científico binomial cuando sea posible, nombre común en español, y la cadena taxonómica desde reino hasta especie.
Usa las coordenadas y el hábitat para razonar sobre la distribución y ecología probables.
Responde SIEMPRE en español neutro. Sé honesto sobre la confianza: si no estás seguro, dilo y propón alternativas.
Si la foto no contiene un ser vivo reconocible o es de muy mala calidad, indícalo en categoria_detectada="desconocido" y explica por qué en razonamiento.
''';

Future<IdentificacionEspecie> identificarEspecie({
  required File archivoFoto,
  required ContextoIdentificacion contexto,
}) async {
  final apiKey = await Configuracion.obtenerApiKey();
  if (apiKey.trim().isEmpty) {
    throw Exception('Falta la API key de Anthropic. Configúrala en Ajustes.');
  }
  final modelo = await Configuracion.obtenerModelo();

  final bytes = await archivoFoto.readAsBytes();
  final base64Foto = base64Encode(bytes);
  final mediaType = _detectarMimeType(archivoFoto.path);

  final lineasContexto = <String>[
    if (contexto.categoriaEsperada != 'auto') 'El usuario espera identificar un/a ${contexto.categoriaEsperada}.',
    if (contexto.latitud != null && contexto.longitud != null)
      'Coordenadas (lat, lon): ${contexto.latitud!.toStringAsFixed(5)}, ${contexto.longitud!.toStringAsFixed(5)}',
    if (contexto.habitat != null && contexto.habitat!.isNotEmpty) 'Hábitat: ${contexto.habitat}',
    if (contexto.especieTentativa != null && contexto.especieTentativa!.isNotEmpty)
      'Sospecha del usuario: ${contexto.especieTentativa}',
    if (contexto.notas != null && contexto.notas!.isNotEmpty) 'Notas del usuario: ${contexto.notas}',
  ];

  final mensajeUsuario = <Map<String, dynamic>>[
    {
      'type': 'image',
      'source': {
        'type': 'base64',
        'media_type': mediaType,
        'data': base64Foto,
      },
    },
    {
      'type': 'text',
      'text': lineasContexto.isNotEmpty
          ? 'Contexto disponible:\n${lineasContexto.join("\n")}\n\nIdentifica la especie de la foto.'
          : 'Identifica la especie de la foto.',
    },
  ];

  final esquema = {
    'type': 'object',
    'properties': {
      'categoria_detectada': {'type': 'string', 'enum': ['animal', 'insecto', 'planta', 'desconocido']},
      'nombre_cientifico': {'type': 'string', 'description': 'Binomial Genus species cuando sea posible.'},
      'nombre_comun': {'type': 'string', 'description': 'Nombre vulgar en español.'},
      'taxonomia': {'type': 'string', 'description': 'Cadena Reino › Filo › Clase › Orden › Familia › Género › Especie.'},
      'confianza': {'type': 'string', 'enum': ['alta', 'media', 'baja']},
      'descripcion': {'type': 'string'},
      'razonamiento': {'type': 'string'},
      'alternativas': {'type': 'array', 'items': {'type': 'string'}},
      'como_confirmar': {'type': 'string'},
      'habitat_tipico': {'type': 'string'},
      'estado_conservacion': {'type': 'string', 'description': 'Categoría IUCN si es conocida (LC, NT, VU, EN, CR, etc.).'},
    },
    'required': [
      'categoria_detectada',
      'nombre_cientifico',
      'nombre_comun',
      'taxonomia',
      'confianza',
      'descripcion',
      'razonamiento',
      'como_confirmar',
    ],
  };

  // La forma canónica de pedir output JSON estructurado a la API
  // Anthropic es vía tool-use: declaras una tool con `input_schema`
  // y la fuerzas con `tool_choice`. La forma anterior con
  // `output_config.format.json_schema` no es parte de la API pública
  // y dejaba de identificar en producción.
  const nombreHerramienta = 'registrar_identificacion';
  final cuerpo = jsonEncode({
    'model': modelo,
    'max_tokens': 2048,
    'system': _systemPrompt,
    'messages': [
      {'role': 'user', 'content': mensajeUsuario}
    ],
    'tools': [
      {
        'name': nombreHerramienta,
        'description':
            'Registra la identificación de la especie observada en la foto, con nombre científico, taxonomía y nivel de confianza.',
        'input_schema': esquema,
      },
    ],
    'tool_choice': {'type': 'tool', 'name': nombreHerramienta},
  });

  final respuesta = await http.post(
    Uri.parse('https://api.anthropic.com/v1/messages'),
    headers: {
      'content-type': 'application/json',
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
      'anthropic-dangerous-direct-browser-access': 'true',
    },
    body: cuerpo,
  ).timeout(const Duration(seconds: 60));

  if (respuesta.statusCode != 200) {
    throw Exception('Error API (${respuesta.statusCode}): ${utf8.decode(respuesta.bodyBytes)}');
  }

  final json = jsonDecode(utf8.decode(respuesta.bodyBytes)) as Map<String, dynamic>;
  final contenidos = ((json['content'] as List?) ?? const [])
      .cast<Map<String, dynamic>>();
  // Con tool-use forzado, la respuesta llega como bloque
  // `type: 'tool_use'` con el JSON estructurado en `input`. Si por
  // cualquier motivo el modelo devuelve un bloque `text` en su
  // lugar, intentamos parsearlo como JSON (compat antigua).
  Map<String, dynamic>? datos;
  for (final bloque in contenidos) {
    if (bloque['type'] == 'tool_use') {
      final entrada = bloque['input'];
      if (entrada is Map<String, dynamic>) {
        datos = entrada;
        break;
      }
    }
  }
  if (datos == null) {
    for (final bloque in contenidos) {
      if (bloque['type'] == 'text') {
        final texto = bloque['text'] as String?;
        if (texto != null && texto.trim().isNotEmpty) {
          try {
            final d = jsonDecode(texto);
            if (d is Map<String, dynamic>) {
              datos = d;
              break;
            }
          } catch (_) {
            // Texto no parseable como JSON: probable mensaje de error
            // del modelo. Lo dejamos pasar para que el throw siguiente
            // lo reporte con contexto.
          }
        }
      }
    }
  }
  if (datos == null) {
    throw Exception(
      'Respuesta sin contenido estructurado. body=${utf8.decode(respuesta.bodyBytes)}',
    );
  }
  return IdentificacionEspecie(
    categoriaDetectada: datos['categoria_detectada'] as String? ?? 'desconocido',
    nombreCientifico: datos['nombre_cientifico'] as String? ?? '',
    nombreComun: datos['nombre_comun'] as String? ?? '',
    taxonomia: datos['taxonomia'] as String? ?? '',
    confianza: datos['confianza'] as String? ?? 'baja',
    descripcion: datos['descripcion'] as String? ?? '',
    razonamiento: datos['razonamiento'] as String? ?? '',
    alternativas: ((datos['alternativas'] as List?) ?? const []).cast<String>(),
    comoConfirmar: datos['como_confirmar'] as String? ?? '',
    habitatTipico: datos['habitat_tipico'] as String?,
    estadoConservacion: datos['estado_conservacion'] as String?,
    modeloUsado: modelo,
  );
}

String _detectarMimeType(String ruta) {
  final ext = ruta.split('.').last.toLowerCase();
  return switch (ext) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    _ => 'image/jpeg',
  };
}
