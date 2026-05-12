import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'pantallas/pantalla_inicio.dart';
import 'pantallas/pantalla_mapa.dart';
import 'pantallas/pantalla_lista.dart';
import 'pantallas/pantalla_nuevo.dart';
import 'pantallas/pantalla_guia.dart';
import 'pantallas/pantalla_ajustes.dart';
import 'servicios/grabador_track.dart';
import 'servicios/estado_conexion.dart';
import 'servicios/auto_backup.dart';
import 'datos/base_datos.dart';
import 'datos/datos_guia.dart';

void _inicializarAccesosDirectos() {
  AccesoDirectoHallazgo.inicializar(
    onNuevoHallazgo: () {},
  );
}

final _autoBackupNaturaleza = AutoBackup(
  nombreApp: 'naturaleza',
  obtenerRutaDb: () => BaseDatosNaturaleza.instancia.rutaBaseDatos(),
  estaVacia: () => BaseDatosNaturaleza.instancia.estaVacia(),
  reiniciarBd: () => BaseDatosNaturaleza.instancia.reiniciar(),
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _inicializarAccesosDirectos();
  await initializeDateFormatting('es_ES', null);

  final restaurado = await _autoBackupNaturaleza.restaurarSiProcede();

  unawaited(GrabadorTrack.instancia.consolidarSesionesPendientes());
  EstadoConexion.instancia.iniciar();
  runApp(AplicacionNaturaleza(restaurado: restaurado));
}

class AplicacionNaturaleza extends StatefulWidget {
  final bool restaurado;
  const AplicacionNaturaleza({super.key, this.restaurado = false});

  @override
  State<AplicacionNaturaleza> createState() => _AplicacionNaturalezaState();
}

class _AplicacionNaturalezaState extends State<AplicacionNaturaleza> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.restaurado) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Datos restaurados desde copia de seguridad.')),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _autoBackupNaturaleza.respaldarAhora();
    }
  }

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
  int contadorRefrescoMapa = 0;

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
          contadorRefrescoMapa++;
          indiceVistaActual = 1; // Vuelve al mapa para ver el nuevo punto
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pantallas = <Widget>[
      PantallaInicio(
        alIrAMapa: () => setState(() => indiceVistaActual = 1),
        alIrAGuia: () => setState(() => indiceVistaActual = 4),
      ),
      PantallaMapa(
        key: ValueKey('mapa_$contadorRefrescoMapa'),
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
          if (indice == 3) {
            irANuevoHallazgo();
            return;
          }
          setState(() => indiceVistaActual = indice);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
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
