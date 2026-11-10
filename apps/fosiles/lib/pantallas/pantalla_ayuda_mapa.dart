import 'package:flutter/material.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import '../servicios/servicio_geologia.dart';

/// «Cómo leer el mapa»: qué es cada capa geológica, dónde están las demás
/// capas y de dónde salen las sugerencias de fósiles y minerales. Se abre
/// desde el menú «⋮» del mapa y desde Ajustes → Acerca de.
class PantallaAyudaMapa extends StatelessWidget {
  const PantallaAyudaMapa({super.key});

  @override
  Widget build(BuildContext context) {
    final estiloTitulo = Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold);
    final colorApagado = Colors.grey.shade700;
    return Scaffold(
      appBar: AppBar(title: Text(SoleraL10n.t('fos.mapa_como_leer_mapa'))),
      body: ListView(
        padding: rellenoInferiorSeguro(context, const EdgeInsets.all(16)),
        children: [
          Text(SoleraL10n.t('fos.mapa_ayuda_capas_titulo'), style: estiloTitulo),
          const SizedBox(height: 6),
          Text(
            SoleraL10n.t('fos.mapa_ayuda_capas_texto'),
            style: TextStyle(fontSize: 13, color: colorApagado),
          ),
          const SizedBox(height: 10),
          ...capasGeologicasWms.map((capa) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ${capa.nombreVisible}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 12, top: 2),
                      child: Text(
                        capa.descripcionVisible,
                        style: const TextStyle(fontSize: 13, height: 1.3),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 4),
          Text(
            SoleraL10n.t('fos.mapa_ayuda_capas_nota'),
            style: TextStyle(fontSize: 13, color: colorApagado, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 24),
          Text(SoleraL10n.t('fos.mapa_ayuda_otras_titulo'), style: estiloTitulo),
          const SizedBox(height: 6),
          Text(
            '${SoleraL10n.t('fos.mapa_ayuda_menu_superior')}\n'
            '• ${SoleraL10n.t('fos.mapa_ayuda_item_lig')}\n'
            '• ${SoleraL10n.t('fos.mapa_ayuda_item_relieve')}\n'
            '• ${SoleraL10n.t('fos.mapa_ayuda_item_calor')}\n'
            '• ${SoleraL10n.t('fos.mapa_ayuda_item_yacimientos')}\n\n'
            '${SoleraL10n.t('fos.mapa_ayuda_boton_capas')}\n'
            '• ${SoleraL10n.t('fos.mapa_ayuda_item_cuevas')}\n'
            '• ${SoleraL10n.t('fos.mapa_ayuda_item_megalitos')}',
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 24),
          Text(SoleraL10n.t('fos.mapa_ayuda_sugerencias_titulo'), style: estiloTitulo),
          const SizedBox(height: 6),
          Text(
            '${SoleraL10n.t('fos.mapa_ayuda_sugerencias_intro')}\n\n'
            '• ${SoleraL10n.t('fos.mapa_ayuda_sugerencias_formacion')}\n'
            '• ${SoleraL10n.t('fos.mapa_ayuda_sugerencias_periodo')}\n'
            '• ${SoleraL10n.t('fos.mapa_ayuda_sugerencias_minerales')}',
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}
