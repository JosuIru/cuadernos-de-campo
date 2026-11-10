import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';

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
          : formatearNumero(salida.meteoTemperaturaC!, decimales: 1),
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
        title: Text(SoleraL10n.t('nat.mapa_cabecera_salida')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controladorTitulo,
                decoration: InputDecoration(labelText: SoleraL10n.t('nat.mapa_titulo')),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: separacionCamposSolera),
              TextField(
                controller: controladorZona,
                decoration: InputDecoration(labelText: SoleraL10n.t('nat.mapa_zona')),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: separacionCamposSolera),
              TextField(
                controller: controladorMeteo,
                decoration:
                    InputDecoration(labelText: SoleraL10n.t('nat.mapa_meteo_resumen')),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: separacionCamposSolera),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controladorTemperatura,
                      decoration: InputDecoration(
                          labelText: SoleraL10n.t('ques.temperatura_c')),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: controladorAltitud,
                      decoration: InputDecoration(
                          labelText: SoleraL10n.t('nat.mapa_altitud_m')),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: separacionCamposSolera),
              TextField(
                controller: controladorHipotesis,
                decoration: InputDecoration(
                    labelText: SoleraL10n.t('nat.mapa_hipotesis_jornada')),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
              ),
              const SizedBox(height: separacionCamposSolera),
              TextField(
                controller: controladorNotas,
                decoration:
                    InputDecoration(labelText: SoleraL10n.t('nat.mapa_notas_generales')),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 4,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(SoleraL10n.t('cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(SoleraL10n.t('guardar')),
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
        title: Text(SoleraL10n.t('nat.mapa_anotacion_margen')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              SoleraL10n.t('nat.mapa_anotacion_explicacion'),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controladorTexto,
              decoration: InputDecoration(
                labelText: SoleraL10n.t('nat.mapa_texto'),
                hintText: SoleraL10n.t('nat.mapa_anotacion_ejemplo'),
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
            child: Text(SoleraL10n.t('cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(SoleraL10n.t('guardar')),
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
        title: Text(SoleraL10n.t('nat.mapa_borrar_anotacion')),
        content: Text(SoleraL10n.t('nat.mapa_borrar_anotacion_texto')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(SoleraL10n.t('cancelar')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(SoleraL10n.t('borrar')),
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
          title: Text(SoleraL10n.t('nat.mapa_cerrar_salida')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(SoleraL10n.t('nat.mapa_cerrar_salida_texto')),
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
                      Expanded(
                        child: Text(
                          SoleraL10n.t('nat.mapa_detener_track_tambien'),
                          style: const TextStyle(fontSize: 14),
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
              child: Text(SoleraL10n.t('nat.mapa_seguir_abierta')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(innerCtx).pop(true),
              child: Text(SoleraL10n.t('fos.mapa_cerrar')),
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
        title: Text(SoleraL10n.t('nat.mapa_borrar_salida')),
        content: Text(SoleraL10n.t('nat.mapa_borrar_salida_texto')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(SoleraL10n.t('cancelar')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(SoleraL10n.t('borrar')),
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
        body: Center(child: Text(SoleraL10n.t('nat.mapa_salida_no_encontrada'))),
      );
    }
    final fmt = DateFormat('EEEE d MMM y · HH:mm', SoleraL10n.idioma);
    final fechaInicio =
        DateTime.fromMillisecondsSinceEpoch(salida.fechaInicioMs);
    final etiquetaInicio = fmt.format(fechaInicio);
    final titulo = salida.titulo.isNotEmpty
        ? salida.titulo
        : (salida.zona.isNotEmpty ? salida.zona : SoleraL10n.t('nat.mapa_salida_del_dia'));

    return Scaffold(
      appBar: AppBar(
        title: Text(titulo),
        actions: [
          IconButton(
            tooltip: SoleraL10n.t('nat.mapa_editar_cabecera'),
            icon: const Icon(Icons.edit),
            onPressed: _editarCabecera,
          ),
          IconButton(
            tooltip: SoleraL10n.t('nat.mapa_borrar_salida'),
            icon: const Icon(Icons.delete_outline),
            onPressed: _borrarSalida,
          ),
        ],
      ),
      floatingActionButton: salida.enCurso
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.check),
              label: Text(SoleraL10n.t('nat.mapa_cerrar_salida')),
              onPressed: _cerrarSalida,
            )
          : FloatingActionButton.extended(
              icon: const Icon(Icons.edit_note),
              label: Text(SoleraL10n.t('nat.mapa_anotar_margen')),
              onPressed: _aniadirAnotacion,
            ),
      body: ListView(
        padding: rellenoInferiorSeguro(context, const EdgeInsets.fromLTRB(16, 16, 16, 96)),
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
            child: Text(
              SoleraL10n.t('nat.mapa_en_curso'),
              style: const TextStyle(
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
          '${formatearNumero(salida.meteoTemperaturaC!, decimales: 1)} °C',
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
        Text(SoleraL10n.tf('nat.mapa_altitud_aprox', {'n': '${salida.altitudAproximada}'})),
      ]));
    }

    if (salida.hipotesisJornada.isNotEmpty) {
      filas.add(const SizedBox(height: 12));
      filas.add(_bloqueTexto(SoleraL10n.t('nat.mapa_hipotesis_jornada'), salida.hipotesisJornada));
    }
    if (salida.notasGenerales.isNotEmpty) {
      filas.add(const SizedBox(height: 12));
      filas.add(_bloqueTexto(SoleraL10n.t('fos.mapa_notas'), salida.notasGenerales));
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
            ? '${formatearNumero(distancia / 1000, decimales: 2)} km'
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
                      ? SoleraL10n.t('nat.mapa_track_en_curso')
                      : SoleraL10n.t('nat.mapa_track_de_salida'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  estaCorriendoEstaSalida
                      ? SoleraL10n.tf('nat.mapa_track_puntos_asociara',
                          {'n': '${GrabadorTrack.instancia.puntos.length}'})
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
    final fmt = DateFormat('HH:mm', SoleraL10n.idioma);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(SoleraL10n.tf('nat.mapa_observaciones_de_salida', {'n': '${_hallazgos.length}'}),
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        if (_hallazgos.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              SoleraL10n.t('nat.mapa_sin_observaciones_salida'),
              style: const TextStyle(color: Colors.grey),
            ),
          )
        else
          ..._hallazgos.map((h) => Card(
                child: ListTile(
                  leading: Icon(_iconoTipoEvidencia(h.tipoEvidencia)),
                  title: Text(
                    h.nombreComun.isNotEmpty
                        ? h.nombreComun
                        : (h.especie.isNotEmpty ? h.especie : SoleraL10n.t('nat.mapa_sin_especie')),
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
    final fmt = DateFormat('d MMM HH:mm', SoleraL10n.idioma);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(SoleraL10n.t('nat.mapa_anotaciones_margen'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            // Si la salida está abierta, el FAB sirve para cerrarla:
            // este botón inline asegura que también se pueden anotar.
            if (salida.enCurso)
              TextButton.icon(
                onPressed: _aniadirAnotacion,
                icon: const Icon(Icons.add),
                label: Text(SoleraL10n.t('fos.hall_anadir')),
              ),
          ],
        ),
        const SizedBox(height: 4),
        if (_anotaciones.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              SoleraL10n.t('nat.mapa_sin_anotaciones'),
              style: const TextStyle(color: Colors.grey),
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
                        tooltip: SoleraL10n.t('nat.mapa_borrar_anotacion'),
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
