import 'dart:convert';
import 'dart:io';

/// Dónde se guarda la caché (un JSON). En la app, un fichero en
/// documentos; en los tests, memoria.
abstract class AlmacenCache {
  Future<Map<String, dynamic>> leer();
  Future<void> escribir(Map<String, dynamic> contenido);
}

class AlmacenCacheMemoria implements AlmacenCache {
  Map<String, dynamic> contenido = {};

  @override
  Future<Map<String, dynamic>> leer() async => jsonDecode(jsonEncode(contenido)) as Map<String, dynamic>;

  @override
  Future<void> escribir(Map<String, dynamic> nuevo) async {
    contenido = jsonDecode(jsonEncode(nuevo)) as Map<String, dynamic>;
  }
}

class AlmacenCacheFichero implements AlmacenCache {
  AlmacenCacheFichero(this._resolverFichero);

  final Future<File> Function() _resolverFichero;

  @override
  Future<Map<String, dynamic>> leer() async {
    try {
      final fichero = await _resolverFichero();
      if (!await fichero.exists()) return {};
      final decodificado = jsonDecode(await fichero.readAsString());
      return decodificado is Map<String, dynamic> ? decodificado : {};
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> escribir(Map<String, dynamic> contenido) async {
    try {
      final fichero = await _resolverFichero();
      final temporal = File('${fichero.path}.tmp');
      await temporal.writeAsString(jsonEncode(contenido), flush: true);
      await temporal.rename(fichero.path);
    } catch (_) {}
  }
}

/// Entrada leída de la caché: los datos y cuándo se guardaron.
class EntradaCache {
  const EntradaCache(this.datos, this.guardadaEn);

  final Object? datos;
  final DateTime guardadaEn;

  bool caducadaPara(Duration vigencia, DateTime ahora) => ahora.difference(guardadaEn) > vigencia;
}

/// Caché clave → JSON con la fecha de guardado. La vigencia la decide quien
/// lee (fotos 30 días, recuentos 7…): una entrada caducada se sigue
/// devolviendo para usarla sin red. Al cargar se tiran las de más de
/// [antiguedadMaxima].
class CacheConCaducidad {
  CacheConCaducidad(
    this._almacen, {
    DateTime Function()? reloj,
    this.antiguedadMaxima = const Duration(days: 180),
  }) : _reloj = reloj ?? DateTime.now;

  final AlmacenCache _almacen;
  final DateTime Function() _reloj;
  final Duration antiguedadMaxima;
  Map<String, dynamic>? _entradas;
  Future<void> _escrituraPendiente = Future.value();

  Future<Map<String, dynamic>> _cargar() async {
    final cargadas = _entradas;
    if (cargadas != null) return cargadas;
    final leidas = await _almacen.leer();
    final ahora = _reloj();
    leidas.removeWhere((_, valor) {
      final guardada = valor is Map ? valor['t'] : null;
      if (guardada is! int) return true;
      return ahora.difference(DateTime.fromMillisecondsSinceEpoch(guardada)) > antiguedadMaxima;
    });
    return _entradas ??= leidas;
  }

  Future<EntradaCache?> leer(String clave) async {
    final entrada = (await _cargar())[clave];
    if (entrada is! Map || entrada['t'] is! int) return null;
    return EntradaCache(entrada['d'], DateTime.fromMillisecondsSinceEpoch(entrada['t'] as int));
  }

  Future<void> guardar(String clave, Object? datos) async {
    final entradas = await _cargar();
    entradas[clave] = {'t': _reloj().millisecondsSinceEpoch, 'd': datos};
    // Escrituras en serie para no pisar el fichero.
    _escrituraPendiente = _escrituraPendiente.then((_) => _almacen.escribir(entradas));
    await _escrituraPendiente;
  }
}
