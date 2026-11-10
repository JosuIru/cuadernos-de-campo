import 'package:flutter_test/flutter_test.dart';
import 'package:naturaleza_flutter/sonido/clasificacion_sonido.dart';
import 'package:naturaleza_flutter/sonido/manifiesto_modelo_fauna.dart';

const mirlo = ClaseSonido(
  etiqueta: 'Turdus merula',
  tipo: TipoClaseSonido.especie,
  grupo: GrupoEspecieSonido.ave,
  nombres: {'es': 'Mirlo común', 'eu': 'Zozoa', 'en': 'Common Blackbird'},
);
const zorzalSinNombresLocales = ClaseSonido(
  etiqueta: 'Zoothera aurea',
  tipo: TipoClaseSonido.especie,
  grupo: GrupoEspecieSonido.ave,
  nombres: {'es': null, 'eu': null, 'en': "White's Thrush"},
);
const habla = ClaseSonido(
  etiqueta: 'Speech',
  tipo: TipoClaseSonido.sonido,
  nombres: {'es': 'Habla', 'eu': 'Hizketa', 'en': 'Speech'},
  esVozHumana: true,
);
const viento = ClaseSonido(
  etiqueta: 'Wind',
  tipo: TipoClaseSonido.sonido,
  nombres: {'es': 'Viento', 'eu': 'Haizea', 'en': 'Wind'},
);
const clases = [mirlo, zorzalSinNombresLocales, habla, viento];

ClaseClasificada c(int indiceClase, double puntuacion) =>
    ClaseClasificada(indiceClase: indiceClase, puntuacion: puntuacion);

List<int> indices(List<ClaseClasificada> clasificadas) =>
    clasificadas.map((clasificada) => clasificada.indiceClase).toList();

void main() {
  test('clasesMejorPuntuadas devuelve las mejores ordenadas y descarta valores no finitos', () {
    expect(clasesMejorPuntuadas([1, 9, double.nan, 5, 7], 3), [c(1, 9), c(4, 7), c(3, 5)]);
    expect(clasesMejorPuntuadas([2], 5), [c(0, 2)]);
  });

  group('confianza', () {
    test('clasifica las puntuaciones en dudoso, posible y probable', () {
      expect(nivelConfianzaPara(5), NivelConfianzaSonido.dudoso);
      expect(nivelConfianzaPara(7), NivelConfianzaSonido.posible);
      expect(nivelConfianzaPara(12), NivelConfianzaSonido.probable);
    });

    test('la barra va de 0 a 1 sin salirse', () {
      expect(fraccionBarraConfianza(-10), 0);
      expect(fraccionBarraConfianza(9), closeTo(0.5, 1e-9));
      expect(fraccionBarraConfianza(40), 1);
    });
  });

  test('nombreVisiblePara usa el idioma de la app y, si falta, los otros por orden', () {
    expect(nombreVisiblePara(mirlo, 'eu'), 'Zozoa');
    expect(nombreVisiblePara(mirlo, 'es'), 'Mirlo común');
    // Catalán y gallego no están en el manifiesto: castellano.
    expect(nombreVisiblePara(mirlo, 'ca'), 'Mirlo común');
    expect(nombreVisiblePara(mirlo, 'gl'), 'Mirlo común');
    expect(nombreVisiblePara(zorzalSinNombresLocales, 'eu'), "White's Thrush");
    expect(
      nombreVisiblePara(
          const ClaseSonido(etiqueta: 'Zoothera aurea', tipo: TipoClaseSonido.especie), 'es'),
      'Zoothera aurea',
    );
    expect(
      nombreVisiblePara(
          const ClaseSonido(etiqueta: 'Car_passing_by', tipo: TipoClaseSonido.sonido), 'es'),
      'Car passing by',
    );
  });

  group('decidirTrozo', () {
    test('cuenta la mejor especie que llega al umbral', () {
      expect(decidirTrozo([c(3, 11), c(0, 9)], clases), const DecisionTrozo.apuntar(0, 9));
    });

    test('descarta el trozo si hay voz humana entre las tres primeras, aunque cante un mirlo', () {
      expect(decidirTrozo([c(0, 12), c(2, 6)], clases), DecisionTrozo.vozHumana);
      expect(hayVozHumana([c(0, 12), c(2, 6)], clases), isTrue);
    });

    test('ignora una voz humana muy débil o fuera de las tres primeras', () {
      final topConHablaLejana = [c(0, 12), c(1, 8), c(3, 7), c(2, 6)];
      expect(decidirTrozo(topConHablaLejana, clases).tipo, TipoDecisionTrozo.apuntar);
      expect(decidirTrozo([c(0, 12), c(2, 1)], clases).tipo, TipoDecisionTrozo.apuntar);
    });

    test('cuenta la mejor especie aunque haya otras dentro del margen', () {
      expect(decidirTrozo([c(0, 9), c(1, 8)], clases), const DecisionTrozo.apuntar(0, 9));
    });

    test('no cuenta sonidos generales ni especies dudosas', () {
      expect(decidirTrozo([c(3, 14)], clases), DecisionTrozo.bajoUmbral);
      expect(decidirTrozo([c(0, 5)], clases), DecisionTrozo.bajoUmbral);
    });
  });

  group('seleccionarResultadosMostrados', () {
    const petirrojo = ClaseSonido(etiqueta: 'Erithacus rubecula', tipo: TipoClaseSonido.especie);
    const chochin = ClaseSonido(etiqueta: 'Troglodytes troglodytes', tipo: TipoClaseSonido.especie);
    const coche = ClaseSonido(etiqueta: 'Car', tipo: TipoClaseSonido.sonido);
    // 0 mirlo, 1 petirrojo, 2 chochín, 3 viento, 4 coche
    const clasesMostrar = [mirlo, petirrojo, chochin, viento, coche];

    test('con una primera muy clara no muestra acompañantes lejanas', () {
      final resultados =
          seleccionarResultadosMostrados([c(0, 14), c(1, 9), c(2, 7.5)], clasesMostrar);
      expect(indices(resultados.especiesMostradas), [0]);
      expect(indices(resultados.especiesDudosas), [1, 2]);
    });

    test('muestra las especies cercanas a la primera que llegan a «posible»', () {
      final resultados = seleccionarResultadosMostrados(
        [c(0, 11), c(1, 11 - margenRelativoPuntuacion + 0.5), c(2, 11 - margenRelativoPuntuacion)],
        clasesMostrar,
      );
      expect(indices(resultados.especiesMostradas), [0, 1]);
      expect(indices(resultados.especiesDudosas), [2]);
    });

    test('oculta lo dudoso aunque esté cerca de la primera', () {
      final resultados = seleccionarResultadosMostrados([c(0, 6.5), c(1, 6)], clasesMostrar);
      expect(resultados.especiesMostradas, isEmpty);
      expect(indices(resultados.especiesDudosas), [0, 1]);
    });

    test('el margen se mide desde la primera especie, no desde un sonido general', () {
      final resultados =
          seleccionarResultadosMostrados([c(3, 15), c(0, 9), c(4, 8)], clasesMostrar);
      expect(indices(resultados.especiesMostradas), [0]);
      // El viento (15) se menciona; el coche (8) no llega a «también se oye».
      expect(indices(resultados.sonidosTambienOidos), [3]);
    });

    test('acepta otro umbral absoluto', () {
      expect(
        seleccionarResultadosMostrados([c(0, 8)], clasesMostrar, puntuacionMinimaEspecie: 9)
            .especiesMostradas,
        isEmpty,
      );
    });
  });
}
