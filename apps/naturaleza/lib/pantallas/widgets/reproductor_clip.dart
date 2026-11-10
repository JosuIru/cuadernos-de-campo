import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';

/// Reproduce el clip de audio de un hallazgo (WAV en `audios/`).
class ReproductorClip extends StatefulWidget {
  final String rutaAudio;

  /// Si se da, aparece un botón para quitar el clip (en el alta).
  final VoidCallback? alQuitar;

  const ReproductorClip({super.key, required this.rutaAudio, this.alQuitar});

  @override
  State<ReproductorClip> createState() => _ReproductorClipState();
}

class _ReproductorClipState extends State<ReproductorClip> {
  final AudioPlayer _reproductor = AudioPlayer();
  final List<StreamSubscription<Object?>> _suscripciones = [];
  PlayerState _estado = PlayerState.stopped;
  Duration _posicion = Duration.zero;
  Duration? _duracion;
  bool _existe = true;

  @override
  void initState() {
    super.initState();
    _existe = File(widget.rutaAudio).existsSync();
    _suscripciones
      ..add(_reproductor.onPlayerStateChanged.listen((estado) {
        if (mounted) setState(() => _estado = estado);
      }))
      ..add(_reproductor.onPositionChanged.listen((posicion) {
        if (mounted) setState(() => _posicion = posicion);
      }))
      ..add(_reproductor.onDurationChanged.listen((duracion) {
        if (mounted) setState(() => _duracion = duracion);
      }))
      ..add(_reproductor.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _posicion = Duration.zero);
      }));
  }

  @override
  void dispose() {
    for (final suscripcion in _suscripciones) {
      suscripcion.cancel();
    }
    _reproductor.dispose();
    super.dispose();
  }

  Future<void> _alternar() async {
    try {
      if (_estado == PlayerState.playing) {
        await _reproductor.pause();
      } else if (_estado == PlayerState.paused) {
        await _reproductor.resume();
      } else {
        await _reproductor.play(DeviceFileSource(widget.rutaAudio));
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${SoleraL10n.t('nat.son_error_reproducir')}: $error')),
      );
    }
  }

  String _formatear(Duration duracion) {
    final segundos = duracion.inMilliseconds / 1000;
    return '${segundos.toStringAsFixed(1)} s';
  }

  @override
  Widget build(BuildContext context) {
    final duracion = _duracion;
    final fraccion = duracion == null || duracion.inMilliseconds == 0
        ? 0.0
        : (_posicion.inMilliseconds / duracion.inMilliseconds).clamp(0.0, 1.0);
    return Row(
      children: [
        IconButton.filledTonal(
          icon: Icon(_estado == PlayerState.playing ? Icons.pause : Icons.play_arrow),
          tooltip: SoleraL10n.t(
              _estado == PlayerState.playing ? 'nat.son_pausar_clip' : 'nat.son_escuchar_clip'),
          onPressed: _existe ? _alternar : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _existe
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(value: fraccion),
                    const SizedBox(height: 4),
                    Text(
                      duracion == null
                          ? SoleraL10n.t('nat.son_clip_audio')
                          : '${SoleraL10n.t('nat.son_clip_audio')} · ${_formatear(duracion)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                )
              : Text(SoleraL10n.t('nat.son_clip_no_encontrado'),
                  style: Theme.of(context).textTheme.bodySmall),
        ),
        if (widget.alQuitar != null)
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: SoleraL10n.t('nat.son_quitar_clip'),
            onPressed: widget.alQuitar,
          ),
      ],
    );
  }
}
