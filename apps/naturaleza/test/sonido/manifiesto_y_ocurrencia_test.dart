import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:naturaleza_flutter/sonido/clasificacion_sonido.dart';
import 'package:naturaleza_flutter/sonido/filtro_ocurrencia.dart';
import 'package:naturaleza_flutter/sonido/manifiesto_modelo_fauna.dart';

final manifiestoValido = <String, dynamic>{
  'formatVersion': 1,
  'modelVersion': 'europa-1',
  'modelFile': 'perch_europe_fp16.tflite',
  'modelBytes': 37215308,
  'modelSha256': '4917A179600929B4C28E36CF2F8411105ED054E99A4CE97862203EF8C3A64BA7',
  'sampleRateHz': 32000,
  'windowSamples': 160000,
  'outputs': {'embedding': 0, 'spatialEmbedding': 1, 'spectrogram': 2, 'logits': 3},
  'license': 'Apache-2.0 (Google Perch 2.0)',
  'classes': [
    {
      'label': 'Turdus merula',
      'kind': 'species',
      'group': 'bird',
      'names': {'es': 'Mirlo común', 'eu': 'Zozoa', 'en': 'Blackbird'},
    },
    {
      'label': 'Speech',
      'kind': 'sound',
      'names': {'es': 'Habla', 'eu': 'Hizketa', 'en': ''},
      'isHumanVoice': true,
    },
    {
      'label': 'Wind',
      'kind': 'sound',
      'names': {'es': 'Viento', 'eu': null, 'en': 'Wind'},
    },
  ],
};

Map<String, dynamic> conCambio(String clave, Object? valor) =>
    {...manifiestoValido, clave: valor};

/// Bitset con los bits indicados a 1 (el menos significativo primero), en base64.
String bitsetCodificado(List<int> bitsActivos, {int numeroBytes = 2}) {
  final bytes = Uint8List(numeroBytes);
  for (final bit in bitsActivos) {
    bytes[bit >> 3] |= 1 << (bit & 7);
  }
  return base64.encode(bytes);
}

List<int> deEneroADiciembre(int actividad, [List<int> mesesBajos = const []]) =>
    [for (var mes = 0; mes < 12; mes++) mesesBajos.contains(mes) ? 3 : actividad];

// Bits: 0 mirlo, 1 petirrojo, 8 golondrina (en el segundo byte, para probar
// el orden de bytes).
const etiquetasEspecies = [
  'Turdus merula', 'Erithacus rubecula', 'b2', 'b3', 'b4', 'b5', 'b6', 'b7', 'Hirundo rustica',
];
final ocurrenciaCruda = <String, dynamic>{
  'formatVersion': 1,
  'cellSizeDegrees': 2,
  'latitudeMin': 34,
  'longitudeMin': -26,
  'rows': 19,
  'columns': 36,
  'speciesLabels': etiquetasEspecies,
  'cells': {
    // Donostia (43,32 N, −1,98 E) → fila 4, columna 12.
    '4_12': bitsetCodificado([0, 8]),
  },
  'monthlyActivity': {
    'Hirundo rustica': deEneroADiciembre(80, [0, 1, 10, 11]),
    'Turdus merula': deEneroADiciembre(100),
    'Mal escrita': [1, 2, 3],
  },
};

const latitudDonostia = 43.32;
const longitudDonostia = -1.98;
const enero = 0;
const junio = 5;

void main() {
  group('leerManifiestoFauna', () {
    test('lee un manifiesto válido y normaliza el hash y los nombres vacíos', () {
      final manifiesto = leerManifiestoFauna(manifiestoValido);
      expect(manifiesto.sha256Modelo, (manifiestoValido['modelSha256'] as String).toLowerCase());
      expect(manifiesto.clases.length, 3);
      final mirlo = manifiesto.clases[0];
      expect(mirlo.etiqueta, 'Turdus merula');
      expect(mirlo.tipo, TipoClaseSonido.especie);
      expect(mirlo.grupo, GrupoEspecieSonido.ave);
      expect(mirlo.grupo!.categoriaNaturaleza, 'ave');
      expect(mirlo.nombres, {'es': 'Mirlo común', 'eu': 'Zozoa', 'en': 'Blackbird'});
      expect(manifiesto.clases[1].esVozHumana, isTrue);
      expect(manifiesto.clases[1].nombres['en'], isNull);
      expect(manifiesto.clases[2].esVozHumana, isFalse);
      expect(manifiesto.bytesModelo, 37215308);
    });

    test('rechaza formatos desconocidos, hashes raros y nombres de fichero peligrosos', () {
      final errorFormato = throwsA(isA<ErrorFormatoManifiesto>());
      expect(() => leerManifiestoFauna(conCambio('formatVersion', 2)), errorFormato);
      expect(() => leerManifiestoFauna(conCambio('modelSha256', 'abc')), errorFormato);
      expect(() => leerManifiestoFauna(conCambio('modelFile', '../../x.tflite')), errorFormato);
      expect(() => leerManifiestoFauna(conCambio('classes', [])), errorFormato);
      expect(() => leerManifiestoFauna(null), errorFormato);
      expect(() => leerManifiestoFauna(conCambio('occurrenceFile', '../x.json')), errorFormato);
    });

    test('usa el fichero de presencia por defecto si el manifiesto no lo trae', () {
      expect(leerManifiestoFauna(manifiestoValido).ficheroOcurrencia, ficheroOcurrenciaPorDefecto);
      expect(
        leerManifiestoFauna(conCambio('occurrenceFile', 'fauna-occurrence-europa-2.json'))
            .ficheroOcurrencia,
        'fauna-occurrence-europa-2.json',
      );
    });
  });

  group('resolverIndicesSalida', () {
    final manifiesto = leerManifiestoFauna(manifiestoValido);

    test('reconoce las salidas por su forma aunque vengan en otro orden', () {
      expect(
        resolverIndicesSalida([
          [1, 3],
          [1, 500, 128],
          [1, 1536],
          [1, 16, 4, 1536],
        ], manifiesto),
        const IndicesSalidaModelo(logits: 0, espectrograma: 1, embedding: 2, embeddingEspacial: 3),
      );
    });

    test('si las formas no bastan, usa el orden del manifiesto', () {
      expect(
        resolverIndicesSalida([
          [1, 1536],
          [1, 1536],
          [1, 5],
          [1, 3],
        ], manifiesto),
        manifiesto.salidas,
      );
    });

    test('falla si los logits no tienen tantas clases como el manifiesto', () {
      expect(
        () => resolverIndicesSalida([
          [1, 7],
        ], manifiesto),
        throwsA(isA<ErrorFormatoManifiesto>()),
      );
    });
  });

  group('comprobarIntegridadModelo', () {
    final manifiesto = leerManifiestoFauna(manifiestoValido);

    test('acepta tamaño y SHA-256 iguales (sin importar mayúsculas)', () {
      comprobarIntegridadModelo(
        manifiesto: manifiesto,
        bytesDescargados: 37215308,
        sha256Descargado: manifiestoValido['modelSha256'] as String,
      );
    });

    test('rechaza otro tamaño u otro SHA-256', () {
      expect(
        () => comprobarIntegridadModelo(
            manifiesto: manifiesto,
            bytesDescargados: 100,
            sha256Descargado: manifiesto.sha256Modelo),
        throwsA(isA<ErrorIntegridadModelo>()),
      );
      expect(
        () => comprobarIntegridadModelo(
            manifiesto: manifiesto, bytesDescargados: 37215308, sha256Descargado: '0' * 64),
        throwsA(isA<ErrorIntegridadModelo>()),
      );
    });
  });

  group('leerDatosOcurrencia', () {
    test('lee la rejilla, los bitsets y la actividad mensual, e ignora las mal escritas', () {
      final datos = leerDatosOcurrencia(ocurrenciaCruda);
      expect(datos.numeroFilas, 19);
      expect(datos.indiceBitPorEspecie['Hirundo rustica'], 8);
      expect(datos.bitsetPorCelda['4_12'], [1, 1]);
      expect(datos.actividadMensualPorEspecie.containsKey('Mal escrita'), isFalse);
    });

    test('rechaza formatos desconocidos y celdas mal formadas', () {
      final errorFormato = throwsA(isA<ErrorFormatoOcurrencia>());
      expect(() => leerDatosOcurrencia({...ocurrenciaCruda, 'formatVersion': 2}), errorFormato);
      expect(() => leerDatosOcurrencia({...ocurrenciaCruda, 'cells': {'../x': 'AA=='}}), errorFormato);
      expect(() => leerDatosOcurrencia({...ocurrenciaCruda, 'cells': {'1_1': r'$$'}}), errorFormato);
      expect(() => leerDatosOcurrencia({...ocurrenciaCruda, 'rows': 0}), errorFormato);
      expect(() => leerDatosOcurrencia('hola'), errorFormato);
    });

    test('acepta base64 sin el relleno final', () {
      expect(decodificarBase64Flexible('AQE'), [1, 1]);
      expect(decodificarBase64Flexible('AQE='), [1, 1]);
    });
  });

  group('rejilla', () {
    final datos = leerDatosOcurrencia(ocurrenciaCruda);

    test('calcula la celda con floor y devuelve null fuera de la rejilla', () {
      expect(claveCeldaPara(datos, latitudDonostia, longitudDonostia), '4_12');
      expect(claveCeldaPara(datos, 34, -26), '0_0');
      expect(claveCeldaPara(datos, 33.99, 0), isNull);
      expect(claveCeldaPara(datos, 34 + 19 * 2, 0), isNull);
      expect(claveCeldaPara(datos, 40, -26 + 36 * 2), isNull);
    });

    test('distingue fuera de la rejilla, celda sin datos y celda con datos', () {
      expect(contextoOcurrenciaPara(datos, 0, 0, junio).estado,
          EstadoContextoOcurrencia.fueraDeRejilla);
      expect(contextoOcurrenciaPara(datos, 60, 20, junio).estado,
          EstadoContextoOcurrencia.celdaSinDatos);
      expect(contextoOcurrenciaPara(datos, latitudDonostia, longitudDonostia, junio).estado,
          EstadoContextoOcurrencia.activo);
    });
  });

  group('plausibilidad', () {
    final datos = leerDatosOcurrencia(ocurrenciaCruda);
    final junioEnDonostia = contextoOcurrenciaPara(datos, latitudDonostia, longitudDonostia, junio);
    final eneroEnDonostia = contextoOcurrenciaPara(datos, latitudDonostia, longitudDonostia, enero);

    test('marca «improbable aquí» si el bit está a 0 y «rara en esta época» si la actividad < 10', () {
      expect(plausibilidadEspecie(datos, junioEnDonostia, 'Turdus merula'),
          PlausibilidadEspecie.plausible);
      expect(plausibilidadEspecie(datos, junioEnDonostia, 'Erithacus rubecula').esImprobableAqui,
          isTrue);
      expect(plausibilidadEspecie(datos, junioEnDonostia, 'Hirundo rustica').esFueraDeTemporada,
          isFalse);
      expect(
        plausibilidadEspecie(datos, eneroEnDonostia, 'Hirundo rustica'),
        const PlausibilidadEspecie(esImprobableAqui: false, esFueraDeTemporada: true),
      );
    });

    test('no juzga especies que no están en el fichero ni lugares sin datos', () {
      expect(plausibilidadEspecie(datos, junioEnDonostia, 'Bubo bubo'),
          PlausibilidadEspecie.plausible);
      final sinDatos = contextoOcurrenciaPara(datos, 60, 20, enero);
      expect(plausibilidadEspecie(datos, sinDatos, 'Hirundo rustica'),
          PlausibilidadEspecie.plausible);
    });
  });

  group('penalizaciones y reordenación', () {
    final datos = leerDatosOcurrencia(ocurrenciaCruda);
    const clases = [
      ClaseSonido(etiqueta: 'Turdus merula', tipo: TipoClaseSonido.especie),
      ClaseSonido(etiqueta: 'Erithacus rubecula', tipo: TipoClaseSonido.especie),
      ClaseSonido(etiqueta: 'Hirundo rustica', tipo: TipoClaseSonido.especie),
      // Un sonido general con la misma etiqueta que una especie ausente no se penaliza.
      ClaseSonido(etiqueta: 'b2', tipo: TipoClaseSonido.sonido),
    ];
    final eneroEnDonostia = contextoOcurrenciaPara(datos, latitudDonostia, longitudDonostia, enero);

    test('penaliza solo especies y suma lugar y época', () {
      final penalizaciones = calcularPenalizacionesClases(datos, eneroEnDonostia, clases);
      expect(penalizaciones.penalizacionPorClase,
          [0, penalizacionFueraDeZona, penalizacionFueraDeTemporada, 0]);
      expect(penalizaciones.clasesPenalizadas, 2);
      expect(penalizaciones.clasesExcluidas, 0);
    });

    test('con «Solo especies de mi zona» excluye las ausentes y sigue penalizando la época', () {
      final penalizaciones = calcularPenalizacionesClases(datos, eneroEnDonostia, clases,
          tratamiento: TratamientoFueraDeZona.excluir);
      expect(penalizaciones.penalizacionPorClase,
          [0, penalizacionEspecieExcluida, penalizacionFueraDeTemporada, 0]);
      expect(penalizaciones.clasesExcluidas, 1);
      expect(penalizaciones.clasesPenalizadas, 1);
      // El petirrojo (ausente) no aparece aunque sea el que más puntúa según el modelo.
      final top = clasificarConPenalizaciones([9, 15, 12, 8], penalizaciones, 4);
      expect(top.map((clasificada) => clasificada.indiceClase), [2, 0, 3]);
      expect(top[0].puntuacion, 12 - penalizacionFueraDeTemporada);
      expect(top[0].puntuacionModelo, 12);
    });

    test('sin exclusión, una ausente muy clara todavía llega a «posible» y una confusión normal no', () {
      expect(13 - penalizacionFueraDeZona, greaterThanOrEqualTo(puntuacionMinimaPosible));
      expect(12 - penalizacionFueraDeZona, lessThan(puntuacionMinimaPosible));
    });

    test('reordena el top con las puntuaciones corregidas y conserva la del modelo', () {
      final junioEnDonostia =
          contextoOcurrenciaPara(datos, latitudDonostia, longitudDonostia, junio);
      final penalizaciones = calcularPenalizacionesClases(datos, junioEnDonostia, clases);
      const logits = [9.0, 11.0, 5.0, 8.0];
      expect(clasificarConPenalizaciones(logits, null, 2).map((c) => c.indiceClase), [1, 0]);
      final top = clasificarConPenalizaciones(logits, penalizaciones, 3);
      expect(top.map((c) => c.indiceClase), [0, 3, 1]);
      expect(
        top[2],
        const ClaseClasificada(
          indiceClase: 1,
          puntuacion: 11 - penalizacionFueraDeZona,
          puntuacionModelo: 11,
          plausibilidad: PlausibilidadEspecie(esImprobableAqui: true, esFueraDeTemporada: false),
        ),
      );
      expect(top[0].plausibilidad, isNull);
      expect(clasificarConPenalizaciones(logits, penalizaciones, 0), isEmpty);
    });
  });

  test('redondearCoordenada deja la ubicación en ≈1 km', () {
    expect(redondearCoordenada(43.31789), 43.32);
    expect(redondearCoordenada(-1.98412), -1.98);
  });
}
