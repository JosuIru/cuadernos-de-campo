import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:naturaleza_flutter/sonido/filtro_ocurrencia.dart';
import 'package:naturaleza_flutter/sonido/temporada_sonido.dart';

/// Rejilla de 2° desde 40° N 4° O, 2 × 2 celdas; bit 0 = Cuculus canorus, bit
/// 1 = Turdus merula. Celda 0_0 con las dos; 0_1 solo el mirlo; 1_x sin datos.
DatosOcurrencia _datos() => leerDatosOcurrencia({
      'formatVersion': 1,
      'cellSizeDegrees': 2,
      'latitudeMin': 40,
      'longitudeMin': -4,
      'rows': 2,
      'columns': 2,
      'speciesLabels': ['Cuculus canorus', 'Turdus merula'],
      'cells': {
        '0_0': base64.encode(Uint8List.fromList([3])),
        '0_1': base64.encode(Uint8List.fromList([2])),
      },
      'monthlyActivity': {
        'Cuculus canorus': [0, 0, 5, 60, 100, 80, 30, 9, 2, 0, 0, 0],
        'Turdus merula': [70, 70, 80, 100, 100, 90, 70, 60, 60, 70, 70, 70],
      },
    });

void main() {
  test('meses esperados con el umbral del filtro y meses de más actividad', () {
    final temporada = temporadaSonidoDe(_datos(), 'Cuculus canorus')!;
    expect(temporada.mesesEsperados, [4, 5, 6, 7]);
    expect(temporada.mesesDeMasActividad, [4, 5, 6]);
    expect(temporada.presencia, PresenciaEnZona.sinUbicacion);
    expect(temporada.tieneDatos, isTrue);
  });

  test('presencia en la celda de la persona', () {
    final datos = _datos();
    expect(temporadaSonidoDe(datos, 'Cuculus canorus', latitud: 41, longitud: -3)!.presencia,
        PresenciaEnZona.registrada);
    expect(temporadaSonidoDe(datos, 'Cuculus canorus', latitud: 41, longitud: -1)!.presencia,
        PresenciaEnZona.sinRegistros);
    expect(temporadaSonidoDe(datos, 'Turdus merula', latitud: 41, longitud: -1)!.presencia,
        PresenciaEnZona.registrada);
    expect(temporadaSonidoDe(datos, 'Turdus merula', latitud: 43, longitud: -3)!.presencia,
        PresenciaEnZona.celdaSinDatos);
    expect(temporadaSonidoDe(datos, 'Turdus merula', latitud: 60, longitud: 20)!.presencia,
        PresenciaEnZona.fueraDeRejilla);
  });

  test('especie que no está en el fichero', () {
    expect(temporadaSonidoDe(_datos(), 'Upupa epops'), isNull);
  });
}
