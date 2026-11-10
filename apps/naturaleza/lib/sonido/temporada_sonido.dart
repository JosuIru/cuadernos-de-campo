import 'filtro_ocurrencia.dart';

/// «Cuándo y dónde suele cantar»: a partir del mismo fichero de presencia por
/// lugar y época que usa el filtro de «¿Quién canta?»
/// (`fauna-occurrence-*.json`, de GBIF, ya descargado con el modelo): los
/// meses con actividad y si hay registros en la celda de la persona. Sin
/// consultas nuevas.

enum PresenciaEnZona {
  /// Sin ubicación: no se puede decir.
  sinUbicacion,

  /// La ubicación cae fuera de la rejilla del fichero.
  fueraDeRejilla,

  /// La celda no tiene datos de ninguna especie.
  celdaSinDatos,

  /// La especie tiene registros en la celda.
  registrada,

  /// La celda tiene datos, pero no de esta especie.
  sinRegistros,
}

class TemporadaSonido {
  /// Actividad relativa (0-100) de enero a diciembre; null si el fichero no
  /// la trae para esta especie.
  final List<double>? actividadMensual;

  /// Meses (1-12) en los que se espera oírla: actividad ≥
  /// [umbralActividadTemporada], el mismo umbral que el filtro usa para
  /// «fuera de temporada».
  final List<int> mesesEsperados;

  /// Meses (1-12) de más actividad (≥ 50 % del máximo).
  final List<int> mesesDeMasActividad;

  final PresenciaEnZona presencia;

  const TemporadaSonido({
    required this.actividadMensual,
    required this.mesesEsperados,
    required this.mesesDeMasActividad,
    required this.presencia,
  });

  /// Si hay algo que enseñar.
  bool get tieneDatos => actividadMensual != null || presencia == PresenciaEnZona.registrada || presencia == PresenciaEnZona.sinRegistros;
}

bool _bitDeEspecie(DatosOcurrencia datos, String claveCelda, int indiceBit) {
  final bitset = datos.bitsetPorCelda[claveCelda];
  if (bitset == null) return false;
  final indiceByte = indiceBit >> 3;
  if (indiceByte >= bitset.length) return false;
  return (bitset[indiceByte] & (1 << (indiceBit & 7))) != 0;
}

/// Temporada de [etiquetaEspecie] (nombre científico del modelo) y, si se da
/// la ubicación aproximada, su presencia en esa celda. Null si la especie no
/// está en el fichero.
TemporadaSonido? temporadaSonidoDe(
  DatosOcurrencia datos,
  String etiquetaEspecie, {
  double? latitud,
  double? longitud,
}) {
  final indiceBit = datos.indiceBitPorEspecie[etiquetaEspecie];
  final actividad = datos.actividadMensualPorEspecie[etiquetaEspecie];
  if (indiceBit == null && actividad == null) return null;
  var presencia = PresenciaEnZona.sinUbicacion;
  if (latitud != null && longitud != null) {
    final claveCelda = claveCeldaPara(datos, latitud, longitud);
    if (claveCelda == null) {
      presencia = PresenciaEnZona.fueraDeRejilla;
    } else if (!datos.bitsetPorCelda.containsKey(claveCelda)) {
      presencia = PresenciaEnZona.celdaSinDatos;
    } else if (indiceBit == null) {
      // En la lista de actividad pero no en la de presencia: no se juzga.
      presencia = PresenciaEnZona.sinUbicacion;
    } else {
      presencia = _bitDeEspecie(datos, claveCelda, indiceBit) ? PresenciaEnZona.registrada : PresenciaEnZona.sinRegistros;
    }
  }
  final List<int> esperados;
  final List<int> deMasActividad;
  if (actividad == null) {
    esperados = const [];
    deMasActividad = const [];
  } else {
    final maximo = actividad.reduce((a, b) => a > b ? a : b);
    esperados = [
      for (var indice = 0; indice < actividad.length; indice++)
        if (actividad[indice] >= umbralActividadTemporada) indice + 1,
    ];
    deMasActividad = maximo <= 0
        ? const []
        : [
            for (var indice = 0; indice < actividad.length; indice++)
              if (actividad[indice] >= maximo * 0.5) indice + 1,
          ];
  }
  return TemporadaSonido(
    actividadMensual: actividad,
    mesesEsperados: esperados,
    mesesDeMasActividad: deMasActividad,
    presencia: presencia,
  );
}
