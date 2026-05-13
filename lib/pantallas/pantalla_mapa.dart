import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart' show launchUrl, LaunchMode;
import '../servicios/servicio_geologia.dart';
import '../servicios/servicio_cuevas.dart';
import '../servicios/servicio_arqueologia.dart';
import '../servicios/cache_teselas.dart';
import '../servicios/grabador_track.dart';
import '../servicios/servicio_wikipedia.dart';
import '../servicios/geofencing.dart';
import '../servicios/estado_conexion.dart';
import '../servicios/servicio_mareas.dart';
import 'pantalla_tracks.dart';
import '../datos/datos_guia.dart';
import '../datos/datos_minerales.dart';
import '../datos/cronoestratigrafia.dart';
import '../datos/base_datos.dart';
import '../datos/yacimientos_curados.dart';
import '../modelos/hallazgo.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path_lib;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../servicios/tarjeta_imagen.dart';
import '../servicios/certificado_hallazgo.dart';
import '../servicios/identidad_descubridor.dart';
import 'pantalla_identidad.dart';
import '../datos/configuracion.dart';
import '../widgets/dialogo_trazabilidad.dart';
import 'pantalla_nuevo.dart';
import '../utiles/permisos_gps.dart' show asegurarPermisoUbicacion, asegurarPermisoNotificaciones;

typedef CallbackPedirNuevoHallazgo = void Function({double? latitud, double? longitud});
typedef CallbackSeleccionarFosilGuia = void Function(String idFosil);

const _centroEuskalHerria = LatLng(43.05, -2.45);
const _zoomInicial = 9.0;

enum _ModoMapa { ver, marcarPunto, explorarGeologia }

class CapaBase {
  final String nombre;
  final String urlPlantilla;
  final int maxZoom;
  final String atribucion;
  CapaBase({required this.nombre, required this.urlPlantilla, required this.maxZoom, required this.atribucion});
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

const String urlPlantillaHillshade =
    'https://server.arcgisonline.com/ArcGIS/rest/services/Elevation/World_Hillshade/MapServer/tile/{z}/{y}/{x}';

class PantallaMapa extends StatefulWidget {
  final CallbackPedirNuevoHallazgo alPedirNuevoHallazgo;
  final CallbackSeleccionarFosilGuia alSeleccionarFosilGuia;
  PantallaMapa({super.key, required this.alPedirNuevoHallazgo, required this.alSeleccionarFosilGuia});

  @override
  State<PantallaMapa> createState() => _PantallaMapaState();
}

class _PantallaMapaState extends State<PantallaMapa> {
  final _controladorMapa = MapController();
  final _proveedorTeselasCache = TileProviderConCache();
  _ModoMapa _modo = _ModoMapa.ver;
  CapaBase _capaBaseActual = capasBaseDisponibles.first;
  CapaGeologicaWms? _capaGeologicaActual = capasGeologicasWms.first;
  bool _mostrarHillshade = false;
  bool _mostrarLig = false;
  bool _cargandoCuevas = false;
  bool _cargandoMonumentos = false;
  bool _mostrarCuevas = false;
  bool _mostrarMonumentos = false;
  Timer? _debounceMovimiento;
  bool _mostrarAsistente = false;
  ContextoGeologico? _contextoAsistente;
  bool _cargandoAsistente = false;
  bool _menuModosExpandido = false;
  bool _modoHeatmap = false;
  bool _mostrarYacimientos = false;
  String? _filtroPeriodoId;
  Position? _ubicacionActual;
  List<Hallazgo> _hallazgos = [];
  final List<CuevaOSM> _cuevasVisibles = [];
  final Set<String> _idsCuevasYaPintadas = {};
  final List<MonumentoArqueologico> _monumentosVisibles = [];
  final Set<String> _idsMonumentosYaPintados = {};

  StreamSubscription<void>? _subTrack;
  StreamSubscription<Position>? _subUbicacion;
  StreamSubscription<MapEvent>? _subEventosMapa;
  StreamSubscription<bool>? _subConexion;
  bool _conectado = true;

  @override
  void initState() {
    super.initState();
    _cargarHallazgos();
    _iniciarSeguimientoUbicacion();
    _subTrack = GrabadorTrack.instancia.cambios.listen((_) {
      if (mounted) setState(() {});
    });
    _conectado = EstadoConexion.instancia.conectado;
    _subConexion = EstadoConexion.instancia.cambios.listen((online) {
      if (mounted) setState(() => _conectado = online);
    });
    _subEventosMapa = _controladorMapa.mapEventStream.listen((evento) {
      if (evento is MapEventMoveEnd) {
        _debounceMovimiento?.cancel();
        _debounceMovimiento = Timer(Duration(milliseconds: 1500), () {
          if (!mounted) return;
          if (_mostrarCuevas && !_cargandoCuevas) _cargarCuevasVistaActual();
          if (_mostrarMonumentos && !_cargandoMonumentos) _cargarMonumentosVistaActual();
          if (_mostrarAsistente && !_cargandoAsistente) _actualizarAsistenteCentro();
        });
      }
    });
  }

  @override
  void dispose() {
    _subTrack?.cancel();
    _subUbicacion?.cancel();
    _subEventosMapa?.cancel();
    _subConexion?.cancel();
    _debounceMovimiento?.cancel();
    _controladorMapa.dispose();
    super.dispose();
  }

  Future<void> _cargarHallazgos() async {
    final lista = await BaseDatosFosiles.instancia.listarHallazgos();
    if (!mounted) return;
    setState(() => _hallazgos = lista);
  }

  Future<void> _iniciarSeguimientoUbicacion() async {
    final permitido = await asegurarPermisoUbicacion();
    if (!permitido) return;
    var primeraPosicionRecibida = false;
    _subUbicacion = Geolocator.getPositionStream(
      locationSettings: LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
    ).listen((pos) {
      if (!mounted) return;
      setState(() => _ubicacionActual = pos);
      if (!primeraPosicionRecibida) {
        primeraPosicionRecibida = true;
        _controladorMapa.move(LatLng(pos.latitude, pos.longitude), 12);
      }
      final yacimiento = Geofencer.instancia.alEntrarEn(pos.latitude, pos.longitude);
      if (yacimiento != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${yacimiento.emoji} Estás en ${yacimiento.nombre}. Toca para ver qué buscar.'),
            duration: Duration(seconds: 8),
            action: SnackBarAction(
              label: 'Ver ficha',
              onPressed: () => _mostrarFichaYacimiento(yacimiento),
            ),
          ),
        );
      }
    });
  }

  Future<void> _centrarEnMiUbicacion() async {
    final permitido = await asegurarPermisoUbicacion();
    if (!permitido) return;
    final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    if (!mounted) return;
    setState(() => _ubicacionActual = pos);
    _controladorMapa.move(LatLng(pos.latitude, pos.longitude), 16);
  }

  void _mostrarDistanciaYRumbo(LatLng destino) {
    if (_ubicacionActual == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Esperando GPS para calcular distancia.')));
      return;
    }
    final origen = LatLng(_ubicacionActual!.latitude, _ubicacionActual!.longitude);
    final distancia = _haversine(origen, destino);
    final rumbo = _rumboInicial(origen, destino);
    final cardinal = _puntoCardinal(rumbo);
    final distanciaTexto = distancia < 1000
        ? '${distancia.toStringAsFixed(0)} m'
        : '${(distancia / 1000).toStringAsFixed(2)} km';
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Distancia y rumbo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Row(children: [
              Icon(Icons.straighten, size: 32),
              SizedBox(width: 12),
              Text(distanciaTexto, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            ]),
            SizedBox(height: 8),
            Row(children: [
              Icon(Icons.explore, size: 32),
              SizedBox(width: 12),
              Text('${rumbo.toStringAsFixed(0)}° ($cardinal)', style: TextStyle(fontSize: 22)),
            ]),
            SizedBox(height: 16),
            Text('Desde tu posición a ${destino.latitude.toStringAsFixed(5)}, ${destino.longitude.toStringAsFixed(5)}',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  double _haversine(LatLng a, LatLng b) {
    const radioTierra = 6371000.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return 2 * radioTierra * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  double _rumboInicial(LatLng a, LatLng b) {
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    var grados = math.atan2(y, x) * 180 / math.pi;
    if (grados < 0) grados += 360;
    return grados;
  }

  String _puntoCardinal(double azimut) {
    const dir = ['N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE', 'S', 'SSO', 'SO', 'OSO', 'O', 'ONO', 'NO', 'NNO', 'N'];
    return dir[((azimut / 22.5).round()) % 16];
  }

  Future<void> _alternarTrack() async {
    final grabador = GrabadorTrack.instancia;
    if (grabador.grabando) {
      final controlador = TextEditingController();
      final guardar = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Detener track'),
          content: TextField(
            controller: controlador,
            decoration: InputDecoration(labelText: 'Nombre (opcional)'),
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Descartar')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(SoleraL10n.t('guardar'))),
          ],
        ),
      );
      if (guardar == true) {
        final inicioMs = grabador.inicioMs;
        final r = grabador.detener(nombre: controlador.text.trim());
        if (r != null) {
          await BaseDatosFosiles.instancia.guardarTrack(r.track, r.puntos);
          // Buffer consolidado correctamente: limpiamos los puntos
          // huérfanos que la grabación dejó en disco (red de seguridad
          // ante crash). Idempotente.
          if (inicioMs != null) {
            await grabador.descartarBufferDeSesion(inicioMs);
          }
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Track guardado')));
        }
      } else {
        grabador.cancelar();
      }
    } else {
      final permitido = await asegurarPermisoUbicacion();
      if (!permitido) return;
      await asegurarPermisoNotificaciones();
      grabador.iniciar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('🔴 Grabando track. Puedes bloquear la pantalla; el track sigue corriendo.')),
        );
      }
    }
  }

  void _alTocarMapa(LatLng punto) async {
    if (_modo == _ModoMapa.marcarPunto) {
      setState(() => _modo = _ModoMapa.ver);
      widget.alPedirNuevoHallazgo(latitud: punto.latitude, longitud: punto.longitude);
      return;
    }
    if (_modo == _ModoMapa.explorarGeologia) {
      setState(() => _modo = _ModoMapa.ver);
      _mostrarFichaGeologia(punto);
      return;
    }
  }

  Future<void> _actualizarAsistenteCentro() async {
    if (_cargandoAsistente) return;
    final centro = _controladorMapa.camera.center;
    setState(() => _cargandoAsistente = true);
    try {
      final ctx = await consultarContextoGeologico(centro.latitude, centro.longitude);
      if (!mounted || !_mostrarAsistente) return;
      setState(() => _contextoAsistente = ctx);
    } catch (_) {
      // silencio: si falla, simplemente no actualizamos
    } finally {
      if (mounted) setState(() => _cargandoAsistente = false);
    }
  }

  void _alternarAsistente() {
    setState(() {
      _mostrarAsistente = !_mostrarAsistente;
      if (!_mostrarAsistente) _contextoAsistente = null;
    });
    if (_mostrarAsistente) _actualizarAsistenteCentro();
  }

  Future<void> _alternarCuevas() async {
    debugPrint('[fosiles] alternarCuevas: mostrar=$_mostrarCuevas yaCargadas=${_idsCuevasYaPintadas.length} zoom=${_controladorMapa.camera.zoom}');
    if (_mostrarCuevas) {
      setState(() {
        _mostrarCuevas = false;
        _cuevasVisibles.clear();
        _idsCuevasYaPintadas.clear();
      });
      return;
    }
    setState(() => _mostrarCuevas = true);
    await _cargarCuevasVistaActual();
  }

  Future<void> _alternarMonumentos() async {
    debugPrint('[fosiles] alternarMonumentos: mostrar=$_mostrarMonumentos yaCargados=${_idsMonumentosYaPintados.length} zoom=${_controladorMapa.camera.zoom}');
    if (_mostrarMonumentos) {
      setState(() {
        _mostrarMonumentos = false;
        _monumentosVisibles.clear();
        _idsMonumentosYaPintados.clear();
      });
      return;
    }
    setState(() => _mostrarMonumentos = true);
    await _cargarMonumentosVistaActual();
  }

  Future<void> _cargarMonumentosVistaActual() async {
    if (_cargandoMonumentos) return;
    final camara = _controladorMapa.camera;
    if (camara.zoom < 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('🗿 Acércate más (zoom ≥ 9) para cargar monumentos.'), duration: Duration(seconds: 4)),
      );
      return;
    }
    final bounds = camara.visibleBounds;
    debugPrint('[fosiles] cargando monumentos bbox=${bounds.south},${bounds.west},${bounds.north},${bounds.east}');
    setState(() => _cargandoMonumentos = true);
    try {
      final monumentos = await buscarMonumentosArqueologicos(LimitesGeograficos(
        sur: bounds.south,
        norte: bounds.north,
        oeste: bounds.west,
        este: bounds.east,
      ));
      debugPrint('[fosiles] monumentos recibidos: ${monumentos.length}');
      if (!mounted) return;
      if (!_mostrarMonumentos) return;
      setState(() {
        for (final m in monumentos) {
          if (_idsMonumentosYaPintados.add(m.id)) {
            _monumentosVisibles.add(m);
          }
        }
      });
      if (mounted) {
        final mensaje = monumentos.isEmpty
            ? '🗿 Sin monumentos OSM en esta vista. Prueba a desplazar el mapa.'
            : '🗿 ${monumentos.length} monumentos cargados.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje), duration: Duration(seconds: 3)));
      }
    } catch (e) {
      debugPrint('[fosiles] error monumentos: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error monumentos: $e'), duration: Duration(seconds: 6)));
    } finally {
      if (mounted) setState(() => _cargandoMonumentos = false);
    }
  }

  void _mostrarFichaYacimiento(YacimientoCurado y) {
    final periodo = buscarPeriodo(y.periodoId);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.95,
        minChildSize: 0.3,
        builder: (_, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(y.emoji, style: TextStyle(fontSize: 32)),
              SizedBox(width: 8),
              Expanded(child: Text(y.nombre, style: Theme.of(context).textTheme.titleLarge)),
            ]),
            SizedBox(height: 8),
            if (periodo != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: periodo.color, borderRadius: BorderRadius.circular(4)),
                child: Text(y.tituloEdad, style: TextStyle(color: Color(0xFF2D3A2E), fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            SizedBox(height: 12),
            Text(y.descripcionCorta),
            SizedBox(height: 16),
            _BloqueMareas(latitud: y.latitud, longitud: y.longitud),
            SizedBox(height: 16),
            Text('Qué buscar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            SizedBox(height: 4),
            ...y.queBuscar.map((q) => Padding(padding: const EdgeInsets.only(left: 8, top: 2), child: Text('• $q'))),
            SizedBox(height: 16),
            Text('Cómo llegar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            SizedBox(height: 4),
            Text(y.comoLlegar),
            SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(Icons.add_location),
                  onPressed: () {
                    Navigator.of(sheetCtx).pop();
                    widget.alPedirNuevoHallazgo(latitud: y.latitud, longitud: y.longitud);
                  },
                  label: Text('Marcar hallazgo aquí'),
                ),
              ),
            ]),
            if (y.referencias.isNotEmpty) ...[
              SizedBox(height: 12),
              Text('Fuente: ${y.referencias.join(", ")}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ],
          ],
        ),
      ),
    );
  }

  void _mostrarPopupMonumento(MonumentoArqueologico m) {
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
                Text(m.emoji, style: TextStyle(fontSize: 28)),
                SizedBox(width: 8),
                Expanded(child: Text(m.nombre, style: Theme.of(context).textTheme.titleLarge)),
              ],
            ),
            SizedBox(height: 8),
            Text(m.tipoLegible, style: TextStyle(fontStyle: FontStyle.italic)),
            SizedBox(height: 12),
            if (m.descripcion != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(m.descripcion!)),
            if (m.historico != null) Text('Cronología: ${m.historico}'),
            SizedBox(height: 16),
            OutlinedButton.icon(
              icon: Icon(Icons.open_in_new),
              onPressed: () => launchUrl(Uri.parse(m.enlaceOSM), mode: LaunchMode.externalApplication),
              label: Text('Ver en OpenStreetMap'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cargarCuevasVistaActual() async {
    if (_cargandoCuevas) return;
    final camara = _controladorMapa.camera;
    if (camara.zoom < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('🦇 Acércate más (zoom ≥ 10) para cargar cuevas.'), duration: Duration(seconds: 4)),
      );
      return;
    }
    final bounds = camara.visibleBounds;
    setState(() => _cargandoCuevas = true);
    try {
      debugPrint('[fosiles] cargando cuevas bbox=${bounds.south},${bounds.west},${bounds.north},${bounds.east}');
      final cuevas = await buscarCuevas(LimitesGeograficos(
        sur: bounds.south,
        norte: bounds.north,
        oeste: bounds.west,
        este: bounds.east,
      ));
      debugPrint('[fosiles] cuevas recibidas: ${cuevas.length}');
      if (!mounted) return;
      if (!_mostrarCuevas) return;
      setState(() {
        for (final cueva in cuevas) {
          if (_idsCuevasYaPintadas.add(cueva.id)) {
            _cuevasVisibles.add(cueva);
          }
        }
      });
      if (mounted) {
        final mensaje = cuevas.isEmpty
            ? '🦇 Sin cuevas OSM en esta vista. Prueba a desplazar el mapa.'
            : '🦇 ${cuevas.length} cuevas cargadas.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje), duration: Duration(seconds: 3)));
      }
    } catch (e) {
      debugPrint('[fosiles] error cuevas: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error cuevas: $e'), duration: Duration(seconds: 6)));
    } finally {
      if (mounted) setState(() => _cargandoCuevas = false);
    }
  }

  void _mostrarFichaHallazgo(List<Hallazgo> lista, int indiceInicial) {
    final controladorPagina = PageController(initialPage: indiceInicial);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (_, setStateLocal) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          builder: (_, scrollController) => Column(
            children: [
              if (lista.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${indiceInicial + 1} / ${lista.length}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black54),
                  ),
                ),
              Expanded(
                child: PageView.builder(
                  controller: controladorPagina,
                  itemCount: lista.length,
                  onPageChanged: (i) => setStateLocal(() => indiceInicial = i),
                  itemBuilder: (_, i) {
                    final h = lista[i];
                  return SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (h.rutasFotos.isNotEmpty)
                          SizedBox(
                            height: 240,
                            child: PageView.builder(
                              itemCount: h.rutasFotos.length,
                              itemBuilder: (_, fi) => Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(File(h.rutasFotos[fi]),
                                          height: 240, width: double.infinity, fit: BoxFit.cover),
                                    ),
                                    if (h.rutasFotos.length > 1)
                                      Positioned(
                                        right: 8,
                                        bottom: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                              color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                                          child: Text('${fi + 1} / ${h.rutasFotos.length}',
                                              style: TextStyle(color: Colors.white, fontSize: 11)),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        SizedBox(height: 12),
                        _BadgeFirmaHallazgo(hallazgo: h),
                        SizedBox(height: 8),
                        _filaHallazgo('Especie', h.especie.isEmpty ? '—' : h.especie),
                        _filaHallazgo('Edad', h.edad.isEmpty ? '—' : h.edad),
                        _filaHallazgo('Formación', h.formacion.isEmpty ? '—' : h.formacion),
                        _filaHallazgo(
                          'Fecha',
                          DateFormat('dd MMM yyyy HH:mm', 'es_ES')
                              .format(DateTime.fromMillisecondsSinceEpoch(h.fechaMs)),
                        ),
                        _filaHallazgo(
                          'Coordenadas',
                          '${h.latitud.toStringAsFixed(5)}, ${h.longitud.toStringAsFixed(5)}${h.precision != null ? " (±${h.precision!.round()} m)" : ""}',
                        ),
                        if (h.strikeGrados != null && h.dipGrados != null)
                          _filaHallazgo('Estrato',
                              '${h.strikeGrados!.toStringAsFixed(0)}° / ${h.dipGrados!.toStringAsFixed(0)}°'),
                        _filaHallazgo('Notas', h.notas.isEmpty ? '—' : h.notas),
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
                                await BaseDatosFosiles.instancia.borrarHallazgo(h.id!);
                                if (!mounted) return;
                                Navigator.of(sheetContext).pop();
                                _cargarHallazgos();
                              },
                              label: Text('Borrar', style: TextStyle(color: Colors.red)),
                            ),
                          ),
                        ]),
                        SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: Icon(Icons.share),
                              onPressed: () => _compartirHallazgo(h),
                              label: Text('Compartir texto'),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              icon: Icon(Icons.image),
                              onPressed: () => _compartirComoTarjeta(h),
                              label: Text('Tarjeta'),
                            ),
                          ),
                        ]),
                        SizedBox(height: 8),
                        OutlinedButton.icon(
                          icon: Icon(Icons.verified_user),
                          onPressed: () => _compartirCertificado(h),
                          label: Text('Certificado verificable'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: Size(double.infinity, 40),
                          ),
                        ),
                        SizedBox(height: 16),
                        if (h.historialTrazabilidad.isNotEmpty) ...[
                          Text('Historial de trazabilidad',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          SizedBox(height: 6),
                          ...h.historialTrazabilidad.map(tarjetaEventoTrazabilidad),
                          SizedBox(height: 8),
                        ],
                        OutlinedButton.icon(
                          icon: Icon(Icons.add),
                          onPressed: () async {
                            final nombre = await Configuracion.obtenerNombreDescubridor();
                            if (!mounted) return;
                            final anadido = await mostrarDialogoAnadirTrazabilidad(context, h, nombre);
                            if (anadido) {
                              _cargarHallazgos();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Evento añadido al historial.')),
                                );
                              }
                            }
                          },
                          label: Text(h.historialTrazabilidad.isEmpty
                              ? 'Añadir trazabilidad'
                              : 'Añadir evento'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: Size(double.infinity, 40),
                          ),
                        ),
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

  Widget _filaHallazgo(String clave, String valor) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 100, child: Text(clave, style: TextStyle(fontWeight: FontWeight.bold))),
            Expanded(child: Text(valor)),
          ],
        ),
      );

  Future<void> _compartirHallazgo(Hallazgo hallazgo) async {
    final fecha = DateFormat('dd MMM yyyy', 'es_ES')
        .format(DateTime.fromMillisecondsSinceEpoch(hallazgo.fechaMs));
    final texto = StringBuffer()
      ..writeln('Hallazgo de fósil')
      ..writeln('Especie: ${hallazgo.especie.isEmpty ? "?" : hallazgo.especie}')
      ..writeln('Edad: ${hallazgo.edad.isEmpty ? "?" : hallazgo.edad}')
      ..writeln('Formación: ${hallazgo.formacion.isEmpty ? "?" : hallazgo.formacion}')
      ..writeln(
          'Coordenadas: ${hallazgo.latitud.toStringAsFixed(5)}, ${hallazgo.longitud.toStringAsFixed(5)}')
      ..writeln('Fecha: $fecha')
      ..writeln(
          'Mapa: https://www.openstreetmap.org/?mlat=${hallazgo.latitud}&mlon=${hallazgo.longitud}#map=16/${hallazgo.latitud}/${hallazgo.longitud}');
    if (hallazgo.notas.isNotEmpty) {
      texto
        ..writeln()
        ..writeln(hallazgo.notas);
    }
    if (hallazgo.rutaFoto != null) {
      await Share.shareXFiles([XFile(hallazgo.rutaFoto!)],
          text: texto.toString(), subject: 'Hallazgo: ${hallazgo.especie}');
    } else {
      await Share.share(texto.toString(), subject: 'Hallazgo: ${hallazgo.especie}');
    }
  }

  Future<void> _compartirComoTarjeta(Hallazgo hallazgo) async {
    showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => Center(child: CircularProgressIndicator()));
    try {
      final fichero = await generarTarjetaHallazgo(hallazgo);
      if (!mounted) return;
      Navigator.of(context).pop();
      await Share.shareXFiles([XFile(fichero.path)],
          subject: 'Hallazgo: ${hallazgo.especie}');
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error generando tarjeta: $e')));
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

  void _mostrarPopupCueva(CuevaOSM cueva) {
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
                Text('🦇', style: TextStyle(fontSize: 28)),
                SizedBox(width: 8),
                Expanded(child: Text(cueva.nombre, style: Theme.of(context).textTheme.titleLarge)),
              ],
            ),
            SizedBox(height: 12),
            if (cueva.profundidadMetros != null) Text('Profundidad: ${cueva.profundidadMetros} m'),
            if (cueva.longitudMetros != null) Text('Longitud: ${cueva.longitudMetros} m'),
            if (cueva.tipo != null) Text('Tipo: ${cueva.tipo}'),
            SizedBox(height: 16),
            OutlinedButton.icon(
              icon: Icon(Icons.open_in_new),
              onPressed: () => launchUrl(Uri.parse(cueva.enlaceOSM), mode: LaunchMode.externalApplication),
              label: Text('Ver en OpenStreetMap'),
            ),
          ],
        ),
      ),
    );
  }

  Future<({ContextoGeologico? geo, List<LugarInteresGeologico> ligs})> _consultarPunto(LatLng punto) async {
    final delta = 0.02;
    final results = await Future.wait([
      consultarContextoGeologico(punto.latitude, punto.longitude),
      _mostrarLig
          ? buscarLigsEnExtension(
              sur: punto.latitude - delta,
              norte: punto.latitude + delta,
              oeste: punto.longitude - delta,
              este: punto.longitude + delta,
            )
          : Future.value(<LugarInteresGeologico>[]),
    ]);
    return (geo: results[0] as ContextoGeologico?, ligs: results[1] as List<LugarInteresGeologico>);
  }

  Future<void> _mostrarFichaGeologia(LatLng punto) async {
    final futuro = _consultarPunto(punto);
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          maxChildSize: 0.9,
          minChildSize: 0.3,
          builder: (_, scrollController) => FutureBuilder<({ContextoGeologico? geo, List<LugarInteresGeologico> ligs})>(
            future: futuro,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
              }
              final contexto = snapshot.data?.geo;
              final ligs = snapshot.data?.ligs ?? const <LugarInteresGeologico>[];
              if (contexto == null && ligs.isEmpty) {
                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: const [
                    Text('Sin datos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    SizedBox(height: 8),
                    Text('El IGME no devuelve información en este punto.'),
                  ],
                );
              }
              final periodoId = inferirPeriodoDesdeEdad(contexto?.edad);
              final periodo = periodoId != null ? buscarPeriodo(periodoId) : null;
              final fosiles = periodoId != null ? fosilesPorPeriodo(periodoId).take(6).toList() : <FosilGuia>[];
              final minerales = mineralesProbablesEnContexto(
                edad: contexto?.edad,
                formacion: contexto?.formacion,
                litologia: contexto?.litologia,
              ).take(6).toList();
              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Geología en este punto', style: Theme.of(context).textTheme.titleLarge),
                  SizedBox(height: 12),
                  if (contexto?.edad != null) ...[
                    _filaGeo('Edad', contexto!.edad!),
                    if (rangoMaDeEdad(contexto.edad) != null)
                      _filaGeo('Antigüedad', '≈ ${rangoMaDeEdad(contexto.edad)!.formatear()}'),
                  ],
                  if (periodo != null)
                    _filaGeo('Era / Período', '${periodo.nombre} · ${periodo.edadMa}'),
                  if (contexto?.formacion != null) _filaGeo('Formación', contexto!.formacion!),
                  if (contexto?.litologia != null) _filaGeo('Litología', contexto!.litologia!),
                  if (ligs.isNotEmpty) ...[
                    SizedBox(height: 16),
                    Text('Lugares de Interés Geológico cerca', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    SizedBox(height: 6),
                    ...ligs.take(8).map((lig) => Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            leading: CircleAvatar(child: Text('⭐')),
                            title: Text(lig.nombre, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              [lig.interesPrincipal, lig.edad].where((s) => s != null && s.isNotEmpty).join(' · '),
                              style: TextStyle(fontSize: 11),
                            ),
                            onTap: () => _mostrarFichaLig(lig),
                          ),
                        )),
                  ],
                  SizedBox(height: 16),
                  if (fosiles.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: periodo?.color, borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        'Fósiles probables aquí · ${periodo?.nombre ?? ''}',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D3A2E), fontSize: 13),
                      ),
                    ),
                    SizedBox(height: 8),
                    ...fosiles.map((f) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: _MiniaturaFosilWikipedia(tituloWikipedia: f.tituloWikipedia),
                          title: Text(f.nombre),
                          subtitle: Text(f.grupo, style: TextStyle(fontSize: 11)),
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            widget.alSeleccionarFosilGuia(f.id);
                          },
                        )),
                  ] else if (contexto?.edad != null) ...[
                    Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('No hay fósiles asociados en la guía para esta edad.', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
                    ),
                  ],
                  if (minerales.isNotEmpty) ...[
                    SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.blueGrey.shade200, borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        '💎 Minerales probables aquí',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D3A2E), fontSize: 13),
                      ),
                    ),
                    SizedBox(height: 8),
                    ...minerales.map((m) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: _MiniaturaFosilWikipedia(tituloWikipedia: m.tituloWikipedia),
                          title: Text(m.nombre),
                          subtitle: Text('${m.formulaQuimica}  ·  Mohs ${m.durezaMohs}', style: TextStyle(fontSize: 11)),
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            abrirDetalleMineral(context, m.id);
                          },
                        )),
                  ],
                  SizedBox(height: 12),
                  Text('Fuente: IGME GEODE 50', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _mostrarFichaLig(LugarInteresGeologico lig) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        builder: (__, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('⭐', style: TextStyle(fontSize: 28)),
              SizedBox(width: 8),
              Expanded(child: Text(lig.nombre, style: Theme.of(context).textTheme.titleLarge)),
            ]),
            SizedBox(height: 12),
            if (lig.interesPrincipal != null) _filaGeo('Interés principal', lig.interesPrincipal!),
            if (lig.edad != null) _filaGeo('Edad', lig.edad!),
            if (lig.descripcion != null) ...[
              SizedBox(height: 12),
              Text('Descripción', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text(lig.descripcion!),
            ],
            SizedBox(height: 16),
            Text('Fuente: IGME · Inventario Español de LIG', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _filaGeo(String clave, String valor) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: RichText(
          text: TextSpan(
            style: DefaultTextStyle.of(context).style,
            children: [
              TextSpan(text: '$clave: ', style: TextStyle(fontWeight: FontWeight.bold)),
              TextSpan(text: valor),
            ],
          ),
        ),
      );

  List<Hallazgo> get _hallazgosFiltrados {
    if (_filtroPeriodoId == null) return _hallazgos;
    return _hallazgos.where((h) => inferirPeriodoDesdeEdad(h.edad) == _filtroPeriodoId).toList();
  }

  @override
  Widget build(BuildContext context) {
    final hallazgosVisibles = _hallazgosFiltrados;
    final marcadoresHallazgos = _modoHeatmap
        ? <Marker>[]
        : List.generate(hallazgosVisibles.length, (i) {
            final h = hallazgosVisibles[i];
            final periodoId = inferirPeriodoDesdeEdad(h.edad);
            final color = periodoId != null ? buscarPeriodo(periodoId)?.color : null;
            final esMineral = h.esMineral;
            final icono = esMineral ? Icons.diamond : Icons.location_on;
            final colorIcono = color ?? (esMineral ? Color(0xFF2E5C8A) : Color(0xFFB54A2A));
            return Marker(
              point: LatLng(h.latitud, h.longitud),
              width: 44,
              height: 44,
              child: GestureDetector(
                onTap: () => _mostrarFichaHallazgo(hallazgosVisibles, i),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
                  ),
                  child: Icon(icono, color: colorIcono, size: esMineral ? 24 : 28),
                ),
              ),
            );
          });
    final circulosCalor = _modoHeatmap
        ? hallazgosVisibles.map((h) => CircleMarker(
              point: LatLng(h.latitud, h.longitud),
              radius: 24,
              useRadiusInMeter: false,
              color: Color(0xFFB54A2A).withValues(alpha: 0.35),
              borderStrokeWidth: 0,
            )).toList()
        : <CircleMarker>[];

    final marcadoresCuevas = _cuevasVisibles.map((c) => Marker(
          point: LatLng(c.latitud, c.longitud),
          width: 28,
          height: 28,
          child: GestureDetector(
            onTap: () => _mostrarPopupCueva(c),
            child: Container(
              decoration: BoxDecoration(
                color: Color(0xFF7A4A9A),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              alignment: Alignment.center,
              child: Text('🦇', style: TextStyle(fontSize: 14)),
            ),
          ),
        )).toList();

    final marcadoresYacimientos = _mostrarYacimientos
        ? yacimientosCurados.map((y) => Marker(
              point: LatLng(y.latitud, y.longitud),
              width: 32,
              height: 32,
              child: GestureDetector(
                onTap: () => _mostrarFichaYacimiento(y),
                child: Container(
                  decoration: BoxDecoration(
                    color: Color(0xFF8B0000),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(y.emoji, style: TextStyle(fontSize: 16)),
                ),
              ),
            )).toList()
        : <Marker>[];

    final marcadoresMonumentos = _monumentosVisibles.map((m) => Marker(
          point: LatLng(m.latitud, m.longitud),
          width: 28,
          height: 28,
          child: GestureDetector(
            onTap: () => _mostrarPopupMonumento(m),
            child: Container(
              decoration: BoxDecoration(
                color: Color(0xFF806040),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              alignment: Alignment.center,
              child: Text(m.emoji, style: TextStyle(fontSize: 14)),
            ),
          ),
        )).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(SoleraL10n.t('mapa')),
        actions: [
          PopupMenuButton<CapaBase>(
            icon: Icon(Icons.layers),
            tooltip: 'Capa base',
            onSelected: (capa) => setState(() => _capaBaseActual = capa),
            itemBuilder: (_) => capasBaseDisponibles
                .map((c) => PopupMenuItem(value: c, child: Text(c.nombre + (c == _capaBaseActual ? ' ✓' : ''))))
                .toList(),
          ),
          PopupMenuButton<String>(
            icon: Icon(_capaGeologicaActual == null ? Icons.terrain_outlined : Icons.terrain),
            tooltip: 'Capa geológica',
            onSelected: (valor) => setState(() {
              if (valor == '__off__') {
                _capaGeologicaActual = null;
              } else {
                _capaGeologicaActual = capasGeologicasWms.firstWhere((c) => c.nombre == valor);
              }
            }),
            itemBuilder: (_) => [
              PopupMenuItem(value: '__off__', child: Text('Sin geología' + (_capaGeologicaActual == null ? ' ✓' : ''))),
              PopupMenuDivider(),
              ...capasGeologicasWms.map((c) => PopupMenuItem(
                    value: c.nombre,
                    child: Text(c.nombre + (c.nombre == _capaGeologicaActual?.nombre ? ' ✓' : '')),
                  )),
            ],
          ),
          IconButton(
            icon: Icon(_mostrarLig ? Icons.star : Icons.star_outline),
            tooltip: _mostrarLig ? 'Ocultar LIG' : 'Mostrar Lugares de Interés Geológico',
            onPressed: () => setState(() => _mostrarLig = !_mostrarLig),
          ),
          IconButton(
            icon: Icon(_mostrarHillshade ? Icons.landscape : Icons.landscape_outlined),
            tooltip: _mostrarHillshade ? 'Ocultar relieve' : 'Mostrar relieve',
            onPressed: () => setState(() => _mostrarHillshade = !_mostrarHillshade),
          ),
          IconButton(
            icon: Icon(_modoHeatmap ? Icons.local_fire_department : Icons.local_fire_department_outlined),
            tooltip: _modoHeatmap ? 'Ver puntos' : 'Ver mapa de calor',
            onPressed: () => setState(() => _modoHeatmap = !_modoHeatmap),
          ),
          IconButton(
            icon: Icon(_mostrarYacimientos ? Icons.museum : Icons.museum_outlined),
            tooltip: _mostrarYacimientos ? 'Ocultar yacimientos' : 'Mostrar yacimientos curados',
            onPressed: () => setState(() => _mostrarYacimientos = !_mostrarYacimientos),
          ),
          IconButton(
            icon: Icon(GrabadorTrack.instancia.grabando ? Icons.stop_circle : Icons.fiber_manual_record),
            color: GrabadorTrack.instancia.grabando ? Colors.red : null,
            tooltip: GrabadorTrack.instancia.grabando ? 'Detener track' : 'Iniciar track',
            onPressed: _alternarTrack,
          ),
          IconButton(
            icon: Icon(Icons.timeline),
            tooltip: 'Tracks guardados',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PantallaTracks())),
          ),
        ],
      ),
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
          FlutterMap(
            mapController: _controladorMapa,
            options: MapOptions(
              initialCenter: _centroEuskalHerria,
              initialZoom: _zoomInicial,
              minZoom: 6,
              maxZoom: 18,
              onTap: (_, punto) => _alTocarMapa(punto),
              onLongPress: (_, punto) => _mostrarDistanciaYRumbo(punto),
            ),
            children: [
              TileLayer(
                urlTemplate: _capaBaseActual.urlPlantilla,
                maxZoom: _capaBaseActual.maxZoom.toDouble(),
                userAgentPackageName: 'com.josu.fosiles',
                tileProvider: _proveedorTeselasCache,
              ),
              if (_capaGeologicaActual != null)
                Opacity(
                  opacity: 0.55,
                  child: TileLayer(
                    key: ValueKey('geo-${_capaGeologicaActual!.nombre}'),
                    wmsOptions: WMSTileLayerOptions(
                      baseUrl: '${_capaGeologicaActual!.urlBase}?',
                      layers: _capaGeologicaActual!.capas,
                      format: 'image/png',
                      transparent: true,
                      version: '1.1.1',
                    ),
                    userAgentPackageName: 'com.josu.fosiles',
                    tileProvider: _proveedorTeselasCache,
                  ),
                ),
              if (_mostrarLig)
                Opacity(
                  opacity: 0.85,
                  child: TileLayer(
                    key: ValueKey('lig'),
                    wmsOptions: WMSTileLayerOptions(
                      baseUrl: '$urlWmsIgmeLig?',
                      layers: const ['0'],
                      format: 'image/png',
                      transparent: true,
                      version: '1.1.1',
                    ),
                    userAgentPackageName: 'com.josu.fosiles',
                    tileProvider: _proveedorTeselasCache,
                  ),
                ),
              if (_mostrarHillshade)
                Opacity(
                  opacity: 0.5,
                  child: TileLayer(
                    urlTemplate: urlPlantillaHillshade,
                    maxZoom: 16,
                    userAgentPackageName: 'com.josu.fosiles',
                    tileProvider: _proveedorTeselasCache,
                  ),
                ),
              if (_capaGeologicaActual != null || _mostrarLig)
                TileLayer(
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager_only_labels/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  maxZoom: 19,
                  userAgentPackageName: 'com.josu.fosiles',
                  tileProvider: _proveedorTeselasCache,
                ),
              if (GrabadorTrack.instancia.grabando && GrabadorTrack.instancia.puntos.length >= 2)
                PolylineLayer(polylines: [
                  Polyline(
                    points: GrabadorTrack.instancia.puntos.map((p) => LatLng(p.latitud, p.longitud)).toList(),
                    color: Colors.red,
                    strokeWidth: 4,
                  ),
                ]),
              if (circulosCalor.isNotEmpty) CircleLayer(circles: circulosCalor),
              if (marcadoresHallazgos.isNotEmpty) MarkerLayer(markers: marcadoresHallazgos),
              if (marcadoresCuevas.isNotEmpty) MarkerLayer(markers: marcadoresCuevas),
              if (marcadoresMonumentos.isNotEmpty) MarkerLayer(markers: marcadoresMonumentos),
              if (marcadoresYacimientos.isNotEmpty) MarkerLayer(markers: marcadoresYacimientos),
              if (_ubicacionActual != null)
                MarkerLayer(markers: [
                  Marker(
                    point: LatLng(_ubicacionActual!.latitude, _ubicacionActual!.longitude),
                    width: 24,
                    height: 24,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Color(0xFF5E7D3A),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                      ),
                    ),
                  ),
                ]),
            ],
          ),
          if (_modo != _ModoMapa.ver)
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    _modo == _ModoMapa.marcarPunto
                        ? '👆 Toca el mapa para marcar el hallazgo'
                        : '👆 Toca el mapa para ver la geología',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ),
            ),
          if (_hallazgos.isNotEmpty)
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _chipFiltro(null, 'Todos', _hallazgos.length),
                    ...periodos.map((p) {
                      final n = _hallazgos.where((h) => inferirPeriodoDesdeEdad(h.edad) == p.id).length;
                      if (n == 0) return const SizedBox.shrink();
                      return _chipFiltro(p.id, p.nombre, n, color: p.color);
                    }),
                  ],
                ),
              ),
            ),
          Positioned(
            left: 12,
            bottom: 100,
            child: _menuModos(),
          ),
          Positioned(
            right: 12,
            bottom: 100,
            child: FloatingActionButton(
              heroTag: 'fab_ubicacion',
              onPressed: _centrarEnMiUbicacion,
              child: Icon(Icons.my_location),
            ),
          ),
          if (_mostrarAsistente)
            Center(
              child: IgnorePointer(
                child: _MarcadorCentroAsistente(),
              ),
            ),
          if (_mostrarAsistente)
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: _panelAsistente(),
            ),
        ],
      ),
    );
  }

  Widget _panelAsistente() {
    final ctx = _contextoAsistente;
    final periodoId = inferirPeriodoDesdeEdad(ctx?.edad);
    final periodo = periodoId != null ? buscarPeriodo(periodoId) : null;
    final fosiles = periodoId != null ? fosilesPorPeriodo(periodoId).take(4).toList() : <FosilGuia>[];
    final minerales = mineralesProbablesEnContexto(
      edad: ctx?.edad,
      formacion: ctx?.formacion,
      litologia: ctx?.litologia,
    ).take(4).toList();
    final esquema = Theme.of(context).colorScheme;
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      color: esquema.surface.withValues(alpha: 0.95),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.assistant, size: 18, color: esquema.primary),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  _cargandoAsistente
                      ? 'Consultando IGME…'
                      : (ctx?.edad ?? 'Sin datos del IGME en el centro del mapa'),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: esquema.onSurface),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, size: 18),
                onPressed: _alternarAsistente,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
            ]),
            if (periodo != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: periodo.color, borderRadius: BorderRadius.circular(4)),
                  child: Text('${periodo.nombre} · ${periodo.edadMa}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2D3A2E))),
                ),
              ),
            if (fosiles.isNotEmpty || minerales.isNotEmpty)
              SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final f in fosiles)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          avatar: Text('🦴'),
                          label: Text(f.nombre, style: TextStyle(fontSize: 11)),
                          onPressed: () => widget.alSeleccionarFosilGuia(f.id),
                        ),
                      ),
                    for (final m in minerales)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          avatar: Text('💎'),
                          label: Text(m.nombre, style: TextStyle(fontSize: 11)),
                          onPressed: () => abrirDetalleMineral(context, m.id),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chipFiltro(String? id, String etiqueta, int conteo, {Color? color}) {
    final activo = _filtroPeriodoId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: activo ? (color ?? Theme.of(context).colorScheme.primary) : Colors.white,
        elevation: 2,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() => _filtroPeriodoId = activo ? null : id),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (color != null && !activo)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                Text('$etiqueta · $conteo', style: TextStyle(fontSize: 12, color: activo ? Colors.white : Colors.black87, fontWeight: activo ? FontWeight.bold : FontWeight.normal)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _menuModos() {
    final activos = [
      _modo == _ModoMapa.marcarPunto,
      _modo == _ModoMapa.explorarGeologia,
      _mostrarCuevas,
      _mostrarMonumentos,
      _mostrarAsistente,
    ].where((b) => b).length;
    final esquema = Theme.of(context).colorScheme;

    if (!_menuModosExpandido) {
      return Material(
        color: activos > 0 ? esquema.primary : esquema.surface,
        borderRadius: BorderRadius.circular(28),
        elevation: 3,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () => setState(() => _menuModosExpandido = true),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.layers, color: activos > 0 ? Colors.white : esquema.onSurface),
                if (activos > 0)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      constraints: BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Text('$activos',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _botonModo(
          icono: Icons.location_on,
          etiqueta: 'Marcar punto',
          activo: _modo == _ModoMapa.marcarPunto,
          onTap: () => setState(() => _modo = _modo == _ModoMapa.marcarPunto ? _ModoMapa.ver : _ModoMapa.marcarPunto),
        ),
        SizedBox(height: 6),
        _botonModo(
          icono: Icons.info,
          etiqueta: 'Explorar geología',
          activo: _modo == _ModoMapa.explorarGeologia,
          onTap: () => setState(() => _modo = _modo == _ModoMapa.explorarGeologia ? _ModoMapa.ver : _ModoMapa.explorarGeologia),
        ),
        SizedBox(height: 6),
        _botonModo(
          icono: _cargandoCuevas ? Icons.hourglass_top : Icons.bedroom_baby,
          etiqueta: _cargandoCuevas
              ? 'Cargando…'
              : (_idsCuevasYaPintadas.isEmpty ? 'Cuevas' : 'Cuevas (${_idsCuevasYaPintadas.length})'),
          activo: _mostrarCuevas,
          onTap: _alternarCuevas,
        ),
        SizedBox(height: 6),
        _botonModo(
          icono: _cargandoMonumentos ? Icons.hourglass_top : Icons.account_balance,
          etiqueta: _cargandoMonumentos
              ? 'Cargando…'
              : (_idsMonumentosYaPintados.isEmpty ? 'Megalitos' : 'Megalitos (${_idsMonumentosYaPintados.length})'),
          activo: _mostrarMonumentos,
          onTap: _alternarMonumentos,
        ),
        SizedBox(height: 6),
        _botonModo(
          icono: _cargandoAsistente ? Icons.hourglass_top : Icons.assistant,
          etiqueta: _mostrarAsistente ? 'Asistente activo' : 'Asistente',
          activo: _mostrarAsistente,
          onTap: _alternarAsistente,
        ),
        SizedBox(height: 6),
        _botonModo(
          icono: Icons.close,
          etiqueta: 'Cerrar',
          activo: false,
          onTap: () => setState(() => _menuModosExpandido = false),
        ),
      ],
    );
  }

  Widget _botonModo({required IconData icono, required String etiqueta, required bool activo, required VoidCallback? onTap}) {
    final esquema = Theme.of(context).colorScheme;
    final colorFondo = activo ? esquema.primary : esquema.surface;
    final colorTexto = activo ? esquema.onPrimary : esquema.onSurface;
    return Material(
      color: colorFondo,
      borderRadius: BorderRadius.circular(20),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 18, color: colorTexto),
              SizedBox(width: 6),
              Text(etiqueta, style: TextStyle(fontSize: 13, color: colorTexto)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniaturaFosilWikipedia extends StatelessWidget {
  final String tituloWikipedia;
  _MiniaturaFosilWikipedia({required this.tituloWikipedia});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ResumenWikipedia?>(
      future: obtenerResumenWikipedia(tituloWikipedia),
      builder: (_, snapshot) {
        final url = snapshot.data?.thumbnailUrl;
        if (url == null) {
          return CircleAvatar(child: Text('🦴'));
        }
        return CircleAvatar(
          backgroundColor: Colors.grey[200],
          backgroundImage: NetworkImage(url, headers: cabecerasImagenWiki),
          onBackgroundImageError: (_, __) {},
        );
      },
    );
  }
}

class _BloqueMareas extends StatelessWidget {
  final double latitud;
  final double longitud;
  _BloqueMareas({required this.latitud, required this.longitud});

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final colorSubir = Colors.blue.shade400;
    final colorBajar = Colors.indigoAccent.shade100;
    return FutureBuilder<List<EventoMarea>>(
      future: obtenerMareas(latitud, longitud).catchError((_) => <EventoMarea>[]),
      builder: (_, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(height: 18, child: LinearProgressIndicator());
        }
        final eventos = (snapshot.data ?? const <EventoMarea>[])
            .where((e) => e.fecha.isAfter(DateTime.now().subtract(Duration(hours: 1))))
            .take(6)
            .toList();
        if (eventos.isEmpty) return const SizedBox.shrink();
        final bajamarSiguiente = eventos.firstWhere((e) => e.esBajamar, orElse: () => eventos.first);
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: esquema.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: esquema.outlineVariant, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.waves, size: 18, color: esquema.primary),
                SizedBox(width: 6),
                Text('Mareas', style: Theme.of(context).textTheme.titleSmall),
                Spacer(),
                if (bajamarSiguiente.esBajamar)
                  Text('Bajamar: ${_formatearHora(bajamarSiguiente.fecha)}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: esquema.primary)),
              ]),
              SizedBox(height: 6),
              ...eventos.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Row(children: [
                      Icon(e.esBajamar ? Icons.arrow_downward : Icons.arrow_upward,
                          size: 14, color: e.esBajamar ? colorBajar : colorSubir),
                      SizedBox(width: 6),
                      Text(e.esBajamar ? 'Bajamar' : 'Pleamar',
                          style: TextStyle(fontSize: 12, color: esquema.onSurface)),
                      Spacer(),
                      Text('${_formatearDiaHora(e.fecha)}  ·  ${e.alturaM.toStringAsFixed(2)} m',
                          style: TextStyle(fontSize: 12, color: esquema.onSurface)),
                    ]),
                  )),
            ],
          ),
        );
      },
    );
  }

  static String _formatearHora(DateTime f) =>
      '${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';

  static String _formatearDiaHora(DateTime f) {
    final hoy = DateTime.now();
    final esHoy = f.year == hoy.year && f.month == hoy.month && f.day == hoy.day;
    final manana = hoy.add(Duration(days: 1));
    final esManana = f.year == manana.year && f.month == manana.month && f.day == manana.day;
    final etiqueta = esHoy ? 'hoy' : (esManana ? 'mañana' : '${f.day}/${f.month}');
    return '$etiqueta ${_formatearHora(f)}';
  }
}

class _MarcadorCentroAsistente extends StatelessWidget {
  _MarcadorCentroAsistente();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black87, width: 2),
            ),
          ),
          Container(width: 6, height: 6, decoration: BoxDecoration(color: Colors.black87, shape: BoxShape.circle)),
          Positioned(top: 0, child: Container(width: 2, height: 8, color: Colors.black87)),
          Positioned(bottom: 0, child: Container(width: 2, height: 8, color: Colors.black87)),
          Positioned(left: 0, child: Container(width: 8, height: 2, color: Colors.black87)),
          Positioned(right: 0, child: Container(width: 8, height: 2, color: Colors.black87)),
        ],
      ),
    );
  }
}

/// Indicador del estado de firma de un hallazgo. Tres estados:
///
/// - **Verde "✓ Firmado por ti"**: el hallazgo tiene firma y la clave
///   pública del firmante coincide con la de la app actual (= soy yo).
/// - **Azul "↓ Firmado por otra persona"**: hay firma pero con clave
///   distinta a la mía (= viene de un .fos-card importado).
/// - **Gris "Sin firma criptográfica"**: hallazgo pre-Fase A o creado
///   sin que el Keystore funcionara. Tap → abre Mi identidad para
///   refirmarlo si el usuario quiere.
///
/// La verificación (cuadran firma + datos + clave pública) la hace
/// IdentidadDescubridor.verificarFirma. Si la firma NO cuadra (datos
/// modificados desde la creación) se renderiza en rojo "✗ Firma rota".
class _BadgeFirmaHallazgo extends StatefulWidget {
  final Hallazgo hallazgo;
  const _BadgeFirmaHallazgo({required this.hallazgo});

  @override
  State<_BadgeFirmaHallazgo> createState() => _BadgeFirmaHallazgoState();
}

class _BadgeFirmaHallazgoState extends State<_BadgeFirmaHallazgo> {
  Future<_EstadoFirma>? _futureEstado;

  @override
  void initState() {
    super.initState();
    _futureEstado = _evaluar();
  }

  Future<_EstadoFirma> _evaluar() async {
    final h = widget.hallazgo;
    if (!h.tieneFirma) {
      return _EstadoFirma(tipo: _TipoFirma.sinFirma);
    }
    final miClavePublica = await IdentidadDescubridor.instancia.obtenerClavePublicaBase64();
    final esMia = h.clavePublicaDescubridor == miClavePublica;
    final nombreDescubridor = await Configuracion.obtenerNombreDescubridor();
    final mensajeCanonico = IdentidadDescubridor.mensajeCanonicoHallazgo(h, nombreDescubridor);
    final valida = await IdentidadDescubridor.instancia.verificarFirma(
      mensajeCanonico: mensajeCanonico,
      firmaBase64: h.firmaDescubridor!,
      clavePublicaBase64: h.clavePublicaDescubridor!,
    );
    if (!valida) return _EstadoFirma(tipo: _TipoFirma.rota);
    return _EstadoFirma(tipo: esMia ? _TipoFirma.miaValida : _TipoFirma.otraValida);
  }

  void _abrirIdentidad() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PantallaIdentidad()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_EstadoFirma>(
      future: _futureEstado,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(height: 24);
        }
        final estado = snap.data!;
        late Color colorFondo;
        late Color colorTexto;
        late IconData icono;
        late String texto;
        switch (estado.tipo) {
          case _TipoFirma.miaValida:
            colorFondo = Colors.green.shade50;
            colorTexto = Colors.green.shade900;
            icono = Icons.verified;
            texto = '✓ Firmado por ti';
            break;
          case _TipoFirma.otraValida:
            colorFondo = Colors.blue.shade50;
            colorTexto = Colors.blue.shade900;
            icono = Icons.south;
            texto = 'Firmado por otra persona';
            break;
          case _TipoFirma.sinFirma:
            colorFondo = Colors.grey.shade200;
            colorTexto = Colors.grey.shade800;
            icono = Icons.help_outline;
            texto = 'Sin firma criptográfica';
            break;
          case _TipoFirma.rota:
            colorFondo = Colors.red.shade50;
            colorTexto = Colors.red.shade900;
            icono = Icons.error_outline;
            texto = '✗ Firma rota — los datos han sido modificados';
            break;
        }
        return InkWell(
          onTap: _abrirIdentidad,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorFondo,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(icono, size: 18, color: colorTexto),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    texto,
                    style: TextStyle(
                      color: colorTexto,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, size: 16, color: colorTexto),
              ],
            ),
          ),
        );
      },
    );
  }
}

enum _TipoFirma { miaValida, otraValida, sinFirma, rota }

class _EstadoFirma {
  final _TipoFirma tipo;
  _EstadoFirma({required this.tipo});
}
