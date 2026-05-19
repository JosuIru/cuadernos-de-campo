import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class EstadoConexion {
  static final EstadoConexion instancia = EstadoConexion._interno();
  EstadoConexion._interno();

  final _controlador = StreamController<bool>.broadcast();
  bool _conectado = true;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  bool get conectado => _conectado;
  Stream<bool> get cambios => _controlador.stream;

  void iniciar() {
    _sub?.cancel();
    _sub = Connectivity().onConnectivityChanged.listen((resultados) {
      final online = !resultados.contains(ConnectivityResult.none);
      if (online != _conectado) {
        _conectado = online;
        _controlador.add(online);
      }
    });
    Connectivity().checkConnectivity().then((resultados) {
      _conectado = !resultados.contains(ConnectivityResult.none);
      _controlador.add(_conectado);
    });
  }

  void dispose() {
    _sub?.cancel();
    _controlador.close();
  }
}
