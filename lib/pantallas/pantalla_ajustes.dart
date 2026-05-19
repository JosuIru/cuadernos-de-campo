import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import 'package:share_plus/share_plus.dart';
import '../comunidad/cliente_comunidad.dart';
import '../comunidad/feature_flag_comunidad.dart';
import '../datos/configuracion.dart';
import '../datos/yacimientos_curados.dart';
import '../servicios/servicio_geologia.dart';
import '../servicios/cache_teselas.dart';
import '../servicios/servicio_backup.dart';
import '../servicios/geofencing.dart';
import 'pantalla_identidad.dart';
import 'pantalla_mapas_offline.dart';
import 'pantalla_modo_experto.dart';
import 'pantalla_onboarding.dart';
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
      if (!mounted) return;
      ScaffoldMessenger.of(contextoExterior).showSnackBar(SnackBar(
          content: Text(
              'Solicitud enviada. Revisa tu email para confirmar el borrado.')));
    } catch (e) {
      if (!mounted) return;
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
          SizedBox(height: 8),
          OutlinedButton.icon(
            icon: Icon(Icons.school_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PantallaModoExperto()),
            ),
            label: Text('Modo Experto (autoridades certificadoras)'),
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

          if (kFeatureComunidadHabilitada) ...[
            SizedBox(height: 32),
            Text('Tus aportaciones a la comunidad',
                style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 8),
            Text(
              'Si has compartido fotos con la comunidad puedes pedir su '
              'borrado en cualquier momento (RGPD). Te llegará un enlace '
              'al email indicado; haciendo click se borrarán todas tus '
              'aportaciones, incluso las que ya estén publicadas.',
              style: TextStyle(fontSize: 13),
            ),
            SizedBox(height: 12),
            OutlinedButton.icon(
              icon: Icon(Icons.delete_sweep_outlined),
              onPressed: () => _solicitarBorradoAportacionesComunidad(context),
              label: Text('Borrar mis aportaciones'),
              style: OutlinedButton.styleFrom(
                minimumSize: Size(double.infinity, 40),
              ),
            ),
          ],

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
          
          Text('Sobre la app', style: Theme.of(context).textTheme.titleLarge),
          SizedBox(height: 8),
          Text(
            'Cuaderno de campo de fósiles para adulto aficionado. Anota '
            'hallazgos georreferenciados con foto, edad, formación, '
            'strike/dip del estrato; consulta el contexto geológico del '
            'IGME en el punto donde pinches; y guarda una guía local de '
            'fósiles y minerales por período.',
            style: TextStyle(fontSize: 13),
          ),
          SizedBox(height: 12),
          OutlinedButton.icon(
            icon: Icon(Icons.help_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) => const PantallaOnboarding(
                  marcarComoVistoAlSalir: false,
                ),
              ),
            ),
            label: Text('Ver tour de presentación'),
          ),
          SizedBox(height: 16),

          Text('Capas geológicas del mapa',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          SizedBox(height: 6),
          Text(
            'En la barra superior del mapa, el icono 🌍 abre el desplegable '
            'de capas geológicas del IGME. La app arranca con la primera '
            'de la lista (GEODE 50). Para qué sirve cada una:',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          SizedBox(height: 10),
          ...capasGeologicasWms.map((capa) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ${capa.nombre}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 12, top: 2),
                      child: Text(
                        capa.descripcion,
                        style: const TextStyle(fontSize: 12, height: 1.3),
                      ),
                    ),
                  ],
                ),
              )),
          SizedBox(height: 8),
          Text(
            'Las sugerencias de fósiles y minerales del asistente y del '
            'explorador SIEMPRE consultan GEODE 50 internamente, sin '
            'importar qué capa esté pintada — así cambiar de capa visual '
            'no hace bailar la lista de fósiles probables.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
          ),
          SizedBox(height: 16),

          Text('Otras capas y filtros',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          SizedBox(height: 6),
          Text(
            '• ⭐ LIG — Lugares de Interés Geológico declarados por el IGME.\n'
            '• ⛰️ Relieve sombreado (hillshade) para ver topografía.\n'
            '• 🦇 Cuevas (OpenStreetMap, requiere zoom ≥ 10).\n'
            '• 🗿 Megalitos y monumentos arqueológicos (OSM, zoom ≥ 9).\n'
            '• 🏛️ Yacimientos curados — selección manual con fichas, '
            'aparecen también como pista de "yacimientos cercanos" cuando '
            'pinchas a menos de 5 km.',
            style: TextStyle(fontSize: 12, height: 1.5),
          ),
          SizedBox(height: 16),

          Text('Sugerencias de fósiles y minerales',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          SizedBox(height: 6),
          Text(
            'Al pinchar un punto (modo Explorar geología) o con el '
            'asistente activado en el centro del mapa, la app cruza la '
            'respuesta del IGME con sus catálogos locales:\n\n'
            '• Si la formación que devuelve GEODE coincide con el catálogo '
            'de formaciones ibéricas, se sugieren los fósiles '
            'característicos de esa formación (sello PENDIENTE_VALIDACION '
            'paleontológica hasta auditoría de comité científico).\n'
            '• Si no, se sugieren fósiles del período inferido y filtrados '
            'por el ambiente sedimentario probable de la litología '
            '(p. ej. granito o basalto → sin fósiles; caliza → marinos).\n'
            '• Los minerales se ponderan por litología: cada grupo '
            '(granítico, carbonático, basáltico, evaporítico, metamórfico…) '
            'tiene su propio set probable.',
            style: TextStyle(fontSize: 12, height: 1.4),
          ),
          SizedBox(height: 16),

          Text('Funcionalidades clave',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          SizedBox(height: 6),
          Text(
            '• Hallazgo georreferenciado con foto, edad, formación, '
            'strike/dip, notas y trazabilidad.\n'
            '• Mapa con capas IGME, hillshade, LIG, cuevas, megalitos y '
            'yacimientos curados.\n'
            '• Asistente geológico en el centro del mapa al panear.\n'
            '• Mapas offline descargables por bbox + zoom.\n'
            '• Guía local de fósiles y minerales por período.\n'
            '• Estadísticas y línea del tiempo.\n'
            '• Quiz de identificación.\n'
            '• Chat de IA paleontológica (requiere API key personal).\n'
            '• Exportar hallazgo como tarjeta de imagen o certificado '
            'verificable cripto-firmado.\n'
            '• Importar .fos-card de otra persona y certificar cadena '
            '(Modo Experto).\n'
            '• Backup y restauración completa de la base de datos.',
            style: TextStyle(fontSize: 12, height: 1.4),
          ),
          SizedBox(height: 16),

          Text('Datos y fuentes',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          SizedBox(height: 6),
          Text(
            'Datos geológicos: IGME (GEODE 50, MAGNA 50, Edades 1M, '
            'Litologías 1M, IELIG). Mapa base: OpenStreetMap, ESRI, '
            'OpenTopoMap. Cuevas y megalitos: OpenStreetMap (Overpass). '
            'Imágenes y descripciones complementarias: Wikipedia '
            '(CC-BY-SA). Versión Flutter para Android.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
