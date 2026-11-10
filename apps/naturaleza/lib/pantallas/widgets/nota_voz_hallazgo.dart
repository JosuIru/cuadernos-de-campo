import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import 'package:path/path.dart' as path_lib;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'reproductor_clip.dart';

/// Duración máxima de una nota de voz: se para sola.
const Duration duracionMaximaNotaVoz = Duration(minutes: 3);

/// Carpeta de las notas de voz dentro de documentos (va en la copia de
/// seguridad y en el ZIP exportado).
const String carpetaNotasVoz = 'notas_voz';

/// Grabar, escuchar y borrar la nota de voz de un hallazgo. Graba en AAC
/// (m4a) si el móvil puede y si no en WAV. Quien la usa decide qué hacer
/// con el fichero al guardar o al salir sin guardar.
class NotaVozHallazgo extends StatefulWidget {
  final String? rutaNotaVoz;
  final ValueChanged<String> alGrabar;
  final VoidCallback alBorrar;

  const NotaVozHallazgo({super.key, required this.rutaNotaVoz, required this.alGrabar, required this.alBorrar});

  @override
  State<NotaVozHallazgo> createState() => _NotaVozHallazgoState();
}

class _NotaVozHallazgoState extends State<NotaVozHallazgo> {
  AudioRecorder? _grabadora;
  String? _rutaEnCurso;
  DateTime? _inicioGrabacion;
  Timer? _temporizador;
  Duration _transcurrido = Duration.zero;

  bool get _grabando => _grabadora != null;

  @override
  void dispose() {
    _temporizador?.cancel();
    final grabadora = _grabadora;
    final ruta = _rutaEnCurso;
    _grabadora = null;
    if (grabadora != null) {
      // Se sale mientras graba: se para y se tira lo grabado.
      unawaited(() async {
        try {
          await grabadora.stop();
        } catch (_) {}
        try {
          await grabadora.dispose();
        } catch (_) {}
        if (ruta != null) {
          try {
            await File(ruta).delete();
          } catch (_) {}
        }
      }());
    }
    super.dispose();
  }

  Future<bool> _asegurarPermiso() async {
    var estado = await Permission.microphone.status;
    if (estado.isGranted) return true;
    estado = await Permission.microphone.request();
    if (estado.isGranted) return true;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(SoleraL10n.t('nat.son_permiso_microfono_denegado'))),
      );
    }
    return false;
  }

  Future<void> _empezar() async {
    if (_grabando || !await _asegurarPermiso() || !mounted) return;
    final grabadora = AudioRecorder();
    try {
      final documentos = await getApplicationDocumentsDirectory();
      final carpeta = Directory(path_lib.join(documentos.path, carpetaNotasVoz));
      await carpeta.create(recursive: true);
      final conAac = await grabadora.isEncoderSupported(AudioEncoder.aacLc);
      final ruta = path_lib.join(
          carpeta.path, 'nota_${DateTime.now().millisecondsSinceEpoch}.${conAac ? 'm4a' : 'wav'}');
      await grabadora.start(
        RecordConfig(
          encoder: conAac ? AudioEncoder.aacLc : AudioEncoder.wav,
          sampleRate: conAac ? 44100 : 16000,
          numChannels: 1,
          bitRate: 64000,
        ),
        path: ruta,
      );
      if (!mounted) {
        await grabadora.stop();
        await grabadora.dispose();
        return;
      }
      setState(() {
        _grabadora = grabadora;
        _rutaEnCurso = ruta;
        _inicioGrabacion = DateTime.now();
        _transcurrido = Duration.zero;
      });
      _temporizador = Timer.periodic(const Duration(milliseconds: 250), (_) {
        final inicio = _inicioGrabacion;
        if (inicio == null || !mounted) return;
        final transcurrido = DateTime.now().difference(inicio);
        if (transcurrido >= duracionMaximaNotaVoz) {
          _parar();
        } else {
          setState(() => _transcurrido = transcurrido);
        }
      });
    } catch (error) {
      try {
        await grabadora.dispose();
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(SoleraL10n.tf('nat.voz_error_grabar', {'error': error}))),
        );
      }
    }
  }

  Future<void> _parar() async {
    final grabadora = _grabadora;
    if (grabadora == null) return;
    _temporizador?.cancel();
    _temporizador = null;
    setState(() => _grabadora = null);
    String? ruta;
    try {
      ruta = await grabadora.stop();
    } catch (_) {}
    try {
      await grabadora.dispose();
    } catch (_) {}
    ruta ??= _rutaEnCurso;
    _rutaEnCurso = null;
    _inicioGrabacion = null;
    if (ruta == null || !File(ruta).existsSync() || File(ruta).lengthSync() == 0) return;
    widget.alGrabar(ruta);
  }

  Future<void> _confirmarBorrado() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contextoDialogo) => AlertDialog(
        title: Text(SoleraL10n.t('nat.voz_borrar_titulo')),
        content: Text(SoleraL10n.t('nat.voz_borrar_texto')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contextoDialogo, false), child: Text(SoleraL10n.t('cancelar'))),
          FilledButton(onPressed: () => Navigator.pop(contextoDialogo, true), child: Text(SoleraL10n.t('borrar'))),
        ],
      ),
    );
    if (confirmado == true) widget.alBorrar();
  }

  String _formatear(Duration duracion) {
    final minutos = duracion.inMinutes;
    final segundos = duracion.inSeconds % 60;
    return '$minutos:${segundos.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final ruta = widget.rutaNotaVoz;
    if (_grabando) {
      return Row(
        children: [
          Icon(Icons.fiber_manual_record, color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              SoleraL10n.tf('nat.voz_grabando', {
                'tiempo': _formatear(_transcurrido),
                'maximo': _formatear(duracionMaximaNotaVoz),
              }),
              style: tema.bodyMedium,
            ),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.stop),
            label: Text(SoleraL10n.t('nat.voz_parar')),
            onPressed: _parar,
          ),
        ],
      );
    }
    if (ruta != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ReproductorClip(
            key: ValueKey(ruta),
            rutaAudio: ruta,
            etiqueta: SoleraL10n.t('nat.voz_nota'),
            textoQuitar: SoleraL10n.t('nat.voz_borrar'),
            alQuitar: _confirmarBorrado,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.mic_none),
              label: Text(SoleraL10n.t('nat.voz_volver_a_grabar')),
              onPressed: _empezar,
            ),
          ),
        ],
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.mic_none),
        label: Text(SoleraL10n.t('nat.voz_grabar')),
        onPressed: _empezar,
      ),
    );
  }
}
