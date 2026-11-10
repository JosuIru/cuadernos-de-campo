// Edge-to-edge de Android 15+ (targetSdk ≥ 35): lo último de una pantalla
// u hoja queda por encima de la barra de navegación del sistema, y los
// campos seguidos de un formulario guardan la separación común
// (separacionCamposSolera).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naturaleza_flutter/pantallas/pantalla_nuevo.dart';
import 'package:naturaleza_flutter/pantallas/sheet_donaciones.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart'
    show SoleraL10n, separacionCamposSolera;
import 'package:shared_preferences/shared_preferences.dart';

/// Barra de navegación de Android de 48 px lógicos.
const double alturaBarraSistema = 48;

void simularBarraSistema(WidgetTester tester) {
  final escala = tester.view.devicePixelRatio;
  tester.view.viewPadding =
      FakeViewPadding(bottom: alturaBarraSistema * escala);
  tester.view.padding = FakeViewPadding(bottom: alturaBarraSistema * escala);
  addTearDown(tester.view.reset);
}

double altoPantalla(WidgetTester tester) =>
    tester.view.physicalSize.height / tester.view.devicePixelRatio;

Future<void> abrirAltaHallazgo(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(
    home: PantallaNuevoHallazgo(
        latitudPredefinida: 43.0, longitudPredefinida: -2.0),
  ));
  await tester.pump();
}

/// Lleva el scroll de [lista] hasta el final (repite porque la lista
/// construye perezosamente y su extensión crece al bajar).
Future<void> irAlFinal(WidgetTester tester, Finder lista) async {
  for (var intento = 0; intento < 10; intento++) {
    final posicion = tester
        .state<ScrollableState>(
            find.descendant(of: lista, matching: find.byType(Scrollable)).first)
        .position;
    if (posicion.pixels >= posicion.maxScrollExtent) break;
    posicion.jumpTo(posicion.maxScrollExtent);
    await tester.pumpAndSettle();
  }
}

Finder campoConEtiqueta(String etiqueta) =>
    find.ancestor(of: find.text(etiqueta), matching: find.byType(TextField));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('el final del alta de hallazgo queda sobre la barra del sistema',
      (tester) async {
    simularBarraSistema(tester);
    await abrirAltaHallazgo(tester);
    await irAlFinal(tester, find.byType(ListView).first);
    final ultimaTarjeta = find.ancestor(
        of: find.text(SoleraL10n.t('identificacion_con_ia')),
        matching: find.byType(Card));
    final abajoUltimaTarjeta = tester.getRect(ultimaTarjeta).bottom;
    expect(abajoUltimaTarjeta,
        lessThanOrEqualTo(altoPantalla(tester) - alturaBarraSistema - 16));
  });

  testWidgets('la última tarjeta de la hoja de apoyo queda sobre la barra',
      (tester) async {
    simularBarraSistema(tester);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => mostrarSheetDonaciones(context),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    final lista = find.descendant(
        of: find.byType(BottomSheet), matching: find.byType(ListView));
    await irAlFinal(tester, lista);
    final abajoUltimaTarjeta = tester
        .getRect(find.text(SoleraL10n.t('fos.ajus_ecosistema_texto')))
        .bottom;
    // La hoja deja 32 px propios por debajo de su lista.
    expect(abajoUltimaTarjeta,
        lessThanOrEqualTo(altoPantalla(tester) - alturaBarraSistema - 32));
  });

  testWidgets('los campos seguidos del alta de hallazgo no se pegan',
      (tester) async {
    await abrirAltaHallazgo(tester);
    final campoNombreComun =
        campoConEtiqueta(SoleraL10n.t('agro.nombre_comun'));
    final campoEspecie =
        campoConEtiqueta(SoleraL10n.t('nat.hall_nombre_cientifico_binomial'));
    await tester.scrollUntilVisible(campoEspecie, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    final hueco = tester.getRect(campoEspecie).top -
        tester.getRect(campoNombreComun).bottom;
    expect(hueco, greaterThanOrEqualTo(separacionCamposSolera));
    expect(separacionCamposSolera, greaterThanOrEqualTo(12));
  });
}
