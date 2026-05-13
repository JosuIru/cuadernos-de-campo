import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import 'package:share_plus/share_plus.dart';
import '../datos/configuracion.dart';
import '../datos/yacimientos_curados.dart';
import '../servicios/cache_teselas.dart';
import '../servicios/servicio_backup.dart';
import '../servicios/geofencing.dart';
import 'pantalla_identidad.dart';
import 'pantalla_mapas_offline.dart';
import 'pantalla_verificar_certificado.dart';
import 'sheet_donaciones.dart';

class PantallaAjustes extends StatefulWidget {
  PantallaAjustes({super.key});

  @override
  State<PantallaAjustes> createState() => _PantallaAjustesState();
}

class _PantallaAjustesState extends State<PantallaAjustes> {
  final _controladorApiKey = TextEditingController();
  final _controladorDeepseekKey = TextEditingController();
  final _controladorNombre = TextEditingController();
  final _controladorEmail = TextEditingController();
  final _controladorOrg = TextEditingController();
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
    _controladorNombre.dispose();
    _controladorEmail.dispose();
    _controladorOrg.dispose();
    _controladorDeepseekKey.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final apiKey = await Configuracion.obtenerApiKey();
    final apiKeyDeepseek = await Configuracion.obtenerApiKeyDeepseek();
    final modelo = await Configuracion.obtenerModelo();
    final nombre = await Configuracion.obtenerNombreDescubridor();
    final email = await Configuracion.obtenerEmailDescubridor();
    final org = await Configuracion.obtenerOrganizacionDescubridor();
    if (!mounted) return;
    setState(() {
      _controladorApiKey.text = apiKey;
      _controladorDeepseekKey.text = apiKeyDeepseek;
      _modeloSeleccionado = modelo;
      _controladorNombre.text = nombre;
      _controladorEmail.text = email;
      _controladorOrg.text = org;
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
    await Configuracion.guardarApiKeyDeepseek(_controladorDeepseekKey.text.trim());
    await Configuracion.guardarModelo(_modeloSeleccionado);
    await Configuracion.guardarNombreDescubridor(_controladorNombre.text);
    await Configuracion.guardarEmailDescubridor(_controladorEmail.text);
    await Configuracion.guardarOrganizacionDescubridor(_controladorOrg.text);
    if (!mounted) return;
    setState(() => _mensajeEstado = '✅ Ajustes guardados');
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
            'Para identificar fósiles automáticamente, introduce tu API key de Anthropic. '
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
          SizedBox(height: 16),
          Text('Modelo de Claude', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          ...modelosDisponibles.map((modelo) => RadioListTile<String>(
                value: modelo.id,
                groupValue: _modeloSeleccionado,
                onChanged: (v) => setState(() => _modeloSeleccionado = v ?? modeloPorDefecto),
                title: Text(modelo.nombre),
                subtitle: Text('${modelo.descripcion} ~${modelo.precioOrientativoCentimosPorIdentificacion} céntimos por foto.'),
              )),
          SizedBox(height: 16),
          FilledButton(onPressed: _guardar, child: Text('Guardar ajustes')),
          if (_mensajeEstado != null) ...[
            SizedBox(height: 12),
            Center(child: Text(_mensajeEstado!, style: TextStyle(color: Theme.of(context).colorScheme.primary))),
          ],

          SizedBox(height: 32),
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
          Text('Perfil del descubridor', style: Theme.of(context).textTheme.titleLarge),
          SizedBox(height: 8),
          Text(
            'Tu nombre se incluirá en los certificados de hallazgo. '
            'El email y la organización son opcionales. Estos datos se guardan solo en tu teléfono.',
            style: TextStyle(fontSize: 13),
          ),
          SizedBox(height: 12),
          TextField(
            controller: _controladorNombre,
            decoration: InputDecoration(
              labelText: 'Nombre (obligatorio para certificados)',
              border: OutlineInputBorder(),
              hintText: 'Ej: María González',
            ),
          ),
          SizedBox(height: 8),
          TextField(
            controller: _controladorEmail,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email (opcional)',
              border: OutlineInputBorder(),
              hintText: 'contacto@ejemplo.com',
            ),
          ),
          SizedBox(height: 8),
          TextField(
            controller: _controladorOrg,
            decoration: InputDecoration(
              labelText: 'Organización / afiliación (opcional)',
              border: OutlineInputBorder(),
              hintText: 'Ej: UPV/EHU, Sociedad de Ciencias Aranzadi…',
            ),
          ),
          SizedBox(height: 12),
          OutlinedButton.icon(
            icon: Icon(Icons.fingerprint),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PantallaIdentidad()),
            ),
            label: Text('Mi identidad criptográfica'),
          ),
          SizedBox(height: 8),
          OutlinedButton.icon(
            icon: Icon(Icons.verified),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => PantallaVerificarCertificado()),
            ),
            label: Text('Verificar un certificado'),
          ),

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

          SizedBox(height: 32),
          
          Text('Copia de seguridad', style: Theme.of(context).textTheme.titleLarge),
          SizedBox(height: 8),
          Text(
            'Exporta toda tu base (hallazgos + tracks + fotos) en un fichero único .fosbackup. '
            'Guárdalo en Drive/USB/correo. Para restaurar, selecciona el .fosbackup; reemplazará los datos actuales.',
            style: TextStyle(fontSize: 13),
          ),
          SizedBox(height: 12),
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

          SizedBox(height: 32),
          
          Text('Asistente de campo', style: Theme.of(context).textTheme.titleLarge),
          SizedBox(height: 8),
          Text(
            'Cuando el GPS detecta que estás dentro de un radio de 250 m de un yacimiento curado, '
            'aparece un aviso en el mapa con el botón "Ver ficha". Cada yacimiento te avisa una sola vez por sesión.',
            style: TextStyle(fontSize: 13),
          ),
          SizedBox(height: 12),
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
            'Fósiles — Cuaderno de campo. Versión Flutter para Android.\n\n'
            'Datos geológicos: IGME (MAGNA 50 / GEODE 50). Mapa base: OpenStreetMap, ESRI, OpenTopoMap. '
            'Cuevas: OpenStreetMap (Overpass). Imágenes y descripciones complementarias: Wikipedia (CC-BY-SA).',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
