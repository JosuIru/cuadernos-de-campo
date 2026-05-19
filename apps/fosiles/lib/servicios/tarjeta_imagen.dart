import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path_lib;
import 'package:path_provider/path_provider.dart';
import '../modelos/hallazgo.dart';

const double _ancho = 1080;
const double _alto = 1350;
const double _padding = 40;

Future<File> generarTarjetaHallazgo(Hallazgo hallazgo) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final fondo = Paint()..color = const Color(0xFFF5F1E8);
  canvas.drawRect(const Rect.fromLTWH(0, 0, _ancho, _alto), fondo);

  double yActual = _padding;
  if (hallazgo.rutaFoto != null) {
    final foto = await _cargarImagen(File(hallazgo.rutaFoto!));
    if (foto != null) {
      const altoFoto = 720.0;
      final destino = const Rect.fromLTWH(_padding, _padding, _ancho - 2 * _padding, altoFoto);
      final origen = _cuadradoCentrado(foto.width.toDouble(), foto.height.toDouble(), destino.width / destino.height);
      _drawRRectClipped(canvas, destino, 24, () {
        canvas.drawImageRect(foto, origen, destino, Paint());
      });
      yActual = destino.bottom + 32;
    }
  } else {
    final cabecera = const Rect.fromLTWH(_padding, _padding, _ancho - 2 * _padding, 720);
    final paint = Paint()..color = const Color(0xFFD9CFB8);
    _drawRRectClipped(canvas, cabecera, 24, () => canvas.drawRect(cabecera, paint));
    _texto(canvas, '🦴', cabecera.center.dx, cabecera.center.dy - 60, fontSize: 160, alineacion: TextAlign.center, ancho: 200);
    yActual = cabecera.bottom + 32;
  }

  final fecha = DateFormat('dd MMM yyyy', 'es_ES').format(DateTime.fromMillisecondsSinceEpoch(hallazgo.fechaMs));
  yActual = _bloque(canvas, hallazgo.especie.isEmpty ? 'Hallazgo de fósil' : hallazgo.especie, yActual,
      fontSize: 56, peso: FontWeight.bold);
  yActual += 8;
  final subtitulo = [
    if (hallazgo.edad.isNotEmpty) hallazgo.edad,
    if (hallazgo.formacion.isNotEmpty) hallazgo.formacion,
  ].join('  ·  ');
  if (subtitulo.isNotEmpty) {
    yActual = _bloque(canvas, subtitulo, yActual, fontSize: 28, color: const Color(0xFF5E7D3A));
    yActual += 16;
  }
  final coords = '${hallazgo.latitud.toStringAsFixed(5)}, ${hallazgo.longitud.toStringAsFixed(5)}';
  yActual = _bloque(canvas, '📍  $coords  ·  $fecha', yActual, fontSize: 22, color: Colors.black54);
  if (hallazgo.strikeGrados != null && hallazgo.dipGrados != null) {
    yActual = _bloque(canvas, '📐  Estrato ${hallazgo.strikeGrados!.toStringAsFixed(0)}° / ${hallazgo.dipGrados!.toStringAsFixed(0)}°',
        yActual, fontSize: 22, color: Colors.black54);
  }

  _texto(canvas, 'Fósiles · cuaderno de campo', _padding, _alto - _padding - 24, fontSize: 18, color: const Color(0xFF8A8268));

  final picture = recorder.endRecording();
  final imagen = await picture.toImage(_ancho.toInt(), _alto.toInt());
  final pngBytes = await imagen.toByteData(format: ui.ImageByteFormat.png);
  final dir = await getTemporaryDirectory();
  final nombre = 'hallazgo_${hallazgo.id ?? hallazgo.fechaMs}.png';
  final fichero = File(path_lib.join(dir.path, nombre));
  await fichero.writeAsBytes(pngBytes!.buffer.asUint8List());
  return fichero;
}

Future<ui.Image?> _cargarImagen(File archivo) async {
  try {
    final bytes = await archivo.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  } catch (_) {
    return null;
  }
}

Rect _cuadradoCentrado(double anchoOrigen, double altoOrigen, double aspectoDestino) {
  final aspectoOrigen = anchoOrigen / altoOrigen;
  if (aspectoOrigen > aspectoDestino) {
    final nuevoAncho = altoOrigen * aspectoDestino;
    final offsetX = (anchoOrigen - nuevoAncho) / 2;
    return Rect.fromLTWH(offsetX, 0, nuevoAncho, altoOrigen);
  } else {
    final nuevoAlto = anchoOrigen / aspectoDestino;
    final offsetY = (altoOrigen - nuevoAlto) / 2;
    return Rect.fromLTWH(0, offsetY, anchoOrigen, nuevoAlto);
  }
}

void _drawRRectClipped(ui.Canvas canvas, Rect rect, double radio, void Function() pintar) {
  canvas.save();
  canvas.clipRRect(RRect.fromRectAndRadius(rect, Radius.circular(radio)));
  pintar();
  canvas.restore();
}

double _bloque(ui.Canvas canvas, String texto, double y,
    {double fontSize = 28, Color color = Colors.black87, FontWeight peso = FontWeight.normal}) {
  final tp = TextPainter(
    text: TextSpan(text: texto, style: TextStyle(color: color, fontSize: fontSize, fontWeight: peso, height: 1.2)),
    textDirection: ui.TextDirection.ltr,
    maxLines: 4,
  )..layout(maxWidth: _ancho - 2 * _padding);
  tp.paint(canvas, Offset(_padding, y));
  return y + tp.height;
}

void _texto(ui.Canvas canvas, String texto, double x, double y,
    {double fontSize = 24, Color color = Colors.black87, double? ancho, TextAlign alineacion = TextAlign.left}) {
  final tp = TextPainter(
    text: TextSpan(text: texto, style: TextStyle(color: color, fontSize: fontSize)),
    textDirection: ui.TextDirection.ltr,
    textAlign: alineacion,
  )..layout(maxWidth: ancho ?? _ancho);
  tp.paint(canvas, Offset(x - (ancho != null ? ancho / 2 : 0), y));
}

