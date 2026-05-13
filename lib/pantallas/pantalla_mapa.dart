import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import '../datos/base_datos.dart';
import '../datos/datos_guia.dart';
import '../modelos/hallazgo.dart';
import '../servicios/cache_teselas.dart';
import '../servicios/grabador_track.dart';
import '../servicios/estado_conexion.dart';
import '../servicios/servicio_gbif.dart';
import '../servicios/servicio_overpass.dart';
import 'pantalla_nuevo.dart';
import '../utiles/permisos_gps.dart' show asegurarPermisoUbicacion, asegurarPermisoNotificaciones;
import 'pantalla_mapas_offline.dart';
import 'pantalla_tracks.dart';
import 'widgets/barra_filtro_categoria.dart';

typedef CallbackPedirNuevoHallazgo = void Function({double? latitud, double? longitud});
typedef CallbackSeleccionarEspecieGuia = void Function(String idEspecie);

const _centroInicial = LatLng(40.4168, -3.7038);
const _zoomInicial = 6.0;

class CapaBase {
  final String nombre;
  final String urlPlantilla;
  final int maxZoom;
  final String atribucion;
  CapaBase({
    required this.nombre,
    required this.urlPlantilla,
    required this.maxZoom,
    required this.atribucion,
  });
}

final List<CapaBase> capasBaseDisponibles = [
  CapaBase(
    nombre: 'Callejero',
    urlPlantilla: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    maxZoom: 19,
    atribucion: '© OpenStreetMap',
  ),
  CapaBase(
    nombre: 'Satélite',
    urlPlantilla: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    maxZoom: 19,
    atribucion: '© Esri',
  ),
  CapaBase(
    nombre: 'Topográfico',
    urlPlantilla: 'https://tile.opentopomap.org/{z}/{x}/{y}.png',
    maxZoom: 17,
    atribucion: '© OpenTopoMap',
  ),
];

class PantallaMapa extends StatefulWidget {
  final CallbackPedirNuevoHallazgo alPedirNuevoHallazgo;
  final CallbackSeleccionarEspecieGuia alSeleccionarEspecieGuia;
  PantallaMapa({
    super.key,
    required this.alPedirNuevoHallazgo,
    required this.alSeleccionarEspecieGuia,
  });

  @override
  State<PantallaMapa> createState() => _PantallaMapaState();
}

class _PantallaMapaState extends State<PantallaMapa> {
  final _controladorMapa = MapController();
  final _proveedorTeselasCache = TileProviderConCache();
  CapaBase _capaBaseActual = capasBaseDisponibles.first;
  String _filtroCategoria = 'todos';
  List<Hallazgo> _hallazgos = [];
  List<OcurrenciaGbif> _ocurrenciasGbif = [];
  bool _cargandoGbif = false;
  Set<TipoLugarInteres> _tiposLugaresActivos = {};
  List<LugarInteres> _lugaresInteres = [];
  bool _cargandoLugares = false;
  StreamSubscription<void>? _suscripcionTrack;
  StreamSubscription<bool>? _subConexion;
  bool _conectado = true;
  bool _modoAgregar = false;
  LatLng? _ultimoCentroMapa;

  // Tick del track: cada GPS-fix del grabador antes disparaba setState que
  // reconstruía TODO el FlutterMap (tiles base, lugares, GBIF, clusters).
  // Ahora un notifier que sólo agita la PolylineLayer del track.
  final ValueNotifier<int> _tickTrack = ValueNotifier(0);

  // Caches de markers/hallazgos filtrados. Antes se generaban DE CERO en
  // cada build() — para cada hallazgo, lugar y ocurrencia GBIF se creaba
  // un GestureDetector + Container + BoxShadow. Cualquier setState (filtro
  // de categoría, cargar GBIF, cambiar capa base, banner de conexión) tiraba
  // toda la lista. Ahora se recalculan SÓLO en los métodos que cambian la
  // fuente.
  List<Hallazgo> _hallazgosFiltradosCache = const [];
  List<Marker> _markersHallazgosCache = const [];
  List<Marker> _markersLugaresCache = const [];
  List<Marker> _markersGbifCache = const [];

  @override
  void initState() {
    super.initState();
    _cargarHallazgos();
    _suscripcionTrack = GrabadorTrack.instancia.cambios.listen((_) {
      // No setState — incrementamos el tick para que sólo se reconstruya
      // la PolylineLayer del track, no todo el FlutterMap.
      _tickTrack.value++;
    });
    _conectado = EstadoConexion.instancia.conectado;
    _subConexion = EstadoConexion.instancia.cambios.listen((online) {
      if (mounted) setState(() => _conectado = online);
    });
  }

  @override
  void dispose() {
    _suscripcionTrack?.cancel();
    _subConexion?.cancel();
    _tickTrack.dispose();
    super.dispose();
  }

  Future<void> _cargarHallazgos() async {
    final lista = await BaseDatosNaturaleza.instancia.listarHallazgos();
    if (!mounted) return;
    setState(() {
      _hallazgos = lista;
      _recalcularHallazgosFiltrados();
    });
  }

  void _recalcularHallazgosFiltrados() {
    _hallazgosFiltradosCache = _filtroCategoria == 'todos'
        ? _hallazgos
        : _hallazgos.where((hallazgo) => hallazgo.categoria == _filtroCategoria).toList();
    _recalcularMarkersHallazgos();
  }

  void _recalcularMarkersHallazgos() {
    final lista = _hallazgosFiltradosCache;
    _markersHallazgosCache = List.generate(lista.length, (i) {
      final hallazgo = lista[i];
      return Marker(
        width: 36,
        height: 36,
        point: LatLng(hallazgo.latitud, hallazgo.longitud),
        child: GestureDetector(
          onTap: () => _abrirDetalleHallazgo(lista, i),
          child: _IconoHallazgo(hallazgo: hallazgo),
        ),
      );
    });
  }

  void _recalcularMarkersLugares() {
    _markersLugaresCache = [
      for (final lugar in _lugaresInteres)
        Marker(
          width: 32,
          height: 32,
          point: LatLng(lugar.latitud, lugar.longitud),
          child: GestureDetector(
            onTap: () => _abrirDetalleLugar(lugar),
            child: Container(
              decoration: BoxDecoration(
                color: _colorTipoLugar(lugar.tipo),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1)),
                ],
              ),
              child: Icon(_iconoTipoLugar(lugar.tipo), color: Colors.white, size: 16),
            ),
          ),
        ),
    ];
  }

  void _recalcularMarkersGbif() {
    _markersGbifCache = [
      for (final ocurrencia in _ocurrenciasGbif)
        if (ocurrencia.latitud != null && ocurrencia.longitud != null)
          Marker(
            width: 22,
            height: 22,
            point: LatLng(ocurrencia.latitud!, ocurrencia.longitud!),
            child: GestureDetector(
              onTap: () => _abrirDetalleOcurrenciaGbif(ocurrencia),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.deepOrange.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
          ),
    ];
  }

  Future<void> _centrarEnMiUbicacion() async {
    final permitido = await asegurarPermisoUbicacion();
    if (!permitido) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falta permiso de ubicación.')));
      }
      return;
    }
    try {
      final posicion = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _controladorMapa.move(LatLng(posicion.latitude, posicion.longitude), 15);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error GPS: $e')));
      }
    }
  }

  Future<void> _seleccionarTiposLugares() async {
    final seleccion = await showModalBottomSheet<Set<TipoLugarInteres>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SelectorTiposLugares(seleccionInicial: _tiposLugaresActivos),
    );
    if (seleccion == null) return;
    setState(() => _tiposLugaresActivos = seleccion);
    if (seleccion.isEmpty) {
      setState(() {
        _lugaresInteres = const [];
        _recalcularMarkersLugares();
      });
    } else {
      await _refrescarLugaresInteres();
    }
  }

  Future<void> _refrescarLugaresInteres() async {
    if (_tiposLugaresActivos.isEmpty) return;
    final camara = _controladorMapa.camera;
    final limites = camara.visibleBounds;
    setState(() => _cargandoLugares = true);
    try {
      final lugares = await lugaresInteresEnBbox(
        sur: limites.south,
        norte: limites.north,
        oeste: limites.west,
        este: limites.east,
        tipos: _tiposLugaresActivos,
      );
      if (!mounted) return;
      setState(() {
        _lugaresInteres = lugares;
        _recalcularMarkersLugares();
      });
      if (lugares.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sin lugares de interés en esta zona.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error Overpass: $e')));
    } finally {
      if (mounted) setState(() => _cargandoLugares = false);
    }
  }

  void _abrirDetalleLugar(LugarInteres lugar) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_iconoTipoLugar(lugar.tipo), color: _colorTipoLugar(lugar.tipo)),
                SizedBox(width: 8),
                Text(
                  lugar.tipo.etiqueta,
                  style: TextStyle(fontSize: 13, color: _colorTipoLugar(lugar.tipo), fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              lugar.tituloMostrado,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              '${lugar.latitud.toStringAsFixed(5)}, ${lugar.longitud.toStringAsFixed(5)}',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (lugar.tags['description'] != null) ...[
              SizedBox(height: 8),
              Text(lugar.tags['description']!, style: TextStyle(fontSize: 13)),
            ],
            if (lugar.tags['operator'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Gestor: ${lugar.tags['operator']}', style: TextStyle(fontSize: 12)),
              ),
            if (lugar.tags['website'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(lugar.tags['website']!, style: TextStyle(fontSize: 12, color: Colors.blue)),
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconoTipoLugar(TipoLugarInteres tipo) => switch (tipo) {
        TipoLugarInteres.mirador => Icons.visibility,
        TipoLugarInteres.miradorAves => Icons.flutter_dash,
        TipoLugarInteres.reservaNatural => Icons.shield_outlined,
        TipoLugarInteres.cueva => Icons.terrain,
        TipoLugarInteres.humedal => Icons.water_drop,
        TipoLugarInteres.arbolSingular => Icons.park,
        TipoLugarInteres.refugio => Icons.house,
        TipoLugarInteres.manantial => Icons.water,
        TipoLugarInteres.centroVisitantes => Icons.info_outline,
      };

  Color _colorTipoLugar(TipoLugarInteres tipo) => switch (tipo) {
        TipoLugarInteres.mirador => Colors.indigo,
        TipoLugarInteres.miradorAves => Colors.teal,
        TipoLugarInteres.reservaNatural => Colors.green.shade700,
        TipoLugarInteres.cueva => Colors.brown,
        TipoLugarInteres.humedal => Colors.lightBlue.shade700,
        TipoLugarInteres.arbolSingular => Colors.green,
        TipoLugarInteres.refugio => Colors.orange.shade700,
        TipoLugarInteres.manantial => Colors.cyan.shade700,
        TipoLugarInteres.centroVisitantes => Colors.deepPurple,
      };

  Future<void> _consultarObservacionesCercanas() async {
    final camara = _controladorMapa.camera;
    final limites = camara.visibleBounds;
    setState(() => _cargandoGbif = true);
    try {
      final ocurrencias = await ocurrenciasEnBbox(
        latMin: limites.south,
        latMax: limites.north,
        lonMin: limites.west,
        lonMax: limites.east,
        limite: 200,
      );
      if (!mounted) return;
      setState(() {
        _ocurrenciasGbif = ocurrencias;
        _recalcularMarkersGbif();
      });
      if (ocurrencias.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sin observaciones GBIF en esta zona.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${ocurrencias.length} observaciones de la comunidad cargadas.'),
            action: SnackBarAction(
              label: 'Ocultar',
              onPressed: () => setState(() {
                _ocurrenciasGbif = const [];
                _recalcularMarkersGbif();
              }),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error GBIF: $e')));
    } finally {
      if (mounted) setState(() => _cargandoGbif = false);
    }
  }

  Future<void> _alternarGrabacionTrack() async {
    final grabador = GrabadorTrack.instancia;
    if (grabador.grabando) {
      final inicioMs = grabador.inicioMs;
      final resultado = grabador.detener();
      if (resultado != null) {
        await BaseDatosNaturaleza.instancia.guardarTrack(resultado.track, resultado.puntos);
        // Buffer consolidado correctamente: limpiamos los puntos
        // huérfanos que la grabación dejó en disco (red de seguridad
        // ante crash). Idempotente.
        if (inicioMs != null) {
          await grabador.descartarBufferDeSesion(inicioMs);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Track guardado (${resultado.puntos.length} puntos).')),
          );
        }
      }
    } else {
      final permisoUbicacion = await asegurarPermisoUbicacion();
      if (!permisoUbicacion) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falta permiso de ubicación.')));
        }
        return;
      }
      await asegurarPermisoNotificaciones();
      grabador.iniciar();
    }
    setState(() {});
  }

  void _abrirDetalleOcurrenciaGbif(OcurrenciaGbif ocurrencia) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.public, color: Colors.deepOrange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Observación GBIF',
                    style: TextStyle(fontSize: 14, color: Colors.deepOrange, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              ocurrencia.nombreCientifico ?? '(sin nombre)',
              style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold),
            ),
            if (ocurrencia.familia != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Familia: ${ocurrencia.familia}', style: TextStyle(fontSize: 13)),
              ),
            if (ocurrencia.fechaEvento != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Fecha: ${ocurrencia.fechaEvento}', style: TextStyle(fontSize: 13)),
              ),
            if (ocurrencia.localidad != null && ocurrencia.localidad!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Localidad: ${ocurrencia.localidad}', style: TextStyle(fontSize: 13)),
              ),
            if (ocurrencia.baseRegistro != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Tipo: ${ocurrencia.baseRegistro}', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
          ],
        ),
      ),
    );
  }

  void _abrirDetalleHallazgo(List<Hallazgo> lista, int indiceInicial) {
    final controladorPagina = PageController(initialPage: indiceInicial);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (_, setStateLocal) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          builder: (_, scrollController) => Column(
            children: [
              if (lista.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('${indiceInicial + 1} / ${lista.length}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black54)),
                ),
              Expanded(
                child: PageView.builder(
                  controller: controladorPagina,
                  itemCount: lista.length,
                  onPageChanged: (i) => setStateLocal(() => indiceInicial = i),
                  itemBuilder: (_, i) {
                    final h = lista[i];
                    final cat = categoriaPorId(h.categoria);
                    return SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (h.rutasFotos.isNotEmpty)
                            SizedBox(
                              height: 200,
                              child: PageView.builder(
                                itemCount: h.rutasFotos.length,
                                itemBuilder: (_, fi) => ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  // cacheWidth: 1600 → decodificación tope
                                  // a 1600 px. Sin esto una foto de cámara
                                  // de 12 MP se decodifica entera en RAM.
                                  child: Image.file(
                                    File(h.rutasFotos[fi]),
                                    height: 200,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    cacheWidth: 1600,
                                  ),
                                ),
                              ),
                            ),
                          SizedBox(height: 12),
                          Row(children: [
                            if (cat != null)
                              CircleAvatar(
                                backgroundColor: cat.color.withValues(alpha: 0.2),
                                child: Icon(cat.icono, color: cat.color),
                              ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    h.nombreComun.isNotEmpty
                                        ? h.nombreComun
                                        : (h.especie.isNotEmpty ? h.especie : 'Hallazgo'),
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                  if (h.especie.isNotEmpty && h.especie != h.nombreComun)
                                    Text(h.especie, style: TextStyle(fontStyle: FontStyle.italic)),
                                ],
                              ),
                            ),
                          ]),
                          SizedBox(height: 12),
                          _filaNaturaleza('Categoría', cat?.nombre ?? h.categoria),
                          if (h.habitat.isNotEmpty) _filaNaturaleza('Hábitat', h.habitat),
                          if (h.taxonomia.isNotEmpty) _filaNaturaleza('Taxonomía', h.taxonomia),
                          _filaNaturaleza('Coordenadas',
                              '${h.latitud.toStringAsFixed(5)}, ${h.longitud.toStringAsFixed(5)}'),
                          if (h.notas.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Notas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  SizedBox(height: 4),
                                  Text(h.notas),
                                ],
                              ),
                            ),
                          SizedBox(height: 16),
                          Row(children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: Icon(Icons.edit_outlined),
                                onPressed: () async {
                                  Navigator.of(sheetContext).pop();
                                  final actualizado = await Navigator.of(context).push<bool>(
                                    MaterialPageRoute(
                                        builder: (_) => PantallaNuevoHallazgo(hallazgoExistente: h)),
                                  );
                                  if (actualizado == true) _cargarHallazgos();
                                },
                                label: Text(SoleraL10n.t('editar')),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () async {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      content: Text('¿Borrar este hallazgo?'),
                                      actions: [
                                        TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: Text(SoleraL10n.t('cancelar'))),
                                        TextButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            child: Text('Borrar',
                                                style: TextStyle(color: Colors.red))),
                                      ],
                                    ),
                                  );
                                  if (ok != true) return;
                                  await BaseDatosNaturaleza.instancia.borrarHallazgo(h.id!);
                                  if (!mounted) return;
                                  Navigator.of(sheetContext).pop();
                                  _cargarHallazgos();
                                },
                                label: Text('Borrar', style: TextStyle(color: Colors.red)),
                              ),
                            ),
                          ]),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filaNaturaleza(String clave, String valor) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 100, child: Text(clave, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
            Expanded(child: Text(valor, style: TextStyle(fontSize: 13))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final grabador = GrabadorTrack.instancia;
    final estaGrabando = grabador.grabando;

    return Scaffold(
      body: Stack(
        children: [
          if (!_conectado)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Material(
                elevation: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: Colors.orange.shade800,
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_off, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text('Sin conexión — usando datos en caché',
                            style: TextStyle(color: Colors.white, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // RepaintBoundary aísla todo el subárbol del FlutterMap a su
          // propia capa GPU. Eventos del HUD (FAB, snackbars, banner de
          // conexión) y cambios de estado que no afectan al mapa ya no
          // fuerzan repintar las teselas raster.
          RepaintBoundary(
            child: FlutterMap(
              mapController: _controladorMapa,
              options: MapOptions(
                initialCenter: _centroInicial,
                initialZoom: _zoomInicial,
                onLongPress: (_, punto) => widget.alPedirNuevoHallazgo(
                  latitud: punto.latitude,
                  longitud: punto.longitude,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: _capaBaseActual.urlPlantilla,
                  maxZoom: _capaBaseActual.maxZoom.toDouble(),
                  tileProvider: _proveedorTeselasCache,
                  userAgentPackageName: 'com.josu.naturaleza',
                  keepBuffer: 4,
                  panBuffer: 1,
                ),
                // PolylineLayer del track grabando: extraída a notifier para
                // que cada nuevo punto NO reconstruya FlutterMap.
                ValueListenableBuilder<int>(
                  valueListenable: _tickTrack,
                  builder: (context, _, __) {
                    if (!GrabadorTrack.instancia.grabando ||
                        GrabadorTrack.instancia.puntos.length < 2) {
                      return const SizedBox.shrink();
                    }
                    return PolylineLayer(polylines: [
                      Polyline(
                        points: GrabadorTrack.instancia.puntos
                            .map((p) => LatLng(p.latitud, p.longitud))
                            .toList(),
                        strokeWidth: 4,
                        color: Colors.redAccent,
                      ),
                    ]);
                  },
                ),
                if (_markersLugaresCache.isNotEmpty)
                  MarkerLayer(markers: _markersLugaresCache),
                if (_markersGbifCache.isNotEmpty)
                  MarkerLayer(markers: _markersGbifCache),
                MarkerClusterLayerWidget(
                  options: MarkerClusterLayerOptions(
                    maxClusterRadius: 60,
                    size: Size(40, 40),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(50),
                    markers: _markersHallazgosCache,
                    builder: (context, marcadores) => Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${marcadores.length}',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            right: 8,
            child: BarraFiltroCategoria(
              filtroActual: _filtroCategoria,
              onCambio: (nuevo) => setState(() {
                _filtroCategoria = nuevo;
                _recalcularHallazgosFiltrados();
              }),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 64,
            right: 8,
            child: _BotonesAccion(
              capaActual: _capaBaseActual,
              onCambioCapa: (capa) => setState(() => _capaBaseActual = capa),
              onCentrar: _centrarEnMiUbicacion,
              onAbrirOffline: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => PantallaMapasOffline()),
              ),
              onAbrirTracks: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => PantallaTracks()),
              ),
              estaGrabando: estaGrabando,
              onAlternarGrabacion: _alternarGrabacionTrack,
              cargandoGbif: _cargandoGbif,
              hayGbif: _ocurrenciasGbif.isNotEmpty,
              onConsultarGbif: _consultarObservacionesCercanas,
              onLimpiarGbif: () => setState(() => _ocurrenciasGbif = []),
              cargandoLugares: _cargandoLugares,
              hayLugaresActivos: _tiposLugaresActivos.isNotEmpty,
              onAbrirSelectorLugares: _seleccionarTiposLugares,
              onRefrescarLugares: _refrescarLugaresInteres,
            ),
          ),
          if (_modoAgregar)
            CruzCentroMapa(
              latitud: _ultimoCentroMapa?.latitude,
              longitud: _ultimoCentroMapa?.longitude,
              onConfirmar: () {
                final centro = _ultimoCentroMapa;
                if (centro != null) {
                  widget.alPedirNuevoHallazgo(
                    latitud: centro.latitude,
                    longitud: centro.longitude,
                  );
                }
                setState(() => _modoAgregar = false);
              },
              onCancelar: () => setState(() => _modoAgregar = false),
            ),
        ],
      ),
      floatingActionButton: _modoAgregar
          ? null
          : FloatingActionButton(
              heroTag: 'fab_add_point',
              onPressed: () => setState(() {
                    _modoAgregar = true;
                    _ultimoCentroMapa = _centroInicial;
                  }),
              child: Icon(Icons.add_location),
            ),
    );
  }
}

class _IconoHallazgo extends StatelessWidget {
  final Hallazgo hallazgo;
  _IconoHallazgo({required this.hallazgo});

  @override
  Widget build(BuildContext context) {
    final categoria = categoriaPorId(hallazgo.categoria);
    final color = categoria?.color ?? Colors.grey;
    final icono = categoria?.icono ?? Icons.place;
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Icon(icono, color: Colors.white, size: 18),
    );
  }
}

/// Lateral derecho del mapa. Antes eran 8 FABs apilados que ocupaban
/// casi toda la altura en pantallas pequeñas. Ahora son 5: dos acciones
/// directas (GPS y track) y tres menús desplegables que agrupan capas,
/// datos cargables y tracks/offline.
class _BotonesAccion extends StatelessWidget {
  final CapaBase capaActual;
  final ValueChanged<CapaBase> onCambioCapa;
  final VoidCallback onCentrar;
  final VoidCallback onAbrirOffline;
  final VoidCallback onAbrirTracks;
  final bool estaGrabando;
  final VoidCallback onAlternarGrabacion;
  final bool cargandoGbif;
  final bool hayGbif;
  final VoidCallback onConsultarGbif;
  final VoidCallback onLimpiarGbif;
  final bool cargandoLugares;
  final bool hayLugaresActivos;
  final VoidCallback onAbrirSelectorLugares;
  final VoidCallback onRefrescarLugares;

  _BotonesAccion({
    required this.capaActual,
    required this.onCambioCapa,
    required this.onCentrar,
    required this.onAbrirOffline,
    required this.onAbrirTracks,
    required this.estaGrabando,
    required this.onAlternarGrabacion,
    required this.cargandoGbif,
    required this.hayGbif,
    required this.onConsultarGbif,
    required this.onLimpiarGbif,
    required this.cargandoLugares,
    required this.hayLugaresActivos,
    required this.onAbrirSelectorLugares,
    required this.onRefrescarLugares,
  });

  Future<void> _abrirMenuCapas(BuildContext context) async {
    const valorOffline = '__offline__';
    final seleccion = await showMenu<dynamic>(
      context: context,
      position: const RelativeRect.fromLTRB(1000, 100, 8, 0),
      items: [
        for (final capa in capasBaseDisponibles)
          PopupMenuItem(
            value: capa,
            child: Row(
              children: [
                Icon(
                  capa.nombre == capaActual.nombre ? Icons.check : Icons.layers_outlined,
                  size: 18,
                  color: capa.nombre == capaActual.nombre ? Colors.green.shade700 : null,
                ),
                const SizedBox(width: 8),
                Text(capa.nombre),
              ],
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: valorOffline,
          child: Row(
            children: [
              Icon(Icons.download_for_offline, size: 18),
              SizedBox(width: 8),
              Text('Mapas offline…'),
            ],
          ),
        ),
      ],
    );
    if (seleccion is CapaBase) {
      onCambioCapa(seleccion);
    } else if (seleccion == valorOffline) {
      onAbrirOffline();
    }
  }

  Future<void> _abrirMenuDatos(BuildContext context) async {
    const valorLugares = '__lugares__';
    const valorRecargarLugares = '__lugares_refresh__';
    const valorGbifVer = '__gbif_ver__';
    const valorGbifOcultar = '__gbif_ocultar__';

    final seleccion = await showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(1000, 100, 8, 0),
      items: [
        PopupMenuItem(
          value: valorLugares,
          child: Row(
            children: [
              Icon(
                Icons.place_outlined,
                size: 18,
                color: hayLugaresActivos ? Colors.green.shade700 : null,
              ),
              const SizedBox(width: 8),
              Text(hayLugaresActivos
                  ? 'Lugares de interés (activos)…'
                  : 'Lugares de interés…'),
            ],
          ),
        ),
        if (hayLugaresActivos)
          const PopupMenuItem(
            value: valorRecargarLugares,
            child: Row(
              children: [
                Icon(Icons.refresh, size: 18),
                SizedBox(width: 8),
                Text('Recargar lugares en la vista'),
              ],
            ),
          ),
        const PopupMenuDivider(),
        if (!hayGbif)
          const PopupMenuItem(
            value: valorGbifVer,
            child: Row(
              children: [
                Icon(Icons.public, size: 18),
                SizedBox(width: 8),
                Text('Observaciones GBIF cerca'),
              ],
            ),
          )
        else
          PopupMenuItem(
            value: valorGbifOcultar,
            child: Row(
              children: [
                Icon(Icons.layers_clear, size: 18, color: Colors.deepOrange),
                const SizedBox(width: 8),
                const Text('Ocultar observaciones GBIF'),
              ],
            ),
          ),
      ],
    );
    switch (seleccion) {
      case valorLugares:
        onAbrirSelectorLugares();
        break;
      case valorRecargarLugares:
        onRefrescarLugares();
        break;
      case valorGbifVer:
        onConsultarGbif();
        break;
      case valorGbifOcultar:
        onLimpiarGbif();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hayDatosCargados = hayLugaresActivos || hayGbif;
    return Column(
      children: [
        FloatingActionButton.small(
          heroTag: 'gps',
          tooltip: 'Centrar en mi ubicación',
          onPressed: onCentrar,
          child: const Icon(Icons.my_location),
        ),
        const SizedBox(height: 8),
        FloatingActionButton.small(
          heroTag: 'track',
          tooltip: estaGrabando ? 'Detener grabación de track' : 'Grabar track',
          backgroundColor: estaGrabando ? Colors.red : null,
          foregroundColor: estaGrabando ? Colors.white : null,
          onPressed: onAlternarGrabacion,
          child: Icon(estaGrabando ? Icons.stop : Icons.fiber_manual_record),
        ),
        const SizedBox(height: 8),
        FloatingActionButton.small(
          heroTag: 'capas',
          tooltip: 'Capas del mapa',
          onPressed: () => _abrirMenuCapas(context),
          child: const Icon(Icons.layers),
        ),
        const SizedBox(height: 8),
        FloatingActionButton.small(
          heroTag: 'datos',
          tooltip: 'Lugares de interés y observaciones',
          backgroundColor: hayDatosCargados ? Colors.green.shade700 : null,
          foregroundColor: hayDatosCargados ? Colors.white : null,
          onPressed: (cargandoLugares || cargandoGbif) ? null : () => _abrirMenuDatos(context),
          child: (cargandoLugares || cargandoGbif)
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.eco_outlined),
        ),
        const SizedBox(height: 8),
        FloatingActionButton.small(
          heroTag: 'tracks',
          tooltip: 'Tracks guardados',
          onPressed: onAbrirTracks,
          child: const Icon(Icons.route),
        ),
      ],
    );
  }
}

class _SelectorTiposLugares extends StatefulWidget {
  final Set<TipoLugarInteres> seleccionInicial;
  _SelectorTiposLugares({required this.seleccionInicial});

  @override
  State<_SelectorTiposLugares> createState() => _SelectorTiposLugaresState();
}

class _SelectorTiposLugaresState extends State<_SelectorTiposLugares> {
  late Set<TipoLugarInteres> _seleccion;

  @override
  void initState() {
    super.initState();
    _seleccion = {...widget.seleccionInicial};
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Capas de lugares de interés', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text(
              'Datos de OpenStreetMap. Las capas se cargan en la vista visible del mapa.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            SizedBox(height: 12),
            ...TipoLugarInteres.values.map(
              (tipo) => CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(tipo.etiqueta),
                value: _seleccion.contains(tipo),
                onChanged: (marcado) {
                  setState(() {
                    if (marcado == true) {
                      _seleccion.add(tipo);
                    } else {
                      _seleccion.remove(tipo);
                    }
                  });
                },
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(() => _seleccion = {}),
                  child: Text('Quitar todas'),
                ),
                Spacer(),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(_seleccion),
                  child: Text('Aplicar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
