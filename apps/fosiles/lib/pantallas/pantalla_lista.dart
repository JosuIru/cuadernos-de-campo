import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path_lib;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../comunidad/dialogo_compartir_comunidad.dart';
import '../comunidad/feature_flag_comunidad.dart';
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
  /// Callback opcional para pedir centrar el mapa en las coords de un
  /// hallazgo. Si se pasa, la ficha del hallazgo muestra un botón "Ver en
  /// el mapa" que cierra la ficha, salta a la pestaña de mapa y centra la
  /// vista sobre el punto. Cuando es null, el botón no aparece.
  final void Function(double latitud, double longitud)? alVerEnMapa;
  PantallaLista({super.key, this.alVerEnMapa});

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


  Future<void> _abrirDetalle(List<Hallazgo> listaVisible, int indiceInicial) async {
    if (listaVisible.isEmpty) return;
    final inicialAcotado = indiceInicial.clamp(0, listaVisible.length - 1);
    final controladorFichas = PageController(initialPage: inicialAcotado);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.9,
        // PageView horizontal entre fichas: arrastra izquierda/derecha
        // sobre cualquier parte del cuerpo (texto, botones, trazabilidad)
        // para saltar al hallazgo anterior/siguiente. El carrousel de
        // fotos lleva su propio PageView dentro y captura el gesto solo
        // en su área, así que swipe sobre las fotos avanza fotos sin
        // tocar la navegación entre fichas. La lista que se navega es la
        // que el usuario ve (con su filtro de búsqueda y pestaña), no el
        // catálogo completo.
        child: PageView.builder(
          controller: controladorFichas,
          itemCount: listaVisible.length,
          itemBuilder: (_, indice) => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _contenidoFichaHallazgo(
              sheetContext: sheetContext,
              hallazgo: listaVisible[indice],
              indiceEnLista: indice,
              total: listaVisible.length,
            ),
          ),
        ),
      ),
    );
    controladorFichas.dispose();
  }

  Widget _contenidoFichaHallazgo({
    required BuildContext sheetContext,
    required Hallazgo hallazgo,
    required int indiceEnLista,
    required int total,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (total > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              SoleraL10n.tf('fos.hall_n_de_total_desliza', {'actual': indiceEnLista + 1, 'total': total}),
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ),
        if (hallazgo.rutasFotos.isNotEmpty)
          SizedBox(
            height: 240,
            child: PageView.builder(
              itemCount: hallazgo.rutasFotos.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Stack(
                  children: [
                    GestureDetector(
                      onTap: () => _abrirVisorFotos(context, hallazgo.rutasFotos, i),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        // cacheWidth: 1600 → decodificación tope a
                        // 1600 px ancho. Suficiente para llenar la
                        // ficha aun en tablet, y evita decodificar
                        // 12 MP de RAM por foto.
                        child: Image.file(
                          File(hallazgo.rutasFotos[i]),
                          height: 240,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          cacheWidth: 1600,
                        ),
                      ),
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
        _filaDetalle(SoleraL10n.t('fos.hall_especie'), hallazgo.especie.isEmpty ? '—' : hallazgo.especie),
        _filaDetalle(SoleraL10n.t('fos.hall_edad'), hallazgo.edad.isEmpty ? '—' : hallazgo.edad),
        _filaDetalle(SoleraL10n.t('fos.hall_formacion'), hallazgo.formacion.isEmpty ? '—' : hallazgo.formacion),
        _filaDetalle(SoleraL10n.t('fos.hall_fecha'), DateFormat('dd MMM yyyy HH:mm', SoleraL10n.idioma).format(DateTime.fromMillisecondsSinceEpoch(hallazgo.fechaMs))),
        _filaDetalle(SoleraL10n.t('fos.hall_coordenadas'), '${hallazgo.latitud.toStringAsFixed(5)}, ${hallazgo.longitud.toStringAsFixed(5)}${hallazgo.precision != null ? " (±${hallazgo.precision!.round()} m)" : ""}'),
        if (hallazgo.strikeGrados != null && hallazgo.dipGrados != null)
          _filaDetalle(SoleraL10n.t('fos.hall_estrato'), '${hallazgo.strikeGrados!.toStringAsFixed(0)}° / ${hallazgo.dipGrados!.toStringAsFixed(0)}°'),
        _filaDetalle(SoleraL10n.t('fos.hall_notas'), hallazgo.notas.isEmpty ? '—' : hallazgo.notas),
        SizedBox(height: 16),
        if (widget.alVerEnMapa != null) ...[
          FilledButton.tonalIcon(
            icon: Icon(Icons.map_outlined),
            onPressed: () {
              Navigator.of(sheetContext).pop();
              widget.alVerEnMapa!(hallazgo.latitud, hallazgo.longitud);
            },
            label: Text(SoleraL10n.t('fos.hall_ver_en_mapa')),
            style: FilledButton.styleFrom(
              minimumSize: Size(double.infinity, 40),
            ),
          ),
          SizedBox(height: 8),
        ],
        if (kFeatureComunidadHabilitada && hallazgo.rutasFotos.isNotEmpty) ...[
          OutlinedButton.icon(
            icon: Icon(Icons.public),
            onPressed: () {
              showDialog<bool>(
                context: context,
                builder: (_) => DialogoCompartirComunidad(hallazgo: hallazgo),
              );
            },
            label: Text(SoleraL10n.t('fos.hall_compartir_comunidad')),
            style: OutlinedButton.styleFrom(
              minimumSize: Size(double.infinity, 40),
            ),
          ),
          SizedBox(height: 8),
        ],
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
                  final confirmar = await _confirmar(context, SoleraL10n.t('fos.hall_confirmar_borrar'));
                  if (confirmar != true) return;
                  await BaseDatosFosiles.instancia.borrarHallazgo(hallazgo.id!);
                  if (!mounted) return;
                  if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  _cargar();
                },
                label: Text(SoleraL10n.t('borrar'), style: TextStyle(color: Colors.red)),
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
                label: Text(SoleraL10n.t('fos.hall_compartir_texto')),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                icon: Icon(Icons.image),
                onPressed: () => _compartirComoTarjeta(hallazgo),
                label: Text(SoleraL10n.t('fos.hall_tarjeta')),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        OutlinedButton.icon(
          icon: Icon(Icons.verified_user),
          onPressed: () => _compartirCertificado(hallazgo),
          label: Text(SoleraL10n.t('fos.hall_certificado_verificable')),
          style: OutlinedButton.styleFrom(
            minimumSize: Size(double.infinity, 40),
          ),
        ),
        SizedBox(height: 16),
        if (hallazgo.historialTrazabilidad.isNotEmpty) ...[
          Text(SoleraL10n.t('fos.hall_historial_trazabilidad'),
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
                  SnackBar(content: Text(SoleraL10n.t('fos.hall_evento_anadido'))),
                );
              }
            }
          },
          label: Text(hallazgo.historialTrazabilidad.isEmpty
              ? SoleraL10n.t('fos.hall_anadir_trazabilidad')
              : SoleraL10n.t('fos.hall_anadir_evento')),
          style: OutlinedButton.styleFrom(
            minimumSize: Size(double.infinity, 40),
          ),
        ),
      ],
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
      await Share.shareXFiles([XFile(fichero.path)], subject: SoleraL10n.t('fos.hall_asunto_exportacion'), text: SoleraL10n.tf('fos.hall_n_exportados', {'n': _hallazgos.length}));
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(SoleraL10n.tf('fos.hall_error_exportando', {'error': e}))));
    }
  }

  Future<void> _compartirComoTarjeta(Hallazgo hallazgo) async {
    showDialog<void>(context: context, barrierDismissible: false, builder: (_) => Center(child: CircularProgressIndicator()));
    try {
      final fichero = await generarTarjetaHallazgo(hallazgo);
      if (!mounted) return;
      Navigator.of(context).pop();
      await Share.shareXFiles([XFile(fichero.path)], subject: SoleraL10n.tf('fos.hall_asunto_hallazgo', {'especie': hallazgo.especie}));
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(SoleraL10n.tf('fos.hall_error_tarjeta', {'error': e}))));
    }
  }

  Future<void> _compartirCertificado(Hallazgo hallazgo) async {
    final nombre = await Configuracion.obtenerNombreDescubridor();
    if (nombre.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(SoleraL10n.t('fos.hall_configura_nombre')),
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
        subject: SoleraL10n.tf('fos.hall_asunto_certificado', {'especie': hallazgo.especie}),
        text: '${SoleraL10n.t('fos.hall_certificado_texto')} '
            'Hash: ${certificado['hash']}\n'
            '${SoleraL10n.t('fos.hall_especie')}: ${hallazgo.especie}\n'
            '${SoleraL10n.t('fos.hall_descubridor')}: $nombre');
  }

  Future<void> _compartir(Hallazgo hallazgo) async {
    final fecha = DateFormat('dd MMM yyyy', SoleraL10n.idioma).format(DateTime.fromMillisecondsSinceEpoch(hallazgo.fechaMs));
    final texto = StringBuffer()
      ..writeln(SoleraL10n.t('fos.hall_hallazgo_de_fosil'))
      ..writeln('${SoleraL10n.t('fos.hall_especie')}: ${hallazgo.especie.isEmpty ? "?" : hallazgo.especie}')
      ..writeln('${SoleraL10n.t('fos.hall_edad')}: ${hallazgo.edad.isEmpty ? "?" : hallazgo.edad}')
      ..writeln('${SoleraL10n.t('fos.hall_formacion')}: ${hallazgo.formacion.isEmpty ? "?" : hallazgo.formacion}')
      ..writeln('${SoleraL10n.t('fos.hall_coordenadas')}: ${hallazgo.latitud.toStringAsFixed(5)}, ${hallazgo.longitud.toStringAsFixed(5)}')
      ..writeln('${SoleraL10n.t('fos.hall_fecha')}: $fecha')
      ..writeln('${SoleraL10n.t('mapa')}: https://www.openstreetmap.org/?mlat=${hallazgo.latitud}&mlon=${hallazgo.longitud}#map=16/${hallazgo.latitud}/${hallazgo.longitud}');
    if (hallazgo.notas.isNotEmpty) {
      texto..writeln()..writeln(hallazgo.notas);
    }
    if (hallazgo.rutaFoto != null) {
      await Share.shareXFiles([XFile(hallazgo.rutaFoto!)], text: texto.toString(), subject: SoleraL10n.tf('fos.hall_asunto_hallazgo', {'especie': hallazgo.especie}));
    } else {
      await Share.share(texto.toString(), subject: SoleraL10n.tf('fos.hall_asunto_hallazgo', {'especie': hallazgo.especie}));
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
            TextButton(onPressed: () => Navigator.pop(context, true), child: Text(SoleraL10n.t('borrar'), style: TextStyle(color: Colors.red))),
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
          title: Text(SoleraL10n.t('fos.hall_titulo')),
          actions: _accionesAppBar(),
          bottom: TabBar(
            tabs: [
              Tab(text: SoleraL10n.tf('fos.hall_tab_mias', {'n': _propios.length})),
              Tab(text: SoleraL10n.tf('fos.hall_tab_compartidas', {'n': _compartidos.length})),
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
                    mensajeVacio: SoleraL10n.t('fos.hall_ninguno_recibido_coincide'),
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
        title: Text(SoleraL10n.t('fos.hall_titulo')),
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
        tooltip: SoleraL10n.t('fos.hall_estadisticas'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PantallaEstadisticas()),
        ),
      ),
      IconButton(
        icon: const Icon(Icons.archive_outlined),
        tooltip: SoleraL10n.t('fos.hall_exportar_zip'),
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
            decoration: InputDecoration(
              hintText: SoleraL10n.t('fos.hall_buscar_hint'),
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'todos', label: Text(SoleraL10n.t('todos')), icon: const Icon(Icons.apps)),
              ButtonSegment(value: 'fosil', label: Text(SoleraL10n.t('fos.hall_fosiles')), icon: const Icon(Icons.bug_report)),
              ButtonSegment(value: 'mineral', label: Text(SoleraL10n.t('fos.hall_minerales')), icon: const Icon(Icons.diamond)),
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
        ? '${SoleraL10n.t('fos.hall_aun_no_hay_hallazgos')}\n${SoleraL10n.t('fos.hall_toca_mas_primero')}'
        : SoleraL10n.t('fos.hall_ninguno_coincide');
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
          final fecha = DateFormat('dd MMM yyyy', SoleraL10n.idioma)
              .format(DateTime.fromMillisecondsSinceEpoch(h.fechaMs));
          return ListTile(
            leading: h.rutaFoto != null
                // GestureDetector envuelve la miniatura y captura el tap
                // ANTES de que el ListTile lo reciba, así pulsar la foto
                // abre el visor a pantalla completa en vez de la ficha.
                // Para abrir la ficha se pulsa cualquier otro punto de la
                // tile.
                ? GestureDetector(
                    onTap: () => _abrirVisorFotos(context, h.rutasFotos, 0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      // cacheWidth fuerza a Flutter a decodificar la foto a
                      // 96 px de ancho (densidad 2x para pantallas hi-dpi)
                      // en lugar de a su resolución original (típicamente
                      // 4000+ px). Sin esto, una lista con 100 hallazgos de
                      // cámara consume varios GB de RAM por miniatura.
                      child: Image.file(
                        File(h.rutaFoto!),
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        cacheWidth: 96,
                        cacheHeight: 96,
                      ),
                    ),
                  )
                : const CircleAvatar(child: Icon(Icons.image_not_supported)),
            title: Row(
              children: [
                Expanded(child: Text(h.especie.isEmpty ? SoleraL10n.t('fos.hall_sin_nombre') : h.especie)),
                if (mostrarBadgeRemitente)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '↓ ${SoleraL10n.t('fos.hall_recibida')}',
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
            onTap: () => _abrirDetalle(lista, i),
          );
        },
      ),
    );
  }
}

/// Abre un visor a pantalla completa con las fotos del hallazgo. Permite
/// pinch-zoom (hasta 6x), swipe entre fotos cuando hay más de una y un
/// botón de cerrar. Pensado para que el usuario pueda mirar el detalle
/// fino de una foto sin ir a la galería del sistema.
void _abrirVisorFotos(BuildContext context, List<String> rutasFotos, int indiceInicial) {
  if (rutasFotos.isEmpty) return;
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _VisorFotosFullscreen(
        rutasFotos: rutasFotos,
        indiceInicial: indiceInicial.clamp(0, rutasFotos.length - 1),
      ),
    ),
  );
}

class _VisorFotosFullscreen extends StatefulWidget {
  final List<String> rutasFotos;
  final int indiceInicial;
  const _VisorFotosFullscreen({required this.rutasFotos, required this.indiceInicial});

  @override
  State<_VisorFotosFullscreen> createState() => _VisorFotosFullscreenState();
}

class _VisorFotosFullscreenState extends State<_VisorFotosFullscreen> {
  late final PageController _controladorPagina;
  late int _indiceActual;

  @override
  void initState() {
    super.initState();
    _indiceActual = widget.indiceInicial;
    _controladorPagina = PageController(initialPage: widget.indiceInicial);
  }

  @override
  void dispose() {
    _controladorPagina.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hayVarias = widget.rutasFotos.length > 1;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: hayVarias
            ? Text('${_indiceActual + 1} / ${widget.rutasFotos.length}')
            : null,
      ),
      body: PageView.builder(
        controller: _controladorPagina,
        itemCount: widget.rutasFotos.length,
        onPageChanged: (i) => setState(() => _indiceActual = i),
        itemBuilder: (_, i) => InteractiveViewer(
          minScale: 1.0,
          maxScale: 6.0,
          child: Center(
            child: Image.file(
              File(widget.rutasFotos[i]),
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
