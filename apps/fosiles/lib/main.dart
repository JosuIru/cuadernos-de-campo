import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:latlong2/latlong.dart';
import 'pantallas/pantalla_inicio.dart';
import 'pantallas/pantalla_mapa.dart';
import 'pantallas/pantalla_lista.dart';
import 'pantallas/pantalla_nuevo.dart';
import 'pantallas/pantalla_guia.dart';
import 'pantallas/pantalla_ajustes.dart';
import 'pantallas/pantalla_importar_fos_card.dart';
import 'pantallas/pantalla_onboarding.dart';
import 'servicios/grabador_track.dart';
import 'servicios/estado_conexion.dart';
import 'servicios/auto_backup.dart';
import 'servicios/checker_actualizaciones_fosiles.dart';
import 'datos/base_datos.dart';
import 'datos/configuracion.dart';
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
  unawaited(comprobarActualizacionFosilesEnBackground());
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
  /// Coordenadas a las que la pestaña Mapa debe saltar la próxima vez que
  /// se construye. Lo setea `_verHallazgoEnMapa` cuando el usuario pulsa
  /// "Ver en el mapa" en la ficha de un hallazgo de la pestaña Lista; la
  /// pestaña Mapa lo escucha y mueve la cámara.
  final ValueNotifier<LatLng?> _destinoMapaNotifier = ValueNotifier(null);

  void _verHallazgoEnMapa(double latitud, double longitud) {
    setState(() {
      _indicesVisitados.add(1);
      indiceVistaActual = 1;
    });
    // El postFrame asegura que la pestaña Mapa ya está construida (la
    // primera visita es cuando se construye) antes de pedirle el move.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _destinoMapaNotifier.value = LatLng(latitud, longitud);
    });
  }

  // IndexedStack construye TODOS los hijos al primer frame: arrancando la app
  // se inicializaba el mapa con sus GPS streams, tile layers WMS, etc. aunque
  // el usuario empezase en Inicio. Con este set sólo construimos cada pantalla
  // la primera vez que se visita y desde ahí se conserva en el stack.
  final Set<int> _indicesVisitados = {0};

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

    // Mini-tour de primer arranque: si el usuario nunca lo ha visto, lo
    // abrimos como diálogo a pantalla completa una vez montado el árbol.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final yaVisto = await Configuracion.haVistoOnboarding();
      if (yaVisto || !mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const PantallaOnboarding(),
        ),
      );
    });
  }

  @override
  void dispose() {
    _suscripcionShare?.cancel();
    _destinoMapaNotifier.dispose();
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
            _indicesVisitados.add(2);
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
          _indicesVisitados.add(1);
          indiceVistaActual = 1; // Vuelve al mapa para ver el nuevo punto
        });
      }
    });
  }

  Widget _construirPantalla(int indice) {
    switch (indice) {
      case 0:
        return PantallaInicio(
          alIrAMapa: () => setState(() {
            _indicesVisitados.add(1);
            indiceVistaActual = 1;
          }),
          alIrAGuia: () => setState(() {
            _indicesVisitados.add(4);
            indiceVistaActual = 4;
          }),
        );
      case 1:
        return PantallaMapa(
          key: ValueKey('mapa_$contadorRefrescoMapa'),
          alPedirNuevoHallazgo: ({double? latitud, double? longitud}) =>
              irANuevoHallazgo(latitudPredefinida: latitud, longitudPredefinida: longitud),
          alSeleccionarFosilGuia: (idFosil) => abrirDetalleFosilGuia(context, idFosil),
          destinoMapaNotifier: _destinoMapaNotifier,
        );
      case 2:
        return PantallaLista(
          key: ValueKey(contadorRefrescoLista),
          alVerEnMapa: _verHallazgoEnMapa,
        );
      case 4:
        return const PantallaGuia();
      case 5:
        return PantallaAjustes();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pantallas = <Widget>[
      for (var indice = 0; indice < 6; indice++)
        _indicesVisitados.contains(indice)
            ? _construirPantalla(indice)
            : const SizedBox.shrink(),
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
          setState(() {
            _indicesVisitados.add(indice);
            indiceVistaActual = indice;
          });
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
