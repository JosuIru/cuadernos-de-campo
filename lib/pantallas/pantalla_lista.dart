import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path_lib;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../datos/base_datos.dart';
import '../modelos/hallazgo.dart';
import '../datos/configuracion.dart';
import '../servicios/certificado_hallazgo.dart';
import '../servicios/exportar_zip.dart';
import '../servicios/identidad_descubridor.dart';
import '../servicios/tarjeta_imagen.dart';
import '../widgets/dialogo_trazabilidad.dart';
import 'pantalla_estadisticas.dart';
import 'pantalla_nuevo.dart';

class PantallaLista extends StatefulWidget {
  PantallaLista({super.key});

  @override
  State<PantallaLista> createState() => _PantallaListaState();
}

class _PantallaListaState extends State<PantallaLista> {
  final _controladorBusqueda = TextEditingController();
  List<Hallazgo> _hallazgos = [];
  String _consulta = '';
  String _filtroTipo = 'todos'; // 'todos' | 'fosil' | 'mineral'
  String? _miClavePublicaB64;

  @override
  void initState() {
    super.initState();
    _cargar();
    _cargarMiClave();
    _controladorBusqueda.addListener(() {
      setState(() => _consulta = _controladorBusqueda.text.trim().toLowerCase());
    });
  }

  Future<void> _cargar() async {
    final lista = await BaseDatosFosiles.instancia.listarHallazgos();
    if (!mounted) return;
    setState(() => _hallazgos = lista);
  }

  Future<void> _cargarMiClave() async {
    final clave = await IdentidadDescubridor.instancia.obtenerClavePublicaBase64();
    if (!mounted) return;
    setState(() => _miClavePublicaB64 = clave);
  }

  /// True si el hallazgo viene de otra persona (clave pública distinta a
  /// la mía). Hallazgos sin firma o firmados con mi clave cuentan como
  /// "propios".
  bool _esCompartido(Hallazgo h) {
    if (!h.tieneFirma) return false;
    if (_miClavePublicaB64 == null) return false;
    return h.clavePublicaDescubridor != _miClavePublicaB64;
  }

  List<Hallazgo> _aplicarFiltros(Iterable<Hallazgo> origen) {
    return origen.where((h) {
      if (_filtroTipo != 'todos' && h.tipo != _filtroTipo) return false;
      if (_consulta.isEmpty) return true;
      final texto = '${h.especie} ${h.edad} ${h.formacion} ${h.notas}'.toLowerCase();
      return texto.contains(_consulta);
    }).toList();
  }

  List<Hallazgo> get _propios =>
      _aplicarFiltros(_hallazgos.where((h) => !_esCompartido(h)));
  List<Hallazgo> get _compartidos =>
      _aplicarFiltros(_hallazgos.where(_esCompartido));


  Future<void> _abrirDetalle(Hallazgo hallazgo) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hallazgo.rutasFotos.isNotEmpty)
                SizedBox(
                  height: 240,
                  child: PageView.builder(
                    itemCount: hallazgo.rutasFotos.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(File(hallazgo.rutasFotos[i]), height: 240, width: double.infinity, fit: BoxFit.cover),
                          ),
                          if (hallazgo.rutasFotos.length > 1)
                            Positioned(
                              right: 8,
                              bottom: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                                child: Text('${i + 1} / ${hallazgo.rutasFotos.length}', style: TextStyle(color: Colors.white, fontSize: 11)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              SizedBox(height: 12),
              _filaDetalle('Especie', hallazgo.especie.isEmpty ? '—' : hallazgo.especie),
              _filaDetalle('Edad', hallazgo.edad.isEmpty ? '—' : hallazgo.edad),
              _filaDetalle('Formación', hallazgo.formacion.isEmpty ? '—' : hallazgo.formacion),
              _filaDetalle('Fecha', DateFormat('dd MMM yyyy HH:mm', 'es_ES').format(DateTime.fromMillisecondsSinceEpoch(hallazgo.fechaMs))),
              _filaDetalle('Coordenadas', '${hallazgo.latitud.toStringAsFixed(5)}, ${hallazgo.longitud.toStringAsFixed(5)}${hallazgo.precision != null ? " (±${hallazgo.precision!.round()} m)" : ""}'),
              if (hallazgo.strikeGrados != null && hallazgo.dipGrados != null)
                _filaDetalle('Estrato', '${hallazgo.strikeGrados!.toStringAsFixed(0)}° / ${hallazgo.dipGrados!.toStringAsFixed(0)}°'),
              _filaDetalle('Notas', hallazgo.notas.isEmpty ? '—' : hallazgo.notas),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.edit_outlined),
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        final actualizado = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(builder: (_) => PantallaNuevoHallazgo(hallazgoExistente: hallazgo)),
                        );
                        if (actualizado == true) _cargar();
                      },
                      label: Text(SoleraL10n.t('editar')),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        final confirmar = await _confirmar(context, '¿Borrar este hallazgo?');
                        if (confirmar != true) return;
                        await BaseDatosFosiles.instancia.borrarHallazgo(hallazgo.id!);
                        if (!mounted) return;
                        Navigator.of(sheetContext).pop();
                        _cargar();
                      },
                      label: Text('Borrar', style: TextStyle(color: Colors.red)),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.share),
                      onPressed: () => _compartir(hallazgo),
                      label: Text('Compartir texto'),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      icon: Icon(Icons.image),
                      onPressed: () => _compartirComoTarjeta(hallazgo),
                      label: Text('Tarjeta'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              OutlinedButton.icon(
                icon: Icon(Icons.verified_user),
                onPressed: () => _compartirCertificado(hallazgo),
                label: Text('Certificado verificable'),
                style: OutlinedButton.styleFrom(
                  minimumSize: Size(double.infinity, 40),
                ),
              ),
              SizedBox(height: 16),
              if (hallazgo.historialTrazabilidad.isNotEmpty) ...[
                Text('Historial de trazabilidad',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                SizedBox(height: 6),
                ...hallazgo.historialTrazabilidad.map(tarjetaEventoTrazabilidad),
                SizedBox(height: 8),
              ],
              OutlinedButton.icon(
                icon: Icon(Icons.add),
                onPressed: () async {
                  final nombre = await Configuracion.obtenerNombreDescubridor();
                  if (!mounted) return;
                  final anadido = await mostrarDialogoAnadirTrazabilidad(
                      context, hallazgo, nombre);
                  if (anadido) {
                    _cargar();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Evento añadido al historial.')),
                      );
                    }
                  }
                },
                label: Text(hallazgo.historialTrazabilidad.isEmpty
                    ? 'Añadir trazabilidad'
                    : 'Añadir evento'),
                style: OutlinedButton.styleFrom(
                  minimumSize: Size(double.infinity, 40),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportar() async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(child: CircularProgressIndicator()),
    );
    try {
      final fichero = await generarZipHallazgos(_hallazgos);
      if (!mounted) return;
      Navigator.of(context).pop(); // cerrar progress
      await Share.shareXFiles([XFile(fichero.path)], subject: 'Hallazgos de fósiles', text: '${_hallazgos.length} hallazgos exportados.');
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error exportando: $e')));
    }
  }

  Future<void> _compartirComoTarjeta(Hallazgo hallazgo) async {
    showDialog<void>(context: context, barrierDismissible: false, builder: (_) => Center(child: CircularProgressIndicator()));
    try {
      final fichero = await generarTarjetaHallazgo(hallazgo);
      if (!mounted) return;
      Navigator.of(context).pop();
      await Share.shareXFiles([XFile(fichero.path)], subject: 'Hallazgo: ${hallazgo.especie}');
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generando tarjeta: $e')));
    }
  }

  Future<void> _compartirCertificado(Hallazgo hallazgo) async {
    final nombre = await Configuracion.obtenerNombreDescubridor();
    if (nombre.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Configura primero tu nombre en Ajustes → Perfil del descubridor.'),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }
    final email = await Configuracion.obtenerEmailDescubridor();
    final org = await Configuracion.obtenerOrganizacionDescubridor();
    final certificado = generarCertificadoJson(hallazgo, nombre,
        emailDescubridor: email, organizacionDescubridor: org);
    final jsonStr = const JsonEncoder.withIndent('  ').convert(certificado);
    final dir = await getTemporaryDirectory();
    final nombreFichero =
        'certificado_${hallazgo.especie.isNotEmpty ? hallazgo.especie.replaceAll(RegExp(r'\s+'), '_') : 'hallazgo'}_${hallazgo.fechaMs}.json';
    final fichero = File(path_lib.join(dir.path, nombreFichero));
    await fichero.writeAsString(jsonStr);
    if (!mounted) return;
    await Share.shareXFiles([XFile(fichero.path)],
        subject: 'Certificado de hallazgo: ${hallazgo.especie}',
        text: 'Certificado verificable de hallazgo fósil. '
            'Hash: ${certificado['hash']}\n'
            'Especie: ${hallazgo.especie}\n'
            'Descubridor: $nombre');
  }

  Future<void> _compartir(Hallazgo hallazgo) async {
    final fecha = DateFormat('dd MMM yyyy', 'es_ES').format(DateTime.fromMillisecondsSinceEpoch(hallazgo.fechaMs));
    final texto = StringBuffer()
      ..writeln('Hallazgo de fósil')
      ..writeln('Especie: ${hallazgo.especie.isEmpty ? "?" : hallazgo.especie}')
      ..writeln('Edad: ${hallazgo.edad.isEmpty ? "?" : hallazgo.edad}')
      ..writeln('Formación: ${hallazgo.formacion.isEmpty ? "?" : hallazgo.formacion}')
      ..writeln('Coordenadas: ${hallazgo.latitud.toStringAsFixed(5)}, ${hallazgo.longitud.toStringAsFixed(5)}')
      ..writeln('Fecha: $fecha')
      ..writeln('Mapa: https://www.openstreetmap.org/?mlat=${hallazgo.latitud}&mlon=${hallazgo.longitud}#map=16/${hallazgo.latitud}/${hallazgo.longitud}');
    if (hallazgo.notas.isNotEmpty) {
      texto..writeln()..writeln(hallazgo.notas);
    }
    if (hallazgo.rutaFoto != null) {
      await Share.shareXFiles([XFile(hallazgo.rutaFoto!)], text: texto.toString(), subject: 'Hallazgo: ${hallazgo.especie}');
    } else {
      await Share.share(texto.toString(), subject: 'Hallazgo: ${hallazgo.especie}');
    }
  }

  Widget _filaDetalle(String clave, String valor) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 100, child: Text(clave, style: TextStyle(fontWeight: FontWeight.bold))),
            Expanded(child: Text(valor)),
          ],
        ),
      );

  Future<bool?> _confirmar(BuildContext context, String texto) => showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          content: Text(texto),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(SoleraL10n.t('cancelar'))),
            TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Borrar', style: TextStyle(color: Colors.red))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    // Sólo mostramos la pestaña "Compartidas conmigo" si hay al menos una.
    // Antes del primer import, la app se ve exactamente igual que siempre.
    final hayCompartidos = _hallazgos.any(_esCompartido);
    if (!hayCompartidos) return _construirSinTabs();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Hallazgos'),
          actions: _accionesAppBar(),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Mías (${_propios.length})'),
              Tab(text: 'Compartidas (${_compartidos.length})'),
            ],
          ),
        ),
        body: Column(
          children: [
            _buscadorYFiltros(),
            Expanded(
              child: TabBarView(
                children: [
                  _listaHallazgos(_propios, mensajeVacio: _mensajeVacioMias()),
                  _listaHallazgos(
                    _compartidos,
                    mensajeVacio: 'Ningún hallazgo recibido coincide con la búsqueda.',
                    mostrarBadgeRemitente: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirSinTabs() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hallazgos'),
        actions: _accionesAppBar(),
      ),
      body: Column(
        children: [
          _buscadorYFiltros(),
          Expanded(
            child: _listaHallazgos(_propios, mensajeVacio: _mensajeVacioMias()),
          ),
        ],
      ),
    );
  }

  List<Widget> _accionesAppBar() {
    return [
      IconButton(
        icon: const Icon(Icons.bar_chart),
        tooltip: 'Estadísticas',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PantallaEstadisticas()),
        ),
      ),
      IconButton(
        icon: const Icon(Icons.archive_outlined),
        tooltip: 'Exportar ZIP',
        onPressed: _hallazgos.isEmpty ? null : _exportar,
      ),
    ];
  }

  Widget _buscadorYFiltros() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: TextField(
            controller: _controladorBusqueda,
            decoration: const InputDecoration(
              hintText: 'Buscar por nombre, edad, notas…',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'todos', label: Text(SoleraL10n.t('todos')), icon: const Icon(Icons.apps)),
              const ButtonSegment(value: 'fosil', label: Text('Fósiles'), icon: Icon(Icons.bug_report)),
              const ButtonSegment(value: 'mineral', label: Text('Minerales'), icon: Icon(Icons.diamond)),
            ],
            selected: {_filtroTipo},
            onSelectionChanged: (s) => setState(() => _filtroTipo = s.first),
          ),
        ),
      ],
    );
  }

  String _mensajeVacioMias() {
    return _hallazgos.isEmpty
        ? 'Aún no hay hallazgos.\nToca el + para registrar el primero.'
        : 'Ningún hallazgo coincide con la búsqueda.';
  }

  Widget _listaHallazgos(
    List<Hallazgo> lista, {
    required String mensajeVacio,
    bool mostrarBadgeRemitente = false,
  }) {
    if (lista.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            mensajeVacio,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.builder(
        itemCount: lista.length,
        itemBuilder: (_, i) {
          final h = lista[i];
          final fecha = DateFormat('dd MMM yyyy', 'es_ES')
              .format(DateTime.fromMillisecondsSinceEpoch(h.fechaMs));
          return ListTile(
            leading: h.rutaFoto != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.file(File(h.rutaFoto!),
                        width: 48, height: 48, fit: BoxFit.cover),
                  )
                : const CircleAvatar(child: Icon(Icons.image_not_supported)),
            title: Row(
              children: [
                Expanded(child: Text(h.especie.isEmpty ? 'Sin nombre' : h.especie)),
                if (mostrarBadgeRemitente)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '↓ recibida',
                      style: TextStyle(fontSize: 11, color: Colors.blue),
                    ),
                  ),
              ],
            ),
            subtitle: Text(
              '${h.edad.isEmpty ? "—" : h.edad}\n$fecha · '
              '${h.latitud.toStringAsFixed(4)}, ${h.longitud.toStringAsFixed(4)}',
            ),
            isThreeLine: true,
            onTap: () => _abrirDetalle(h),
          );
        },
      ),
    );
  }
}
