import 'package:flutter/material.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';

import '../../sonido/calidad_audio.dart';

/// Aviso de calidad del audio en la tarjeta de escucha: una línea por
/// problema («Mucho viento: protege el micro o cambia de sitio») o «Sonido
/// limpio» si no hay ninguno.
class IndicadorCalidadAudio extends StatelessWidget {
  final EvaluacionCalidad evaluacion;

  const IndicadorCalidadAudio({super.key, required this.evaluacion});

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    if (evaluacion.avisos.isEmpty) {
      return Row(
        children: [
          Icon(Icons.check_circle_outline, size: 18, color: colores.primary),
          const SizedBox(width: 6),
          Expanded(child: Text(SoleraL10n.t('nat.son_calidad_limpio'), style: tema.bodySmall)),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final aviso in AvisoCalidad.values)
          if (evaluacion.avisos.contains(aviso))
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: colores.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(_icono(aviso), size: 18, color: colores.onErrorContainer),
                  const SizedBox(width: 6),
                  Expanded(
                    child:
                        Text(_texto(aviso), style: tema.bodySmall?.copyWith(color: colores.onErrorContainer)),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  static IconData _icono(AvisoCalidad aviso) => switch (aviso) {
        AvisoCalidad.saturacion => Icons.volume_up,
        AvisoCalidad.viento => Icons.air,
        AvisoCalidad.trafico => Icons.directions_car_outlined,
        AvisoCalidad.senalDebil => Icons.volume_mute,
      };

  static String _texto(AvisoCalidad aviso) => switch (aviso) {
        AvisoCalidad.saturacion => SoleraL10n.t('nat.son_calidad_saturacion'),
        AvisoCalidad.viento => SoleraL10n.t('nat.son_calidad_viento'),
        AvisoCalidad.trafico => SoleraL10n.t('nat.son_calidad_trafico'),
        AvisoCalidad.senalDebil => SoleraL10n.t('nat.son_calidad_debil'),
      };
}
