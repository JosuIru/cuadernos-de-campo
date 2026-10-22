import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import 'package:share_plus/share_plus.dart';
import '../comunidad/cliente_comunidad.dart';
import '../comunidad/feature_flag_comunidad.dart';
import '../datos/yacimientos_curados.dart';
import '../servicios/cache_teselas.dart';
import '../servicios/checker_actualizaciones_fosiles.dart';
import '../servicios/servicio_backup.dart';
import '../servicios/geofencing.dart';
import 'pantalla_ajustes_ia.dart';
import 'pantalla_ayuda_mapa.dart';
import 'pantalla_mapas_offline.dart';
import 'pantalla_onboarding.dart';
import 'pantalla_perfil_identidad.dart';
import 'sheet_donaciones.dart';

/// Ajustes por secciones: General · Inteligencia artificial · Perfil e
/// identidad · Mapas y datos · Privacidad · Acerca de. La IA y el perfil
/// viven en subpantallas con su propio Guardar.
class PantallaAjustes extends StatefulWidget {
  PantallaAjustes({super.key});

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
    showDialog<void>(context: context, barrierDismissible: false, builder: (_) => Center(child: CircularProgressIndicator()));
    try {
      final fichero = await exportarBackup();
      if (!mounted) return;
      Navigator.of(context).pop();
      await Share.shareXFiles([XFile(fichero.path)], subject: 'Backup fósiles', text: 'Copia de seguridad de Fósiles (${(await fichero.length()) ~/ 1024} KB)');
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
        content: Text('Esto reemplazará TODOS tus hallazgos, tracks y fotos actuales por los del fichero. ¿Continuar?'),
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
    showDialog<void>(context: context, barrierDismissible: false, builder: (_) => Center(child: CircularProgressIndicator()));
    try {
      final r = await restaurarBackup(File(ruta));
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Restaurados ${r.hallazgosRestaurados} hallazgos y ${r.fotosRestauradas} fotos. Reinicia la app para ver los cambios.')));
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(SoleraL10n.t('error_restaurando:_$e'))));
    }
  }

  void _resetearGeofencing() {
    Geofencer.instancia.resetear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Avisos reactivados. Volverán a sonar al entrar en cada yacimiento.')),
    );
  }

  void _probarGeofencing() {
    if (yacimientosCurados.isEmpty) return;
    final y = yacimientosCurados.first;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${y.emoji} (Prueba) Estás en ${y.nombre}.'),
        duration: Duration(seconds: 6),
      ),
    );
  }

  Future<void> _solicitarBorradoAportacionesComunidad(
      BuildContext contextoExterior) async {
    final controladorEmail = TextEditingController();
    final email = await showDialog<String>(
      context: contextoExterior,
      builder: (dialogoContext) => AlertDialog(
        title: Text('Borrar mis aportaciones'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Introduce el email con el que enviaste las aportaciones. '
              'Te mandaremos un enlace; al pulsarlo se borrarán todas tus '
              'fotos (pendientes y aprobadas).',
              style: TextStyle(fontSize: 13),
            ),
            SizedBox(height: 12),
            TextField(
              controller: controladorEmail,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogoContext).pop(null),
            child: Text(SoleraL10n.t('cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogoContext)
                .pop(controladorEmail.text.trim()),
            child: Text('Enviar'),
          ),
        ],
      ),
    );
    if (email == null || email.isEmpty) return;
    try {
      await ClienteComunidad().solicitarBorradoPorEmail(email);
      if (!mounted || !contextoExterior.mounted) return;
      ScaffoldMessenger.of(contextoExterior).showSnackBar(SnackBar(
          content: Text(
              'Solicitud enviada. Revisa tu email para confirmar el borrado.')));
    } catch (e) {
      if (!mounted || !contextoExterior.mounted) return;
      ScaffoldMessenger.of(contextoExterior)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _vaciarCache() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        content: Text('¿Vaciar la caché de mapas offline? Tendrás que volver a descargar para usar sin conexión.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(SoleraL10n.t('cancelar'))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Vaciar', style: TextStyle(color: Colors.red))),
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
            subtitle: Text('Anthropic para identificar por foto, DeepSeek para el chat'),
            trailing: Icon(Icons.chevron_right),
            onTap: () => _abrir(const PantallaAjustesIa()),
          ),

          const CabeceraSeccionAjustes('Perfil e identidad'),
          ListTile(
            leading: Icon(Icons.badge_outlined),
            title: Text('Perfil del descubridor e identidad'),
            subtitle: Text('Nombre para los certificados, identidad criptográfica, verificar certificados y Modo Experto'),
            trailing: Icon(Icons.chevron_right),
            onTap: () => _abrir(const PantallaPerfilIdentidad()),
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
                      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PantallaMapasOffline()));
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
              'Exporta toda tu base (hallazgos + tracks + fotos) en un fichero único .fosbackup. '
              'Guárdalo en Drive/USB/correo. Para restaurar, selecciona el .fosbackup; reemplazará los datos actuales.',
            ),
            Row(children: [
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
            ]),
            SizedBox(height: 8),
            _subtitulo('Asistente de campo'),
            _explicacion(
              'Cuando el GPS detecta que estás dentro de un radio de 250 m de un yacimiento curado, '
              'aparece un aviso en el mapa con el botón "Ver ficha". Cada yacimiento te avisa una sola vez por sesión.',
            ),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(Icons.refresh),
                  onPressed: _resetearGeofencing,
                  label: Text('Reactivar avisos'),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(Icons.notifications_active),
                  onPressed: _probarGeofencing,
                  label: Text('Probar aviso'),
                ),
              ),
            ]),
          ]),

          if (kFeatureComunidadHabilitada) ...[
            const CabeceraSeccionAjustes('Privacidad'),
            _bloque([
              _subtitulo('Tus aportaciones a la comunidad'),
              _explicacion(
                'Si has compartido fotos con la comunidad puedes pedir su '
                'borrado en cualquier momento (RGPD). Te llegará un enlace '
                'al email indicado; haciendo click se borrarán todas tus '
                'aportaciones, incluso las que ya estén publicadas.',
              ),
              OutlinedButton.icon(
                icon: Icon(Icons.delete_sweep_outlined),
                onPressed: () => _solicitarBorradoAportacionesComunidad(context),
                label: Text('Borrar mis aportaciones'),
              ),
            ]),
          ],

          const CabeceraSeccionAjustes('Acerca de'),
          ListTile(
            leading: Icon(Icons.system_update),
            title: Text('Comprobar actualizaciones'),
            trailing: Icon(Icons.chevron_right),
            onTap: () => _abrir(const PantallaEstadoActualizaciones(
              config: configActualizacionesFosiles,
              nombreApp: 'Fósiles',
            )),
          ),
          ListTile(
            leading: Icon(Icons.map_outlined),
            title: Text('Cómo leer el mapa'),
            subtitle: Text('Capas geológicas, otras capas y sugerencias de fósiles'),
            trailing: Icon(Icons.chevron_right),
            onTap: () => _abrir(const PantallaAyudaMapa()),
          ),
          ListTile(
            leading: Icon(Icons.help_outline),
            title: Text('Ver tour de presentación'),
            trailing: Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) => const PantallaOnboarding(
                  marcarComoVistoAlSalir: false,
                ),
              ),
            ),
          ),
          _bloque([
            _subtitulo('Sobre la app'),
            _explicacion(
              'Cuaderno de campo de fósiles para adulto aficionado. Anota '
              'hallazgos georreferenciados con foto, edad, formación, '
              'strike/dip del estrato; consulta el contexto geológico del '
              'IGME en el punto donde pinches; y guarda una guía local de '
              'fósiles y minerales por período.',
            ),
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
            _subtitulo('Datos y fuentes'),
            Text(
              'Datos geológicos: IGME (GEODE 50, MAGNA 50, Edades 1M, '
              'Litologías 1M, IELIG). Mapa base: OpenStreetMap, ESRI, '
              'OpenTopoMap. Cuevas y megalitos: OpenStreetMap (Overpass). '
              'Imágenes y descripciones complementarias: Wikipedia '
              '(CC-BY-SA). Versión Flutter para Android.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ]),
        ],
      ),
    );
  }
}
