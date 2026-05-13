import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../datos/configuracion.dart';
import '../servicios/servicio_chat.dart';

class PantallaChat extends StatefulWidget {
  final String? contextoInicial;
  final String sistemaPrompt;

  const PantallaChat({super.key, this.contextoInicial, this.sistemaPrompt = sistemaFosiles});

  static const sistemaFosiles =
      'Eres un asistente especializado en paleontología y geología para aficionados. '
      'Ayudas a identificar fósiles, interpretar formaciones geológicas, entender la '
      'cronoestratigrafía y dar consejos prácticos de campo. '
      'Hablas con precisión científica pero en tono accesible y entusiasta. '
      'Cuando no estés seguro de algo, lo dices claramente y sugieres consultar '
      'a un geólogo profesional o a un museo. '
      'Respondes en castellano. Sé conciso (máximo 3 párrafos salvo que te pidan detalle).';

  static const sistemaNaturaleza =
      'Eres un asistente especializado en naturaleza, fauna, flora y biodiversidad. '
      'Ayudas a identificar especies animales y vegetales, entender ecosistemas, '
      'dar consejos de observación responsable y buenas prácticas de campo. '
      'Hablas con precisión científica pero en tono accesible y entusiasta. '
      'Cuando no estés seguro de algo, lo dices claramente. '
      'Respondes en castellano. Sé conciso (máximo 3 párrafos salvo que te pidan detalle).';

  static const sistemaSolera =
      'Eres un asistente especializado en agricultura, viticultura y apicultura. '
      'Ayudas a identificar plagas y enfermedades, interpretar síntomas, sugerir '
      'tratamientos (siempre mencionando que consultes a un técnico antes de aplicar), '
      'y dar consejos de manejo agronómico. Hablas con precisión técnica pero en tono '
      'accesible. Cuando no estés seguro, lo dices y sugieres consultar a un especialista. '
      'Respondes en castellano. Sé conciso (máximo 3 párrafos salvo que te pidan detalle).';

  @override
  State<PantallaChat> createState() => _PantallaChatState();
}

class _PantallaChatState extends State<PantallaChat> {
  final _controladorMensaje = TextEditingController();
  final _scrollController = ScrollController();
  final _selectorImagen = ImagePicker();
  final List<MensajeChat> _mensajes = [];
  bool _enviando = false;
  ProveedorChat _proveedor = ProveedorChat.deepseek;
  ServicioChat? _servicio;
  String? _imagenAdjunta;

  @override
  void initState() {
    super.initState();
    _inicializarServicio();
    if (widget.contextoInicial != null && widget.contextoInicial!.isNotEmpty) {
      _mensajes.add(MensajeChat(
        texto: widget.contextoInicial!,
        esUsuario: false,
      ));
    }
  }

  @override
  void dispose() {
    _controladorMensaje.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _inicializarServicio() async {
    final apiKeyClaude = await Configuracion.obtenerApiKey();
    final apiKeyDeepseek = await Configuracion.obtenerApiKeyDeepseek();
    final modeloClaude = await Configuracion.obtenerModelo();
    setState(() {
      _servicio = ServicioChat(
        apiKeyClaude: apiKeyClaude,
        apiKeyDeepseek: apiKeyDeepseek,
        modeloClaude: modeloClaude,
      );
    });
  }

  Future<void> _hacerFoto() async {
    final foto = await _selectorImagen.pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 1200);
    if (foto != null) setState(() => _imagenAdjunta = foto.path);
  }

  Future<void> _elegirDeGaleria() async {
    final foto = await _selectorImagen.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1200);
    if (foto != null) setState(() => _imagenAdjunta = foto.path);
  }

  Future<void> _enviar() async {
    final texto = _controladorMensaje.text.trim();
    final imagen = _imagenAdjunta;
    if (texto.isEmpty && imagen == null || _enviando) return;
    _controladorMensaje.clear();

    // Si hay imagen, forzar Claude
    final proveedor = imagen != null ? ProveedorChat.claude : _proveedor;

    final clave = proveedor == ProveedorChat.claude
        ? await Configuracion.obtenerApiKey()
        : await Configuracion.obtenerApiKeyDeepseek();

    if (clave.isEmpty) {
      final nombre = proveedor == ProveedorChat.claude ? 'Claude' : 'DeepSeek';
      setState(() {
        _mensajes.add(MensajeChat(
          texto: 'Necesitas configurar tu API key de $nombre en Ajustes.',
          esUsuario: false,
          proveedor: proveedor,
        ));
      });
      return;
    }

    setState(() {
      _mensajes.add(MensajeChat(
        texto: texto.isNotEmpty ? texto : '¿Qué ves en esta imagen?',
        esUsuario: true,
        rutaImagen: imagen,
      ));
      _imagenAdjunta = null;
      _enviando = true;
    });
    _scrollAbajo();

    try {
      final respuesta = await _servicio!.enviarMensaje(
        texto.isNotEmpty ? texto : '¿Qué ves en esta imagen? Identifícala por favor.',
        proveedor: proveedor,
        historial: _mensajes.length > 1
            ? _mensajes.sublist(0, _mensajes.length - 1)
            : null,
        sistemaPrompt: widget.sistemaPrompt,
        rutaImagen: imagen,
      );
      if (!mounted) return;
      setState(() {
        _mensajes.add(MensajeChat(
          texto: respuesta,
          esUsuario: false,
          proveedor: proveedor,
        ));
        _enviando = false;
      });
      _scrollAbajo();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mensajes.add(MensajeChat(
          texto: 'Error: $e',
          esUsuario: false,
          proveedor: proveedor,
        ));
        _enviando = false;
      });
      _scrollAbajo();
    }
  }

  void _scrollAbajo() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        actions: [
          SegmentedButton<ProveedorChat>(
            segments: const [
              ButtonSegment(
                value: ProveedorChat.deepseek,
                label: Text('DeepSeek', style: TextStyle(fontSize: 11)),
                icon: Icon(Icons.bolt, size: 16),
              ),
              ButtonSegment(
                value: ProveedorChat.claude,
                label: Text('Claude', style: TextStyle(fontSize: 11)),
                icon: Icon(Icons.auto_awesome, size: 16),
              ),
            ],
            selected: {_proveedor},
            onSelectionChanged: (s) => setState(() => _proveedor = s.first),
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: _mensajes.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: esquema.primary.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        const Text(
                          'Pregúntame lo que quieras sobre fósiles,\ngeología, identificación, yacimientos…',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: _mensajes.length + (_enviando ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i >= _mensajes.length) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: LinearProgressIndicator(),
                      );
                    }
                    final m = _mensajes[i];
                    final esUsuario = m.esUsuario;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment:
                            esUsuario ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.82,
                            ),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: esUsuario
                                  ? esquema.primary.withValues(alpha: 0.1)
                                  : esquema.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12).copyWith(
                                bottomRight: esUsuario ? Radius.zero : null,
                                bottomLeft: esUsuario ? null : Radius.zero,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (m.tieneImagen)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(File(m.rutaImagen!),
                                          height: 200,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          cacheWidth: 800,
                                          cacheHeight: 400),
                                    ),
                                  ),
                                if (m.texto.isNotEmpty)
                                  Text(m.texto, style: const TextStyle(fontSize: 14, height: 1.4)),
                              ],
                            ),
                          ),
                          if (m.proveedor != null && !esUsuario)
                            Padding(
                              padding: const EdgeInsets.only(top: 2, left: 4),
                              child: Text(
                                'vía ${m.proveedor == ProveedorChat.claude ? 'Claude' : 'DeepSeek'}',
                                style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_imagenAdjunta != null)
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.file(File(_imagenAdjunta!),
                          height: 48,
                          width: 48,
                          fit: BoxFit.cover,
                          cacheWidth: 96,
                          cacheHeight: 96),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Imagen adjunta — se enviará a Claude',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _imagenAdjunta = null),
                      visualDensity: VisualDensity.compact,
                    ),
                  ]),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.camera_alt, size: 22),
                    tooltip: 'Hacer foto',
                    onPressed: _hacerFoto,
                  ),
                  IconButton(
                    icon: const Icon(Icons.photo_library, size: 22),
                    tooltip: 'Galería',
                    onPressed: _elegirDeGaleria,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controladorMensaje,
                      decoration: InputDecoration(
                        hintText: 'Escribe tu pregunta…',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _enviar(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _enviando ? null : _enviar,
                    icon: _enviando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}
