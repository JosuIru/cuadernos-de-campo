import 'package:flutter/material.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart' show numeroParaEditar;
import 'package:url_launcher/url_launcher.dart' show launchUrl, LaunchMode;
import '../datos/configuracion.dart';

/// Ajustes → Inteligencia artificial: claves de Anthropic (identificación
/// por foto) y DeepSeek (chat) y modelo de Claude. Guarda solo esto, con
/// las mismas claves de [Configuracion] de siempre.
class PantallaAjustesIa extends StatefulWidget {
  const PantallaAjustesIa({super.key});

  @override
  State<PantallaAjustesIa> createState() => _PantallaAjustesIaState();
}

class _PantallaAjustesIaState extends State<PantallaAjustesIa> {
  final _controladorApiKey = TextEditingController();
  final _controladorDeepseekKey = TextEditingController();
  String _modeloSeleccionado = modeloPorDefecto;
  bool _ocultarClaves = true;
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
    _controladorDeepseekKey.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final apiKey = await Configuracion.obtenerApiKey();
    final apiKeyDeepseek = await Configuracion.obtenerApiKeyDeepseek();
    final modelo = await Configuracion.obtenerModelo();
    if (!mounted) return;
    setState(() {
      _controladorApiKey.text = apiKey;
      _controladorDeepseekKey.text = apiKeyDeepseek;
      _modeloSeleccionado = modelo;
      _cargado = true;
    });
  }

  Future<void> _guardar() async {
    await Configuracion.guardarApiKey(_controladorApiKey.text.trim());
    await Configuracion.guardarApiKeyDeepseek(_controladorDeepseekKey.text.trim());
    await Configuracion.guardarModelo(_modeloSeleccionado);
    if (!mounted) return;
    setState(() => _mensajeEstado = '✅ Ajustes de IA guardados');
  }

  /// Abre en el navegador la web donde se saca cada clave.
  Future<void> _abrirWeb(String direccion) async {
    try {
      await launchUrl(Uri.parse(direccion), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir el navegador. Entra en $direccion')),
      );
    }
  }

  Widget _botonConseguirClave(String texto, String direccion) => Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          icon: const Icon(Icons.open_in_new, size: 18),
          label: Text(texto),
          onPressed: () => _abrirWeb(direccion),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Inteligencia artificial')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Para identificar fósiles automáticamente, introduce tu API key de Anthropic. '
            'Se guarda solo en tu teléfono y se envía únicamente a api.anthropic.com. '
            'Consigue una en console.anthropic.com. La de DeepSeek es para el chat.',
            style: TextStyle(fontSize: 13),
          ),
          _botonConseguirClave('Conseguir clave de Anthropic', 'https://console.anthropic.com/settings/keys'),
          _botonConseguirClave('Conseguir clave de DeepSeek', 'https://platform.deepseek.com/api_keys'),
          SizedBox(height: 4),
          TextField(
            controller: _controladorApiKey,
            obscureText: _ocultarClaves,
            decoration: InputDecoration(
              labelText: 'API key de Anthropic',
              border: OutlineInputBorder(),
              hintText: 'sk-ant-…',
              suffixIcon: IconButton(
                icon: Icon(_ocultarClaves ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _ocultarClaves = !_ocultarClaves),
              ),
            ),
          ),
          SizedBox(height: 12),
          TextField(
            controller: _controladorDeepseekKey,
            obscureText: _ocultarClaves,
            decoration: InputDecoration(
              labelText: 'API key de DeepSeek (para chat)',
              border: OutlineInputBorder(),
              hintText: 'sk-…',
            ),
          ),
          SizedBox(height: 16),
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
                        subtitle: Text('${modelo.descripcion} ~${numeroParaEditar(modelo.precioOrientativoCentimosPorIdentificacion)} céntimos por foto.'),
                      ))
                  .toList(),
            ),
          ),
          SizedBox(height: 16),
          FilledButton(onPressed: _cargado ? _guardar : null, child: Text('Guardar')),
          if (_mensajeEstado != null) ...[
            SizedBox(height: 12),
            Center(child: Text(_mensajeEstado!, style: TextStyle(color: Theme.of(context).colorScheme.primary))),
          ],
        ],
      ),
    );
  }
}
