import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:sensors_plus/sensors_plus.dart';

class MedicionOrientacion {
  final double strikeGrados;
  final double dipGrados;
  final double dipDireccionGrados;
  MedicionOrientacion({required this.strikeGrados, required this.dipGrados, required this.dipDireccionGrados});
}

Future<MedicionOrientacion?> mostrarModalOrientacion(BuildContext context) {
  return showModalBottomSheet<MedicionOrientacion?>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ModalOrientacion(),
  );
}

class _ModalOrientacion extends StatefulWidget {
  _ModalOrientacion();

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
    _subAccel = accelerometerEventStream(samplingPeriod: Duration(milliseconds: 100)).listen((evento) {
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
    final direcciones = SoleraL10n.t('fos.mapa_rosa_vientos').split(',');
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
          Text(SoleraL10n.t('fos.mapa_orientacion_estrato'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text(
            SoleraL10n.t('fos.mapa_orientacion_instrucciones'),
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          SizedBox(height: 16),
          _filaDato(SoleraL10n.t('fos.mapa_strike'), '${medida.strike.toStringAsFixed(0)}°', subtitulo: SoleraL10n.t('fos.mapa_strike_ayuda')),
          _filaDato(SoleraL10n.t('fos.mapa_dip'), '${formatearNumero(medida.dip, decimales: 1)}°', subtitulo: SoleraL10n.t('fos.mapa_dip_ayuda')),
          _filaDato(SoleraL10n.t('fos.mapa_direccion_dip'), '${medida.dipDir.toStringAsFixed(0)}° ${_puntoCardinal(medida.dipDir)}', subtitulo: SoleraL10n.t('fos.mapa_direccion_dip_ayuda')),
          _filaDato(SoleraL10n.t('fos.mapa_brujula'), '${_heading.toStringAsFixed(0)}°', subtitulo: SoleraL10n.t('fos.mapa_solo_referencia')),
          SizedBox(height: 12),
          if (tiltCasiHorizontal)
            Text(SoleraL10n.t('fos.mapa_aviso_casi_horizontal'), style: TextStyle(color: Colors.orange, fontSize: 12)),
          if (tiltCasiVertical)
            Text(SoleraL10n.t('fos.mapa_aviso_casi_vertical'), style: TextStyle(color: Colors.orange, fontSize: 12)),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: Text(SoleraL10n.t('cancelar')),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  icon: Icon(Icons.flag),
                  onPressed: () {
                    Navigator.of(context).pop(MedicionOrientacion(
                      strikeGrados: medida.strike,
                      dipGrados: medida.dip,
                      dipDireccionGrados: medida.dipDir,
                    ));
                  },
                  label: Text(SoleraL10n.t('fos.mapa_capturar')),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
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
                  Text(etiqueta, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  if (subtitulo != null) Text(subtitulo, style: TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
            Text(valor, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
          ],
        ),
      );
}
