import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'pantallas/pantalla_inicio.dart';
import 'pantallas/pantalla_mapa.dart';
import 'pantallas/pantalla_lista.dart';
import 'pantallas/pantalla_nuevo.dart';
import 'pantallas/pantalla_guia.dart';
import 'pantallas/pantalla_ajustes.dart';
import 'pantallas/pantalla_importar_fos_card.dart';
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

final _autoBackup = AutoBackup(
  nombreApp: 'fosiles',
  obtenerRutaDb: () => BaseDatosFosiles.instancia.rutaBaseDatos(),
  estaVacia: () => BaseDatosFosiles.instancia.estaVacia(),
  reiniciarBd: () => BaseDatosFosiles.instancia.reiniciar(),
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _inicializarAccesosDirectos();
  await initializeDateFormatting('es_ES', null);

  // Restaurar backup automático si la BD está vacía
  final restaurado = await _autoBackup.restaurarSiProcede();

  unawaited(GrabadorTrack.instancia.consolidarSesionesPendientes());
  EstadoConexion.instancia.iniciar();
  runApp(AplicacionFosiles(restaurado: restaurado));
}

class AplicacionFosiles extends StatefulWidget {
  final bool restaurado;
  const AplicacionFosiles({super.key, this.restaurado = false});

  @override
  State<AplicacionFosiles> createState() => _AplicacionFosilesState();
}

class _AplicacionFosilesState extends State<AplicacionFosiles> with WidgetsBindingObserver {
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
      _autoBackup.respaldarAhora();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fósiles',
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
  StreamSubscription<List<SharedMediaFile>>? _suscripcionShare;

  @override
  void initState() {
    super.initState();
    // Escuchar archivos compartidos (.fos-card) en caliente y al arrancar.
    _suscripcionShare = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(_manejarMediaCompartida, onError: (_) {});
    ReceiveSharingIntent.instance.getInitialMedia().then((media) {
      if (media.isNotEmpty) {
        _manejarMediaCompartida(media);
        ReceiveSharingIntent.instance.reset();
      }
    });
  }

  @override
  void dispose() {
    _suscripcionShare?.cancel();
    super.dispose();
  }

  void _manejarMediaCompartida(List<SharedMediaFile> media) {
    if (media.isEmpty) return;
    final fosCards = media.where((m) => m.path.toLowerCase().endsWith('.fos-card')).toList();
    if (fosCards.isEmpty) return;
    final primero = fosCards.first;
    final fichero = File(primero.path);
    if (!fichero.existsSync()) return;
    // Difiero a un postFrame para que el árbol esté montado.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context)
          .push<bool>(MaterialPageRoute(
            builder: (_) => PantallaImportarFosCard(ficheroFosCard: fichero),
          ))
          .then((importado) {
        if (importado == true) {
          setState(() {
            contadorRefrescoLista++;
            contadorRefrescoMapa++;
            indiceVistaActual = 2; // pasar a la lista para que vea la entrante
          });
        }
      });
    });
  }

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
        alSeleccionarFosilGuia: (idFosil) => abrirDetalleFosilGuia(context, idFosil),
      ),
      PantallaLista(key: ValueKey(contadorRefrescoLista)),
      const SizedBox.shrink(),
      const PantallaGuia(),
      PantallaAjustes(),
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
