import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:sensors_plus/sensors_plus.dart';

class MedicionOrientacion {
  final double strikeGrados;
  final double dipGrados;
  final double dipDireccionGrados;
  const MedicionOrientacion({required this.strikeGrados, required this.dipGrados, required this.dipDireccionGrados});
}

Future<MedicionOrientacion?> mostrarModalOrientacion(BuildContext context) {
  return showModalBottomSheet<MedicionOrientacion?>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _ModalOrientacion(),
  );
}

class _ModalOrientacion extends StatefulWidget {
  const _ModalOrientacion();

  @override
  State<_ModalOrientacion> createState() => _ModalOrientacionState();
}

class _ModalOrientacionState extends State<_ModalOrientacion> {
  StreamSubscription<AccelerometerEvent>? _subAccel;
  StreamSubscription<CompassEvent>? _subBrujula;
  double _ax = 0, _ay = 0, _az = 0;
  double _heading = 0;

  @override
  void initState() {
    super.initState();
    _subAccel = accelerometerEventStream(samplingPeriod: const Duration(milliseconds: 100)).listen((evento) {
      if (!mounted) return;
      setState(() {
        _ax = evento.x;
        _ay = evento.y;
        _az = evento.z;
      });
    });
    final brujula = FlutterCompass.events;
    if (brujula != null) {
      _subBrujula = brujula.listen((evento) {
        if (!mounted) return;
        if (evento.heading != null) setState(() => _heading = evento.heading!);
      });
    }
  }

  @override
  void dispose() {
    _subAccel?.cancel();
    _subBrujula?.cancel();
    super.dispose();
  }

  ({double strike, double dip, double dipDir}) _calcular() {
    final magnitud = math.sqrt(_ax * _ax + _ay * _ay + _az * _az);
    if (magnitud < 0.5) return (strike: 0, dip: 0, dipDir: 0);
    final componenteHorizontal = math.sqrt(_ax * _ax + _ay * _ay);
    final dipRad = math.atan2(componenteHorizontal, _az.abs());
    final dipGrados = dipRad * 180 / math.pi;
    final anguloEnPhone = math.atan2(-_ax, -_ay) * 180 / math.pi;
    var dipDireccion = (_heading + anguloEnPhone) % 360;
    if (dipDireccion < 0) dipDireccion += 360;
    var strike = (dipDireccion - 90) % 360;
    if (strike < 0) strike += 360;
    return (strike: strike, dip: dipGrados, dipDir: dipDireccion);
  }

  String _puntoCardinal(double azimut) {
    const direcciones = ['N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE', 'S', 'SSO', 'SO', 'OSO', 'O', 'ONO', 'NO', 'NNO', 'N'];
    final indice = ((azimut / 22.5).round()) % 16;
    return direcciones[indice];
  }

  @override
  Widget build(BuildContext context) {
    final medida = _calcular();
    final tiltCasiVertical = medida.dip > 80;
    final tiltCasiHorizontal = medida.dip < 3;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Orientación del estrato', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'Apoya el teléfono plano sobre la superficie de la capa rocosa, pantalla hacia arriba. Mantén estable y pulsa Capturar.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          _filaDato('Strike (rumbo)', '${medida.strike.toStringAsFixed(0)}°', subtitulo: 'Línea horizontal de la capa'),
          _filaDato('Dip (buzamiento)', '${medida.dip.toStringAsFixed(1)}°', subtitulo: 'Inclinación desde la horizontal'),
          _filaDato('Dirección de dip', '${medida.dipDir.toStringAsFixed(0)}° ${_puntoCardinal(medida.dipDir)}', subtitulo: 'Hacia dónde cae la capa'),
          _filaDato('Brújula (top del móvil)', '${_heading.toStringAsFixed(0)}°', subtitulo: 'Sólo referencia'),
          const SizedBox(height: 12),
          if (tiltCasiHorizontal)
            const Text('⚠ La superficie está casi horizontal — el rumbo será impreciso.', style: TextStyle(color: Colors.orange, fontSize: 12)),
          if (tiltCasiVertical)
            const Text('⚠ Capa casi vertical — usa otra cara para medir mejor.', style: TextStyle(color: Colors.orange, fontSize: 12)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.flag),
                  onPressed: () {
                    Navigator.of(context).pop(MedicionOrientacion(
                      strikeGrados: medida.strike,
                      dipGrados: medida.dip,
                      dipDireccionGrados: medida.dipDir,
                    ));
                  },
                  label: const Text('Capturar'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _filaDato(String etiqueta, String valor, {String? subtitulo}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(etiqueta, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  if (subtitulo != null) Text(subtitulo, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
            Text(valor, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
          ],
        ),
      );
}
