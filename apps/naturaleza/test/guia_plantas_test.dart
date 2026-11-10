// Reglas de la guía de plantas (2026-11-10): sin etiquetas «medicinal» ni
// «comestible» sueltas; el uso tradicional solo con fuente de la EMA, con
// precauciones, sin dosis, y nunca en especies tóxicas ni protegidas.

import 'package:flutter_test/flutter_test.dart';
import 'package:naturaleza_flutter/datos/datos_guia.dart';
import 'package:naturaleza_flutter/datos/usos_tradicionales.dart';

void main() {
  final ids = {for (final especie in especiesGuia) especie.id};

  test('ids de la guía únicos', () {
    expect(ids, hasLength(especiesGuia.length));
  });

  test('no quedan las etiquetas «medicinal» ni «comestible»', () {
    expect(usosCatalogo.map((uso) => uso.id),
        isNot(anyOf(contains('medicinal'), contains('comestible'))));
    for (final especie in especiesGuia) {
      expect(especie.usos, isNot(contains('medicinal')), reason: especie.id);
      expect(especie.usos, isNot(contains('comestible')), reason: especie.id);
      for (final uso in especie.usos) {
        expect(usoPorId(uso), isNotNull, reason: '${especie.id}: $uso');
      }
    }
  });

  test('cada uso de la EMA es de una especie de la guía y cita su fuente', () {
    for (final uso in usosTradicionalesEma) {
      expect(ids, contains(uso.especieId));
      expect(uso.url, startsWith('https://www.ema.europa.eu/'));
      expect(uso.estadoMonografia, isNotEmpty);
      expect(uso.uso.isNotEmpty || uso.precauciones.isNotEmpty, isTrue,
          reason: uso.especieId);
    }
  });

  test('sin dosis ni preparaciones', () {
    final dosis = RegExp(r'\d+\s*(mg|g|ml|gotas|veces al día|tazas?)\b',
        caseSensitive: false);
    for (final uso in usosTradicionalesEma) {
      expect(dosis.hasMatch(uso.uso), isFalse, reason: uso.especieId);
    }
  });

  test('tóxicas y protegidas no enseñan uso tradicional', () {
    for (final especie in especiesGuia) {
      if (especie.usos.contains('toxica') ||
          especie.usos.contains('protegida')) {
        expect(usosTradicionalesDe(especie), isEmpty, reason: especie.id);
      }
    }
    // La hiedra tiene monografía, pero es tóxica: no se enseña.
    expect(usosTradicionalesDe(especiePorId('hedera-helix')!), isEmpty);
    expect(usosTradicionalesDe(especiePorId('gentiana-lutea')!), isEmpty);
    expect(
        usosTradicionalesDe(especiePorId('hypericum-perforatum')!), isNotEmpty);
  });

  test('las aromáticas silvestres de Larrea están y avisan de confusiones', () {
    for (final id in [
      'lavandula-angustifolia',
      'thymus-zygis',
      'satureja-montana',
      'gentiana-lutea',
      'arnica-montana',
    ]) {
      expect(ids, contains(id));
    }
    expect(especiePorId('gentiana-lutea')!.usos, contains('protegida'));
    expect(especiePorId('gentiana-lutea')!.confundibles.join(' '),
        contains('Veratrum'));
    expect(especiePorId('foeniculum-vulgare')!.confundibles.join(' '),
        contains('Cicuta'));
  });

  test('plantas y setas llevan el aviso de consumo', () {
    expect(llevaAvisoConsumo(especiePorId('foeniculum-vulgare')!), isTrue);
    final ave = especiesGuia.firstWhere((e) => e.categoriaId == 'ave');
    expect(llevaAvisoConsumo(ave), isFalse);
  });
}
