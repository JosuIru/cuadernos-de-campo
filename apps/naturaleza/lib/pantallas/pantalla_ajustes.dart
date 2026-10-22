import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import 'package:share_plus/share_plus.dart';
import '../servicios/cache_teselas.dart';
import '../servicios/checker_actualizaciones_naturaleza.dart';
import '../servicios/servicio_backup.dart';
import 'pantalla_ajustes_ia.dart';
import 'pantalla_mapas_offline.dart';
import 'sheet_donaciones.dart';

/// Ajustes por secciones: General · Inteligencia artificial (subpantalla
/// con su propio Guardar) · Mapas y datos · Acerca de.
class PantallaAjustes extends StatefulWidget {
  const PantallaAjustes({super.key});

  @override
  State<PantallaAjustes> createState() => _PantallaAjustesState();
}

class _PantallaAjustesState extends State<PantallaAjustes> {
  String _resumenCache = 'Calculando…';

  @override
  void initState() {
    super.initState();
    _refrescarResumenCache();
  }

  Future<void> _refrescarResumenCache() async {
    final ficheros = await CacheTeselasDisco.contarFicheros();
    final bytes = await CacheTeselasDisco.tamanoTotalBytes();
    if (!mounted) return;
    setState(() {
      _resumenCache = '$ficheros teselas en caché · ${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    });
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

  void _abrir(Widget pantalla) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => pantalla));
  }

  /// Contenido de una sección con el mismo margen lateral que su cabecera.
  Widget _bloque(List<Widget> hijos) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: hijos),
    );
  }

  Widget _subtitulo(String texto) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Text(texto, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }

  Widget _explicacion(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(texto, style: TextStyle(fontSize: 13)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(SoleraL10n.t('ajustes'))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const CabeceraSeccionAjustes('General'),
          _bloque([
            _subtitulo('Idioma / Language'),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectorIdioma(onCambio: () => setState(() {})),
            ),
          ]),

          const CabeceraSeccionAjustes('Inteligencia artificial'),
          ListTile(
            leading: Icon(Icons.auto_awesome_outlined),
            title: Text('Claves y modelo'),
            subtitle: Text('Claude para identificar, Pl@ntNet para plantas y DeepSeek para el chat'),
            trailing: Icon(Icons.chevron_right),
            onTap: () => _abrir(const PantallaAjustesIa()),
          ),

          const CabeceraSeccionAjustes('Mapas y datos'),
          _bloque([
            _subtitulo('Mapas sin conexión'),
            _explicacion(
              'Las teselas que veas en el mapa se guardan automáticamente en caché. '
              'Para precachear una zona entera (vista actual del mapa), usa el botón de descarga.',
            ),
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
            SizedBox(height: 8),
            _subtitulo('Copia de seguridad'),
            _explicacion(
              'Exporta toda tu base (hallazgos + tracks + fotos) en un fichero único .natbackup. '
              'Guárdalo en Drive/USB/correo. Para restaurar, selecciona el .natbackup; '
              'reemplazará los datos actuales.',
            ),
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
          ]),

          const CabeceraSeccionAjustes('Acerca de'),
          ListTile(
            leading: Icon(Icons.system_update),
            title: Text('Comprobar actualizaciones'),
            trailing: Icon(Icons.chevron_right),
            onTap: () => _abrir(const PantallaEstadoActualizaciones(
              config: configActualizacionesNaturaleza,
              nombreApp: 'Naturaleza',
            )),
          ),
          _bloque([
            _subtitulo('Apoyar el proyecto'),
            _explicacion(
              'La app es y seguirá siendo gratuita y abierta para todos. '
              'Si te ha sido útil y puedes permitírtelo, una pequeña aportación '
              'voluntaria ayuda al mantenimiento, soporte y actualizaciones.',
            ),
            FilledButton.tonalIcon(
              icon: Icon(Icons.favorite_outline),
              onPressed: () => mostrarSheetDonaciones(context),
              label: Text('Ver formas de apoyar'),
            ),
            SizedBox(height: 8),
            _subtitulo('Sobre la app'),
            Text(
              'Naturaleza — Cuaderno de campo (animales, insectos y plantas). Versión Flutter para Android.\n\n'
              'Mapa base: OpenStreetMap, ESRI, OpenTopoMap. '
              'Identificación: Claude (Anthropic). Taxonomía y referencias: iNaturalist y GBIF.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ]),
        ],
      ),
    );
  }
}
