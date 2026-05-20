/// Anotación a posteriori sobre una salida o un hallazgo concreto.
///
/// Captura el gesto físico del cuaderno: escribir en el margen días
/// después, al revisar fotos o consultar bibliografía. La fecha de
/// la anotación es distinta de la del hallazgo/salida que comenta.
///
/// Invariante: al menos uno de [salidaId] o [hallazgoId] debe estar
/// presente (impuesto por CHECK en SQLite). El otro suele ser null.
class AnotacionDiferida {
  final int? id;
  final int fechaAnotacionMs;
  final int? salidaId;
  final int? hallazgoId;
  final String texto;

  AnotacionDiferida({
    this.id,
    required this.fechaAnotacionMs,
    this.salidaId,
    this.hallazgoId,
    required this.texto,
  })  : assert(
          salidaId != null || hallazgoId != null,
          'AnotacionDiferida necesita salidaId o hallazgoId',
        ),
        assert(texto != '', 'AnotacionDiferida vacía no se admite');

  bool get sobreSalida => salidaId != null && hallazgoId == null;
  bool get sobreHallazgo => hallazgoId != null;

  Map<String, Object?> toMap() => {
        'id': id,
        'fecha_anotacion_ms': fechaAnotacionMs,
        'salida_id': salidaId,
        'hallazgo_id': hallazgoId,
        'texto': texto,
      };

  factory AnotacionDiferida.fromMap(Map<String, Object?> mapa) =>
      AnotacionDiferida(
        id: mapa['id'] as int?,
        fechaAnotacionMs: mapa['fecha_anotacion_ms'] as int,
        salidaId: mapa['salida_id'] as int?,
        hallazgoId: mapa['hallazgo_id'] as int?,
        texto: (mapa['texto'] as String?) ?? '',
      );
}
