import 'dart:convert';
import 'package:http/http.dart' as http;

const List<String> _servidoresOverpass = [
  'https://overpass-api.de/api/interpreter',
  'https://overpass.private.coffee/api/interpreter',
  'https://overpass.kumi.systems/api/interpreter',
  'https://overpass.osm.ch/api/interpreter',
];

const _cabecerasOverpass = {
  'User-Agent': 'fosiles-flutter/1.0 (https://github.com/josu/fosiles-flutter)',
  'Accept': 'application/json',
};

class OverpassError implements Exception {
  final String mensaje;
  OverpassError(this.mensaje);
  @override
  String toString() => 'OverpassError: $mensaje';
}

Future<Map<String, dynamic>> consultarOverpass(String consulta, {Duration timeout = const Duration(seconds: 20)}) async {
  Object? ultimoError;
  for (final servidor in _servidoresOverpass) {
    try {
      final respuesta = await http.post(
        Uri.parse(servidor),
        headers: _cabecerasOverpass,
        body: {'data': consulta},
      ).timeout(timeout);
      if (respuesta.statusCode == 200) {
        final json = jsonDecode(utf8.decode(respuesta.bodyBytes)) as Map<String, dynamic>;
        final remark = json['remark']?.toString() ?? '';
        if (remark.toLowerCase().contains('error') || remark.toLowerCase().contains('runtime')) {
          ultimoError = 'Servidor ${Uri.parse(servidor).host} devolvió remark: $remark';
          continue;
        }
        return json;
      }
      ultimoError = 'Servidor ${Uri.parse(servidor).host} respondió ${respuesta.statusCode}';
    } catch (e) {
      ultimoError = e;
    }
  }
  throw OverpassError('Todos los servidores Overpass fallaron · último: $ultimoError');
}
