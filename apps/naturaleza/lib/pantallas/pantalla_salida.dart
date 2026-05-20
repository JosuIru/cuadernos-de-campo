import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../datos/base_datos.dart';
import '../modelos/anotacion_diferida.dart';
import '../modelos/hallazgo.dart';
import '../modelos/salida.dart';
import '../modelos/track.dart';
import '../servicios/estado_salida_en_curso.dart';
import '../servicios/grabador_track.dart';

/// Detalle narrativo de una salida: cabecera con datos editables,
/// hallazgos asociados, anotaciones diferidas y botón de cerrar.
class PantallaSalida extends StatefulWidget {
  final int idSalida;
  const PantallaSalida({super.key, required this.idSalida});

  @override
  State<PantallaSalida> createState() => _PantallaSalidaState();
}

class _PantallaSalidaState extends State<PantallaSalida> {
  Salida? _salida;
  List<Hallazgo> _hallazgos = const [];
  List<AnotacionDiferida> _anotaciones = const [];
  Track? _track;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final salida =
        await BaseDatosNaturaleza.instancia.obtenerSalida(widget.idSalida);
    final hallazgos = await BaseDatosNaturaleza.instancia
        .hallazgosDeSalida(widget.idSalida);
    final anotaciones = await BaseDatosNaturaleza.instancia
        .anotacionesDeSalida(widget.idSalida);
    final track =
        await BaseDatosNaturaleza.instancia.trackDeSalida(widget.idSalida);
    if (!mounted) return;
    setState(() {
      _salida = salida;
      _hallazgos = hallazgos;
      _anotaciones = anotaciones;
      _track = track;
      _cargando = false;
    });
  }

  Future<void> _editarCabecera() async {
    final salida = _salida;
    if (salida == null) return;
    final controladorTitulo = TextEditingController(text: salida.titulo);
    final controladorZona = TextEditingController(text: salida.zona);
    final controladorMeteo =
        TextEditingController(text: salida.meteoResumen);
    final controladorTemperatura = TextEditingController(
      text: salida.meteoTemperaturaC == null
          ? ''
          : salida.meteoTemperaturaC!.toStringAsFixed(1),
    );
    final controladorAltitud = TextEditingController(
      text: salida.altitudAproximada?.toString() ?? '',
    );
    final controladorHipotesis =
        TextEditingController(text: salida.hipotesisJornada);
    final controladorNotas =
        TextEditingController(text: salida.notasGenerales);

    final guardado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cabecera de la salida'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controladorTitulo,
                decoration: const InputDecoration(labelText: 'Título'),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controladorZona,
                decoration: const InputDecoration(labelText: 'Zona'),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controladorMeteo,
                decoration:
                    const InputDecoration(labelText: 'Meteo (resumen)'),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controladorTemperatura,
                      decoration: const InputDecoration(
                          labelText: 'Temperatura (°C)'),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: controladorAltitud,
                      decoration: const InputDecoration(
                          labelText: 'Altitud (m)'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controladorHipotesis,
                decoration: const InputDecoration(
                    labelText: 'Hipótesis de jornada'),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controladorNotas,
                decoration:
                    const InputDecoration(labelText: 'Notas generales'),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 4,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (guardado != true || salida.id == null) return;
    final temperatura = double.tryParse(
        controladorTemperatura.text.replaceAll(',', '.'));
    final altitud = int.tryParse(controladorAltitud.text);
    await BaseDatosNaturaleza.instancia.actualizarSalida(salida.id!, {
      'titulo': controladorTitulo.text.trim().isEmpty
          ? null
          : controladorTitulo.text.trim(),
      'zona': controladorZona.text.trim().isEmpty
          ? null
          : controladorZona.text.trim(),
      'meteo_resumen': controladorMeteo.text.trim().isEmpty
          ? null
          : controladorMeteo.text.trim(),
      'meteo_temperatura_c': temperatura,
      'altitud_aproximada': altitud,
      'hipotesis_jornada': controladorHipotesis.text.trim().isEmpty
          ? null
          : controladorHipotesis.text.trim(),
      'notas_generales': controladorNotas.text.trim().isEmpty
          ? null
          : controladorNotas.text.trim(),
    });
    await EstadoSalidaEnCurso.instancia.recargarDesdeBD();
    if (mounted) _cargar();
  }

  Future<void> _aniadirAnotacion() async {
    final salida = _salida;
    if (salida?.id == null) return;
    final controladorTexto = TextEditingController();
    final guardada = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Anotación al margen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Esto es para lo que escribes al revisar la salida días '
              'después: dudas, correcciones, conexiones con otra jornada.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controladorTexto,
              decoration: const InputDecoration(
                labelText: 'Texto',
                hintText: 'p. ej. al final era hembra, no macho',
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 5,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (guardada != true || controladorTexto.text.trim().isEmpty) return;
    final anotacion = AnotacionDiferida(
      fechaAnotacionMs: DateTime.now().millisecondsSinceEpoch,
      salidaId: salida!.id,
      texto: controladorTexto.text.trim(),
    );
    await BaseDatosNaturaleza.instancia.guardarAnotacionDiferida(anotacion);
    if (mounted) _cargar();
  }

  Future<void> _borrarAnotacion(int? idAnotacion) async {
    if (idAnotacion == null) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Borrar anotación'),
        content: const Text(
          'Se borrará esta anotación al margen. La salida y los '
          'hallazgos se mantienen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    await BaseDatosNaturaleza.instancia
        .borrarAnotacionDiferida(idAnotacion);
    if (mounted) _cargar();
  }

  Future<void> _cerrarSalida() async {
    final salida = _salida;
    if (salida?.id == null || salida!.cerrada) return;
    final hayTrackGrabando = GrabadorTrack.instancia.grabando;
    bool detenerTrack = hayTrackGrabando;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (innerCtx, refrescar) => AlertDialog(
          title: const Text('Cerrar salida'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Al cerrar la salida ya no se asociarán hallazgos '
                'nuevos a ella automáticamente. Puedes seguir añadiendo '
                'anotaciones al margen después.',
              ),
              if (hayTrackGrabando) ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: () =>
                      refrescar(() => detenerTrack = !detenerTrack),
                  child: Row(
                    children: [
                      Checkbox(
                        value: detenerTrack,
                        onChanged: (v) =>
                            refrescar(() => detenerTrack = v ?? false),
                      ),
                      const Expanded(
                        child: Text(
                          'Detener también el track GPS en curso',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(innerCtx).pop(false),
              child: const Text('Seguir abierta'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(innerCtx).pop(true),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
    if (confirmar != true) return;

    // Detener track antes de cerrar la salida: así, al guardar el
    // track, pantalla_mapa lee EstadoSalidaEnCurso.salida (aún
    // activa) y le pone el salida_id correcto.
    if (hayTrackGrabando && detenerTrack) {
      final inicioMs = GrabadorTrack.instancia.inicioMs;
      final resultado = GrabadorTrack.instancia.detener();
      if (resultado != null) {
        final trackConSalida = Track(
          fechaMs: resultado.track.fechaMs,
          nombre: resultado.track.nombre,
          duracionMs: resultado.track.duracionMs,
          distanciaMetros: resultado.track.distanciaMetros,
          salidaId: salida.id,
        );
        await BaseDatosNaturaleza.instancia
            .guardarTrack(trackConSalida, resultado.puntos);
        if (inicioMs != null) {
          await GrabadorTrack.instancia.descartarBufferDeSesion(inicioMs);
        }
      }
    }

    await EstadoSalidaEnCurso.instancia.cerrar();
    if (mounted) _cargar();
  }

  Future<void> _borrarSalida() async {
    final salida = _salida;
    if (salida?.id == null) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Borrar salida'),
        content: const Text(
          'Se borrará el contenedor de la salida y sus anotaciones al '
          'margen. Los hallazgos y el track quedarán como sueltos, sin '
          'borrarse.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    await BaseDatosNaturaleza.instancia.borrarSalida(salida!.id!);
    await EstadoSalidaEnCurso.instancia.recargarDesdeBD();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final salida = _salida;
    if (salida == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Salida no encontrada')),
      );
    }
    final fmt = DateFormat('EEEE d MMM y · HH:mm', 'es_ES');
    final fechaInicio =
        DateTime.fromMillisecondsSinceEpoch(salida.fechaInicioMs);
    final etiquetaInicio = fmt.format(fechaInicio);
    final titulo = salida.titulo.isNotEmpty
        ? salida.titulo
        : (salida.zona.isNotEmpty ? salida.zona : 'Salida del día');

    return Scaffold(
      appBar: AppBar(
        title: Text(titulo),
        actions: [
          IconButton(
            tooltip: 'Editar cabecera',
            icon: const Icon(Icons.edit),
            onPressed: _editarCabecera,
          ),
          IconButton(
            tooltip: 'Borrar salida',
            icon: const Icon(Icons.delete_outline),
            onPressed: _borrarSalida,
          ),
        ],
      ),
      floatingActionButton: salida.enCurso
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.check),
              label: const Text('Cerrar salida'),
              onPressed: _cerrarSalida,
            )
          : FloatingActionButton.extended(
              icon: const Icon(Icons.edit_note),
              label: const Text('Anotar al margen'),
              onPressed: _aniadirAnotacion,
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _cabecera(salida, etiquetaInicio),
          const SizedBox(height: 24),
          _seccionTrack(salida),
          const SizedBox(height: 24),
          _seccionHallazgos(),
          const SizedBox(height: 24),
          _seccionAnotaciones(salida),
        ],
      ),
    );
  }

  Widget _cabecera(Salida salida, String etiquetaInicio) {
    final esquema = Theme.of(context).colorScheme;
    final filas = <Widget>[];

    filas.add(Row(
      children: [
        if (salida.enCurso)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'EN CURSO',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        if (salida.enCurso) const SizedBox(width: 8),
        Expanded(
          child: Text(
            etiquetaInicio,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ),
      ],
    ));

    if (salida.zona.isNotEmpty) {
      filas.add(const SizedBox(height: 8));
      filas.add(Row(children: [
        const Icon(Icons.place, size: 16, color: Colors.grey),
        const SizedBox(width: 6),
        Expanded(child: Text(salida.zona)),
      ]));
    }

    if (salida.meteoResumen.isNotEmpty || salida.meteoTemperaturaC != null) {
      final etiquetaMeteo = [
        if (salida.meteoTemperaturaC != null)
          '${salida.meteoTemperaturaC!.toStringAsFixed(1)} °C',
        if (salida.meteoResumen.isNotEmpty) salida.meteoResumen,
      ].join(' · ');
      filas.add(const SizedBox(height: 4));
      filas.add(Row(children: [
        const Icon(Icons.wb_cloudy, size: 16, color: Colors.grey),
        const SizedBox(width: 6),
        Expanded(child: Text(etiquetaMeteo)),
      ]));
    }

    if (salida.altitudAproximada != null) {
      filas.add(const SizedBox(height: 4));
      filas.add(Row(children: [
        const Icon(Icons.terrain, size: 16, color: Colors.grey),
        const SizedBox(width: 6),
        Text('${salida.altitudAproximada} m aprox.'),
      ]));
    }

    if (salida.hipotesisJornada.isNotEmpty) {
      filas.add(const SizedBox(height: 12));
      filas.add(_bloqueTexto('Hipótesis de jornada', salida.hipotesisJornada));
    }
    if (salida.notasGenerales.isNotEmpty) {
      filas.add(const SizedBox(height: 12));
      filas.add(_bloqueTexto('Notas', salida.notasGenerales));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: esquema.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: filas,
      ),
    );
  }

  Widget _bloqueTexto(String titulo, String texto) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Text(texto, style: const TextStyle(fontSize: 13, height: 1.4)),
        ],
      );

  Widget _seccionTrack(Salida salida) {
    final track = _track;
    final estaGrabando = GrabadorTrack.instancia.grabando;
    final estaCorriendoEstaSalida = estaGrabando && salida.enCurso;
    // Sin track persistido y sin grabación en curso: no mostramos
    // nada (la UI no debe ofuscarse con secciones vacías).
    if (track == null && !estaCorriendoEstaSalida) {
      return const SizedBox.shrink();
    }
    final distancia = track?.distanciaMetros;
    final duracionMs = track?.duracionMs;
    final etiquetaDistancia = distancia == null
        ? '—'
        : distancia >= 1000
            ? '${(distancia / 1000).toStringAsFixed(2)} km'
            : '${distancia.round()} m';
    final etiquetaDuracion = duracionMs == null
        ? '—'
        : _formatearDuracion(Duration(milliseconds: duracionMs));
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            estaCorriendoEstaSalida ? Icons.fiber_manual_record : Icons.timeline,
            color: estaCorriendoEstaSalida
                ? Colors.red
                : Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  estaCorriendoEstaSalida
                      ? 'Track GPS en curso'
                      : 'Track GPS de la salida',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  estaCorriendoEstaSalida
                      ? '${GrabadorTrack.instancia.puntos.length} puntos · '
                          'se asociará a la salida al detenerlo'
                      : '$etiquetaDistancia · $etiquetaDuracion',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatearDuracion(Duration duracion) {
    final horas = duracion.inHours;
    final minutos = duracion.inMinutes % 60;
    if (horas > 0) return '${horas}h ${minutos}min';
    return '${minutos}min';
  }

  Widget _seccionHallazgos() {
    final fmt = DateFormat('HH:mm', 'es_ES');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Hallazgos de la salida (${_hallazgos.length})',
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        if (_hallazgos.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Todavía no hay hallazgos en esta salida. Mientras esté '
              'abierta, los que registres se asociarán automáticamente.',
              style: TextStyle(color: Colors.grey),
            ),
          )
        else
          ..._hallazgos.map((h) => Card(
                child: ListTile(
                  leading: Icon(_iconoTipoEvidencia(h.tipoEvidencia)),
                  title: Text(
                    h.nombreComun.isNotEmpty
                        ? h.nombreComun
                        : (h.especie.isNotEmpty ? h.especie : 'Sin especie'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${fmt.format(DateTime.fromMillisecondsSinceEpoch(h.fechaMs))}'
                    ' · ${h.tipoEvidencia.etiqueta}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              )),
      ],
    );
  }

  Widget _seccionAnotaciones(Salida salida) {
    final fmt = DateFormat('d MMM HH:mm', 'es_ES');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Anotaciones al margen',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            // Si la salida está abierta, el FAB sirve para cerrarla:
            // este botón inline asegura que también se pueden anotar.
            if (salida.enCurso)
              TextButton.icon(
                onPressed: _aniadirAnotacion,
                icon: const Icon(Icons.add),
                label: const Text('Añadir'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        if (_anotaciones.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Sin anotaciones todavía. Úsalas para revisar la salida '
              'días después: dudas, correcciones, conexiones.',
              style: TextStyle(color: Colors.grey),
            ),
          )
        else
          ..._anotaciones.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 3),
                    ),
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fmt.format(DateTime.fromMillisecondsSinceEpoch(
                                  a.fechaAnotacionMs)),
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            Text(a.texto,
                                style: const TextStyle(
                                    fontSize: 14, height: 1.4)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            size: 18, color: Colors.grey),
                        tooltip: 'Borrar anotación',
                        onPressed: () => _borrarAnotacion(a.id),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                            minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
                ),
              )),
      ],
    );
  }

  IconData _iconoTipoEvidencia(TipoEvidencia tipo) {
    switch (tipo) {
      case TipoEvidencia.avistamiento:
        return Icons.visibility;
      case TipoEvidencia.huella:
        return Icons.pets;
      case TipoEvidencia.pluma:
        return Icons.air;
      case TipoEvidencia.excremento:
        return Icons.circle_outlined;
      case TipoEvidencia.restosAlimentacion:
        return Icons.set_meal;
      case TipoEvidencia.marcaCorteza:
        return Icons.park;
      case TipoEvidencia.nidoVacio:
        return Icons.egg;
      case TipoEvidencia.refugio:
        return Icons.house_outlined;
      case TipoEvidencia.sonido:
        return Icons.graphic_eq;
      case TipoEvidencia.interaccion:
        return Icons.compare_arrows;
    }
  }
}
