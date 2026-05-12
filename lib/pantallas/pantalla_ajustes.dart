import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import 'package:share_plus/share_plus.dart';
import '../datos/configuracion.dart';
import '../servicios/cache_teselas.dart';
import '../servicios/servicio_backup.dart';
import 'pantalla_mapas_offline.dart';
import 'sheet_donaciones.dart';

class PantallaAjustes extends StatefulWidget {
  PantallaAjustes({super.key});

  @override
  State<PantallaAjustes> createState() => _PantallaAjustesState();
}

class _PantallaAjustesState extends State<PantallaAjustes> {
  final _controladorApiKey = TextEditingController();
  final _controladorApiKeyPlantNet = TextEditingController();
  final _controladorDeepseekKey = TextEditingController();
  String _modeloSeleccionado = modeloPorDefecto;
  bool _ocultarApiKey = true;
  bool _ocultarApiKeyPlantNet = true;
  String? _mensajeEstado;
  String _resumenCache = 'Calculando…';

  @override
  void initState() {
    super.initState();
    _cargar();
    _refrescarResumenCache();
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
    });
  }

  Future<void> _refrescarResumenCache() async {
    final ficheros = await CacheTeselasDisco.contarFicheros();
    final bytes = await CacheTeselasDisco.tamanoTotalBytes();
    if (!mounted) return;
    setState(() {
      _resumenCache = '$ficheros teselas en caché · ${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    });
  }

  Future<void> _guardar() async {
    await Configuracion.guardarApiKey(_controladorApiKey.text.trim());
    await Configuracion.guardarApiKeyPlantNet(_controladorApiKeyPlantNet.text.trim());
    await Configuracion.guardarApiKeyDeepseek(_controladorDeepseekKey.text.trim());
    await Configuracion.guardarModelo(_modeloSeleccionado);
    if (!mounted) return;
    setState(() => _mensajeEstado = 'Ajustes guardados');
  }

  Future<void> _hacerBackup() async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(child: CircularProgressIndicator()),
    );
    try {
      final fichero = await exportarBackup();
      if (!mounted) return;
      Navigator.of(context).pop();
      await Share.shareXFiles(
        [XFile(fichero.path)],
        subject: 'Backup naturaleza',
        text: 'Copia de seguridad (${(await fichero.length()) ~/ 1024} KB)',
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error backup: $e')));
    }
  }

  Future<void> _restaurarBackup() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Restaurar copia de seguridad'),
        content: Text(
          'Esto reemplazará TODOS tus hallazgos, tracks y fotos actuales por los del fichero. ¿Continuar?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(SoleraL10n.t('cancelar'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(SoleraL10n.t('continuar'))),
        ],
      ),
    );
    if (confirmar != true) return;
    final resultado = await FilePicker.platform.pickFiles(type: FileType.any);
    if (resultado == null || resultado.files.isEmpty) return;
    final ruta = resultado.files.first.path;
    if (ruta == null) return;
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(child: CircularProgressIndicator()),
    );
    try {
      final restauracion = await restaurarBackup(File(ruta));
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Restaurados ${restauracion.hallazgosRestaurados} hallazgos y '
            '${restauracion.fotosRestauradas} fotos. Reinicia la app para ver los cambios.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(SoleraL10n.t('error_restaurando:_$e'))));
    }
  }

  Future<void> _vaciarCache() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        content: Text(
          '¿Vaciar la caché de mapas offline? Tendrás que volver a descargar para usar sin conexión.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(SoleraL10n.t('cancelar'))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Vaciar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    await CacheTeselasDisco.vaciar();
    await _refrescarResumenCache();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(SoleraL10n.t('ajustes'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Identificación con Claude', style: Theme.of(context).textTheme.titleLarge),
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
          Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Idioma / Language',
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              SelectorIdioma(),
            ],
          ),
        ),
      ),
      Divider(),
          SizedBox(height: 16),
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
          ...modelosDisponibles.map(
            (modelo) => RadioListTile<String>(
              value: modelo.id,
              groupValue: _modeloSeleccionado,
              onChanged: (valor) => setState(() => _modeloSeleccionado = valor ?? modeloPorDefecto),
              title: Text(modelo.nombre),
              subtitle: Text(
                '${modelo.descripcion} ~${modelo.precioOrientativoCentimosPorIdentificacion} céntimos por foto.',
              ),
            ),
          ),
          SizedBox(height: 16),
          FilledButton(onPressed: _guardar, child: Text('Guardar ajustes')),
          if (_mensajeEstado != null) ...[
            SizedBox(height: 12),
            Center(
              child: Text(_mensajeEstado!, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            ),
          ],
          SizedBox(height: 32),
          
          Text('Mapas sin conexión', style: Theme.of(context).textTheme.titleLarge),
          SizedBox(height: 8),
          Text(
            'Las teselas que veas en el mapa se guardan automáticamente en caché. '
            'Para precachear una zona entera (vista actual del mapa), usa el botón de descarga.',
            style: TextStyle(fontSize: 13),
          ),
          SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(6)),
            child: Text(_resumenCache),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: Icon(Icons.download),
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => PantallaMapasOffline()),
                    );
                    await _refrescarResumenCache();
                  },
                  label: Text('Descargar zona'),
                ),
              ),
              SizedBox(width: 8),
              OutlinedButton.icon(
                icon: Icon(Icons.delete_outline),
                onPressed: _vaciarCache,
                label: Text('Vaciar'),
              ),
            ],
          ),
          SizedBox(height: 32),
          
          Text('Copia de seguridad', style: Theme.of(context).textTheme.titleLarge),
          SizedBox(height: 8),
          Text(
            'Exporta toda tu base (hallazgos + tracks + fotos) en un fichero único .natbackup. '
            'Guárdalo en Drive/USB/correo. Para restaurar, selecciona el .natbackup; '
            'reemplazará los datos actuales.',
            style: TextStyle(fontSize: 13),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: Icon(Icons.backup),
                  onPressed: _hacerBackup,
                  label: Text('Hacer copia'),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(Icons.restore),
                  onPressed: _restaurarBackup,
                  label: Text('Restaurar copia'),
                ),
              ),
            ],
          ),
          SizedBox(height: 32),
          
          Text('Apoyar el proyecto', style: Theme.of(context).textTheme.titleLarge),
          SizedBox(height: 8),
          Text(
            'La app es y seguirá siendo gratuita y abierta para todos. '
            'Si te ha sido útil y puedes permitírtelo, una pequeña aportación '
            'voluntaria ayuda al mantenimiento, soporte y actualizaciones.',
            style: TextStyle(fontSize: 13),
          ),
          SizedBox(height: 12),
          FilledButton.tonalIcon(
            icon: Icon(Icons.favorite_outline),
            onPressed: () => mostrarSheetDonaciones(context),
            label: Text('Ver formas de apoyar'),
          ),
          SizedBox(height: 32),
          
          Text('Sobre la app', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text(
            'Naturaleza — Cuaderno de campo (animales, insectos y plantas). Versión Flutter para Android.\n\n'
            'Mapa base: OpenStreetMap, ESRI, OpenTopoMap. '
            'Identificación: Claude (Anthropic). Taxonomía y referencias: iNaturalist y GBIF.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
