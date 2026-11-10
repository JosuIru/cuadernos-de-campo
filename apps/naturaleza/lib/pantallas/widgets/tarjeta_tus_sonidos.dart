import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';

import '../../servicios/controlador_sonidos_propios.dart';
import '../../sonido/sonidos_propios.dart';

/// Tarjeta «Tus sonidos»: crear sonidos con nombre propio y enseñárselos con
/// lo último oído (el último trozo de 5 s sin voz humana), fondo y
/// sensibilidad.
class TarjetaTusSonidos extends StatelessWidget {
  final ControladorSonidosPropios controlador;

  /// Embedding del último trozo limpio, o null si aún no hay.
  final Float32List? embeddingUltimoTrozo;

  const TarjetaTusSonidos({super.key, required this.controlador, required this.embeddingUltimoTrozo});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controlador,
      builder: (context, _) {
        final tema = Theme.of(context).textTheme;
        final hayEmbedding = embeddingUltimoTrozo != null && embeddingUltimoTrozo!.isNotEmpty;
        final fondo = controlador.sonidoFondo;
        final ejemplosFondo = fondo == null ? 0 : controlador.ejemplosDe(fondo.id);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(SoleraL10n.t('nat.son_tus_titulo'), style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  SoleraL10n.tf('nat.son_tus_intro', {'minimo': ejemplosMinimosParaReconocer}),
                  style: tema.bodySmall,
                ),
                if (!hayEmbedding) Text(SoleraL10n.t('nat.son_tus_sin_trozo'), style: tema.bodySmall),
                if (controlador.error != null)
                  Text(controlador.error!,
                      style: tema.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error)),
                for (final sonido in controlador.sonidos) _filaSonido(context, sonido, hayEmbedding),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: Text(SoleraL10n.t('nat.son_tus_nuevo')),
                    onPressed: () => _crear(context),
                  ),
                ),
                const Divider(),
                Text(SoleraL10n.t('nat.son_tus_fondo_titulo'), style: tema.labelLarge),
                Text(SoleraL10n.t('nat.son_tus_fondo_ayuda'), style: tema.bodySmall),
                Row(
                  children: [
                    Expanded(
                      child: Text(SoleraL10n.tf('nat.son_tus_ejemplos', {
                        'n': ejemplosFondo,
                        'maximo': ejemplosMaximosPorSonido,
                      })),
                    ),
                    if (fondo != null && ejemplosFondo > 0)
                      IconButton(
                        icon: const Icon(Icons.undo),
                        tooltip: SoleraL10n.t('nat.son_tus_quitar_ultimo'),
                        onPressed: () => controlador.quitarUltimoEjemplo(fondo.id),
                      ),
                    TextButton(
                      onPressed: hayEmbedding && ejemplosFondo < ejemplosMaximosPorSonido
                          ? () => _anadirFondo(context)
                          : null,
                      child: Text(SoleraL10n.t('nat.son_tus_anadir_ultimo')),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(SoleraL10n.t('nat.son_tus_sensibilidad'), style: tema.labelLarge),
                const SizedBox(height: 4),
                SegmentedButton<SensibilidadSonidosPropios>(
                  segments: [
                    for (final opcion in SensibilidadSonidosPropios.values)
                      ButtonSegment(value: opcion, label: Text(_etiquetaSensibilidad(opcion))),
                  ],
                  selected: {controlador.sensibilidad},
                  showSelectedIcon: false,
                  onSelectionChanged: (seleccion) => controlador.cambiarSensibilidad(seleccion.first),
                ),
                const SizedBox(height: 4),
                Text(
                  SoleraL10n.tf('nat.son_tus_sensibilidad_ayuda', {
                    'umbral': textoSimilitud(umbralPorSensibilidad[controlador.sensibilidad]!),
                  }),
                  style: tema.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(SoleraL10n.t('nat.son_tus_privacidad'), style: tema.bodySmall),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _filaSonido(BuildContext context, SonidoPropio sonido, bool hayEmbedding) {
    final tema = Theme.of(context).textTheme;
    final ejemplos = controlador.ejemplosDe(sonido.id);
    final deOtroModelo = controlador.ejemplosDeOtroModelo(sonido.id);
    final lleno = ejemplos >= ejemplosMaximosPorSonido;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(sonido.nombre),
      subtitle: Text(
        [
          ejemplos >= ejemplosMinimosParaReconocer
              ? SoleraL10n.tf('nat.son_tus_ejemplos', {'n': ejemplos, 'maximo': ejemplosMaximosPorSonido})
              : SoleraL10n.tf('nat.son_tus_faltan', {'n': ejemplos, 'minimo': ejemplosMinimosParaReconocer}),
          if (deOtroModelo > 0) SoleraL10n.tf('nat.son_tus_otro_modelo', {'n': deOtroModelo}),
        ].join(' · '),
        style: tema.bodySmall?.copyWith(
          color: ejemplos >= ejemplosMinimosParaReconocer ? null : Theme.of(context).colorScheme.error,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: hayEmbedding && !lleno ? () => _anadir(context, sonido) : null,
            child: Text(SoleraL10n.t('nat.son_tus_anadir_ultimo')),
          ),
          PopupMenuButton<String>(
            onSelected: (accion) {
              switch (accion) {
                case 'quitar':
                  controlador.quitarUltimoEjemplo(sonido.id);
                case 'renombrar':
                  _renombrar(context, sonido);
                case 'borrar':
                  _borrar(context, sonido);
              }
            },
            itemBuilder: (_) => [
              if (ejemplos > 0)
                PopupMenuItem(value: 'quitar', child: Text(SoleraL10n.t('nat.son_tus_quitar_ultimo'))),
              PopupMenuItem(value: 'renombrar', child: Text(SoleraL10n.t('nat.son_tus_renombrar'))),
              PopupMenuItem(value: 'borrar', child: Text(SoleraL10n.t('borrar'))),
            ],
          ),
        ],
      ),
    );
  }

  Future<String?> _pedirNombre(BuildContext context, {required String titulo, String inicial = ''}) {
    final controladorTexto = TextEditingController(text: inicial);
    return showDialog<String>(
      context: context,
      builder: (contextoDialogo) => AlertDialog(
        title: Text(titulo),
        content: TextField(
          controller: controladorTexto,
          autofocus: true,
          maxLength: longitudMaximaNombreSonido,
          decoration: InputDecoration(hintText: SoleraL10n.t('nat.son_tus_nombre_ejemplo')),
          onSubmitted: (texto) => Navigator.pop(contextoDialogo, texto),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contextoDialogo), child: Text(SoleraL10n.t('cancelar'))),
          FilledButton(
            onPressed: () => Navigator.pop(contextoDialogo, controladorTexto.text),
            child: Text(SoleraL10n.t('guardar')),
          ),
        ],
      ),
    ).whenComplete(controladorTexto.dispose);
  }

  Future<void> _crear(BuildContext context) async {
    final nombre = await _pedirNombre(context, titulo: SoleraL10n.t('nat.son_tus_nuevo'));
    if (nombre == null) return;
    final idSonido = await controlador.crear(nombre);
    final embedding = embeddingUltimoTrozo;
    if (idSonido == null || embedding == null || embedding.isEmpty || !context.mounted) return;
    final usarUltimo = await showDialog<bool>(
      context: context,
      builder: (contextoDialogo) => AlertDialog(
        content: Text(SoleraL10n.t('nat.son_tus_usar_ultimo_pregunta')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(contextoDialogo, false),
              child: Text(SoleraL10n.t('nat.son_tus_ahora_no'))),
          FilledButton(
              onPressed: () => Navigator.pop(contextoDialogo, true),
              child: Text(SoleraL10n.t('nat.son_tus_anadir_ultimo'))),
        ],
      ),
    );
    if (usarUltimo == true) await controlador.anadirEjemplo(idSonido, embedding);
  }

  Future<void> _anadir(BuildContext context, SonidoPropio sonido) async {
    final embedding = embeddingUltimoTrozo;
    if (embedding == null) return;
    final anadido = await controlador.anadirEjemplo(sonido.id, embedding);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(anadido
          ? SoleraL10n.tf('nat.son_tus_anadido', {'nombre': sonido.nombre})
          : SoleraL10n.tf('nat.son_tus_lleno', {'maximo': ejemplosMaximosPorSonido})),
    ));
  }

  Future<void> _anadirFondo(BuildContext context) async {
    final embedding = embeddingUltimoTrozo;
    if (embedding == null) return;
    await controlador.anadirEjemploFondo(SoleraL10n.t('nat.son_tus_fondo_titulo'), embedding);
  }

  Future<void> _renombrar(BuildContext context, SonidoPropio sonido) async {
    final nombre =
        await _pedirNombre(context, titulo: SoleraL10n.t('nat.son_tus_renombrar'), inicial: sonido.nombre);
    if (nombre != null) await controlador.renombrar(sonido.id, nombre);
  }

  Future<void> _borrar(BuildContext context, SonidoPropio sonido) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contextoDialogo) => AlertDialog(
        title: Text(SoleraL10n.t('nat.son_tus_borrar_titulo')),
        content: Text(SoleraL10n.tf('nat.son_tus_borrar_texto', {
          'nombre': sonido.nombre,
          'n': controlador.ejemplosDe(sonido.id) + controlador.ejemplosDeOtroModelo(sonido.id),
        })),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(contextoDialogo, false), child: Text(SoleraL10n.t('cancelar'))),
          FilledButton(
              onPressed: () => Navigator.pop(contextoDialogo, true), child: Text(SoleraL10n.t('borrar'))),
        ],
      ),
    );
    if (confirmado == true) await controlador.borrar(sonido.id);
  }
}

String _etiquetaSensibilidad(SensibilidadSonidosPropios sensibilidad) => switch (sensibilidad) {
      SensibilidadSonidosPropios.estricta => SoleraL10n.t('nat.son_tus_estricta'),
      SensibilidadSonidosPropios.normal => SoleraL10n.t('nat.son_tus_normal'),
      SensibilidadSonidosPropios.sensible => SoleraL10n.t('nat.son_tus_sensible'),
    };
