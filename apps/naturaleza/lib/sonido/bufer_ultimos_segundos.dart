import 'dart:math' as math;
import 'dart:typed_data';

/// Lo último oído: mientras la pantalla de escucha está abierta y el
/// micrófono activo se conservan siempre los últimos 10 s en un búfer
/// circular (en memoria; se vacía al parar). Al anotar un hallazgo, el clip
/// puede ser ese tramo en vez del trozo analizado, para no perder el canto
/// que sonó justo antes de elegir.
///
/// Privacidad, igual que en el resto de «¿Quién canta?»: del búfer solo se
/// usa audio **ya analizado y sin voz humana**. [RegistroTramosAnalizados]
/// apunta qué tramos se analizaron y cuáles tenían voz; el clip es el último
/// tramo continuo limpio (y lo que aún no se ha analizado no entra).

/// Duración máxima del clip de lo último oído.
const double segundosBuferUltimoOido = 10;

/// Lo que se guarda además en el búfer: lo más reciente (hasta una ventana
/// de 5 s y su análisis) aún no está analizado y no puede entrar en el clip.
const double segundosMargenSinAnalizar = 5;

/// Hueco sin analizar que se tolera entre dos trozos limpios para darlos por
/// continuos. Sin solape, cada trozo se toma cuando llega el bloque del
/// micrófono que completa el salto, así que entre uno y otro quedan unas
/// decenas de milisegundos sin analizar: ahí no cabe una frase.
const double segundosHuecoToleradoEntreTrozos = 0.1;

/// Búfer circular de muestras con posiciones absolutas (contadas desde que
/// se abrió el micrófono), para casarlas con los trozos analizados.
class BuferCircularAudio {
  final int capacidadMuestras;
  final Float32List _muestras;
  int _muestrasTotales = 0;

  BuferCircularAudio(this.capacidadMuestras)
      : _muestras = Float32List(capacidadMuestras > 0 ? capacidadMuestras : 1) {
    if (capacidadMuestras <= 0) throw RangeError('El búfer debe tener capacidad positiva');
  }

  /// Muestras recibidas desde el principio: la siguiente tendrá esta posición.
  int get muestrasTotales => _muestrasTotales;
  int get muestrasGuardadas => math.min(_muestrasTotales, capacidadMuestras);

  /// Posición absoluta de la muestra más antigua que se conserva.
  int get primeraMuestraDisponible => _muestrasTotales - muestrasGuardadas;

  void anadir(List<double> bloque) {
    final longitud = bloque.length;
    // De un bloque más largo que el búfer solo caben sus últimas muestras.
    final saltadas = math.max(0, longitud - capacidadMuestras);
    var posicion = (_muestrasTotales + saltadas) % capacidadMuestras;
    for (var indice = saltadas; indice < longitud; indice++) {
      _muestras[posicion] = bloque[indice];
      posicion++;
      if (posicion == capacidadMuestras) posicion = 0;
    }
    _muestrasTotales += longitud;
  }

  /// Copia de las muestras con posición absoluta en [desde, hasta). Null si
  /// el tramo ya no está (o aún no ha llegado) o está vacío.
  Float32List? extraer(int desde, int hasta) {
    if (hasta <= desde || desde < primeraMuestraDisponible || hasta > _muestrasTotales) return null;
    final resultado = Float32List(hasta - desde);
    for (var indice = 0; indice < resultado.length; indice++) {
      resultado[indice] = _muestras[(desde + indice) % capacidadMuestras];
    }
    return resultado;
  }

  /// Las últimas [numeroMuestras] (o todas las que haya).
  Float32List ultimas(int numeroMuestras) {
    final cuantas = math.min(math.max(0, numeroMuestras), muestrasGuardadas);
    return extraer(_muestrasTotales - cuantas, _muestrasTotales) ?? Float32List(0);
  }

  void vaciar() {
    _muestras.fillRange(0, _muestras.length, 0);
    _muestrasTotales = 0;
  }
}

/// Tramo [inicio, fin) en posiciones absolutas de muestra.
typedef TramoMuestras = ({int inicio, int fin});

/// Qué tramos del micrófono se han analizado y cuáles tenían voz humana.
class RegistroTramosAnalizados {
  final List<TramoMuestras> _limpios = [];
  final List<TramoMuestras> _conVoz = [];

  void registrar(int inicio, int fin, {required bool conVozHumana}) {
    if (fin <= inicio) return;
    (conVozHumana ? _conVoz : _limpios).add((inicio: inicio, fin: fin));
  }

  /// Olvida lo que acaba antes de [muestra] (ya fuera del búfer).
  void olvidarAnterioresA(int muestra) {
    _limpios.removeWhere((tramo) => tramo.fin <= muestra);
    _conVoz.removeWhere((tramo) => tramo.fin <= muestra);
  }

  void vaciar() {
    _limpios.clear();
    _conVoz.clear();
  }

  /// Unión de tramos, ordenada y sin solapes (los contiguos, o separados por
  /// [huecoTolerado] muestras o menos, se juntan).
  static List<TramoMuestras> _unir(List<TramoMuestras> tramos, {int huecoTolerado = 0}) {
    final ordenados = List<TramoMuestras>.of(tramos)..sort((a, b) => a.inicio.compareTo(b.inicio));
    final unidos = <TramoMuestras>[];
    for (final tramo in ordenados) {
      if (unidos.isNotEmpty && tramo.inicio <= unidos.last.fin + huecoTolerado) {
        final ultimo = unidos.removeLast();
        unidos.add((inicio: ultimo.inicio, fin: math.max(ultimo.fin, tramo.fin)));
      } else {
        unidos.add(tramo);
      }
    }
    return unidos;
  }

  /// Tramos analizados sin voz humana: los limpios (juntando los separados
  /// por [huecoTolerado] muestras o menos) menos todo lo que toque un trozo
  /// con voz.
  List<TramoMuestras> tramosLimpios({int huecoTolerado = 0}) {
    final voz = _unir(_conVoz);
    final resultado = <TramoMuestras>[];
    for (final limpio in _unir(_limpios, huecoTolerado: huecoTolerado)) {
      var inicio = limpio.inicio;
      for (final tramoVoz in voz) {
        if (tramoVoz.fin <= inicio || tramoVoz.inicio >= limpio.fin) continue;
        if (tramoVoz.inicio > inicio) resultado.add((inicio: inicio, fin: tramoVoz.inicio));
        inicio = math.max(inicio, tramoVoz.fin);
      }
      if (inicio < limpio.fin) resultado.add((inicio: inicio, fin: limpio.fin));
    }
    return resultado;
  }

  /// El último tramo continuo limpio, recortado a [maximoMuestras] (se
  /// queda con el final) y a lo que aún está en el búfer. Null si no hay.
  TramoMuestras? ultimoTramoLimpio({
    required int maximoMuestras,
    required int primeraDisponible,
    int huecoTolerado = 0,
  }) {
    final limpios = tramosLimpios(huecoTolerado: huecoTolerado);
    for (var indice = limpios.length - 1; indice >= 0; indice--) {
      final tramo = limpios[indice];
      final inicio = math.max(tramo.inicio, math.max(primeraDisponible, tramo.fin - maximoMuestras));
      if (inicio < tramo.fin) return (inicio: inicio, fin: tramo.fin);
    }
    return null;
  }
}
