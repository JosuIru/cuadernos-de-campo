// Exportador del catálogo Dart `formacionesIbericas` a JSON que el
// wp-plugin consume al activarse (seed de la tabla
// `wp_ns_fosiles_formaciones_catalogadas`).
//
// Implementado como flutter test (no como dart run puro) porque
// `formacion_a_fosiles.dart` arrastra `datos_guia.dart`, que importa
// `package:flutter/material.dart` para el campo `Color` de
// `PeriodoGeologico`. `flutter test` resuelve el Flutter SDK
// correctamente; `dart run` no.
//
// Ejecución:
//   ( cd apps/fosiles && flutter test test/exportar_formaciones_a_json_test.dart )
//
// Salida: `wp-plugin/nuevo-ser-core/seeds/fosiles_formaciones.json`
//
// Reejecutar cada vez que se añadan / quiten entradas al catálogo
// Dart. El plugin lo aplica con INSERT ... ON DUPLICATE KEY UPDATE,
// así que reejecutarlo es seguro.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fosiles_flutter/datos/datos_guia.dart';
import 'package:fosiles_flutter/datos/formacion_a_fosiles.dart';

void main() {
  test('exporta formacionesIbericas a JSON portable para el wp-plugin',
      () async {
    final periodosPorId = <String, PeriodoGeologico>{
      for (final periodoGeologico in periodos)
        periodoGeologico.id: periodoGeologico,
    };

    final salida = <Map<String, dynamic>>[];
    for (final formacion in formacionesIbericas) {
      final periodoLegible = periodosPorId[formacion.periodoId];
      salida.add(<String, dynamic>{
        'codigo': formacion.id,
        'nombre_oficial': _nombreOficialPara(formacion),
        'periodo': periodoLegible?.nombre ?? formacion.periodoId,
        'edad_aproximada': periodoLegible?.edadMa ?? '',
        'regiones': formacion.regiones,
        'descripcion': formacion.descripcionCorta,
        'activo': true,
      });
    }

    final destino = File(
      '../../wp-plugin/nuevo-ser-core/seeds/fosiles_formaciones.json',
    );
    await destino.parent.create(recursive: true);
    await destino.writeAsString(
      const JsonEncoder.withIndent('  ').convert(salida),
    );

    expect(salida.length, greaterThanOrEqualTo(25));
    stdout.writeln(
      '✓ Exportadas ${salida.length} formaciones a ${destino.path}',
    );
  });
}

/// Construye un nombre oficial legible a partir del primer patrón
/// (que suele ser el nombre canónico de la formación) capitalizado.
String _nombreOficialPara(CatalogoFormacion formacion) {
  if (formacion.patronesNombre.isEmpty) {
    return formacion.id;
  }
  final primero = formacion.patronesNombre.first;
  return primero
      .split(' ')
      .map((palabra) => palabra.isEmpty
          ? palabra
          : '${palabra[0].toUpperCase()}${palabra.substring(1)}')
      .join(' ');
}
