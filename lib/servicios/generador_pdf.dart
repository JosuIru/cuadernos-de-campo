import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../modelos/track.dart';
import '../modelos/hallazgo.dart';

Future<List<int>> generarPdfSalida({
  required Track track,
  required List<TrackPunto> puntos,
  required List<Hallazgo> hallazgosEnRango,
}) async {
  final pdf = pw.Document();
  final fecha = DateTime.fromMillisecondsSinceEpoch(track.fechaMs);
  final duracion = Duration(milliseconds: track.duracionMs ?? 0);
  final distanciaMetros = track.distanciaMetros ?? 0;

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (context) => [
        pw.Header(
          level: 0,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Informe de salida', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
              pw.Text(track.nombre.isEmpty ? 'Track sin nombre' : track.nombre, style: const pw.TextStyle(fontSize: 14)),
            ],
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          columnWidths: const {0: pw.IntrinsicColumnWidth(), 1: pw.FlexColumnWidth()},
          children: [
            _filaTabla('Fecha', _formatearFecha(fecha)),
            _filaTabla('Duración', _formatearDuracion(duracion)),
            _filaTabla('Distancia', '${(distanciaMetros / 1000).toStringAsFixed(2)} km'),
            _filaTabla('Puntos GPS', '${puntos.length}'),
            _filaTabla('Hallazgos en el rango', '${hallazgosEnRango.length}'),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Header(level: 1, text: 'Hallazgos'),
        if (hallazgosEnRango.isEmpty)
          pw.Text('Sin hallazgos registrados durante este track.', style: pw.TextStyle(fontStyle: pw.FontStyle.italic))
        else
          for (final h in hallazgosEnRango) _bloqueHallazgo(h),
        pw.SizedBox(height: 16),
        pw.Header(level: 1, text: 'Recorrido'),
        if (puntos.isNotEmpty) _bloquePuntos(puntos),
      ],
    ),
  );
  return pdf.save();
}

pw.TableRow _filaTabla(String etiqueta, String valor) {
  return pw.TableRow(children: [
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: pw.Text(etiqueta, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
    ),
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: pw.Text(valor),
    ),
  ]);
}

pw.Widget _bloqueHallazgo(Hallazgo h) {
  final fecha = DateTime.fromMillisecondsSinceEpoch(h.fechaMs);
  return pw.Container(
    margin: const pw.EdgeInsets.symmetric(vertical: 4),
    padding: const pw.EdgeInsets.all(6),
    decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5), borderRadius: pw.BorderRadius.circular(4)),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(children: [
          pw.Expanded(
            child: pw.Text(
              h.nombreComun.isNotEmpty
                  ? h.nombreComun
                  : (h.especie.isNotEmpty ? h.especie : '(sin nombre)'),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Text(_formatearFecha(fecha), style: const pw.TextStyle(fontSize: 10)),
        ]),
        pw.Text('Categoría: ${h.categoria}', style: const pw.TextStyle(fontSize: 10)),
        if (h.especie.isNotEmpty && h.especie != h.nombreComun)
          pw.Text('Nombre científico: ${h.especie}', style: const pw.TextStyle(fontSize: 10)),
        if (h.taxonomia.isNotEmpty) pw.Text('Taxonomía: ${h.taxonomia}', style: const pw.TextStyle(fontSize: 10)),
        if (h.habitat.isNotEmpty) pw.Text('Hábitat: ${h.habitat}', style: const pw.TextStyle(fontSize: 10)),
        pw.Text('Coords: ${h.latitud.toStringAsFixed(5)}, ${h.longitud.toStringAsFixed(5)}', style: const pw.TextStyle(fontSize: 10)),
        if (h.notas.isNotEmpty) pw.Padding(padding: const pw.EdgeInsets.only(top: 2), child: pw.Text(h.notas, style: const pw.TextStyle(fontSize: 11))),
        if (h.rutasFotos.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final ruta in h.rutasFotos) _miniaturaFoto(ruta),
              ],
            ),
          ),
      ],
    ),
  );
}

pw.Widget _miniaturaFoto(String ruta) {
  try {
    final archivo = File(ruta);
    if (!archivo.existsSync()) return pw.SizedBox.shrink();
    final bytes = archivo.readAsBytesSync();
    return pw.ClipRRect(
      horizontalRadius: 4,
      verticalRadius: 4,
      child: pw.Image(pw.MemoryImage(bytes), width: 120, height: 90, fit: pw.BoxFit.cover),
    );
  } catch (_) {
    return pw.SizedBox.shrink();
  }
}

pw.Widget _bloquePuntos(List<TrackPunto> puntos) {
  final muestreo = puntos.length > 50 ? (puntos.length / 50).ceil() : 1;
  final filas = <pw.TableRow>[
    pw.TableRow(children: [
      pw.Text('Hora', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
      pw.Text('Latitud', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
      pw.Text('Longitud', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
      pw.Text('Alt', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
    ]),
  ];
  for (var i = 0; i < puntos.length; i += muestreo) {
    final p = puntos[i];
    final fecha = DateTime.fromMillisecondsSinceEpoch(p.fechaMs);
    filas.add(pw.TableRow(children: [
      pw.Text(_formatearHora(fecha), style: const pw.TextStyle(fontSize: 9)),
      pw.Text(p.latitud.toStringAsFixed(5), style: const pw.TextStyle(fontSize: 9)),
      pw.Text(p.longitud.toStringAsFixed(5), style: const pw.TextStyle(fontSize: 9)),
      pw.Text(p.altitud == null ? '-' : '${p.altitud!.toStringAsFixed(0)} m', style: const pw.TextStyle(fontSize: 9)),
    ]));
  }
  return pw.Table(border: pw.TableBorder.all(width: 0.3), children: filas);
}

String _formatearFecha(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year} ${_formatearHora(f)}';

String _formatearHora(DateTime f) =>
    '${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';

String _formatearDuracion(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  return '${h}h ${m}m';
}
