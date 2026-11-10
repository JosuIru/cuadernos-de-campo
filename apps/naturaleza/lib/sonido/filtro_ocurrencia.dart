import 'dart:convert';
import 'dart:typed_data';

import 'clasificacion_sonido.dart';
import 'manifiesto_modelo_fauna.dart';

/// Filtro por lugar y época. Portado de `occurrenceFilter.ts`.
///
/// Con los registros de presencia de cada especie en una rejilla de Europa y
/// su actividad por meses (`fauna-occurrence-*.json`, GBIF, en la release del
/// modelo), trata aparte las especies que no se han visto por la zona o que
/// casi no se oyen en este mes:
/// - Fuera de la zona: con «Solo especies de mi zona» (lo normal) se excluyen
///   del todo; si no, se penalizan con [penalizacionFueraDeZona].
/// - Fuera de temporada: siempre se penalizan con
///   [penalizacionFueraDeTemporada].
/// El top se reordena con las puntuaciones corregidas. Los sonidos generales
/// no se tocan.

/// Especie sin registros en la celda ni en sus vecinas, cuando no se excluye.
/// Con 6, solo una detección muy clara (≥ 13) llega a «posible».
const double penalizacionFueraDeZona = 6;

/// «Penalización» de una especie excluida: con infinito, su puntuación
/// corregida deja de ser finita y la ordenación la salta.
const double penalizacionEspecieExcluida = double.infinity;

/// Especie de la zona, pero en un mes en el que apenas se registra.
const double penalizacionFueraDeTemporada = 2;

/// Actividad del mes (0-100, relativa al mes de más registros) por debajo de
/// la cual se considera «rara en esta época».
const double umbralActividadTemporada = 10;

enum TratamientoFueraDeZona { excluir, penalizar }

class DatosOcurrencia {
  final double tamanoCeldaGrados;
  final double latitudMinima;
  final double longitudMinima;
  final int numeroFilas;
  final int numeroColumnas;

  /// Posición del bit de cada especie (nombre científico) en los bitsets.
  final Map<String, int> indiceBitPorEspecie;

  /// Clave «fila_columna» → bitset. Las celdas sin clave no tienen datos.
  final Map<String, Uint8List> bitsetPorCelda;

  /// Actividad relativa (0-100) de enero a diciembre.
  final Map<String, List<double>> actividadMensualPorEspecie;

  const DatosOcurrencia({
    required this.tamanoCeldaGrados,
    required this.latitudMinima,
    required this.longitudMinima,
    required this.numeroFilas,
    required this.numeroColumnas,
    required this.indiceBitPorEspecie,
    required this.bitsetPorCelda,
    required this.actividadMensualPorEspecie,
  });
}

class ErrorFormatoOcurrencia implements Exception {
  final String problema;
  const ErrorFormatoOcurrencia(this.problema);
  @override
  String toString() => 'Fichero de presencia no válido: $problema';
}

int _enteroPositivo(Map<String, dynamic> registro, String clave) {
  final valor = registro[clave];
  if (valor is! num || valor != valor.roundToDouble() || valor <= 0) {
    throw ErrorFormatoOcurrencia('«$clave» debe ser un entero positivo');
  }
  return valor.toInt();
}

double _numeroFinito(Map<String, dynamic> registro, String clave) {
  final valor = registro[clave];
  if (valor is! num || !valor.isFinite) {
    throw ErrorFormatoOcurrencia('«$clave» debe ser un número');
  }
  return valor.toDouble();
}

final _patronClaveCelda = RegExp(r'^\d+_\d+$');
final _patronBase64 = RegExp(r'^[A-Za-z0-9+/]*={0,2}$');

/// Base64 con o sin relleno final. Lanza [FormatException] si no lo es.
Uint8List decodificarBase64Flexible(String textoBase64) {
  if (!_patronBase64.hasMatch(textoBase64)) {
    throw const FormatException('Carácter base64 no válido');
  }
  final sinRelleno = textoBase64.replaceAll('=', '');
  final relleno = (4 - sinRelleno.length % 4) % 4;
  if (relleno == 3) throw const FormatException('Longitud base64 no válida');
  return base64.decode(sinRelleno + '=' * relleno);
}

/// Comprueba y tipa el JSON descargado. Lanza [ErrorFormatoOcurrencia] si no
/// encaja.
DatosOcurrencia leerDatosOcurrencia(Object? ocurrenciaCruda) {
  if (ocurrenciaCruda is! Map) throw const ErrorFormatoOcurrencia('no es un objeto');
  final registro = ocurrenciaCruda.cast<String, dynamic>();
  if (registro['formatVersion'] != 1) {
    throw ErrorFormatoOcurrencia('versión de formato ${registro['formatVersion']} no admitida');
  }
  final tamanoCelda = _numeroFinito(registro, 'cellSizeDegrees');
  if (tamanoCelda <= 0) throw const ErrorFormatoOcurrencia('«cellSizeDegrees» debe ser positivo');
  final etiquetasCrudas = registro['speciesLabels'];
  if (etiquetasCrudas is! List || !etiquetasCrudas.every((etiqueta) => etiqueta is String)) {
    throw const ErrorFormatoOcurrencia('«speciesLabels» debe ser una lista de textos');
  }
  final indiceBitPorEspecie = <String, int>{
    for (final (indiceBit, etiqueta) in etiquetasCrudas.cast<String>().indexed) etiqueta: indiceBit,
  };

  final celdasCrudas = registro['cells'];
  if (celdasCrudas is! Map) throw const ErrorFormatoOcurrencia('faltan las celdas');
  final bitsetPorCelda = <String, Uint8List>{};
  for (final MapEntry(key: claveCelda, value: bitsetCodificado) in celdasCrudas.entries) {
    if (claveCelda is! String || !_patronClaveCelda.hasMatch(claveCelda) || bitsetCodificado is! String) {
      throw ErrorFormatoOcurrencia('celda «$claveCelda» mal formada');
    }
    try {
      bitsetPorCelda[claveCelda] = decodificarBase64Flexible(bitsetCodificado);
    } on FormatException {
      throw ErrorFormatoOcurrencia('la celda «$claveCelda» no está en base64');
    }
  }

  final actividadMensual = <String, List<double>>{};
  final actividadCruda = registro['monthlyActivity'];
  if (actividadCruda is Map) {
    for (final MapEntry(key: especie, value: valoresMes) in actividadCruda.entries) {
      // Una especie con la actividad mal escrita se queda sin filtro de
      // época; no invalida el resto.
      if (especie is String &&
          valoresMes is List &&
          valoresMes.length == 12 &&
          valoresMes.every((valor) => valor is num && valor.isFinite)) {
        actividadMensual[especie] = [for (final valor in valoresMes) (valor as num).toDouble()];
      }
    }
  }

  return DatosOcurrencia(
    tamanoCeldaGrados: tamanoCelda,
    latitudMinima: _numeroFinito(registro, 'latitudeMin'),
    longitudMinima: _numeroFinito(registro, 'longitudeMin'),
    numeroFilas: _enteroPositivo(registro, 'rows'),
    numeroColumnas: _enteroPositivo(registro, 'columns'),
    indiceBitPorEspecie: indiceBitPorEspecie,
    bitsetPorCelda: bitsetPorCelda,
    actividadMensualPorEspecie: actividadMensual,
  );
}

/// Clave «fila_columna» de la celda que contiene el punto, o `null` si cae
/// fuera de la rejilla.
String? claveCeldaPara(DatosOcurrencia datos, double latitud, double longitud) {
  final filaReal = (latitud - datos.latitudMinima) / datos.tamanoCeldaGrados;
  final columnaReal = (longitud - datos.longitudMinima) / datos.tamanoCeldaGrados;
  if (!filaReal.isFinite || !columnaReal.isFinite) return null;
  final fila = filaReal.floor();
  final columna = columnaReal.floor();
  if (fila < 0 || fila >= datos.numeroFilas) return null;
  if (columna < 0 || columna >= datos.numeroColumnas) return null;
  return '${fila}_$columna';
}

enum EstadoContextoOcurrencia { activo, fueraDeRejilla, celdaSinDatos }

/// Dónde y cuándo se escucha, ya resuelto contra la rejilla.
class ContextoOcurrencia {
  final EstadoContextoOcurrencia estado;
  final String? claveCelda;
  final Uint8List? bitsetCelda;

  /// 0 = enero … 11 = diciembre.
  final int indiceMes;

  const ContextoOcurrencia._(this.estado, this.claveCelda, this.bitsetCelda, this.indiceMes);
}

ContextoOcurrencia contextoOcurrenciaPara(
  DatosOcurrencia datos,
  double latitud,
  double longitud,
  int indiceMes,
) {
  final claveCelda = claveCeldaPara(datos, latitud, longitud);
  if (claveCelda == null) {
    return ContextoOcurrencia._(EstadoContextoOcurrencia.fueraDeRejilla, null, null, indiceMes);
  }
  final bitset = datos.bitsetPorCelda[claveCelda];
  if (bitset == null) {
    return ContextoOcurrencia._(EstadoContextoOcurrencia.celdaSinDatos, claveCelda, null, indiceMes);
  }
  return ContextoOcurrencia._(EstadoContextoOcurrencia.activo, claveCelda, bitset, indiceMes);
}

bool _bitActivo(Uint8List bitset, int indiceBit) {
  final indiceByte = indiceBit >> 3;
  // Un bitset más corto que la lista de especies: los bits que faltan
  // cuentan como 0.
  if (indiceByte >= bitset.length) return false;
  return (bitset[indiceByte] & (1 << (indiceBit & 7))) != 0;
}

/// Cómo de plausible es oír esta especie aquí y ahora. Una especie que no
/// está en el fichero no se juzga (no hay datos para decir que no está).
PlausibilidadEspecie plausibilidadEspecie(
  DatosOcurrencia datos,
  ContextoOcurrencia contexto,
  String etiquetaEspecie,
) {
  if (contexto.estado != EstadoContextoOcurrencia.activo) return PlausibilidadEspecie.plausible;
  final indiceBit = datos.indiceBitPorEspecie[etiquetaEspecie];
  final esImprobableAqui = indiceBit != null && !_bitActivo(contexto.bitsetCelda!, indiceBit);
  final actividadMensual = datos.actividadMensualPorEspecie[etiquetaEspecie];
  final actividadMes = actividadMensual?[contexto.indiceMes];
  final esFueraDeTemporada = actividadMes != null && actividadMes < umbralActividadTemporada;
  return PlausibilidadEspecie(
    esImprobableAqui: esImprobableAqui,
    esFueraDeTemporada: esFueraDeTemporada,
  );
}

double penalizacionPorPlausibilidad(
  PlausibilidadEspecie plausibilidad, {
  TratamientoFueraDeZona tratamiento = TratamientoFueraDeZona.penalizar,
}) {
  if (plausibilidad.esImprobableAqui && tratamiento == TratamientoFueraDeZona.excluir) {
    return penalizacionEspecieExcluida;
  }
  return (plausibilidad.esImprobableAqui ? penalizacionFueraDeZona : 0) +
      (plausibilidad.esFueraDeTemporada ? penalizacionFueraDeTemporada : 0);
}

/// Penalización de cada clase del modelo (mismo orden que los logits).
class PenalizacionesClases {
  final Float64List penalizacionPorClase;
  final Map<int, PlausibilidadEspecie> plausibilidadPorClase;

  /// Especies excluidas por no ser de la zona (solo con
  /// [TratamientoFueraDeZona.excluir]).
  final int clasesExcluidas;

  /// Especies penalizadas, sin contar las excluidas.
  final int clasesPenalizadas;

  const PenalizacionesClases({
    required this.penalizacionPorClase,
    required this.plausibilidadPorClase,
    required this.clasesExcluidas,
    required this.clasesPenalizadas,
  });
}

/// Calcula de una vez la penalización de todas las clases para un lugar y un
/// mes (se recalcula solo cuando cambian), así cada trozo solo tiene que
/// restar.
PenalizacionesClases calcularPenalizacionesClases(
  DatosOcurrencia datos,
  ContextoOcurrencia contexto,
  List<ClaseSonido> clases, {
  TratamientoFueraDeZona tratamiento = TratamientoFueraDeZona.penalizar,
}) {
  final penalizaciones = Float64List(clases.length);
  final plausibilidades = <int, PlausibilidadEspecie>{};
  var excluidas = 0;
  for (final (indiceClase, clase) in clases.indexed) {
    if (!clase.esEspecie) continue;
    final plausibilidad = plausibilidadEspecie(datos, contexto, clase.etiqueta);
    final penalizacion = penalizacionPorPlausibilidad(plausibilidad, tratamiento: tratamiento);
    if (penalizacion == 0) continue;
    if (penalizacion == penalizacionEspecieExcluida) excluidas++;
    penalizaciones[indiceClase] = penalizacion;
    plausibilidades[indiceClase] = plausibilidad;
  }
  return PenalizacionesClases(
    penalizacionPorClase: penalizaciones,
    plausibilidadPorClase: plausibilidades,
    clasesExcluidas: excluidas,
    clasesPenalizadas: plausibilidades.length - excluidas,
  );
}

/// Las [numeroResultados] mejores clases tras restar las penalizaciones (las
/// excluidas no aparecen). Con [penalizaciones] = null (filtro apagado) es
/// igual que ordenar por la puntuación del modelo.
List<ClaseClasificada> clasificarConPenalizaciones(
  List<double> logits,
  PenalizacionesClases? penalizaciones,
  int numeroResultados,
) {
  if (numeroResultados <= 0) return const [];
  final clasificadas = <ClaseClasificada>[];
  for (var indiceClase = 0; indiceClase < logits.length; indiceClase++) {
    final puntuacionModelo = logits[indiceClase];
    final penalizacion = penalizaciones != null &&
            indiceClase < penalizaciones.penalizacionPorClase.length
        ? penalizaciones.penalizacionPorClase[indiceClase]
        : 0.0;
    final puntuacionCorregida = puntuacionModelo - penalizacion;
    if (!puntuacionCorregida.isFinite) continue;
    if (clasificadas.length == numeroResultados &&
        puntuacionCorregida <= clasificadas.last.puntuacion) {
      continue;
    }
    if (clasificadas.length == numeroResultados) clasificadas.removeLast();
    clasificadas.add(ClaseClasificada(
      indiceClase: indiceClase,
      puntuacion: puntuacionCorregida,
      puntuacionModelo: puntuacionModelo,
      plausibilidad: penalizaciones?.plausibilidadPorClase[indiceClase],
    ));
    clasificadas.sort((a, b) => b.puntuacion.compareTo(a.puntuacion));
  }
  return clasificadas;
}

/// Coordenada redondeada a 0,01° (≈1 km): basta para el filtro y no
/// guarda dónde está exactamente la persona.
double redondearCoordenada(double grados) => (grados * 100).roundToDouble() / 100;
