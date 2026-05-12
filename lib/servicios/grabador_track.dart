import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import '../datos/base_datos.dart';
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
      final punto = TrackPunto(
        fechaMs: DateTime.now().millisecondsSinceEpoch,
        latitud: pos.latitude,
        longitud: pos.longitude,
        altitud: pos.altitude,
        precision: pos.accuracy,
      );
      _puntos.add(punto);
      // Persistencia incremental: si la app muere por crash o kill OS
      // mientras grabamos, los puntos del buffer sobreviven y se
      // pueden recuperar en el próximo arranque vía
      // BaseDatosFosiles.recuperarBufferTrack(). Fallos de I/O se
      // ignoran — el punto sigue en memoria y se reintentará en el
      // próximo bufferarPuntoTrack del siguiente fix.
      final inicio = _inicioMs;
      if (inicio != null) {
        BaseDatosFosiles.instancia
            .bufferarPuntoTrack(inicioMs: inicio, punto: punto)
            .catchError((_) {});
      }
      _streamCambios.add(null);
    });
    _streamCambios.add(null);
  }

  ({Track track, List<TrackPunto> puntos})? detener({String nombre = ''}) {
    if (!grabando) return null;
    _suscripcion?.cancel();
    _suscripcion = null;
    final inicio = _inicioMs;
    if (_puntos.isEmpty) {
      // Limpiamos el buffer aunque no haya puntos (sesión vacía sin
      // valor que recuperar).
      if (inicio != null) {
        BaseDatosFosiles.instancia
            .vaciarBufferTrack(inicioMs: inicio)
            .catchError((_) {});
      }
      _streamCambios.add(null);
      return null;
    }
    final ahora = DateTime.now().millisecondsSinceEpoch;
    final track = Track(
      fechaMs: inicio ?? ahora,
      nombre: nombre,
      duracionMs: ahora - (inicio ?? ahora),
      distanciaMetros: _calcularDistancia(_puntos),
    );
    final puntos = List<TrackPunto>.from(_puntos);
    _puntos.clear();
    _inicioMs = null;
    _streamCambios.add(null);
    // El caller persistirá el track con guardarTrack(). Cuando lo haga
    // llamará a `descartarBufferDeSesion(inicio)` para cerrar el ciclo.
    // Hasta entonces, el buffer queda como red de seguridad adicional.
    return (track: track, puntos: puntos);
  }

  /// Recupera tracks que quedaron grabándose cuando la app murió por
  /// crash o kill OS. Cada sesión pendiente con al menos 2 puntos se
  /// consolida como un Track con nombre auto-generado "Track
  /// recuperado <DD/MM HH:mm>" y se guarda en la BD definitiva.
  /// Sesiones con menos de 2 puntos (false positives) se descartan
  /// directamente. Devuelve el número de tracks recuperados.
  Future<int> consolidarSesionesPendientes() async {
    final db = BaseDatosFosiles.instancia;
    int recuperados = 0;
    try {
      final inicios = await db.sesionesPendientesEnBuffer();
      for (final inicioMs in inicios) {
        final puntos = await db.recuperarBufferTrack(inicioMs: inicioMs);
        if (puntos.length < 2) {
          await db.vaciarBufferTrack(inicioMs: inicioMs);
          continue;
        }
        final ultimo = puntos.last.fechaMs;
        final inicio = DateTime.fromMillisecondsSinceEpoch(inicioMs);
        final nombreAuto =
            'Track recuperado ${inicio.day.toString().padLeft(2, '0')}/${inicio.month.toString().padLeft(2, '0')} '
            '${inicio.hour.toString().padLeft(2, '0')}:${inicio.minute.toString().padLeft(2, '0')}';
        final track = Track(
          fechaMs: inicioMs,
          nombre: nombreAuto,
          duracionMs: ultimo - inicioMs,
          distanciaMetros: _calcularDistancia(puntos),
        );
        await db.guardarTrack(track, puntos);
        await db.vaciarBufferTrack(inicioMs: inicioMs);
        recuperados++;
      }
    } catch (_) {
      // Recuperación best-effort: si falla algo, dejamos el buffer
      // como está para reintentar en el próximo arranque.
    }
    return recuperados;
  }

  /// Vacía el buffer de la sesión [inicioMs]. Llamar tras
  /// `guardarTrack` exitoso o tras `cancelar`. Idempotente.
  Future<void> descartarBufferDeSesion(int inicioMs) async {
    try {
      await BaseDatosFosiles.instancia.vaciarBufferTrack(inicioMs: inicioMs);
    } catch (_) {
      // No bloqueamos al usuario por un fallo de limpieza del buffer.
      // El punto se quedará huérfano en el buffer hasta el próximo
      // arranque, donde la consolidación lo verá y lo descartará.
    }
  }

  void cancelar() {
    _suscripcion?.cancel();
    _suscripcion = null;
    final inicio = _inicioMs;
    _puntos.clear();
    _inicioMs = null;
    if (inicio != null) {
      BaseDatosFosiles.instancia
          .vaciarBufferTrack(inicioMs: inicio)
          .catchError((_) {});
    }
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
