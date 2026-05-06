import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../datos/configuracion.dart';
import '../servicios/cache_teselas.dart';
import '../servicios/servicio_backup.dart';
import 'pantalla_mapas_offline.dart';

class PantallaAjustes extends StatefulWidget {
  const PantallaAjustes({super.key});

  @override
  State<PantallaAjustes> createState() => _PantallaAjustesState();
}

class _PantallaAjustesState extends State<PantallaAjustes> {
  final _controladorApiKey = TextEditingController();
  String _modeloSeleccionado = modeloPorDefecto;
  bool _ocultarApiKey = true;
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
    super.dispose();
  }

  Future<void> _cargar() async {
    final apiKey = await Configuracion.obtenerApiKey();
    final modelo = await Configuracion.obtenerModelo();
    if (!mounted) return;
    setState(() {
      _controladorApiKey.text = apiKey;
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
    await Configuracion.guardarModelo(_modeloSeleccionado);
    if (!mounted) return;
    setState(() => _mensajeEstado = 'Ajustes guardados');
  }

  Future<void> _hacerBackup() async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
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
        title: const Text('Restaurar copia de seguridad'),
        content: const Text(
          'Esto reemplazará TODOS tus hallazgos, tracks y fotos actuales por los del fichero. ¿Continuar?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continuar')),
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
      builder: (_) => const Center(child: CircularProgressIndicator()),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error restaurando: $e')));
    }
  }

  Future<void> _vaciarCache() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        content: const Text(
          '¿Vaciar la caché de mapas offline? Tendrás que volver a descargar para usar sin conexión.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Vaciar', style: TextStyle(color: Colors.red)),
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
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Identificación con Claude', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'Para identificar especies automáticamente, introduce tu API key de Anthropic. '
            'Se guarda solo en tu teléfono y se envía únicamente a api.anthropic.com. '
            'Consigue una en console.anthropic.com.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controladorApiKey,
            obscureText: _ocultarApiKey,
            decoration: InputDecoration(
              labelText: 'API key de Anthropic',
              border: const OutlineInputBorder(),
              hintText: 'sk-ant-…',
              suffixIcon: IconButton(
                icon: Icon(_ocultarApiKey ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _ocultarApiKey = !_ocultarApiKey),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Modelo', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
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
          const SizedBox(height: 16),
          FilledButton(onPressed: _guardar, child: const Text('Guardar ajustes')),
          if (_mensajeEstado != null) ...[
            const SizedBox(height: 12),
            Center(
              child: Text(_mensajeEstado!, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            ),
          ],
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          Text('Mapas sin conexión', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'Las teselas que veas en el mapa se guardan automáticamente en caché. '
            'Para precachear una zona entera (vista actual del mapa), usa el botón de descarga.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(6)),
            child: Text(_resumenCache),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.download),
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PantallaMapasOffline()),
                    );
                    await _refrescarResumenCache();
                  },
                  label: const Text('Descargar zona'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline),
                onPressed: _vaciarCache,
                label: const Text('Vaciar'),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          Text('Copia de seguridad', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'Exporta toda tu base (hallazgos + tracks + fotos) en un fichero único .natbackup. '
            'Guárdalo en Drive/USB/correo. Para restaurar, selecciona el .natbackup; '
            'reemplazará los datos actuales.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.backup),
                  onPressed: _hacerBackup,
                  label: const Text('Hacer copia'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.restore),
                  onPressed: _restaurarBackup,
                  label: const Text('Restaurar copia'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          const Text('Sobre la app', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
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
