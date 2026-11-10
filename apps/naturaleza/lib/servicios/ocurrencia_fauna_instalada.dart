import '../sonido/filtro_ocurrencia.dart';
import 'almacen_modelo_fauna.dart';

/// El fichero de presencia por lugar y época del modelo de «¿Quién canta?»,
/// leído una vez y guardado en memoria para las fichas («Cuándo y dónde suele
/// cantar»). Nunca descarga nada: si el modelo no está instalado, no hay
/// datos.
class OcurrenciaFaunaInstalada {
  OcurrenciaFaunaInstalada._();

  static DatosOcurrencia? _datos;
  static Future<DatosOcurrencia?>? _lectura;

  /// Los datos si ya se han leído o fijado (sin esperar).
  static DatosOcurrencia? get enMemoria => _datos;

  static Future<DatosOcurrencia?> cargar() {
    final datos = _datos;
    if (datos != null) return Future.value(datos);
    return _lectura ??= _leer().whenComplete(() => _lectura = null);
  }

  static Future<DatosOcurrencia?> _leer() async {
    final modelo = await leerModeloFaunaInstalado();
    if (modelo == null) return null;
    final datos = await leerOcurrenciaInstalada(modelo.manifiesto);
    _datos ??= datos;
    return _datos;
  }

  /// La pantalla de escucha comparte lo que ya ha cargado o descargado.
  static void fijar(DatosOcurrencia? datos) => _datos = datos;

  /// Al borrar el modelo.
  static void olvidar() => _datos = null;
}
