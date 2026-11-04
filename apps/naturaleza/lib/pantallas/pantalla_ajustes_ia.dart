import 'package:flutter/material.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart' show SoleraL10n, numeroParaEditar;
import 'package:url_launcher/url_launcher.dart' show launchUrl, LaunchMode;
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
    setState(() => _mensajeEstado = SoleraL10n.t('fos.ajus_ia_guardados'));
  }

  /// Abre en el navegador la web donde se saca cada clave.
  Future<void> _abrirWeb(String direccion) async {
    try {
      await launchUrl(Uri.parse(direccion), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(SoleraL10n.tf('fos.ajus_no_abrir_navegador', {'direccion': direccion}))),
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
      appBar: AppBar(title: Text(SoleraL10n.t('seccion_integraciones'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(SoleraL10n.t('nat.ajus_identificacion_claude'), style: Theme.of(context).textTheme.titleMedium),
          SizedBox(height: 8),
          Text(
            SoleraL10n.t('nat.ajus_ia_explicacion'),
            style: TextStyle(fontSize: 13),
          ),
          _botonConseguirClave(SoleraL10n.t('fos.ajus_conseguir_anthropic'), 'https://console.anthropic.com/settings/keys'),
          SizedBox(height: 4),
          TextField(
            controller: _controladorApiKey,
            obscureText: _ocultarApiKey,
            decoration: InputDecoration(
              labelText: SoleraL10n.t('fos.ajus_api_anthropic'),
              border: OutlineInputBorder(),
              hintText: 'sk-ant-…',
              suffixIcon: IconButton(
                icon: Icon(_ocultarApiKey ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _ocultarApiKey = !_ocultarApiKey),
              ),
            ),
          ),
          SizedBox(height: 24),
          Text(SoleraL10n.t('nat.ajus_plantnet_titulo'), style: Theme.of(context).textTheme.titleMedium),
          SizedBox(height: 8),
          Text(
            SoleraL10n.t('nat.ajus_plantnet_explicacion'),
            style: TextStyle(fontSize: 13),
          ),
          _botonConseguirClave(SoleraL10n.t('nat.ajus_conseguir_plantnet'), 'https://my.plantnet.org/'),
          SizedBox(height: 4),
          TextField(
            controller: _controladorApiKeyPlantNet,
            obscureText: _ocultarApiKeyPlantNet,
            decoration: InputDecoration(
              labelText: SoleraL10n.t('nat.ajus_api_plantnet'),
              border: OutlineInputBorder(),
              hintText: '2bxxxxxxxxxxxxxxxxxxxxxxxxx',
              suffixIcon: IconButton(
                icon: Icon(_ocultarApiKeyPlantNet ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _ocultarApiKeyPlantNet = !_ocultarApiKeyPlantNet),
              ),
            ),
          ),
          SizedBox(height: 24),
          Text(SoleraL10n.t('nat.ajus_chat_deepseek'), style: Theme.of(context).textTheme.titleMedium),
          _botonConseguirClave(SoleraL10n.t('fos.ajus_conseguir_deepseek'), 'https://platform.deepseek.com/api_keys'),
          SizedBox(height: 4),
          TextField(
            controller: _controladorDeepseekKey,
            obscureText: _ocultarApiKey,
            decoration: InputDecoration(
              labelText: SoleraL10n.t('fos.ajus_api_deepseek'),
              border: OutlineInputBorder(),
              hintText: 'sk-…',
            ),
          ),
          SizedBox(height: 24),
          Text(SoleraL10n.t('fos.ajus_modelo_claude'), style: TextStyle(fontWeight: FontWeight.bold)),
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
                          SoleraL10n.tf('fos.ajus_modelo_precio', {
                            'descripcion': SoleraL10n.t(modelo.claveDescripcion),
                            'precio': numeroParaEditar(modelo.precioOrientativoCentimosPorIdentificacion),
                          }),
                        ),
                      ))
                  .toList(),
            ),
          ),
          SizedBox(height: 16),
          FilledButton(onPressed: _cargado ? _guardar : null, child: Text(SoleraL10n.t('guardar'))),
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
