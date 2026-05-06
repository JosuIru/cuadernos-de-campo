import 'dart:math' as math;
import '../datos/yacimientos_curados.dart';

double distanciaMetros(double lat1, double lon1, double lat2, double lon2) {
  const radio = 6371000.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLon = (lon2 - lon1) * math.pi / 180;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) * math.sin(dLon / 2) * math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return radio * c;
}

class Geofencer {
  static final Geofencer instancia = Geofencer._();
  Geofencer._();

  final Set<String> _yaAlertados = {};
  static const double radioMetros = 250;

  YacimientoCurado? alEntrarEn(double latitud, double longitud) {
    for (final y in yacimientosCurados) {
      if (_yaAlertados.contains(y.id)) continue;
      final d = distanciaMetros(latitud, longitud, y.latitud, y.longitud);
      if (d <= radioMetros) {
        _yaAlertados.add(y.id);
        return y;
      }
    }
    return null;
  }

  void resetear() {
    _yaAlertados.clear();
  }
}
