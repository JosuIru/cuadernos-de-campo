import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

enum ProveedorChat { claude, deepseek }

class MensajeChat {
  final String texto;
  final bool esUsuario;
  final DateTime timestamp;
  final ProveedorChat? proveedor;
  final String? rutaImagen;

  MensajeChat({
    required this.texto,
    required this.esUsuario,
    this.proveedor,
    DateTime? timestamp,
    this.rutaImagen,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get tieneImagen => rutaImagen != null;

  Map<String, dynamic> toJson() => {
        't': texto,
        'u': esUsuario,
        'p': proveedor?.name,
        'ts': timestamp.millisecondsSinceEpoch,
        if (rutaImagen != null) 'img': rutaImagen,
      };

  factory MensajeChat.fromJson(Map<String, dynamic> json) => MensajeChat(
        texto: json['t'] as String,
        esUsuario: json['u'] as bool,
        proveedor: json['p'] != null
            ? ProveedorChat.values.firstWhere((p) => p.name == json['p'])
            : null,
        timestamp: DateTime.fromMillisecondsSinceEpoch(json['ts'] as int),
        rutaImagen: json['img'] as String?,
      );
}

class ServicioChat {
  final String apiKeyClaude;
  final String apiKeyDeepseek;
  final String modeloClaude;
  final String modeloDeepseek;

  ServicioChat({
    required this.apiKeyClaude,
    required this.apiKeyDeepseek,
    this.modeloClaude = 'claude-haiku-4-5',
    this.modeloDeepseek = 'deepseek-chat',
  });

  Future<String> enviarMensaje(
    String mensaje, {
    required ProveedorChat proveedor,
    List<MensajeChat>? historial,
    String? sistemaPrompt,
    String? rutaImagen,
  }) async {
    if (rutaImagen != null && proveedor == ProveedorChat.deepseek) {
      return 'DeepSeek no puede analizar imágenes. Cambia a Claude para identificar fósiles con foto.';
    }
    switch (proveedor) {
      case ProveedorChat.claude:
        return _enviarAClaude(mensaje, historial: historial, sistemaPrompt: sistemaPrompt, rutaImagen: rutaImagen);
      case ProveedorChat.deepseek:
        return _enviarADeepseek(mensaje, historial: historial, sistemaPrompt: sistemaPrompt);
    }
  }

  Future<String> _enviarAClaude(
    String mensaje, {
    List<MensajeChat>? historial,
    String? sistemaPrompt,
    String? rutaImagen,
  }) async {
    final mensajes = <Map<String, dynamic>>[];
    for (final m in (historial ?? const [])) {
      mensajes.add({
        'role': m.esUsuario ? 'user' : 'assistant',
        'content': m.texto,
      });
    }

    // Construir el contenido del mensaje actual (puede incluir imagen)
    dynamic contenidoUsuario;
    if (rutaImagen != null) {
      final bytes = await File(rutaImagen).readAsBytes();
      final base64 = base64Encode(bytes);
      final ext = rutaImagen.split('.').last.toLowerCase();
      final mediaType = ext == 'png' ? 'image/png' : 'image/jpeg';
      contenidoUsuario = [
        {
          'type': 'image',
          'source': {
            'type': 'base64',
            'media_type': mediaType,
            'data': base64,
          },
        },
        if (mensaje.isNotEmpty)
          {'type': 'text', 'text': mensaje},
      ];
    } else {
      contenidoUsuario = mensaje;
    }
    mensajes.add({'role': 'user', 'content': contenidoUsuario});

    final body = {
      'model': modeloClaude,
      'max_tokens': 1024,
      'system': sistemaPrompt ?? _sistemaPromptFosiles,
      'messages': mensajes,
    };

    final respuesta = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'x-api-key': apiKeyClaude,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 45));

    if (respuesta.statusCode != 200) {
      final err = jsonDecode(respuesta.body);
      throw Exception(err['error']?['message'] ?? 'Error ${respuesta.statusCode}');
    }

    final json = jsonDecode(respuesta.body) as Map<String, dynamic>;
    final content = (json['content'] as List).first as Map<String, dynamic>;
    return content['text'] as String;
  }

  Future<String> _enviarADeepseek(
    String mensaje, {
    List<MensajeChat>? historial,
    String? sistemaPrompt,
  }) async {
    final mensajesApi = <Map<String, dynamic>>[];
    mensajesApi.add({
      'role': 'system',
      'content': sistemaPrompt ?? _sistemaPromptFosiles,
    });
    for (final m in (historial ?? const [])) {
      mensajesApi.add({
        'role': m.esUsuario ? 'user' : 'assistant',
        'content': m.texto,
      });
    }
    mensajesApi.add({'role': 'user', 'content': mensaje});

    final respuesta = await http.post(
      Uri.parse('https://api.deepseek.com/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKeyDeepseek',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': modeloDeepseek,
        'messages': mensajesApi,
        'max_tokens': 1024,
        'temperature': 0.7,
      }),
    ).timeout(const Duration(seconds: 45));

    if (respuesta.statusCode != 200) {
      final err = jsonDecode(respuesta.body);
      throw Exception(err['error']?['message'] ?? 'Error ${respuesta.statusCode}');
    }

    final json = jsonDecode(respuesta.body) as Map<String, dynamic>;
    final choices = json['choices'] as List;
    final message = (choices.first as Map)['message'] as Map;
    return message['content'] as String;
  }

  static const _sistemaPromptFosiles =
      'Eres un asistente especializado en paleontología y geología para aficionados. '
      'Ayudas a identificar fósiles, interpretar formaciones geológicas, entender la '
      'cronoestratigrafía y dar consejos prácticos de campo. '
      'Hablas con precisión científica pero en tono accesible y entusiasta. '
      'Cuando no estés seguro de algo, lo dices claramente y sugieres consultar '
      'a un geólogo profesional o a un museo. '
      'Respondes en castellano. Sé conciso (máximo 3 párrafos salvo que te pidan detalle).';
}
