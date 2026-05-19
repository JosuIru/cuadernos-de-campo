// Tabla cronoestratigráfica simplificada (ICS v2023) en millones de años (Ma).
// Cubre principalmente Mesozoico–Cenozoico, los pisos relevantes para la península ibérica.

class RangoMa {
  final double inicioMa;
  final double finMa;
  const RangoMa(this.inicioMa, this.finMa)
      : assert(inicioMa >= finMa, 'inicioMa debe ser >= finMa (más antiguo primero)');

  /// Solapa dos rangos. Si los rangos son disjuntos (no se tocan)
  /// devuelve null — antes una unión por max(inicios)/min(fines)
  /// producía rangos invertidos al combinar pisos sin solape.
  RangoMa? unirSiSolapan(RangoMa otro) {
    final solapan = inicioMa >= otro.finMa && otro.inicioMa >= finMa;
    if (!solapan) return null;
    final nuevoInicio = inicioMa > otro.inicioMa ? inicioMa : otro.inicioMa;
    final nuevoFin = finMa < otro.finMa ? finMa : otro.finMa;
    return RangoMa(nuevoInicio, nuevoFin);
  }

  String formatear() {
    String fmt(double v) {
      if (v == 0) return '0';
      if (v < 1) return v.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
      if (v < 10) return v.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
      return v.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
    }
    return '${fmt(inicioMa)} – ${fmt(finMa)} Ma';
  }
}

const Map<String, RangoMa> _pisos = {
  // Triásico
  'induense': RangoMa(251.9, 247.2),
  'olenekiense': RangoMa(251.9, 247.2),
  'anisiense': RangoMa(247.2, 242),
  'ladiniense': RangoMa(242, 237),
  'carniense': RangoMa(237, 227),
  'noriense': RangoMa(227, 208.5),
  'retiense': RangoMa(208.5, 201.4),
  'rhetiense': RangoMa(208.5, 201.4),
  'triasico inferior': RangoMa(251.9, 247.2),
  'triasico medio': RangoMa(247.2, 237),
  'triasico superior': RangoMa(237, 201.4),
  'triasico': RangoMa(251.9, 201.4),
  'muschelkalk': RangoMa(247.2, 235),
  'keuper': RangoMa(237, 201.4),
  'buntsandstein': RangoMa(251.9, 247.2),

  // Jurásico
  'hettangiense': RangoMa(201.4, 199.5),
  'sinemuriense': RangoMa(199.5, 192.9),
  'pliensbachiense': RangoMa(192.9, 184.2),
  'toarciense': RangoMa(184.2, 174.7),
  'aaleniense': RangoMa(174.7, 170.9),
  'bajociense': RangoMa(170.9, 168.2),
  'bathoniense': RangoMa(168.2, 165.3),
  'calloviense': RangoMa(165.3, 161.5),
  'oxfordiense': RangoMa(161.5, 154.8),
  'kimmeridgiense': RangoMa(154.8, 149.2),
  'tithoniense': RangoMa(149.2, 145),
  'titoniense': RangoMa(149.2, 145),
  'portlandiense': RangoMa(149.2, 145),
  'jurasico inferior': RangoMa(201.4, 174.7),
  'jurasico medio': RangoMa(174.7, 161.5),
  'jurasico superior': RangoMa(161.5, 145),
  'lias': RangoMa(201.4, 174.7),
  'dogger': RangoMa(174.7, 161.5),
  'malm': RangoMa(161.5, 145),
  'jurasico': RangoMa(201.4, 145),

  // Cretácico Inferior
  'berriasiense': RangoMa(145, 139.8),
  'valanginiense': RangoMa(139.8, 132.6),
  'hauteriviense': RangoMa(132.6, 125.77),
  'barremiense': RangoMa(125.77, 121.4),
  'aptiense': RangoMa(121.4, 113),
  'albiense': RangoMa(113, 100.5),
  'cretacico inferior': RangoMa(145, 100.5),
  'urgoniano': RangoMa(125.77, 100.5),
  'urgoniense': RangoMa(125.77, 100.5),
  'weald': RangoMa(145, 125.77),
  'wealdense': RangoMa(145, 125.77),
  'wealdiense': RangoMa(145, 125.77),

  // Cretácico Superior
  'cenomaniense': RangoMa(100.5, 93.9),
  'turoniense': RangoMa(93.9, 89.8),
  'coniaciense': RangoMa(89.8, 86.3),
  'santoniense': RangoMa(86.3, 83.6),
  'campaniense': RangoMa(83.6, 72.1),
  'maastrichtiense': RangoMa(72.1, 66),
  'cretacico superior': RangoMa(100.5, 66),
  'cretacico': RangoMa(145, 66),
  'flysch cretacico': RangoMa(100.5, 66),

  // Paleoceno
  'daniense': RangoMa(66, 61.6),
  'selandiense': RangoMa(61.6, 59.2),
  'thanetiense': RangoMa(59.2, 56),
  'paleoceno': RangoMa(66, 56),

  // Eoceno
  'ypresiense': RangoMa(56, 47.8),
  'lutetiense': RangoMa(47.8, 41.2),
  'bartoniense': RangoMa(41.2, 37.71),
  'priaboniense': RangoMa(37.71, 33.9),
  'eoceno': RangoMa(56, 33.9),
  'eoceno inferior': RangoMa(56, 47.8),
  'eoceno medio': RangoMa(47.8, 37.71),
  'eoceno superior': RangoMa(37.71, 33.9),

  // Oligoceno
  'rupeliense': RangoMa(33.9, 27.82),
  'chattiense': RangoMa(27.82, 23.03),
  'oligoceno': RangoMa(33.9, 23.03),

  // Mioceno
  'aquitaniense': RangoMa(23.03, 20.44),
  'burdigaliense': RangoMa(20.44, 15.97),
  'langhiense': RangoMa(15.97, 13.82),
  'serravalliense': RangoMa(13.82, 11.63),
  'tortoniense': RangoMa(11.63, 7.246),
  'messiniense': RangoMa(7.246, 5.333),
  'mioceno': RangoMa(23.03, 5.333),
  'mioceno inferior': RangoMa(23.03, 15.97),
  'mioceno medio': RangoMa(15.97, 11.63),
  'mioceno superior': RangoMa(11.63, 5.333),
  // Pisos continentales europeos de mamíferos (escala MN)
  'agenian': RangoMa(23, 21.5),
  'ageniense': RangoMa(23, 21.5),
  'rambliense': RangoMa(21.5, 19.5),
  'aragoniense': RangoMa(19.5, 11.1),
  'aragoniense inferior': RangoMa(19.5, 16.5),
  'aragoniense medio': RangoMa(16.5, 14),
  'aragoniense superior': RangoMa(14, 11.1),
  'vallesiense': RangoMa(11.1, 9),
  'turoliense': RangoMa(9, 5.3),

  // Plioceno
  'zancliense': RangoMa(5.333, 3.6),
  'piacenziense': RangoMa(3.6, 2.58),
  'plioceno': RangoMa(5.333, 2.58),
  'rusciniense': RangoMa(5.3, 3.4),
  'villafranquiense': RangoMa(3.4, 1.2),
  'villafranchiense': RangoMa(3.4, 1.2),

  // Cuaternario
  'gelasiense': RangoMa(2.58, 1.8),
  'calabriense': RangoMa(1.8, 0.774),
  'pleistoceno inferior': RangoMa(2.58, 0.774),
  'pleistoceno medio': RangoMa(0.774, 0.129),
  'pleistoceno superior': RangoMa(0.129, 0.0117),
  'pleistoceno': RangoMa(2.58, 0.0117),
  'holoceno': RangoMa(0.0117, 0),
  'cuaternario': RangoMa(2.58, 0),
};

String _normalizar(String texto) {
  return texto
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n');
}

RangoMa? rangoMaDeEdad(String? texto) {
  if (texto == null || texto.trim().isEmpty) return null;
  final norm = _normalizar(texto);
  final coincidencias = <RangoMa>[];
  for (final entrada in _pisos.entries) {
    // Match por palabra completa para evitar que claves cortas como
    // 'lias' coincidan dentro de palabras no relacionadas.
    final patron = RegExp(r'\b' + RegExp.escape(entrada.key) + r'\b');
    if (patron.hasMatch(norm)) coincidencias.add(entrada.value);
  }
  if (coincidencias.isEmpty) return null;
  // Antes hacía max(inicios) y min(fines), lo que producía rangos
  // invertidos cuando los pisos coincidentes eran disjuntos. Ahora
  // mantiene la envolvente (más antigua – más reciente) sin invertir,
  // lo que es correcto para una "edad mencionada en texto libre" —
  // el rango cubre desde el inicio del más antiguo hasta el fin del
  // más reciente.
  double inicio = coincidencias.first.inicioMa;
  double fin = coincidencias.first.finMa;
  for (final r in coincidencias) {
    if (r.inicioMa > inicio) inicio = r.inicioMa;
    if (r.finMa < fin) fin = r.finMa;
  }
  if (inicio < fin) {
    // Defensa adicional: si tras la combinación el rango es inválido,
    // devolvemos sólo la primera coincidencia. No debería ocurrir tras
    // las correcciones anteriores, pero es barato proteger.
    return coincidencias.first;
  }
  return RangoMa(inicio, fin);
}
