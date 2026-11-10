import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import '../datos/base_datos.dart';
import '../modelos/hallazgo.dart';

/// Muestra el diálogo para añadir un evento de trazabilidad al hallazgo.
/// Devuelve true si se añadió un evento (para que el caller refresque).
Future<bool> mostrarDialogoAnadirTrazabilidad(
  BuildContext context,
  Hallazgo hallazgo,
  String nombreDescubridor,
) async {
  final controladorDesc = TextEditingController();
  final controladorAutor = TextEditingController();
  String tipoSeleccionado = EventoTrazabilidad.tiposDisponibles.first.$1;
  controladorAutor.text = nombreDescubridor;

  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (_, setStateDialog) => AlertDialog(
        title: Text(SoleraL10n.t('fos.hall_anadir_evento_trazabilidad')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value: tipoSeleccionado,
                decoration: InputDecoration(
                    labelText: SoleraL10n.t('fos.hall_tipo_evento'), border: const OutlineInputBorder()),
                items: EventoTrazabilidad.tiposDisponibles
                    .map((t) => DropdownMenuItem(value: t.$1, child: Text(SoleraL10n.t(t.$2))))
                    .toList(),
                onChanged: (v) => setStateDialog(() => tipoSeleccionado = v!),
              ),
              const SizedBox(height: separacionCamposSolera),
              TextField(
                controller: controladorDesc,
                decoration: InputDecoration(
                  labelText: SoleraL10n.t('fos.hall_descripcion'),
                  border: const OutlineInputBorder(),
                  hintText: SoleraL10n.t('fos.hall_ejemplo_descripcion'),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: separacionCamposSolera),
              TextField(
                controller: controladorAutor,
                decoration: InputDecoration(
                  labelText: SoleraL10n.t('fos.hall_autor_evento'),
                  border: const OutlineInputBorder(),
                  hintText: SoleraL10n.t('fos.hall_ejemplo_autor'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(SoleraL10n.t('cancelar'))),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(SoleraL10n.t('fos.hall_anadir')),
          ),
        ],
      ),
    ),
  );
  if (ok != true) return false;

  final desc = controladorDesc.text.trim();
  final autor = controladorAutor.text.trim();
  if (desc.isEmpty) return false;

  final evento = EventoTrazabilidad(
    fechaMs: DateTime.now().millisecondsSinceEpoch,
    tipo: tipoSeleccionado,
    descripcion: desc,
    autor: autor.isEmpty ? nombreDescubridor : autor,
  );
  final nuevoHistorial = [...hallazgo.historialTrazabilidad, evento];
  await BaseDatosFosiles.instancia.actualizarHallazgo(hallazgo.id!, {
    'trazabilidad_json':
        jsonEncode(nuevoHistorial.map((e) => e.toJson()).toList()),
  });
  return true;
}

/// Tarjeta visual para un evento de trazabilidad en la ficha del hallazgo.
Widget tarjetaEventoTrazabilidad(EventoTrazabilidad e) {
  final (icono, color) = switch (e.tipo) {
    'deposito_museo' => (Icons.museum, Colors.brown),
    'estudio' => (Icons.science, Colors.indigo),
    'publicacion' => (Icons.article, Colors.teal),
    'prestamo' => (Icons.swap_horiz, Colors.orange),
    _ => (Icons.circle_notifications, Colors.grey),
  };
  final fecha = DateTime.fromMillisecondsSinceEpoch(e.fechaMs);
  final fechaStr =
      '${fecha.day}/${fecha.month}/${fecha.year} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e.descripcion, style: const TextStyle(fontSize: 13)),
              Text('$fechaStr · ${e.autor}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ],
          ),
        ),
      ],
    ),
  );
}
