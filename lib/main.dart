import 'package:flutter/material.dart';
import 'pantallas/pantalla_mapa.dart';
import 'pantallas/pantalla_lista.dart';
import 'pantallas/pantalla_nuevo.dart';
import 'pantallas/pantalla_guia.dart';
import 'pantallas/pantalla_ajustes.dart';
import 'datos/datos_guia.dart';

void main() {
  runApp(const AplicacionNaturaleza());
}

class AplicacionNaturaleza extends StatelessWidget {
  const AplicacionNaturaleza({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Naturaleza',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5E7D3A),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F1E8),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5E7D3A),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const PantallaPrincipal(),
    );
  }
}

class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  int indiceVistaActual = 0;
  int contadorRefrescoLista = 0;

  void irANuevoHallazgo({double? latitudPredefinida, double? longitudPredefinida}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PantallaNuevoHallazgo(
          latitudPredefinida: latitudPredefinida,
          longitudPredefinida: longitudPredefinida,
        ),
      ),
    ).then((seGuardo) {
      if (seGuardo == true) {
        setState(() {
          contadorRefrescoLista++;
          indiceVistaActual = 1;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pantallas = <Widget>[
      PantallaMapa(
        alPedirNuevoHallazgo: ({double? latitud, double? longitud}) =>
            irANuevoHallazgo(latitudPredefinida: latitud, longitudPredefinida: longitud),
        alSeleccionarEspecieGuia: (idEspecie) => abrirDetalleEspecieGuia(context, idEspecie),
      ),
      PantallaLista(key: ValueKey(contadorRefrescoLista)),
      const SizedBox.shrink(),
      const PantallaGuia(),
      const PantallaAjustes(),
    ];

    return Scaffold(
      body: IndexedStack(index: indiceVistaActual, children: pantallas),
      bottomNavigationBar: NavigationBar(
        selectedIndex: indiceVistaActual,
        onDestinationSelected: (indice) {
          if (indice == 2) {
            irANuevoHallazgo();
            return;
          }
          setState(() => indiceVistaActual = indice);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Mapa'),
          NavigationDestination(icon: Icon(Icons.list_outlined), selectedIcon: Icon(Icons.list), label: 'Lista'),
          NavigationDestination(icon: Icon(Icons.add_circle, size: 32), label: ''),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Guía'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Ajustes'),
        ],
      ),
    );
  }
}
