import 'dart:convert';
import 'package:http/http.dart' as http;

class LugarMeteo {
  final String nombre;
  final double latitud;
  final double longitud;
  final String? region;
  final String? pais;

  LugarMeteo({
    required this.nombre,
    required this.latitud,
    required this.longitud,
    this.region,
    this.pais,
  });
}

String descripcionCodigoMeteo(int code) => switch (code) {
      0 => 'Despejado',
      1 => 'Mayormente despejado',
      2 => 'Parcialmente nublado',
      3 => 'Nublado',
      45 || 48 => 'Niebla',
      51 => 'Llovizna ligera',
      53 => 'Llovizna moderada',
      55 => 'Llovizna densa',
      61 => 'Lluvia ligera',
      63 => 'Lluvia moderada',
      65 => 'Lluvia fuerte',
      71 => 'Nevada ligera',
      73 => 'Nevada moderada',
      75 => 'Nevada fuerte',
      80 => 'Chubascos ligeros',
      81 => 'Chubascos moderados',
      82 => 'Chubascos fuertes',
      95 => 'Tormenta',
      96 || 99 => 'Tormenta con granizo',
      _ => 'Desconocido',
    };

String iconoCodigoMeteo(int code) => switch (code) {
      0 || 1 => '☀️',
      2 => '⛅',
      3 => '☁️',
      45 || 48 => '🌫️',
      51 || 53 || 55 => '🌧️',
      61 || 63 || 65 => '🌧️',
      71 || 73 || 75 => '🌨️',
      80 || 81 || 82 => '🌦️',
      95 || 96 || 99 => '⛈️',
      _ => '❓',
    };

class DiaPrevision {
  final DateTime fecha;
  final double tempMax;
  final double tempMin;
  final double precipitacionMm;
  final int codigoTiempo;
  final double vientoMaxKmh;
  final double uvMax;

  DiaPrevision({
    required this.fecha,
    required this.tempMax,
    required this.tempMin,
    required this.precipitacionMm,
    required this.codigoTiempo,
    required this.vientoMaxKmh,
    required this.uvMax,
  });

  String get descripcion => descripcionCodigoMeteo(codigoTiempo);
  String get icono => iconoCodigoMeteo(codigoTiempo);
}

class HoraPrevision {
  final DateTime fecha;
  final double temperatura;
  final int codigoTiempo;
  final int probabilidadLluvia;
  final double vientoKmh;

  HoraPrevision({
    required this.fecha,
    required this.temperatura,
    required this.codigoTiempo,
    required this.probabilidadLluvia,
    required this.vientoKmh,
  });

  String get descripcion => descripcionCodigoMeteo(codigoTiempo);
  String get icono => iconoCodigoMeteo(codigoTiempo);
}

class PrevisonMeteo {
  final LugarMeteo lugar;
  final List<DiaPrevision> dias;
  final List<HoraPrevision> horas;

  PrevisonMeteo({required this.lugar, required this.dias, required this.horas});
}

/// Busca ubicaciones por nombre (geocoding Open-Meteo).
Future<List<LugarMeteo>> buscarLugaresMeteo(String consulta) async {
  if (consulta.trim().isEmpty) return const [];
  try {
    final uri = Uri.parse(
      'https://geocoding-api.open-meteo.com/v1/search'
      '?name=${Uri.encodeComponent(consulta.trim())}'
      '&count=8&language=es&format=json',
    );
    final respuesta = await http.get(uri).timeout(const Duration(seconds: 8));
    if (respuesta.statusCode != 200) return const [];
    final json = jsonDecode(utf8.decode(respuesta.bodyBytes)) as Map<String, dynamic>;
    final results = (json['results'] as List?) ?? const [];
    return results.map((r) {
      final rMap = r as Map<String, dynamic>;
      return LugarMeteo(
        nombre: rMap['name'] as String? ?? '',
        latitud: (rMap['latitude'] as num).toDouble(),
        longitud: (rMap['longitude'] as num).toDouble(),
        region: rMap['admin1'] as String?,
        pais: rMap['country'] as String?,
      );
    }).toList();
  } catch (_) {
    return const [];
  }
}

/// Obtiene previsión meteorológica para 7 días.
Future<PrevisonMeteo?> obtenerPrevision(
  double latitud,
  double longitud, {
  String nombreLugar = '',
}) async {
  try {
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$latitud&longitude=$longitud'
      '&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,weather_code,wind_speed_10m_max,uv_index_max'
      '&hourly=temperature_2m,precipitation_probability,weather_code,wind_speed_10m'
      '&timezone=auto&forecast_days=3',
    );
    final respuesta = await http.get(uri).timeout(const Duration(seconds: 10));
    if (respuesta.statusCode != 200) return null;
    final json = jsonDecode(utf8.decode(respuesta.bodyBytes)) as Map<String, dynamic>;
    final daily = json['daily'] as Map<String, dynamic>?;
    if (daily == null) return null;

    final fechas = (daily['time'] as List).cast<String>();
    final tempMax = (daily['temperature_2m_max'] as List).cast<num>();
    final tempMin = (daily['temperature_2m_min'] as List).cast<num>();
    final precip = (daily['precipitation_sum'] as List).cast<num>();
    final weatherCode = (daily['weather_code'] as List).cast<num>();
    final viento = (daily['wind_speed_10m_max'] as List).cast<num>();
    final uv = (daily['uv_index_max'] as List).cast<num>();

    final dias = <DiaPrevision>[];
    for (var i = 0; i < fechas.length; i++) {
      dias.add(DiaPrevision(
        fecha: DateTime.parse(fechas[i]),
        tempMax: tempMax[i].toDouble(),
        tempMin: tempMin[i].toDouble(),
        precipitacionMm: precip[i].toDouble(),
        codigoTiempo: weatherCode[i].toInt(),
        vientoMaxKmh: viento[i].toDouble(),
        uvMax: uv[i].toDouble(),
      ));
    }

    // Horas (48h)
    final horas = <HoraPrevision>[];
    final hourly = json['hourly'] as Map<String, dynamic>?;
    if (hourly != null) {
      final hFechas = (hourly['time'] as List).cast<String>();
      final hTemp = (hourly['temperature_2m'] as List).cast<num>();
      final hPrecipProb = (hourly['precipitation_probability'] as List).cast<num>();
      final hCode = (hourly['weather_code'] as List).cast<num>();
      final hViento = (hourly['wind_speed_10m'] as List).cast<num>();
      for (var i = 0; i < hFechas.length && i < 48; i++) {
        horas.add(HoraPrevision(
          fecha: DateTime.parse(hFechas[i]),
          temperatura: hTemp[i].toDouble(),
          codigoTiempo: hCode[i].toInt(),
          probabilidadLluvia: hPrecipProb[i].toInt(),
          vientoKmh: hViento[i].toDouble(),
        ));
      }
    }

    final lugar = LugarMeteo(
      nombre: nombreLugar.isNotEmpty ? nombreLugar : '$latitud, $longitud',
      latitud: latitud,
      longitud: longitud,
    );

    return PrevisonMeteo(lugar: lugar, dias: dias, horas: horas);
  } catch (_) {
    return null;
  }
}
