import 'package:flutter/material.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';

import '../../servicios/controlador_donde_esta.dart';
import '../../sonido/triangulacion_rumbos.dart';
import 'mapa_zona_animal.dart';

/// Tarjeta «¿Dónde está?» de la pantalla de escucha: rumbo en vivo, «Viene
/// de aquí», barrido, tomas, avisos y el mapa con la zona estimada.
class TarjetaDondeEsta extends StatelessWidget {
  final ControladorDondeEsta controlador;

  /// El barrido necesita el micrófono abierto.
  final bool escuchando;

  const TarjetaDondeEsta({super.key, required this.controlador, required this.escuchando});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controlador,
      builder: (context, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(SoleraL10n.t('nat.son_donde_titulo'), style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(SoleraL10n.t('nat.son_donde_ayuda'), style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              if (!controlador.activo && controlador.tomas.isEmpty)
                OutlinedButton.icon(
                  icon: const Icon(Icons.explore_outlined),
                  label: Text(SoleraL10n.t('nat.son_donde_empezar')),
                  onPressed: controlador.activar,
                )
              else
                ..._contenido(context),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _contenido(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final colorError = Theme.of(context).colorScheme.error;
    final rumbo = controlador.rumboActualGrados;
    final precisionBrujula = controlador.precisionBrujulaGrados;
    final hijos = <Widget>[];

    if (!controlador.activo) {
      hijos.add(OutlinedButton.icon(
        icon: const Icon(Icons.explore_outlined),
        label: Text(SoleraL10n.t('nat.son_donde_reanudar_brujula')),
        onPressed: controlador.activar,
      ));
    } else if (controlador.sinBrujula && rumbo == null) {
      hijos.add(Text(SoleraL10n.t('nat.son_donde_sin_brujula'),
          style: tema.bodySmall?.copyWith(color: colorError)));
    } else {
      hijos.add(Row(
        children: [
          Transform.rotate(
            angle: -(rumbo ?? 0) * 3.141592653589793 / 180,
            child: const Icon(Icons.navigation, size: 32),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              rumbo == null
                  ? SoleraL10n.t('nat.son_donde_esperando_brujula')
                  : SoleraL10n.tf(
                      controlador.declinacionGrados == null
                          ? 'nat.son_donde_rumbo_magnetico'
                          : 'nat.son_donde_rumbo_verdadero',
                      {'rumbo': rumbo.round() % 360},
                    ),
              style: tema.titleMedium,
            ),
          ),
        ],
      ));
      if (precisionBrujula != null && precisionBrujula >= 45) {
        hijos.add(
            Text(SoleraL10n.t('nat.son_donde_calibrar'), style: tema.bodySmall?.copyWith(color: colorError)));
      }
    }
    hijos.add(const SizedBox(height: 8));
    hijos.add(Row(
      children: [
        Expanded(child: Text(SoleraL10n.t('nat.son_donde_margen'), style: tema.bodySmall)),
        DropdownButton<double>(
          value: controlador.incertidumbreGrados,
          items: [
            for (final opcion in opcionesIncertidumbreGrados)
              DropdownMenuItem(value: opcion, child: Text('± ${opcion.round()}°')),
          ],
          onChanged: (valor) {
            if (valor != null) controlador.cambiarIncertidumbre(valor);
          },
        ),
      ],
    ));

    if (controlador.barriendo) {
      hijos.addAll([
        Text(
          SoleraL10n.tf('nat.son_barrido_en_curso', {'cubierto': controlador.coberturaBarridoGrados.round()}),
          style: tema.bodyMedium,
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(value: (controlador.coberturaBarridoGrados / 360).clamp(0, 1).toDouble()),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: controlador.terminarBarrido,
                child: Text(SoleraL10n.t('nat.son_barrido_terminar')),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(onPressed: controlador.cancelarBarrido, child: Text(SoleraL10n.t('cancelar'))),
          ],
        ),
      ]);
    } else {
      hijos.add(Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              icon: controlador.tomandoPosicion
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.call_made),
              label: Text(SoleraL10n.t('nat.son_viene_de_aqui')),
              onPressed: controlador.tomandoPosicion || !controlador.activo || rumbo == null
                  ? null
                  : () => controlador.tomarRumbo(),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: escuchando && controlador.activo && rumbo != null ? controlador.empezarBarrido : null,
            child: Text(SoleraL10n.t('nat.son_barrido')),
          ),
        ],
      ));
      if (!escuchando) {
        hijos.add(Text(SoleraL10n.t('nat.son_barrido_necesita_micro'), style: tema.bodySmall));
      }
      final barrido = controlador.ultimoBarrido;
      if (barrido != null) {
        hijos.add(const SizedBox(height: 8));
        if (barrido.hayMaximoClaro) {
          hijos.add(Text(
            SoleraL10n.tf('nat.son_barrido_maximo', {
              'rumbo': barrido.rumboMaximoGrados!.round() % 360,
              'contraste': barrido.contrasteDecibelios.toStringAsFixed(0),
            }),
          ));
          hijos.add(Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.add),
              label: Text(SoleraL10n.t('nat.son_barrido_usar')),
              onPressed: controlador.tomandoPosicion
                  ? null
                  : () =>
                      controlador.tomarRumbo(rumboFijoGrados: barrido.rumboMaximoGrados, orientativa: true),
            ),
          ));
        } else {
          hijos.add(Text(
            SoleraL10n.tf(
              barrido.coberturaSuficiente ? 'nat.son_barrido_sin_maximo' : 'nat.son_barrido_poca_vuelta',
              {
                'cubierto': barrido.coberturaGrados.round(),
                'contraste': barrido.contrasteDecibelios.toStringAsFixed(0),
              },
            ),
            style: tema.bodySmall,
          ));
        }
      }
    }

    final error = controlador.ultimoError;
    if (error != null) {
      hijos.add(Text(
        switch (error) {
          ErrorTomaRumbo.sinPermisoUbicacion => SoleraL10n.t('nat.son_donde_error_permiso'),
          ErrorTomaRumbo.sinPosicion => SoleraL10n.t('nat.son_donde_error_posicion'),
          ErrorTomaRumbo.sinBrujula => SoleraL10n.t('nat.son_donde_sin_brujula'),
        },
        style: tema.bodySmall?.copyWith(color: colorError),
      ));
    }

    final tomas = controlador.tomas;
    if (tomas.isNotEmpty) {
      hijos.add(const SizedBox(height: 8));
      final formatoHora = MaterialLocalizations.of(context);
      for (final (indice, toma) in tomas.indexed) {
        hijos.add(ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading:
              CircleAvatar(radius: 12, child: Text('${indice + 1}', style: const TextStyle(fontSize: 12))),
          title: Text(SoleraL10n.tf(toma.orientativa ? 'nat.son_toma_orientativa' : 'nat.son_toma', {
            'rumbo': toma.rumboGrados.round() % 360,
            'margen': toma.incertidumbreGrados.round(),
          })),
          subtitle: Text(SoleraL10n.tf('nat.son_toma_detalle', {
            'gps': toma.precisionMetros == null ? '?' : toma.precisionMetros!.round(),
            'hora': formatoHora.formatTimeOfDay(TimeOfDay.fromDateTime(toma.momento)),
          })),
          trailing: IconButton(
            icon: const Icon(Icons.close),
            tooltip: SoleraL10n.t('borrar'),
            onPressed: () => controlador.quitarToma(indice),
          ),
        ));
      }
      final zona = controlador.zona;
      for (final aviso in zona.avisos) {
        hijos.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, size: 18, color: colorError),
              const SizedBox(width: 6),
              Expanded(child: Text(_textoAviso(aviso), style: tema.bodySmall)),
            ],
          ),
        ));
      }
      if (zona.hayZona) {
        hijos.add(Text(
          SoleraL10n.tf('nat.son_zona_resumen', {
            'radio': _metrosRedondos(zona.radioAproximadoMetros),
            'distancia': _metrosRedondos(zona.distanciaMinimaMetros ?? 0),
          }),
          style: tema.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ));
        hijos.add(Text(SoleraL10n.t('nat.son_zona_se_guarda'), style: tema.bodySmall));
      }
      hijos.add(const SizedBox(height: 8));
      hijos.add(MapaZonaAnimal(tomas: tomas, contorno: zona.contorno));
      hijos.add(Align(
        alignment: Alignment.centerLeft,
        child:
            TextButton(onPressed: controlador.borrarTomas, child: Text(SoleraL10n.t('nat.son_borrar_tomas'))),
      ));
    }
    if (controlador.activo && controlador.declinacionGrados == null && tomas.isNotEmpty) {
      hijos.add(Text(SoleraL10n.t('nat.son_donde_sin_declinacion'), style: tema.bodySmall));
    }
    return hijos;
  }
}

String _metrosRedondos(double metros) {
  if (metros < 100) return (metros / 5).round() * 5 == 0 ? '5' : ((metros / 5).round() * 5).toString();
  if (metros < 1000) return ((metros / 10).round() * 10).toString();
  return ((metros / 50).round() * 50).toString();
}

String _textoAviso(AvisoTriangulacion aviso) => switch (aviso) {
      AvisoTriangulacion.pocasTomas => SoleraL10n.t('nat.son_aviso_pocas_tomas'),
      AvisoTriangulacion.tomasDemasiadoJuntas => SoleraL10n.t('nat.son_aviso_tomas_juntas'),
      AvisoTriangulacion.rumbosCasiParalelos => SoleraL10n.t('nat.son_aviso_paralelos'),
      AvisoTriangulacion.rumbosNoSeCruzanDelante => SoleraL10n.t('nat.son_aviso_no_se_cruzan'),
      AvisoTriangulacion.sinInterseccion => SoleraL10n.t('nat.son_aviso_sin_zona'),
      AvisoTriangulacion.hayTomasOrientativas => SoleraL10n.t('nat.son_aviso_orientativas'),
    };
