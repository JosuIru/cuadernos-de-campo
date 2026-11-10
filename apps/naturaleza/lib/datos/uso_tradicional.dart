// Uso tradicional de una planta según la monografía de la Unión del HMPC
// (Agencia Europea del Medicamento). Solo se enseña lo que dice esa fuente,
// citada, con las precauciones delante y sin dosis ni preparaciones.

class UsoTradicional {
  const UsoTradicional({
    required this.especieId,
    required this.parte,
    required this.uso,
    required this.contraindicaciones,
    required this.precauciones,
    required this.tipoUso,
    required this.estadoMonografia,
    required this.url,
  });

  final String especieId;

  /// Parte de la planta a la que se refiere la monografía (hoja, raíz…).
  final String parte;

  /// Vacío si la EMA no da uso pero sí un aviso (poleo, borraja).
  final String uso;
  final String contraindicaciones;
  final String precauciones;

  /// «tradicional», «uso bien establecido» o los dos.
  final String tipoUso;
  final String estadoMonografia;
  final String url;
}
