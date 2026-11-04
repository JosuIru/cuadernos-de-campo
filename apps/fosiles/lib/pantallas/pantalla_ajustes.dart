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
  // Se guardan los números y no el texto: así el resumen cambia de idioma
  // al cambiarlo en esta misma pantalla.
  int? _ficherosCache;
  int _bytesCache = 0;

  String get _resumenCache => _ficherosCache == null
      ? SoleraL10n.t('fos.ajus_calculando')
      : SoleraL10n.tf('fos.ajus_resumen_cache', {
          'n': '$_ficherosCache',
          'mb': formatearNumero(_bytesCache / 1024 / 1024, decimales: 1),
        });

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
      _ficherosCache = ficheros;
      _bytesCache = bytes;
    });
  }

  Future<void> _hacerBackup() async {
    showDialog<void>(context: context, barrierDismissible: false, builder: (_) => Center(child: CircularProgressIndicator()));
    try {
      final fichero = await exportarBackup();
      if (!mounted) return;
      Navigator.of(context).pop();
      final kilobytes = (await fichero.length()) ~/ 1024;
      await Share.shareXFiles([XFile(fichero.path)], subject: SoleraL10n.t('fos.ajus_backup_asunto'), text: SoleraL10n.tf('fos.ajus_backup_texto', {'kb': '$kilobytes'}));
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${SoleraL10n.t('fos.ajus_error_backup')}: $e')));
    }
  }

  Future<void> _restaurarBackup() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(SoleraL10n.t('fos.ajus_restaurar_titulo')),
        content: Text(SoleraL10n.t('fos.ajus_restaurar_aviso')),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(SoleraL10n.tf('fos.ajus_restaurados', {'hallazgos': '${r.hallazgosRestaurados}', 'fotos': '${r.fotosRestauradas}'}))));
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${SoleraL10n.t('error_restaurando')}: $e')));
    }
  }

  void _resetearGeofencing() {
    Geofencer.instancia.resetear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(SoleraL10n.t('fos.ajus_avisos_reactivados'))),
    );
  }

  void _probarGeofencing() {
    if (yacimientosCurados.isEmpty) return;
    final y = yacimientosCurados.first;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(SoleraL10n.tf('fos.ajus_prueba_aviso', {'emoji': y.emoji, 'nombre': y.nombre})),
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
        title: Text(SoleraL10n.t('fos.ajus_borrar_aportaciones')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              SoleraL10n.t('fos.ajus_borrar_aportaciones_texto'),
              style: TextStyle(fontSize: 13),
            ),
            SizedBox(height: 12),
            TextField(
              controller: controladorEmail,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: SoleraL10n.t('fos.ajus_email'),
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
            child: Text(SoleraL10n.t('fos.ajus_enviar')),
          ),
        ],
      ),
    );
    if (email == null || email.isEmpty) return;
    try {
      await ClienteComunidad().solicitarBorradoPorEmail(email);
      if (!mounted || !contextoExterior.mounted) return;
      ScaffoldMessenger.of(contextoExterior).showSnackBar(SnackBar(
          content: Text(SoleraL10n.t('fos.ajus_solicitud_enviada'))));
    } catch (e) {
      if (!mounted || !contextoExterior.mounted) return;
      ScaffoldMessenger.of(contextoExterior)
          .showSnackBar(SnackBar(content: Text('${SoleraL10n.t('error')}: $e')));
    }
  }

  Future<void> _vaciarCache() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        content: Text(SoleraL10n.t('fos.ajus_vaciar_cache_pregunta')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(SoleraL10n.t('cancelar'))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(SoleraL10n.t('fos.ajus_vaciar'), style: TextStyle(color: Colors.red))),
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
          CabeceraSeccionAjustes(SoleraL10n.t('fos.ajus_sec_general')),
          _bloque([
            _subtitulo(SoleraL10n.t('fos.ajus_idioma')),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectorIdioma(onCambio: () => setState(() {})),
            ),
          ]),

          CabeceraSeccionAjustes(SoleraL10n.t('seccion_integraciones')),
          ListTile(
            leading: Icon(Icons.auto_awesome_outlined),
            title: Text(SoleraL10n.t('fos.ajus_claves_modelo')),
            subtitle: Text(SoleraL10n.t('fos.ajus_claves_modelo_sub')),
            trailing: Icon(Icons.chevron_right),
            onTap: () => _abrir(const PantallaAjustesIa()),
          ),

          CabeceraSeccionAjustes(SoleraL10n.t('fos.ajus_sec_perfil')),
          ListTile(
            leading: Icon(Icons.badge_outlined),
            title: Text(SoleraL10n.t('fos.ajus_perfil_titulo')),
            subtitle: Text(SoleraL10n.t('fos.ajus_perfil_sub')),
            trailing: Icon(Icons.chevron_right),
            onTap: () => _abrir(const PantallaPerfilIdentidad()),
          ),

          CabeceraSeccionAjustes(SoleraL10n.t('fos.ajus_sec_mapas_datos')),
          _bloque([
            _subtitulo(SoleraL10n.t('fos.ajus_mapas_sin_conexion')),
            _explicacion(SoleraL10n.t('fos.ajus_mapas_explicacion')),
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
                    label: Text(SoleraL10n.t('fos.ajus_descargar_zona')),
                  ),
                ),
                SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: Icon(Icons.delete_outline),
                  onPressed: _vaciarCache,
                  label: Text(SoleraL10n.t('fos.ajus_vaciar')),
                ),
              ],
            ),
            SizedBox(height: 8),
            _subtitulo(SoleraL10n.t('copia_de_seguridad')),
            _explicacion(SoleraL10n.t('fos.ajus_backup_explicacion')),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  icon: Icon(Icons.backup),
                  onPressed: _hacerBackup,
                  label: Text(SoleraL10n.t('fos.ajus_hacer_copia')),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(Icons.restore),
                  onPressed: _restaurarBackup,
                  label: Text(SoleraL10n.t('fos.ajus_restaurar_copia')),
                ),
              ),
            ]),
            SizedBox(height: 8),
            _subtitulo(SoleraL10n.t('fos.ajus_asistente_campo')),
            _explicacion(SoleraL10n.t('fos.ajus_asistente_explicacion')),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(Icons.refresh),
                  onPressed: _resetearGeofencing,
                  label: Text(SoleraL10n.t('fos.ajus_reactivar_avisos')),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(Icons.notifications_active),
                  onPressed: _probarGeofencing,
                  label: Text(SoleraL10n.t('fos.ajus_probar_aviso')),
                ),
              ),
            ]),
          ]),

          if (kFeatureComunidadHabilitada) ...[
            CabeceraSeccionAjustes(SoleraL10n.t('fos.ajus_sec_privacidad')),
            _bloque([
              _subtitulo(SoleraL10n.t('fos.ajus_tus_aportaciones')),
              _explicacion(SoleraL10n.t('fos.ajus_aportaciones_explicacion')),
              OutlinedButton.icon(
                icon: Icon(Icons.delete_sweep_outlined),
                onPressed: () => _solicitarBorradoAportacionesComunidad(context),
                label: Text(SoleraL10n.t('fos.ajus_borrar_aportaciones')),
              ),
            ]),
          ],

          CabeceraSeccionAjustes(SoleraL10n.t('acerca_de')),
          ListTile(
            leading: Icon(Icons.system_update),
            title: Text(SoleraL10n.t('comprobar_actualizaciones')),
            trailing: Icon(Icons.chevron_right),
            onTap: () => _abrir(const PantallaEstadoActualizaciones(
              config: configActualizacionesFosiles,
              nombreApp: 'Fósiles',
            )),
          ),
          ListTile(
            leading: Icon(Icons.map_outlined),
            title: Text(SoleraL10n.t('fos.ajus_como_leer_mapa')),
            subtitle: Text(SoleraL10n.t('fos.ajus_como_leer_mapa_sub')),
            trailing: Icon(Icons.chevron_right),
            onTap: () => _abrir(const PantallaAyudaMapa()),
          ),
          ListTile(
            leading: Icon(Icons.help_outline),
            title: Text(SoleraL10n.t('fos.ajus_ver_tour')),
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
            _subtitulo(SoleraL10n.t('fos.ajus_sobre_app')),
            _explicacion(SoleraL10n.t('fos.ajus_sobre_app_texto')),
            _subtitulo(SoleraL10n.t('fos.ajus_apoyar')),
            _explicacion(SoleraL10n.t('fos.ajus_apoyar_texto')),
            FilledButton.tonalIcon(
              icon: Icon(Icons.favorite_outline),
              onPressed: () => mostrarSheetDonaciones(context),
              label: Text(SoleraL10n.t('fos.ajus_ver_formas_apoyar')),
            ),
            _subtitulo(SoleraL10n.t('fos.ajus_datos_fuentes')),
            Text(
              SoleraL10n.t('fos.ajus_datos_fuentes_texto'),
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ]),
        ],
      ),
    );
  }
}
