import 'dart:io';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as path_lib;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../datos/base_datos.dart';
import '../modelos/track.dart';
import '../servicios/grabador_track.dart';
import '../servicios/generador_pdf.dart';

class PantallaTracks extends StatefulWidget {
  PantallaTracks({super.key});

  @override
  State<PantallaTracks> createState() => _PantallaTracksState();
}

class _PantallaTracksState extends State<PantallaTracks> {
  List<Track> _tracks = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final lista = await BaseDatosNaturaleza.instancia.listarTracks();
      if (!mounted) return;
      setState(() {
        _tracks = lista;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error cargando tracks: $e')));
    }
  }

  Future<void> _verTrack(Track track) async {
    final List<TrackPunto> puntos;
    try {
      puntos = await BaseDatosNaturaleza.instancia.obtenerPuntosTrack(track.id!);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error abriendo track: $e')));
      return;
    }
    if (!mounted) return;
    if (puntos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Este track no tiene puntos guardados (la grabación se detuvo antes del primer fix GPS).')),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, scrollController) {
          final puntosLatLng = puntos.map((p) => LatLng(p.latitud, p.longitud)).toList();
          // Con un solo punto, LatLngBounds.fromPoints crea un rectángulo
          // degenerado y CameraFit.bounds dispara zoom infinito; usamos
          // initialCenter + initialZoom como fallback.
          final MapOptions opcionesMapa = puntosLatLng.length >= 2
              ? MapOptions(
                  initialCameraFit: CameraFit.bounds(
                    bounds: LatLngBounds.fromPoints(puntosLatLng),
                    padding: const EdgeInsets.all(40),
                  ),
                )
              : MapOptions(
                  initialCenter: puntosLatLng.first,
                  initialZoom: 16,
                );
          return ListView(
            controller: scrollController,
            children: [
              SizedBox(
                height: 320,
                child: FlutterMap(
                  options: opcionesMapa,
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.josu.naturaleza',
                      maxZoom: 19,
                    ),
                    if (puntosLatLng.length >= 2)
                      PolylineLayer(polylines: [
                        Polyline(points: puntosLatLng, color: Color(0xFFB54A2A), strokeWidth: 4),
                      ]),
                    MarkerLayer(markers: [
                      Marker(point: puntosLatLng.first, child: Icon(Icons.flag, color: Colors.green)),
                      if (puntosLatLng.length >= 2)
                        Marker(point: puntosLatLng.last, child: Icon(Icons.flag, color: Colors.red)),
                    ]),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(track.nombre.isEmpty ? 'Track' : track.nombre, style: Theme.of(context).textTheme.titleLarge),
                    SizedBox(height: 8),
                    Text(_resumen(track, puntos.length)),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: Icon(Icons.download),
                            onPressed: () async {
                              final fichero = await _exportarGpx(track, puntos);
                              if (!context.mounted) return;
                              await Share.shareXFiles([XFile(fichero.path)], subject: 'Track GPX');
                            },
                            label: Text('GPX'),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: Icon(Icons.picture_as_pdf),
                            onPressed: () => _generarYCompartirPdf(track, puntos),
                            label: Text('Informe PDF'),
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
                                  content: Text('¿Borrar este track?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: Text(SoleraL10n.t('cancelar'))),
                                    TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Borrar', style: TextStyle(color: Colors.red))),
                                  ],
                                ),
                              );
                              if (ok != true) return;
                              await BaseDatosNaturaleza.instancia.borrarTrack(track.id!);
                              if (!mounted) return;
                              Navigator.of(sheetCtx).pop();
                              _cargar();
                            },
                            label: Text('Borrar', style: TextStyle(color: Colors.red)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<File> _exportarGpx(Track track, List<TrackPunto> puntos) async {
    final gpx = generarGpx(track, puntos);
    final dir = await getTemporaryDirectory();
    final nombre = 'track_${track.id ?? track.fechaMs}.gpx';
    final fichero = File(path_lib.join(dir.path, nombre));
    await fichero.writeAsString(gpx);
    return fichero;
  }

  Future<void> _generarYCompartirPdf(Track track, List<TrackPunto> puntos) async {
    try {
      final fechaInicio = track.fechaMs;
      final fechaFin = track.duracionMs == null ? DateTime.now().millisecondsSinceEpoch : track.fechaMs + track.duracionMs!;
      final todosHallazgos = await BaseDatosNaturaleza.instancia.listarHallazgos();
      final enRango = todosHallazgos.where((h) => h.fechaMs >= fechaInicio && h.fechaMs <= fechaFin).toList();
      final pdfBytes = await generarPdfSalida(track: track, puntos: puntos, hallazgosEnRango: enRango);
      final dir = await getTemporaryDirectory();
      final nombre = 'salida_${track.id ?? track.fechaMs}.pdf';
      final fichero = File(path_lib.join(dir.path, nombre));
      await fichero.writeAsBytes(pdfBytes);
      if (!mounted) return;
      await Share.shareXFiles([XFile(fichero.path)], subject: 'Informe de salida');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generando PDF: $e')));
    }
  }

  String _resumen(Track track, int nPuntos) {
    final partes = <String>[];
    if (track.distanciaMetros != null) {
      final km = track.distanciaMetros! / 1000;
      partes.add(km < 1 ? '${track.distanciaMetros!.toStringAsFixed(0)} m' : '${km.toStringAsFixed(2)} km');
    }
    if (track.duracionMs != null) {
      final mins = (track.duracionMs! / 60000).round();
      partes.add(mins < 60 ? '$mins min' : '${(mins / 60).toStringAsFixed(1)} h');
    }
    partes.add('$nPuntos puntos');
    return partes.join(' · ');
  }

  Future<void> _importarGpx() async {
    final resultado = await FilePicker.platform.pickFiles(type: FileType.any);
    if (resultado == null || resultado.files.isEmpty) return;
    final ruta = resultado.files.first.path;
    if (ruta == null) return;
    try {
      final contenido = await File(ruta).readAsString();
      final importado = parsearGpx(contenido, nombrePorDefecto: path_lib.basenameWithoutExtension(ruta));
      if (importado.puntos.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('El GPX no contiene puntos de track.')));
        return;
      }
      double dist = 0;
      for (var i = 1; i < importado.puntos.length; i++) {
        dist += _distHaversine(importado.puntos[i - 1].latitud, importado.puntos[i - 1].longitud, importado.puntos[i].latitud, importado.puntos[i].longitud);
      }
      final track = Track(
        fechaMs: importado.puntos.first.fechaMs,
        nombre: importado.nombre,
        duracionMs: importado.puntos.last.fechaMs - importado.puntos.first.fechaMs,
        distanciaMetros: dist,
      );
      await BaseDatosNaturaleza.instancia.guardarTrack(track, importado.puntos);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Importado: ${importado.nombre} (${importado.puntos.length} puntos)')));
      _cargar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error importando GPX: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tracks'),
        actions: [
          IconButton(
            icon: Icon(Icons.upload_file),
            tooltip: 'Importar GPX',
            onPressed: _importarGpx,
          ),
        ],
      ),
      body: _cargando
          ? Center(child: CircularProgressIndicator())
          : _tracks.isEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Aún no has grabado ningún track.\nUsa el botón ⏺ del mapa para empezar.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                  ),
                )
              : ListView.builder(
                  itemCount: _tracks.length,
                  itemBuilder: (_, i) {
                    final t = _tracks[i];
                    final fecha = DateFormat('dd MMM yyyy HH:mm', 'es_ES').format(DateTime.fromMillisecondsSinceEpoch(t.fechaMs));
                    final km = t.distanciaMetros != null ? (t.distanciaMetros! / 1000).toStringAsFixed(2) : '–';
                    return ListTile(
                      leading: Icon(Icons.timeline, color: Color(0xFFB54A2A)),
                      title: Text(t.nombre.isEmpty ? 'Track del $fecha' : t.nombre),
                      subtitle: Text('$km km · $fecha'),
                      onTap: () => _verTrack(t),
                    );
                  },
                ),
    );
  }
}

double _distHaversine(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLon = (lon2 - lon1) * math.pi / 180;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) * math.sin(dLon / 2) * math.sin(dLon / 2);
  return 2 * r * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}
