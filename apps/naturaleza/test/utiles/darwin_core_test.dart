import 'package:flutter_test/flutter_test.dart';
import 'package:naturaleza_flutter/modelos/atribucion_foto.dart';
import 'package:naturaleza_flutter/modelos/hallazgo.dart';
import 'package:naturaleza_flutter/utiles/darwin_core.dart';

const opciones = OpcionesExportacionDwc(
  identificadorInstalacion: 'abc123',
  licencia: LicenciaExportacion.ccBy,
  registradoPor: 'Ane Etxeberria',
);

Hallazgo _hallazgo({
  int id = 1,
  String especie = 'Turdus merula',
  String nombreComun = 'Mirlo común',
  String categoria = 'ave',
  double? precision = 8.4,
  String notas = '',
  Map<String, dynamic> atributos = const {},
  int validacion = EstadoIdentificacion.sinRevisar,
  List<String> fotos = const [],
  List<AtribucionFoto?> atribuciones = const [],
  String? audio,
}) =>
    Hallazgo(
      id: id,
      fechaMs: DateTime.utc(2026, 3, 23, 7, 15).millisecondsSinceEpoch,
      latitud: 43.263012345,
      longitud: -2.934987654,
      precision: precision,
      categoria: categoria,
      especie: especie,
      nombreComun: nombreComun,
      notas: notas,
      atributos: atributos,
      identificacionValidada: validacion,
      rutasFotos: fotos,
      atribucionesFotos: atribuciones,
      rutaAudio: audio,
    );

List<List<String>> _leerCsv(String csv) {
  // Lector mínimo RFC 4180 para los tests.
  final filas = <List<String>>[];
  var fila = <String>[];
  final campo = StringBuffer();
  var entreComillas = false;
  for (var indice = 0; indice < csv.length; indice++) {
    final caracter = csv[indice];
    if (entreComillas) {
      if (caracter == '"') {
        if (indice + 1 < csv.length && csv[indice + 1] == '"') {
          campo.write('"');
          indice++;
        } else {
          entreComillas = false;
        }
      } else {
        campo.write(caracter);
      }
    } else if (caracter == '"') {
      entreComillas = true;
    } else if (caracter == ',') {
      fila.add(campo.toString());
      campo.clear();
    } else if (caracter == '\r') {
      continue;
    } else if (caracter == '\n') {
      fila.add(campo.toString());
      campo.clear();
      filas.add(fila);
      fila = <String>[];
    } else {
      campo.write(caracter);
    }
  }
  return filas;
}

void main() {
  group('formato', () {
    test('fecha ISO 8601 con zona', () {
      expect(fechaIso8601ConZona(DateTime.utc(2026, 3, 23, 7, 5, 9)), '2026-03-23T07:05:09Z');
      final local = DateTime(2026, 7, 1, 12);
      final texto = fechaIso8601ConZona(local);
      expect(texto, matches(RegExp(r'^2026-07-01T12:00:00[+-]\d{2}:\d{2}$')));
      expect(DateTime.parse(texto).isAtSameMomentAs(local), isTrue);
    });

    test('cabecera con los términos DwC y CRLF', () {
      final exportacion = generarCsvDarwinCore([_hallazgo()], opciones);
      expect(exportacion.csv.split('\r\n').first, terminosDarwinCore.join(','));
      expect(exportacion.csv.endsWith('\r\n'), isTrue);
      expect(exportacion.exportados, 1);
    });

    test('valores de una ocurrencia normal', () {
      final ocurrencia = ocurrenciaDarwinCore(_hallazgo(notas: 'Cantando, en el seto\n"muy cerca"'), opciones)!;
      expect(ocurrencia['occurrenceID'], 'urn:naturaleza:abc123:hallazgo:1');
      expect(ocurrencia['basisOfRecord'], 'HumanObservation');
      expect(ocurrencia['scientificName'], 'Turdus merula');
      expect(ocurrencia['vernacularName'], 'Mirlo común');
      expect(ocurrencia['kingdom'], 'Animalia');
      expect(ocurrencia['decimalLatitude'], '43.263012');
      expect(ocurrencia['decimalLongitude'], '-2.934988');
      expect(ocurrencia['geodeticDatum'], 'WGS84');
      expect(ocurrencia['coordinateUncertaintyInMeters'], '9');
      expect(ocurrencia['recordedBy'], 'Ane Etxeberria');
      expect(ocurrencia['license'], 'http://creativecommons.org/licenses/by/4.0/legalcode');
      expect(ocurrencia['dataGeneralizations'], isEmpty);
      expect(ocurrencia['informationWithheld'], isEmpty);
      expect(ocurrencia['occurrenceRemarks'], 'Cantando, en el seto "muy cerca"');
      expect(ocurrencia['associatedMedia'], isEmpty);
    });

    test('el CSV se lee de vuelta con comas, comillas y saltos de línea', () {
      final exportacion = generarCsvDarwinCore([_hallazgo(notas: 'a, "b"\nc')], opciones);
      final filas = _leerCsv(exportacion.csv);
      expect(filas.length, 2);
      expect(filas[1].length, terminosDarwinCore.length);
      expect(filas[1][terminosDarwinCore.indexOf('occurrenceRemarks')], 'a, "b" c');
    });

    test('sin nombre científico no se exporta; sin precisión, incertidumbre vacía', () {
      final exportacion = generarCsvDarwinCore([
        _hallazgo(especie: '', nombreComun: 'Pájaro'),
        _hallazgo(id: 2, precision: null, categoria: 'seta', especie: 'Amanita muscaria'),
      ], opciones);
      expect(exportacion.exportados, 1);
      expect(exportacion.sinNombreCientifico, 1);
      final fila = _leerCsv(exportacion.csv)[1];
      expect(fila[terminosDarwinCore.indexOf('coordinateUncertaintyInMeters')], '');
      expect(fila[terminosDarwinCore.indexOf('kingdom')], 'Fungi');
    });

    test('licencia CC0', () {
      final ocurrencia = ocurrenciaDarwinCore(
          _hallazgo(),
          const OpcionesExportacionDwc(identificadorInstalacion: 'x', licencia: LicenciaExportacion.cc0))!;
      expect(ocurrencia['license'], 'http://creativecommons.org/publicdomain/zero/1.0/legalcode');
      expect(ocurrencia['recordedBy'], isEmpty);
    });
  });

  group('sonido y basisOfRecord', () {
    const sonido = {
      'modelo': 'Perch 2.0 · europa-1',
      'puntuacion': 12.3,
      'nivel': 'probable',
      'filtro_zona': true,
    };

    test('elegida al escuchar: HumanObservation con el modelo en los comentarios', () {
      final ocurrencia = ocurrenciaDarwinCore(_hallazgo(atributos: {'identificacion_sonido': sonido}), opciones)!;
      expect(ocurrencia['basisOfRecord'], 'HumanObservation');
      expect(ocurrencia['identificationRemarks'], contains('Perch 2.0 · europa-1'));
      expect(ocurrencia['identificationRemarks'], contains('12.3'));
      expect(ocurrencia['identificationRemarks'], contains('probable'));
    });

    test('de una sesión automática sin revisar: MachineObservation', () {
      final atributos = {
        'identificacion_sonido': sonido,
        'sesion_sonora': {'id': 1, 'tipo': 'recorrido', 'detecciones': 4},
      };
      expect(ocurrenciaDarwinCore(_hallazgo(atributos: atributos), opciones)!['basisOfRecord'], 'MachineObservation');
      final revisada = _hallazgo(atributos: atributos, validacion: EstadoIdentificacion.confirmada);
      final ocurrencia = ocurrenciaDarwinCore(revisada, opciones)!;
      expect(ocurrencia['basisOfRecord'], 'HumanObservation');
      expect(ocurrencia['identificationRemarks'], contains('confirmada'));
    });
  });

  group('generalización', () {
    test('centro de la celda de 0,1° e incertidumbre acorde', () {
      final generalizadas = generalizarCoordenadas(43.263, -2.935);
      expect(generalizadas.latitud, closeTo(43.25, 1e-9));
      expect(generalizadas.longitud, closeTo(-2.95, 1e-9));
      // Media diagonal a 43,2°: √(5566² + 4058²) ≈ 6888 → 6900.
      expect(generalizadas.incertidumbreMetros, 6900);
      // El punto original queda dentro del círculo de incertidumbre.
      expect(generalizarCoordenadas(43.263, -2.935, precisionOriginalMetros: 150).incertidumbreMetros, 7100);
      final sur = generalizarCoordenadas(-33.86, 151.21);
      expect(sur.latitud, closeTo(-33.85, 1e-9));
      expect(sur.longitud, closeTo(151.25, 1e-9));
    });

    test('especie sensible: coordenadas generalizadas, términos rellenos y sin fotos', () {
      const sensibles = OpcionesExportacionDwc(
        identificadorInstalacion: 'abc',
        licencia: LicenciaExportacion.cc0,
        clavesSensibles: {'cientifico:lynx pardinus'},
        conMedios: true,
      );
      final hallazgo = _hallazgo(
        especie: 'Lynx pardinus',
        categoria: 'mamifero',
        fotos: ['/doc/fotos/f1.jpg'],
        audio: '/doc/audios/a.wav',
      );
      final ocurrencia = ocurrenciaDarwinCore(hallazgo, sensibles)!;
      expect(ocurrencia['decimalLatitude'], '43.25');
      expect(ocurrencia['decimalLongitude'], '-2.95');
      expect(int.parse(ocurrencia['coordinateUncertaintyInMeters']!), greaterThanOrEqualTo(6900));
      expect(ocurrencia['dataGeneralizations'], contains('0,1°'));
      expect(ocurrencia['informationWithheld'], isNotEmpty);
      expect(ocurrencia['associatedMedia'], 'media/1_a.wav');
      expect(generarCsvDarwinCore([hallazgo], sensibles).generalizados, 1);
    });

    test('no sensible con medios: fotos propias sí, de archivo no', () {
      const conMedios = OpcionesExportacionDwc(
          identificadorInstalacion: 'abc', licencia: LicenciaExportacion.cc0, conMedios: true);
      final hallazgo = _hallazgo(
        fotos: ['/doc/fotos/propia.jpg', '/doc/fotos/archivo.jpg'],
        atribuciones: [
          null,
          const AtribucionFoto(
              urlOrigen: 'https://commons.wikimedia.org', fuente: 'wikipedia', autor: 'X', licencia: 'CC BY-SA'),
        ],
      );
      expect(ocurrenciaDarwinCore(hallazgo, conMedios)!['associatedMedia'], 'media/1_propia.jpg');
    });
  });

  group('plantilla de iNaturalist', () {
    test('8 columnas, fecha y geoprivacidad de las sensibles', () {
      const sensibles = OpcionesExportacionDwc(
        identificadorInstalacion: 'abc',
        licencia: LicenciaExportacion.cc0,
        clavesSensibles: {'cientifico:lynx pardinus'},
      );
      final exportacion = generarCsvInaturalist([
        _hallazgo(),
        _hallazgo(id: 2, especie: 'Lynx pardinus'),
      ], sensibles);
      final filas = _leerCsv(exportacion.csv);
      expect(filas[0], columnasInaturalist);
      expect(filas[1][0], 'Turdus merula');
      expect(filas[1][1], matches(RegExp(r'^2026-03-2[34] \d{2}:\d{2}$')));
      expect(filas[1][7], '');
      expect(filas[2][4], '43.25');
      expect(filas[2][7], 'obscured');
    });
  });

  test('identificador de instalación', () {
    expect(nuevoIdentificadorInstalacion(), matches(RegExp(r'^[0-9a-f]{32}$')));
  });
}
