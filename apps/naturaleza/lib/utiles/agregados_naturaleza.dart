import '../modelos/hallazgo.dart';

// ─── Fenología ──────────────────────────────────────────────────────

/// Primer avistamiento del año para una especie. La fecha lleva
/// también [fechaMs] para poder formatear con la zona horaria local
/// al renderizar.
class PrimerAvistamientoAnual {
  final int anio;
  final int diaDelAnio;
  final int fechaMs;

  const PrimerAvistamientoAnual({
    required this.anio,
    required this.diaDelAnio,
    required this.fechaMs,
  });
}

/// Histórico fenológico de una especie: primer avistamiento de cada
/// año en que la registraste. Ordenado de más reciente a más antiguo.
class FenologiaEspecie {
  /// Clave de identificación: nombre común si no está vacío, si no
  /// nombre científico. La UI puede consultar otros campos de un
  /// hallazgo de muestra para enriquecer (taxonomía, hábitat).
  final String etiquetaPrincipal;

  /// Hallazgo más reciente con esta etiqueta — sirve a la UI para
  /// extraer especie/categoría/foto al renderizar la tarjeta.
  final Hallazgo hallazgoMuestra;

  /// Primer avistamiento de cada año. Ordenado descendiente por año.
  final List<PrimerAvistamientoAnual> primerosPorAnio;

  const FenologiaEspecie({
    required this.etiquetaPrincipal,
    required this.hallazgoMuestra,
    required this.primerosPorAnio,
  });

  /// Sólo es informativo si hay al menos 2 años distintos (comparar
  /// algo con algo).
  bool get tieneComparativa => primerosPorAnio.length >= 2;

  /// Cuánto adelanta o retrasa el primer registro del año actual
  /// respecto a la media de los anteriores, en días. Positivo =
  /// adelantado, negativo = retrasado. Null si no hay comparativa.
  int? get desviacionAnioActual {
    if (primerosPorAnio.length < 2) return null;
    final actual = primerosPorAnio.first;
    final anteriores = primerosPorAnio.skip(1).toList();
    if (anteriores.isEmpty) return null;
    final mediaAnteriores = anteriores
            .map((a) => a.diaDelAnio)
            .reduce((a, b) => a + b) /
        anteriores.length;
    // Positivo = el actual cae antes que la media → adelanto.
    return (mediaAnteriores - actual.diaDelAnio).round();
  }
}

/// Calcula la fenología por especie a partir de los hallazgos. La
/// clave de agrupación es el nombre común; si está vacío, el nombre
/// científico. Especies con menos de 2 hallazgos quedan fuera (no
/// hay nada que aportar fenológicamente).
List<FenologiaEspecie> calcularFenologia(List<Hallazgo> hallazgos) {
  final porEtiqueta = <String, List<Hallazgo>>{};
  for (final h in hallazgos) {
    final etiqueta = h.nombreComun.trim().isNotEmpty
        ? h.nombreComun.trim()
        : h.especie.trim();
    if (etiqueta.isEmpty) continue;
    porEtiqueta.putIfAbsent(etiqueta, () => <Hallazgo>[]).add(h);
  }

  final resultado = <FenologiaEspecie>[];
  for (final entrada in porEtiqueta.entries) {
    final lista = entrada.value;
    if (lista.length < 2) continue;

    // Primer avistamiento de cada año natural.
    final primerosPorAnio = <int, Hallazgo>{};
    for (final h in lista) {
      final fecha = DateTime.fromMillisecondsSinceEpoch(h.fechaMs);
      final anio = fecha.year;
      final actual = primerosPorAnio[anio];
      if (actual == null || h.fechaMs < actual.fechaMs) {
        primerosPorAnio[anio] = h;
      }
    }

    // Si todo cayó en un único año, no hay fenología que mostrar.
    if (primerosPorAnio.length < 2) continue;

    final anios = primerosPorAnio.keys.toList()..sort((a, b) => b - a);
    final primerosOrdenados = anios.map((anio) {
      final h = primerosPorAnio[anio]!;
      final fecha = DateTime.fromMillisecondsSinceEpoch(h.fechaMs);
      return PrimerAvistamientoAnual(
        anio: anio,
        diaDelAnio: _diaDelAnio(fecha),
        fechaMs: h.fechaMs,
      );
    }).toList();

    // Muestra: el más reciente — la UI puede tirar de su foto o
    // taxonomía si tiene.
    lista.sort((a, b) => b.fechaMs.compareTo(a.fechaMs));
    final hallazgoMuestra = lista.first;

    resultado.add(FenologiaEspecie(
      etiquetaPrincipal: entrada.key,
      hallazgoMuestra: hallazgoMuestra,
      primerosPorAnio: primerosOrdenados,
    ));
  }

  // Orden: las que tienen comparativa de año actual primero (más
  // interés), después las históricas. Dentro de cada grupo,
  // alfabético.
  resultado.sort((a, b) {
    final anioActual = DateTime.now().year;
    final aTieneActual = a.primerosPorAnio.first.anio == anioActual;
    final bTieneActual = b.primerosPorAnio.first.anio == anioActual;
    if (aTieneActual != bTieneActual) {
      return aTieneActual ? -1 : 1;
    }
    return a.etiquetaPrincipal
        .toLowerCase()
        .compareTo(b.etiquetaPrincipal.toLowerCase());
  });

  return resultado;
}

/// Día del año (1..365 o 1..366 en bisiestos). Cálculo aritmético
/// para no depender de `DateTime.difference`, que cuenta segundos y
/// se desfasa por cambios de huso horario (CEST/CET en primavera).
int _diaDelAnio(DateTime fecha) {
  const diasPorMesNoBisiesto = [
    31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31
  ];
  var total = 0;
  for (var mes = 1; mes < fecha.month; mes++) {
    total += diasPorMesNoBisiesto[mes - 1];
    if (mes == 2 && _esBisiesto(fecha.year)) total += 1;
  }
  return total + fecha.day;
}

bool _esBisiesto(int anio) =>
    (anio % 4 == 0 && anio % 100 != 0) || (anio % 400 == 0);

// ─── Tasa de acierto ────────────────────────────────────────────────

class DesgloseTasa {
  /// Hallazgos validados por el usuario (confirmados o corregidos).
  /// El total revisado excluye los `sinRevisar`.
  final int totalRevisado;
  final int confirmados;
  final int corregidos;

  const DesgloseTasa({
    required this.totalRevisado,
    required this.confirmados,
    required this.corregidos,
  });

  /// Porcentaje de acierto: confirmados / totalRevisado. 0..1. Si el
  /// total es 0, devuelve null (no hay base para calcular).
  double? get porcentajeAcierto {
    if (totalRevisado == 0) return null;
    return confirmados / totalRevisado;
  }
}

class TasaAcierto {
  /// Total de hallazgos sin revisar (no entran en cálculos pero los
  /// mostramos para que el usuario sepa cuánto trabajo de validación
  /// le queda).
  final int sinRevisar;
  final DesgloseTasa global;

  /// Desglose por categoría (animal, insecto, planta…). Clave =
  /// `Hallazgo.categoria` (texto crudo).
  final Map<String, DesgloseTasa> porCategoria;

  /// Calibración: ¿cuando dices "segura" aciertas más que cuando
  /// dices "tentativa"? Clave = una de
  /// `ConfianzaIdentificacion.segura/probable/tentativa`. Hallazgos
  /// sin confianza marcada quedan fuera.
  final Map<String, DesgloseTasa> porConfianza;

  const TasaAcierto({
    required this.sinRevisar,
    required this.global,
    required this.porCategoria,
    required this.porConfianza,
  });

  /// True si hay algo medible. La UI usa esto para decidir si
  /// mostrar contenido o vista vacía.
  bool get tieneDatos => global.totalRevisado > 0;
}

/// Calcula la tasa de acierto agregada sobre la lista de hallazgos.
/// Hallazgos con `identificacionValidada == sinRevisar` no entran en
/// la tasa pero se contabilizan en [TasaAcierto.sinRevisar].
TasaAcierto calcularTasaAcierto(List<Hallazgo> hallazgos) {
  int sinRevisarTotal = 0;
  int totalRevisado = 0;
  int confirmados = 0;
  int corregidos = 0;
  final acumuladorCategoria = <String, _Acumulador>{};
  final acumuladorConfianza = <String, _Acumulador>{};

  for (final h in hallazgos) {
    if (h.identificacionValidada == EstadoIdentificacion.sinRevisar) {
      sinRevisarTotal++;
      continue;
    }
    final esConfirmado =
        h.identificacionValidada == EstadoIdentificacion.confirmada;
    totalRevisado++;
    if (esConfirmado) confirmados++;
    if (h.identificacionValidada == EstadoIdentificacion.corregida) {
      corregidos++;
    }
    final acumCategoria = acumuladorCategoria.putIfAbsent(
        h.categoria, () => _Acumulador());
    acumCategoria.acumular(esConfirmado: esConfirmado);
    final confianza = h.confianzaIdentificacion;
    if (confianza != null && confianza.isNotEmpty) {
      final acumConfianza =
          acumuladorConfianza.putIfAbsent(confianza, () => _Acumulador());
      acumConfianza.acumular(esConfirmado: esConfirmado);
    }
  }

  return TasaAcierto(
    sinRevisar: sinRevisarTotal,
    global: DesgloseTasa(
      totalRevisado: totalRevisado,
      confirmados: confirmados,
      corregidos: corregidos,
    ),
    porCategoria: {
      for (final entrada in acumuladorCategoria.entries)
        entrada.key: entrada.value.aDesglose(),
    },
    porConfianza: {
      for (final entrada in acumuladorConfianza.entries)
        entrada.key: entrada.value.aDesglose(),
    },
  );
}

class _Acumulador {
  int total = 0;
  int confirmados = 0;

  void acumular({required bool esConfirmado}) {
    total++;
    if (esConfirmado) confirmados++;
  }

  DesgloseTasa aDesglose() => DesgloseTasa(
        totalRevisado: total,
        confirmados: confirmados,
        corregidos: total - confirmados,
      );
}
