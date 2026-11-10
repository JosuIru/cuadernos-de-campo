import '../modelos/hallazgo.dart';

/// «Tu calendario de primeras veces»: la primera observación de cada especie
/// en cada año, sacada de los hallazgos de la persona, y la comparación entre
/// años («el año pasado, 10 días más tarde»).
///
/// Lógica pura (sin BD ni Flutter): recibe la lista de hallazgos.

/// Especie de un hallazgo para contar primeras veces.
class EspecieDeHallazgo {
  /// Clave estable: `cientifico:<género especie>` o `comun:<nombre>`.
  final String clave;

  /// Nombre científico tal como se escribió (vacío si no hay).
  final String nombreCientifico;
  final String nombreComun;

  const EspecieDeHallazgo({required this.clave, required this.nombreCientifico, required this.nombreComun});
}

String _sinTildes(String texto) {
  const conTilde = 'áàäâéèëêíìïîóòöôúùüûñç';
  const sinTilde = 'aaaaeeeeiiiioooouuuunc';
  final resultado = StringBuffer();
  for (final caracter in texto.split('')) {
    final posicion = conTilde.indexOf(caracter);
    resultado.write(posicion < 0 ? caracter : sinTilde[posicion]);
  }
  return resultado.toString();
}

/// Nombre científico normalizado: minúsculas, `_` como espacio, espacios
/// simples y solo género y especie (una subespecie cuenta como su especie).
String normalizarNombreCientifico(String nombre) {
  final palabras = nombre.replaceAll('_', ' ').trim().toLowerCase().split(RegExp(r'\s+'))
    ..removeWhere((palabra) => palabra.isEmpty);
  return palabras.take(2).join(' ');
}

/// Nombre común normalizado: minúsculas, sin tildes y espacios simples.
String normalizarNombreComun(String nombre) =>
    _sinTildes(nombre.trim().toLowerCase()).replaceAll(RegExp(r'\s+'), ' ');

/// Especie de un hallazgo, o null si no tiene ni nombre científico ni común.
///
/// - Si la identificación se corrigió, cuenta la especie corregida.
/// - Sin nombre científico se usa el común; [cientificoPorNombreComun] (p. ej.
///   la guía) puede traducirlo para que «cuco» y *Cuculus canorus* cuenten
///   como la misma especie.
EspecieDeHallazgo? especieDeHallazgo(
  Hallazgo hallazgo, {
  String? Function(String nombreComun)? cientificoPorNombreComun,
}) {
  var cientifico = hallazgo.especie.trim();
  if (hallazgo.identificacionValidada == EstadoIdentificacion.corregida &&
      hallazgo.especieCorregida.trim().isNotEmpty) {
    cientifico = hallazgo.especieCorregida.trim();
  }
  final comun = hallazgo.nombreComun.trim();
  if (cientifico.isEmpty && comun.isNotEmpty && cientificoPorNombreComun != null) {
    cientifico = cientificoPorNombreComun(comun)?.trim() ?? '';
  }
  final cientificoNormalizado = normalizarNombreCientifico(cientifico);
  if (cientificoNormalizado.isNotEmpty) {
    return EspecieDeHallazgo(
      clave: 'cientifico:$cientificoNormalizado',
      nombreCientifico: cientifico.replaceAll('_', ' '),
      nombreComun: comun,
    );
  }
  final comunNormalizado = normalizarNombreComun(comun);
  if (comunNormalizado.isEmpty) return null;
  return EspecieDeHallazgo(clave: 'comun:$comunNormalizado', nombreCientifico: '', nombreComun: comun);
}

/// La primera vez de una especie en un año.
class PrimeraVez {
  final String claveEspecie;
  final String nombreCientifico;
  final String nombreComun;
  final String categoria;
  final int anio;

  /// Fecha local del hallazgo.
  final DateTime fecha;
  final int? idHallazgo;

  const PrimeraVez({
    required this.claveEspecie,
    required this.nombreCientifico,
    required this.nombreComun,
    required this.categoria,
    required this.anio,
    required this.fecha,
    this.idHallazgo,
  });
}

/// Las primeras veces de una especie, por año.
class PrimerasVecesEspecie {
  final String claveEspecie;
  final Map<int, PrimeraVez> porAnio;

  const PrimerasVecesEspecie({required this.claveEspecie, required this.porAnio});

  /// Nombre más reciente con que se anotó (el de la última primera vez).
  PrimeraVez get masReciente => porAnio[porAnio.keys.reduce((a, b) => a > b ? a : b)]!;
}

bool _esAnterior(Hallazgo candidato, Hallazgo actual) {
  if (candidato.fechaMs != actual.fechaMs) return candidato.fechaMs < actual.fechaMs;
  // Misma hora exacta: gana el que se guardó antes (id menor).
  return (candidato.id ?? 1 << 62) < (actual.id ?? 1 << 62);
}

/// Primeras veces de cada especie y año. Los hallazgos sin especie no
/// cuentan. Varias observaciones el mismo día: la de hora más temprana.
Map<String, PrimerasVecesEspecie> calcularPrimerasVeces(
  Iterable<Hallazgo> hallazgos, {
  String? Function(String nombreComun)? cientificoPorNombreComun,
}) {
  final mejorPorEspecieYAnio = <String, Map<int, (Hallazgo, EspecieDeHallazgo)>>{};
  for (final hallazgo in hallazgos) {
    final especie = especieDeHallazgo(hallazgo, cientificoPorNombreComun: cientificoPorNombreComun);
    if (especie == null) continue;
    final anio = DateTime.fromMillisecondsSinceEpoch(hallazgo.fechaMs).year;
    final porAnio = mejorPorEspecieYAnio.putIfAbsent(especie.clave, () => {});
    final actual = porAnio[anio];
    if (actual == null || _esAnterior(hallazgo, actual.$1)) porAnio[anio] = (hallazgo, especie);
  }
  return {
    for (final MapEntry(key: clave, value: porAnio) in mejorPorEspecieYAnio.entries)
      clave: PrimerasVecesEspecie(claveEspecie: clave, porAnio: {
        for (final MapEntry(key: anio, value: (hallazgo, especie)) in porAnio.entries)
          anio: PrimeraVez(
            claveEspecie: clave,
            nombreCientifico: especie.nombreCientifico,
            nombreComun: especie.nombreComun,
            categoria: hallazgo.categoria,
            anio: anio,
            fecha: DateTime.fromMillisecondsSinceEpoch(hallazgo.fechaMs),
            idHallazgo: hallazgo.id,
          ),
      }),
  };
}

/// Primeras veces de un año, de la más temprana a la más tardía.
List<PrimeraVez> primerasVecesDelAnio(Map<String, PrimerasVecesEspecie> primerasVeces, int anio) {
  final delAnio = [
    for (final especie in primerasVeces.values)
      if (especie.porAnio[anio] case final primeraVez?) primeraVez,
  ]..sort((a, b) => a.fecha.compareTo(b.fecha));
  return delAnio;
}

/// Años con alguna primera vez, del más reciente al más antiguo.
List<int> aniosConPrimerasVeces(Map<String, PrimerasVecesEspecie> primerasVeces) {
  final anios = <int>{for (final especie in primerasVeces.values) ...especie.porAnio.keys}.toList()
    ..sort((a, b) => b.compareTo(a));
  return anios;
}

/// Comparación con un año anterior.
class ComparacionPrimeraVez {
  /// Año con el que se compara (el anterior más cercano con datos; puede no
  /// ser el inmediatamente anterior).
  final int anioAnterior;
  final DateTime fechaAnterior;

  /// Días de diferencia en el calendario: negativo = este año antes
  /// (adelanto); positivo = más tarde (retraso); 0 = el mismo día.
  final int diasDiferencia;

  const ComparacionPrimeraVez({required this.anioAnterior, required this.fechaAnterior, required this.diasDiferencia});

  bool get esAdelanto => diasDiferencia < 0;
  bool get esRetraso => diasDiferencia > 0;
}

/// Días entre dos fechas en el calendario, sin contar el año: se lleva
/// [anterior] al año de [actual] (el 29 de febrero pasa al 1 de marzo en un
/// año no bisiesto) y se cuentan días naturales (sin horas ni cambio de hora).
int diasDeDiferenciaEnElCalendario(DateTime actual, DateTime anterior) {
  final actualSoloDia = DateTime.utc(actual.year, actual.month, actual.day);
  final anteriorTrasladado = DateTime.utc(actual.year, anterior.month, anterior.day);
  return actualSoloDia.difference(anteriorTrasladado).inDays;
}

/// Compara la primera vez de [anio] con la del año anterior más cercano que
/// tenga datos. Null si no hay primera vez ese año o ninguna anterior.
ComparacionPrimeraVez? compararConAnioAnterior(PrimerasVecesEspecie especie, int anio) {
  final actual = especie.porAnio[anio];
  if (actual == null) return null;
  final anteriores = especie.porAnio.keys.where((otro) => otro < anio).toList();
  if (anteriores.isEmpty) return null;
  final anioAnterior = anteriores.reduce((a, b) => a > b ? a : b);
  final anterior = especie.porAnio[anioAnterior]!;
  return ComparacionPrimeraVez(
    anioAnterior: anioAnterior,
    fechaAnterior: anterior.fecha,
    diasDiferencia: diasDeDiferenciaEnElCalendario(actual.fecha, anterior.fecha),
  );
}

/// Resultado de mirar si un hallazgo nuevo es la primera vez del año.
class PrimeraVezNueva {
  final PrimeraVez primeraVez;
  final ComparacionPrimeraVez? comparacion;

  const PrimeraVezNueva({required this.primeraVez, this.comparacion});
}

/// Si [nuevo] (aún sin guardar) es la primera vez de su especie en su año
/// frente a [existentes], la primera vez y su comparación; si no, null.
/// Un hallazgo con fecha pasada también puede serlo (si es anterior a todos
/// los de ese año).
PrimeraVezNueva? primeraVezAlGuardar(
  Hallazgo nuevo,
  Iterable<Hallazgo> existentes, {
  String? Function(String nombreComun)? cientificoPorNombreComun,
}) {
  final especieNueva = especieDeHallazgo(nuevo, cientificoPorNombreComun: cientificoPorNombreComun);
  if (especieNueva == null) return null;
  final anio = DateTime.fromMillisecondsSinceEpoch(nuevo.fechaMs).year;
  final mismaEspecie = [
    for (final existente in existentes)
      if (existente.id == null || existente.id != nuevo.id)
        if (especieDeHallazgo(existente, cientificoPorNombreComun: cientificoPorNombreComun)?.clave ==
            especieNueva.clave)
          existente,
  ];
  final yaHabiaAntesEsteAnio = mismaEspecie.any((existente) =>
      DateTime.fromMillisecondsSinceEpoch(existente.fechaMs).year == anio && existente.fechaMs <= nuevo.fechaMs);
  if (yaHabiaAntesEsteAnio) return null;
  final todas = calcularPrimerasVeces([...mismaEspecie, nuevo], cientificoPorNombreComun: cientificoPorNombreComun);
  final primerasVeces = todas[especieNueva.clave]!;
  return PrimeraVezNueva(
    primeraVez: primerasVeces.porAnio[anio]!,
    comparacion: compararConAnioAnterior(primerasVeces, anio),
  );
}
