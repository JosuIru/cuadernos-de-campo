import 'package:flutter/material.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';

import '../../fuentes_abiertas/presencia_gbif.dart' show tramosDeMeses;
import '../../fuentes_abiertas/ubicacion_aproximada.dart';
import '../../servicios/ocurrencia_fauna_instalada.dart';
import '../../servicios/zona_para_consultas.dart';
import '../../sonido/filtro_ocurrencia.dart';
import '../../sonido/temporada_sonido.dart';
import 'fuentes_abiertas_ficha.dart';

String _textoTramos(List<int> meses) {
  final nombres = nombresCortosMeses();
  return tramosDeMeses(meses)
      .map((tramo) => tramo[0] == tramo[1] ? nombres[tramo[0] - 1] : '${nombres[tramo[0] - 1]}–${nombres[tramo[1] - 1]}')
      .join(', ');
}

/// «Cuándo y dónde suele cantar»: meses con actividad y presencia en la zona,
/// del fichero de presencia del modelo de sonido (sin consultas nuevas).
class TarjetaTemporadaSonido extends StatelessWidget {
  const TarjetaTemporadaSonido({
    super.key,
    required this.datos,
    required this.etiquetaEspecie,
    this.latitud,
    this.longitud,
  });

  final DatosOcurrencia datos;

  /// Nombre científico tal como lo usa el modelo.
  final String etiquetaEspecie;
  final double? latitud;
  final double? longitud;

  @override
  Widget build(BuildContext context) {
    final temporada = temporadaSonidoDe(datos, etiquetaEspecie, latitud: latitud, longitud: longitud);
    if (temporada == null || !temporada.tieneDatos) return const SizedBox.shrink();
    final tema = Theme.of(context);
    final textoPresencia = switch (temporada.presencia) {
      PresenciaEnZona.registrada => SoleraL10n.t('nat.cuad_temp_en_tu_zona'),
      PresenciaEnZona.sinRegistros => SoleraL10n.t('nat.cuad_temp_no_en_tu_zona'),
      PresenciaEnZona.celdaSinDatos || PresenciaEnZona.fueraDeRejilla => SoleraL10n.t('nat.cuad_temp_zona_sin_datos'),
      PresenciaEnZona.sinUbicacion => SoleraL10n.t('nat.cuad_temp_sin_ubicacion'),
    };
    final actividad = temporada.actividadMensual;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(SoleraL10n.t('nat.cuad_temp_titulo'), style: tema.textTheme.titleSmall),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              temporada.presencia == PresenciaEnZona.registrada ? Icons.place : Icons.place_outlined,
              size: 18,
              color: tema.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Expanded(child: Text(textoPresencia)),
          ],
        ),
        if (actividad != null) ...[
          const SizedBox(height: 8),
          GraficoRegistrosPorMes(
            porMes: [for (final valor in actividad) valor.round()],
            altura: 48,
            textoValor: (mes, valor) => SoleraL10n.tf('nat.cuad_temp_actividad_mes', {'mes': mes, 'valor': valor}),
          ),
          const SizedBox(height: 6),
          if (temporada.mesesEsperados.isEmpty)
            Text(SoleraL10n.t('nat.cuad_temp_sin_meses'))
          else
            Text(SoleraL10n.tf('nat.cuad_temp_meses', {
              'esperados': _textoTramos(temporada.mesesEsperados),
              'mas': _textoTramos(temporada.mesesDeMasActividad),
            })),
        ],
        const SizedBox(height: 4),
        Text(SoleraL10n.t('nat.cuad_temp_fuente'), style: tema.textTheme.bodySmall),
      ],
    );
  }
}

/// La misma tarjeta en la ficha de la guía: solo si el modelo de sonido está
/// instalado y trae la especie. Usa la zona aproximada de la sesión si ya se
/// pidió (no la pide).
class TemporadaSonidoFichaGuia extends StatelessWidget {
  const TemporadaSonidoFichaGuia({super.key, required this.nombreCientifico});

  final String nombreCientifico;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DatosOcurrencia?>(
      initialData: OcurrenciaFaunaInstalada.enMemoria,
      future: OcurrenciaFaunaInstalada.cargar(),
      builder: (context, instantanea) {
        final datos = instantanea.data;
        if (datos == null || temporadaSonidoDe(datos, nombreCientifico) == null) return const SizedBox.shrink();
        return ValueListenableBuilder<UbicacionAproximada?>(
          valueListenable: ZonaParaConsultas.zonaDeLaSesion,
          builder: (context, zona, _) => Padding(
            padding: const EdgeInsets.only(top: 16),
            child: TarjetaTemporadaSonido(
              datos: datos,
              etiquetaEspecie: nombreCientifico,
              latitud: zona?.latitud,
              longitud: zona?.longitud,
            ),
          ),
        );
      },
    );
  }
}
