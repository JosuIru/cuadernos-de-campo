import 'package:flutter/material.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart' show numeroParaEditar;
import '../datos/configuracion.dart';

/// Ajustes → Inteligencia artificial: claves de Claude (Anthropic),
/// Pl@ntNet y DeepSeek, y modelo de Claude. Guarda solo esto, con las
/// mismas claves de [Configuracion] de siempre.
class PantallaAjustesIa extends StatefulWidget {
  const PantallaAjustesIa({super.key});

  @override
  State<PantallaAjustesIa> createState() => _PantallaAjustesIaState();
}

class _PantallaAjustesIaState extends State<PantallaAjustesIa> {
  final _controladorApiKey = TextEditingController();
  final _controladorApiKeyPlantNet = TextEditingController();
  final _controladorDeepseekKey = TextEditingController();
  String _modeloSeleccionado = modeloPorDefecto;
  bool _ocultarApiKey = true;
  bool _ocultarApiKeyPlantNet = true;
  // Hasta que se lean los valores guardados no se deja guardar: si no,
  // un toque rápido pisaría las claves con campos vacíos.
  bool _cargado = false;
  String? _mensajeEstado;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _controladorApiKey.dispose();
    _controladorApiKeyPlantNet.dispose();
    _controladorDeepseekKey.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final apiKey = await Configuracion.obtenerApiKey();
    final apiKeyPlantNet = await Configuracion.obtenerApiKeyPlantNet();
    final apiKeyDeepseek = await Configuracion.obtenerApiKeyDeepseek();
    final modelo = await Configuracion.obtenerModelo();
    if (!mounted) return;
    setState(() {
      _controladorApiKey.text = apiKey;
      _controladorApiKeyPlantNet.text = apiKeyPlantNet;
      _controladorDeepseekKey.text = apiKeyDeepseek;
      _modeloSeleccionado = modelo;
      _cargado = true;
    });
  }

  Future<void> _guardar() async {
    await Configuracion.guardarApiKey(_controladorApiKey.text.trim());
    await Configuracion.guardarApiKeyPlantNet(_controladorApiKeyPlantNet.text.trim());
    await Configuracion.guardarApiKeyDeepseek(_controladorDeepseekKey.text.trim());
    await Configuracion.guardarModelo(_modeloSeleccionado);
    if (!mounted) return;
    setState(() => _mensajeEstado = 'Ajustes de IA guardados');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Inteligencia artificial')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Identificación con Claude', style: Theme.of(context).textTheme.titleMedium),
          SizedBox(height: 8),
          Text(
            'Para identificar especies automáticamente, introduce tu API key de Anthropic. '
            'Se guarda solo en tu teléfono y se envía únicamente a api.anthropic.com. '
            'Consigue una en console.anthropic.com.',
            style: TextStyle(fontSize: 13),
          ),
          SizedBox(height: 12),
          TextField(
            controller: _controladorApiKey,
            obscureText: _ocultarApiKey,
            decoration: InputDecoration(
              labelText: 'API key de Anthropic',
              border: OutlineInputBorder(),
              hintText: 'sk-ant-…',
              suffixIcon: IconButton(
                icon: Icon(_ocultarApiKey ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _ocultarApiKey = !_ocultarApiKey),
              ),
            ),
          ),
          SizedBox(height: 24),
          Text('Identificación de plantas con Pl@ntNet (gratis)', style: Theme.of(context).textTheme.titleMedium),
          SizedBox(height: 8),
          Text(
            'Pl@ntNet identifica plantas con una foto y devuelve un ranking de candidatas. '
            'El plan gratuito da 500 identificaciones al día. '
            'Regístrate en my.plantnet.org y pega aquí tu clave. '
            'La foto se envía solo cuando pulses el botón "Identificar planta" en la ficha de un hallazgo.',
            style: TextStyle(fontSize: 13),
          ),
          SizedBox(height: 12),
          TextField(
            controller: _controladorApiKeyPlantNet,
            obscureText: _ocultarApiKeyPlantNet,
            decoration: InputDecoration(
              labelText: 'Clave API de Pl@ntNet',
              border: OutlineInputBorder(),
              hintText: '2bxxxxxxxxxxxxxxxxxxxxxxxxx',
              suffixIcon: IconButton(
                icon: Icon(_ocultarApiKeyPlantNet ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _ocultarApiKeyPlantNet = !_ocultarApiKeyPlantNet),
              ),
            ),
          ),
          SizedBox(height: 24),
          Text('Chat con DeepSeek', style: Theme.of(context).textTheme.titleMedium),
          SizedBox(height: 12),
          TextField(
            controller: _controladorDeepseekKey,
            obscureText: _ocultarApiKey,
            decoration: InputDecoration(
              labelText: 'API key de DeepSeek (para chat)',
              border: OutlineInputBorder(),
              hintText: 'sk-…',
            ),
          ),
          SizedBox(height: 24),
          Text('Modelo de Claude', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          RadioGroup<String>(
            groupValue: _modeloSeleccionado,
            onChanged: (valor) => setState(() => _modeloSeleccionado = valor ?? modeloPorDefecto),
            child: Column(
              children: modelosDisponibles
                  .map((modelo) => RadioListTile<String>(
                        value: modelo.id,
                        title: Text(modelo.nombre),
                        subtitle: Text(
                          '${modelo.descripcion} ~${numeroParaEditar(modelo.precioOrientativoCentimosPorIdentificacion)} céntimos por foto.',
                        ),
                      ))
                  .toList(),
            ),
          ),
          SizedBox(height: 16),
          FilledButton(onPressed: _cargado ? _guardar : null, child: Text('Guardar')),
          if (_mensajeEstado != null) ...[
            SizedBox(height: 12),
            Center(
              child: Text(_mensajeEstado!, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            ),
          ],
        ],
      ),
    );
  }
}
