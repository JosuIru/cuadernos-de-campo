import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import '../modelos/track.dart';

class GrabadorTrack {
  static final GrabadorTrack instancia = GrabadorTrack._interno();
  GrabadorTrack._interno();

  StreamSubscription<Position>? _suscripcion;
  final List<TrackPunto> _puntos = [];
  int? _inicioMs;
  final _streamCambios = StreamController<void>.broadcast();

  bool get grabando => _suscripcion != null;
  List<TrackPunto> get puntos => List.unmodifiable(_puntos);
  int? get inicioMs => _inicioMs;
  Stream<void> get cambios => _streamCambios.stream;

  void iniciar() {
    if (grabando) return;
    _puntos.clear();
    _inicioMs = DateTime.now().millisecondsSinceEpoch;
    final settings = Platform.isAndroid
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'Grabando track',
              notificationText: 'Fósiles está registrando tu ruta',
              enableWakeLock: true,
              setOngoing: true,
            ),
          )
        : const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5);
    _suscripcion = Geolocator.getPositionStream(locationSettings: settings).listen((pos) {
      _puntos.add(TrackPunto(
        fechaMs: DateTime.now().millisecondsSinceEpoch,
        latitud: pos.latitude,
        longitud: pos.longitude,
        altitud: pos.altitude,
        precision: pos.accuracy,
      ));
      _streamCambios.add(null);
    });
    _streamCambios.add(null);
  }

  ({Track track, List<TrackPunto> puntos})? detener({String nombre = ''}) {
    if (!grabando) return null;
    _suscripcion?.cancel();
    _suscripcion = null;
    if (_puntos.isEmpty) {
      _streamCambios.add(null);
      return null;
    }
    final ahora = DateTime.now().millisecondsSinceEpoch;
    final track = Track(
      fechaMs: _inicioMs ?? ahora,
      nombre: nombre,
      duracionMs: ahora - (_inicioMs ?? ahora),
      distanciaMetros: _calcularDistancia(_puntos),
    );
    final puntos = List<TrackPunto>.from(_puntos);
    _puntos.clear();
    _inicioMs = null;
    _streamCambios.add(null);
    return (track: track, puntos: puntos);
  }

  void cancelar() {
    _suscripcion?.cancel();
    _suscripcion = null;
    _puntos.clear();
    _inicioMs = null;
    _streamCambios.add(null);
  }
}

double _calcularDistancia(List<TrackPunto> puntos) {
  double total = 0;
  for (var i = 1; i < puntos.length; i++) {
    total += _distanciaHaversine(puntos[i - 1].latitud, puntos[i - 1].longitud, puntos[i].latitud, puntos[i].longitud);
  }
  return total;
}

double _distanciaHaversine(double lat1, double lon1, double lat2, double lon2) {
  const radioTierra = 6371000.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLon = (lon2 - lon1) * math.pi / 180;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) * math.sin(dLon / 2) * math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return radioTierra * c;
}

String generarGpx(Track track, List<TrackPunto> puntos) {
  final buffer = StringBuffer();
  buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
  buffer.writeln('<gpx version="1.1" creator="fosiles-flutter" xmlns="http://www.topografix.com/GPX/1/1">');
  buffer.writeln('  <trk>');
  buffer.writeln('    <name>${_escaparXml(track.nombre.isEmpty ? "Track" : track.nombre)}</name>');
  buffer.writeln('    <trkseg>');
  for (final p in puntos) {
    buffer.write('      <trkpt lat="${p.latitud}" lon="${p.longitud}">');
    if (p.altitud != null) buffer.write('<ele>${p.altitud}</ele>');
    buffer.write('<time>${DateTime.fromMillisecondsSinceEpoch(p.fechaMs, isUtc: true).toIso8601String()}</time>');
    buffer.writeln('</trkpt>');
  }
  buffer.writeln('    </trkseg>');
  buffer.writeln('  </trk>');
  buffer.writeln('</gpx>');
  return buffer.toString();
}

String _escaparXml(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

class GpxImportado {
  final String nombre;
  final List<TrackPunto> puntos;
  GpxImportado({required this.nombre, required this.puntos});
}

GpxImportado parsearGpx(String contenidoGpx, {String nombrePorDefecto = 'Track importado'}) {
  final nombreMatch = RegExp(r'<name>([^<]+)</name>', dotAll: true).firstMatch(contenidoGpx);
  final nombre = nombreMatch?.group(1)?.trim() ?? nombrePorDefecto;
  final regex = RegExp(r'<trkpt\s+lat="([^"]+)"\s+lon="([^"]+)"\s*>(.*?)</trkpt>', dotAll: true);
  final puntos = <TrackPunto>[];
  for (final m in regex.allMatches(contenidoGpx)) {
    final lat = double.tryParse(m.group(1) ?? '');
    final lon = double.tryParse(m.group(2) ?? '');
    if (lat == null || lon == null) continue;
    final cuerpo = m.group(3) ?? '';
    final elev = double.tryParse(RegExp(r'<ele>([^<]+)</ele>').firstMatch(cuerpo)?.group(1) ?? '');
    final tiempo = RegExp(r'<time>([^<]+)</time>').firstMatch(cuerpo)?.group(1);
    final fechaMs = tiempo != null ? DateTime.tryParse(tiempo)?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch : DateTime.now().millisecondsSinceEpoch;
    puntos.add(TrackPunto(fechaMs: fechaMs, latitud: lat, longitud: lon, altitud: elev));
  }
  return GpxImportado(nombre: nombre, puntos: puntos);
}
