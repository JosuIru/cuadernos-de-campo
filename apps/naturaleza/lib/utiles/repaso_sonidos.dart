import 'dart:convert';
import 'dart:math';

import '../modelos/hallazgo.dart';
import 'primeras_veces.dart';

/// «Aprender con tus grabaciones»: tarjetas con los clips de los hallazgos
/// propios (suena el clip, se elige la especie entre 4) y repetición espaciada
/// con el sistema de Leitner (cajas 1-5).
///
/// Lógica pura: el estado se guarda como JSON en las preferencias.

/// Especies distintas con clip necesarias para jugar (una correcta y tres
/// distractores).
const int especiesMinimasRepaso = 4;

/// Opciones por pregunta.
const int opcionesPorPregunta = 4;

/// Tarjetas por ronda.
const int tarjetasPorRonda = 10;

/// Días hasta el siguiente repaso según la caja (índice 0 = caja 1).
const List<int> diasPorCaja = [1, 2, 4, 8, 16];

int get cajaMaxima => diasPorCaja.length;

/// Una tarjeta: el clip de un hallazgo y su especie.
class TarjetaSonido {
  final int idHallazgo;
  final String rutaAudio;
  final String claveEspecie;
  final String nombreCientifico;
  final String nombreComun;
  final String categoria;
  final DateTime fecha;

  const TarjetaSonido({
    required this.idHallazgo,
    required this.rutaAudio,
    required this.claveEspecie,
    required this.nombreCientifico,
    required this.nombreComun,
    required this.categoria,
    required this.fecha,
  });
}

/// Una especie del cuaderno que puede salir como opción.
class OpcionEspecie {
  final String claveEspecie;
  final String nombreCientifico;
  final String nombreComun;
  final String categoria;

  const OpcionEspecie({
    required this.claveEspecie,
    required this.nombreCientifico,
    required this.nombreComun,
    required this.categoria,
  });

  @override
  bool operator ==(Object other) => other is OpcionEspecie && other.claveEspecie == claveEspecie;

  @override
  int get hashCode => claveEspecie.hashCode;
}

/// Tarjetas posibles: hallazgos guardados con clip y especie. [existeAudio]
/// deja fuera los clips cuyo fichero ya no está.
List<TarjetaSonido> tarjetasDesdeHallazgos(
  Iterable<Hallazgo> hallazgos, {
  bool Function(String ruta)? existeAudio,
  String? Function(String nombreComun)? cientificoPorNombreComun,
}) {
  final tarjetas = <TarjetaSonido>[];
  for (final hallazgo in hallazgos) {
    final ruta = hallazgo.rutaAudio;
    final id = hallazgo.id;
    if (ruta == null || ruta.isEmpty || id == null) continue;
    if (existeAudio != null && !existeAudio(ruta)) continue;
    final especie = especieDeHallazgo(hallazgo, cientificoPorNombreComun: cientificoPorNombreComun);
    if (especie == null) continue;
    tarjetas.add(TarjetaSonido(
      idHallazgo: id,
      rutaAudio: ruta,
      claveEspecie: especie.clave,
      nombreCientifico: especie.nombreCientifico,
      nombreComun: especie.nombreComun,
      categoria: hallazgo.categoria,
      fecha: DateTime.fromMillisecondsSinceEpoch(hallazgo.fechaMs),
    ));
  }
  return tarjetas;
}

/// Especies del cuaderno (con o sin clip), para los distractores. Si una
/// especie se anotó con nombres distintos, vale el último.
List<OpcionEspecie> especiesDelCuaderno(
  Iterable<Hallazgo> hallazgos, {
  String? Function(String nombreComun)? cientificoPorNombreComun,
}) {
  final porClave = <String, (int, OpcionEspecie)>{};
  for (final hallazgo in hallazgos) {
    final especie = especieDeHallazgo(hallazgo, cientificoPorNombreComun: cientificoPorNombreComun);
    if (especie == null) continue;
    final anterior = porClave[especie.clave];
    if (anterior != null && anterior.$1 > hallazgo.fechaMs) continue;
    porClave[especie.clave] = (
      hallazgo.fechaMs,
      OpcionEspecie(
        claveEspecie: especie.clave,
        nombreCientifico: especie.nombreCientifico,
        nombreComun: especie.nombreComun,
        categoria: hallazgo.categoria,
      ),
    );
  }
  return [for (final (_, opcion) in porClave.values) opcion];
}

/// Número de especies distintas entre las tarjetas.
int especiesConClip(Iterable<TarjetaSonido> tarjetas) => {for (final tarjeta in tarjetas) tarjeta.claveEspecie}.length;

/// Las opciones de una pregunta: la correcta y [opcionesPorPregunta] − 1
/// distractores del cuaderno, primero de las especies con clip del mismo grupo
/// (categoría), luego del mismo grupo sin clip y luego del resto; barajadas.
/// Con menos especies de las necesarias devuelve las que haya.
List<OpcionEspecie> opcionesParaTarjeta(
  TarjetaSonido tarjeta,
  List<OpcionEspecie> especiesCuaderno,
  Set<String> clavesConClip,
  Random azar,
) {
  final correcta = OpcionEspecie(
    claveEspecie: tarjeta.claveEspecie,
    nombreCientifico: tarjeta.nombreCientifico,
    nombreComun: tarjeta.nombreComun,
    categoria: tarjeta.categoria,
  );
  final candidatas = [
    for (final especie in especiesCuaderno)
      if (especie.claveEspecie != tarjeta.claveEspecie) especie,
  ];
  int prioridad(OpcionEspecie especie) {
    final mismoGrupo = especie.categoria == tarjeta.categoria;
    final conClip = clavesConClip.contains(especie.claveEspecie);
    if (mismoGrupo && conClip) return 0;
    if (mismoGrupo) return 1;
    if (conClip) return 2;
    return 3;
  }

  final porPrioridad = <int, List<OpcionEspecie>>{};
  for (final candidata in candidatas) {
    porPrioridad.putIfAbsent(prioridad(candidata), () => []).add(candidata);
  }
  final distractores = <OpcionEspecie>[];
  for (final nivel in [0, 1, 2, 3]) {
    final grupo = porPrioridad[nivel];
    if (grupo == null) continue;
    grupo.shuffle(azar);
    for (final especie in grupo) {
      if (distractores.length == opcionesPorPregunta - 1) break;
      distractores.add(especie);
    }
  }
  return [correcta, ...distractores]..shuffle(azar);
}

/// Estado de Leitner de una tarjeta.
class EstadoTarjeta {
  /// Caja 1-[cajaMaxima].
  final int caja;

  /// Cuándo toca repasarla (ms).
  final int proximoRepasoMs;

  const EstadoTarjeta({required this.caja, required this.proximoRepasoMs});
}

/// Estado del repaso: caja y próxima fecha por hallazgo. Una tarjeta sin
/// estado es nueva (caja 1, toca ya).
class EstadoRepaso {
  final Map<int, EstadoTarjeta> porHallazgo;

  const EstadoRepaso(this.porHallazgo);

  static const EstadoRepaso vacio = EstadoRepaso({});

  EstadoTarjeta estadoDe(int idHallazgo) =>
      porHallazgo[idHallazgo] ?? const EstadoTarjeta(caja: 1, proximoRepasoMs: 0);

  bool tocaRepasar(int idHallazgo, DateTime ahora) => estadoDe(idHallazgo).proximoRepasoMs <= ahora.millisecondsSinceEpoch;

  /// Tras responder: si acierta sube una caja (hasta la última); si falla
  /// vuelve a la 1. La próxima fecha es ahora + los días de la caja nueva.
  EstadoRepaso conRespuesta(int idHallazgo, {required bool acierto, required DateTime ahora}) {
    final cajaActual = estadoDe(idHallazgo).caja;
    final cajaNueva = acierto ? min(cajaActual + 1, cajaMaxima) : 1;
    final proximo = ahora.add(Duration(days: diasPorCaja[cajaNueva - 1]));
    return EstadoRepaso({
      ...porHallazgo,
      idHallazgo: EstadoTarjeta(caja: cajaNueva, proximoRepasoMs: proximo.millisecondsSinceEpoch),
    });
  }

  /// Quita el estado de las tarjetas que ya no existen.
  EstadoRepaso soloDe(Iterable<int> idsExistentes) {
    final ids = idsExistentes.toSet();
    return EstadoRepaso({
      for (final MapEntry(key: id, value: estado) in porHallazgo.entries)
        if (ids.contains(id)) id: estado,
    });
  }

  String aJson() => jsonEncode({
        for (final MapEntry(key: id, value: estado) in porHallazgo.entries)
          '$id': {'caja': estado.caja, 'proximo_ms': estado.proximoRepasoMs},
      });

  /// Lee el JSON guardado; si está mal, empieza de cero (y lo que esté mal en
  /// una entrada solo descarta esa entrada).
  static EstadoRepaso desdeJson(String? texto) {
    if (texto == null || texto.isEmpty) return vacio;
    Object? crudo;
    try {
      crudo = jsonDecode(texto);
    } catch (_) {
      return vacio;
    }
    if (crudo is! Map) return vacio;
    final porHallazgo = <int, EstadoTarjeta>{};
    for (final MapEntry(key: clave, value: valor) in crudo.entries) {
      final id = int.tryParse('$clave');
      if (id == null || valor is! Map) continue;
      final caja = valor['caja'];
      final proximo = valor['proximo_ms'];
      if (caja is! int || proximo is! int || caja < 1 || caja > cajaMaxima) continue;
      porHallazgo[id] = EstadoTarjeta(caja: caja, proximoRepasoMs: proximo);
    }
    return EstadoRepaso(porHallazgo);
  }
}

/// Tarjetas de una ronda: primero las que tocan (las más atrasadas antes; a
/// igualdad, las de caja más baja), hasta [maximo]. Con [aunqueNoToquen],
/// si faltan se completan con las que toquen antes.
List<TarjetaSonido> tarjetasParaRonda(
  List<TarjetaSonido> tarjetas,
  EstadoRepaso estado,
  DateTime ahora, {
  int maximo = tarjetasPorRonda,
  bool aunqueNoToquen = false,
  Random? azar,
}) {
  final barajadas = [...tarjetas]..shuffle(azar ?? Random());
  int comparar(TarjetaSonido a, TarjetaSonido b) {
    final estadoA = estado.estadoDe(a.idHallazgo);
    final estadoB = estado.estadoDe(b.idHallazgo);
    final porFecha = estadoA.proximoRepasoMs.compareTo(estadoB.proximoRepasoMs);
    if (porFecha != 0) return porFecha;
    return estadoA.caja.compareTo(estadoB.caja);
  }

  final pendientes = [
    for (final tarjeta in barajadas)
      if (estado.tocaRepasar(tarjeta.idHallazgo, ahora)) tarjeta,
  ]..sort(comparar);
  final ronda = pendientes.take(maximo).toList();
  if (aunqueNoToquen && ronda.length < maximo) {
    final resto = [
      for (final tarjeta in barajadas)
        if (!estado.tocaRepasar(tarjeta.idHallazgo, ahora)) tarjeta,
    ]..sort(comparar);
    ronda.addAll(resto.take(maximo - ronda.length));
  }
  return ronda;
}

/// Cuántas tarjetas tocan ya.
int tarjetasPendientes(Iterable<TarjetaSonido> tarjetas, EstadoRepaso estado, DateTime ahora) =>
    tarjetas.where((tarjeta) => estado.tocaRepasar(tarjeta.idHallazgo, ahora)).length;
