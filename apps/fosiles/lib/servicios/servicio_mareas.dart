import 'dart:convert';
import 'package:http/http.dart' as http;

class EventoMarea {
  final DateTime fecha;
  final double alturaM;
  final bool esBajamar;
  EventoMarea({required this.fecha, required this.alturaM, required this.esBajamar});
}

Future<List<EventoMarea>> obtenerMareas(double latitud, double longitud) async {
  final uri = Uri.parse(
    'https://marine-api.open-meteo.com/v1/marine'
    '?latitude=${latitud.toStringAsFixed(3)}'
    '&longitude=${longitud.toStringAsFixed(3)}'
    '&hourly=sea_level_height_msl'
    '&forecast_days=2'
    '&timezone=auto',
  );
  final respuesta = await http.get(uri).timeout(const Duration(seconds: 10));
  if (respuesta.statusCode != 200) {
    throw Exception('Error mareas (${respuesta.statusCode})');
  }
  final json = jsonDecode(utf8.decode(respuesta.bodyBytes)) as Map<String, dynamic>;
  final hourly = json['hourly'] as Map<String, dynamic>?;
  if (hourly == null) return const [];
  final tiempos = ((hourly['time'] as List?) ?? const []).cast<String>();
  final alturas = ((hourly['sea_level_height_msl'] as List?) ?? const []).map<double?>((v) => v == null ? null : (v as num).toDouble()).toList();
  if (tiempos.length != alturas.length || tiempos.length < 5) return const [];
  final eventos = <EventoMarea>[];
  for (var i = 1; i < tiempos.length - 1; i++) {
    final prev = alturas[i - 1];
    final actual = alturas[i];
    final next = alturas[i + 1];
    if (prev == null || actual == null || next == null) continue;
    if (actual > prev && actual >= next) {
      eventos.add(EventoMarea(fecha: DateTime.parse(tiempos[i]), alturaM: actual, esBajamar: false));
    } else if (actual < prev && actual <= next) {
      eventos.add(EventoMarea(fecha: DateTime.parse(tiempos[i]), alturaM: actual, esBajamar: true));
    }
  }
  return eventos;
}
