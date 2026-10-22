import 'package:flutter_test/flutter_test.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:naturaleza_flutter/datos/configuracion.dart';

void main() {
  group('Configuracion.obtenerModelo', () {
    test('sin modelo guardado devuelve el de por defecto (Opus 5.5)', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await Configuracion.obtenerModelo(), modeloClaudePotente);
      expect(modeloPorDefecto, modeloClaudePotente);
    });

    test('traduce los modelos 4.x guardados a su familia 5.5', () async {
      const traducciones = {
        'claude-opus-4-7': modeloClaudePotente,
        'claude-sonnet-4-6': modeloClaudeEquilibrado,
        'claude-haiku-4-5': modeloClaudeRapido,
      };
      for (final entrada in traducciones.entries) {
        SharedPreferences.setMockInitialValues({'modelo_claude': entrada.key});
        expect(await Configuracion.obtenerModelo(), entrada.value, reason: entrada.key);
      }
    });

    test('un modelo 5.5 guardado se respeta', () async {
      SharedPreferences.setMockInitialValues({'modelo_claude': modeloClaudeEquilibrado});
      expect(await Configuracion.obtenerModelo(), modeloClaudeEquilibrado);
    });

    test('la lista de modelos disponibles es la familia 5.5', () {
      expect(modelosDisponibles.map((modelo) => modelo.id),
          [modeloClaudePotente, modeloClaudeEquilibrado, modeloClaudeRapido]);
    });
  });
}
