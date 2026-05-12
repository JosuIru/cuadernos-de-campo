import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class TrazoAnotacion {
  final Color color;
  final double grosor;
  final List<Offset> puntos;
  TrazoAnotacion({required this.color, required this.grosor, required this.puntos});
}

class PantallaAnotarFoto extends StatefulWidget {
  final File archivoFoto;
  const PantallaAnotarFoto({super.key, required this.archivoFoto});

  @override
  State<PantallaAnotarFoto> createState() => _PantallaAnotarFotoState();
}

class _PantallaAnotarFotoState extends State<PantallaAnotarFoto> {
  final _claveLienzo = GlobalKey();
  final List<TrazoAnotacion> _trazos = [];
  Color _colorActual = Colors.red;
  double _grosorActual = 8;
  bool _guardando = false;
  ui.Image? _imagenOriginal;
  Size? _tamanoMostrado;

  @override
  void initState() {
    super.initState();
    _cargarImagenOriginal();
  }

  Future<void> _cargarImagenOriginal() async {
    final bytes = await widget.archivoFoto.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    if (!mounted) return;
    setState(() => _imagenOriginal = frame.image);
  }

  void _iniciarTrazo(Offset punto) {
    setState(() => _trazos.add(TrazoAnotacion(color: _colorActual, grosor: _grosorActual, puntos: [punto])));
  }

  void _continuarTrazo(Offset punto) {
    if (_trazos.isEmpty) return;
    setState(() => _trazos.last.puntos.add(punto));
  }

  Future<void> _guardar() async {
    if (_imagenOriginal == null || _tamanoMostrado == null) return;
    setState(() => _guardando = true);
    try {
      final original = _imagenOriginal!;
      final mostrado = _tamanoMostrado!;
      final escalaX = original.width / mostrado.width;
      final escalaY = original.height / mostrado.height;
      final escala = (escalaX + escalaY) / 2;

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawImage(original, Offset.zero, Paint());
      for (final trazo in _trazos) {
        final paint = Paint()
          ..color = trazo.color
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = trazo.grosor * escala
          ..style = PaintingStyle.stroke;
        if (trazo.puntos.isEmpty) continue;
        if (trazo.puntos.length == 1) {
          final p = trazo.puntos.first;
          canvas.drawCircle(Offset(p.dx * escalaX, p.dy * escalaY), (trazo.grosor * escala) / 2, paint..style = PaintingStyle.fill);
          continue;
        }
        final path = Path();
        final p0 = trazo.puntos.first;
        path.moveTo(p0.dx * escalaX, p0.dy * escalaY);
        for (var i = 1; i < trazo.puntos.length; i++) {
          final p = trazo.puntos[i];
          path.lineTo(p.dx * escalaX, p.dy * escalaY);
        }
        canvas.drawPath(path, paint);
      }

      final picture = recorder.endRecording();
      final imagen = await picture.toImage(original.width, original.height);
      final bytes = await imagen.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw Exception('No se pudo codificar la imagen');
      await widget.archivoFoto.writeAsBytes(bytes.buffer.asUint8List());
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error guardando: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Anotar foto'),
        actions: [
          if (_trazos.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: 'Deshacer',
              onPressed: () => setState(() => _trazos.removeLast()),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Limpiar',
            onPressed: _trazos.isEmpty ? null : () => setState(_trazos.clear),
          ),
          TextButton(
            onPressed: (_guardando || _imagenOriginal == null) ? null : _guardar,
            child: _guardando
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _imagenOriginal == null
                  ? const CircularProgressIndicator()
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final original = _imagenOriginal!;
                        final aspect = original.width / original.height;
                        double w = constraints.maxWidth;
                        double h = w / aspect;
                        if (h > constraints.maxHeight) {
                          h = constraints.maxHeight;
                          w = h * aspect;
                        }
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_tamanoMostrado != Size(w, h)) {
                            setState(() => _tamanoMostrado = Size(w, h));
                          }
                        });
                        return SizedBox(
                          width: w,
                          height: h,
                          child: GestureDetector(
                            onPanStart: (d) => _iniciarTrazo(d.localPosition),
                            onPanUpdate: (d) => _continuarTrazo(d.localPosition),
                            child: Stack(
                              key: _claveLienzo,
                              fit: StackFit.expand,
                              children: [
                                Image.file(widget.archivoFoto, fit: BoxFit.fill),
                                CustomPaint(painter: _PintorAnotaciones(_trazos)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          Container(
            color: Colors.black87,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                ...[Colors.red, Colors.yellow, Colors.lightGreenAccent, Colors.lightBlueAccent, Colors.white, Colors.black].map((c) => GestureDetector(
                      onTap: () => setState(() => _colorActual = c),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(color: _colorActual == c ? Colors.white : Colors.grey, width: _colorActual == c ? 3 : 1),
                        ),
                      ),
                    )),
                const SizedBox(width: 12),
                Expanded(
                  child: Slider(
                    value: _grosorActual,
                    min: 2,
                    max: 24,
                    divisions: 11,
                    label: '${_grosorActual.round()} px',
                    onChanged: (v) => setState(() => _grosorActual = v),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PintorAnotaciones extends CustomPainter {
  final List<TrazoAnotacion> trazos;
  _PintorAnotaciones(this.trazos);

  @override
  void paint(Canvas canvas, Size size) {
    for (final trazo in trazos) {
      final paint = Paint()
        ..color = trazo.color
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = trazo.grosor
        ..style = PaintingStyle.stroke;
      if (trazo.puntos.length < 2) {
        if (trazo.puntos.isNotEmpty) {
          canvas.drawCircle(trazo.puntos.first, trazo.grosor / 2, paint..style = PaintingStyle.fill);
        }
        continue;
      }
      final path = Path()..moveTo(trazo.puntos.first.dx, trazo.puntos.first.dy);
      for (var i = 1; i < trazo.puntos.length; i++) {
        path.lineTo(trazo.puntos[i].dx, trazo.puntos[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PintorAnotaciones oldDelegate) => true;
}
