import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import 'package:path/path.dart' as path_lib;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../datos/base_datos.dart';
import '../servicios/cache_teselas.dart';
import '../servicios/hallazgos_desde_sesion.dart';
import '../sonido/clasificacion_sonido.dart';
import '../sonido/registro_sesion_sonora.dart';
import 'pantalla_mapa.dart' show capasBaseDisponibles;
import 'widgets/reproductor_clip.dart';

/// Resumen de una sesión larga: en un recorrido, el mapa con la traza y las
/// detecciones; en un coro, la actividad por franjas de 15 minutos y la
/// primera detección de cada especie. En los dos, la lista por especie con
/// su mejor clip, «Guardar como hallazgos», el resumen en texto y el CSV.
class PantallaResumenSesionSonora extends StatefulWidget {
  final int sesionId;

  const PantallaResumenSesionSonora({super.key, required this.sesionId});

  @override
  State<PantallaResumenSesionSonora> createState() => _PantallaResumenSesionSonoraState();
}

class _PantallaResumenSesionSonoraState extends State<PantallaResumenSesionSonora> {
  SesionSonora? _sesion;
  List<DeteccionSonora> _detecciones = const [];
  bool _cargando = true;
  bool _soloProbables = false;
  String? _especieResaltada;
  bool _eligiendo = false;
  final Set<String> _elegidas = {};
  bool _guardando = false;
  int? _franjaElegida;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final baseDatos = BaseDatosNaturaleza.instancia;
    final sesion = await baseDatos.obtenerSesionSonora(widget.sesionId);
    final detecciones = await baseDatos.deteccionesDeSesion(widget.sesionId);
    if (!mounted) return;
    setState(() {
      _sesion = sesion;
      _detecciones = detecciones;
      _cargando = false;
    });
  }

  List<DeteccionSonora> get _deteccionesVisibles => _soloProbables
      ? _detecciones.where((deteccion) => deteccion.nivel == NivelConfianzaSonido.probable).toList()
      : _detecciones;

  DateTime _finEfectivo(SesionSonora sesion) =>
      sesion.fin ??
      (_detecciones.isEmpty ? sesion.inicio : DateTime.fromMillisecondsSinceEpoch(_detecciones.last.momentoMs));

  String _hora(DateTime momento) => DateFormat('HH:mm', SoleraL10n.idioma).format(momento);

  String _duracion(Duration duracion) {
    final horas = duracion.inHours;
    final minutos = duracion.inMinutes % 60;
    return horas > 0 ? '$horas h ${minutos.toString().padLeft(2, '0')} min' : '$minutos min';
  }

  String _nombre(ResumenEspecieSesion especie) =>
      especie.nombreComun.isNotEmpty ? especie.nombreComun : especie.etiqueta.replaceAll('_', ' ');

  String _nivel(NivelConfianzaSonido nivel) => switch (nivel) {
        NivelConfianzaSonido.probable => SoleraL10n.t('nat.son_nivel_probable'),
        NivelConfianzaSonido.posible => SoleraL10n.t('nat.son_nivel_posible'),
        NivelConfianzaSonido.dudoso => SoleraL10n.t('nat.son_nivel_dudoso'),
      };

  // ------------------------------------------------------------ Acciones

  Future<void> _guardarComoHallazgos(List<ResumenEspecieSesion> especies) async {
    final sesion = _sesion;
    if (sesion == null || _elegidas.isEmpty) return;
    setState(() => _guardando = true);
    try {
      final elegidas = especies.where((especie) => _elegidas.contains(especie.etiqueta)).toList();
      final guardados = await guardarEspeciesComoHallazgos(sesion, elegidas);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(SoleraL10n.tf('nat.ses_hallazgos_guardados', {'n': guardados})),
      ));
      setState(() {
        _eligiendo = false;
        _elegidas.clear();
      });
      await _cargar();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(SoleraL10n.tf('nat.hall_error_guardar_hallazgo', {'error': error}))),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  String _textoResumen(SesionSonora sesion, List<ResumenEspecieSesion> especies, List<FranjaActividad> franjas) {
    final fin = _finEfectivo(sesion);
    final formatoFecha = DateFormat('d MMM yyyy', SoleraL10n.idioma);
    final esRecorrido = sesion.tipo == TipoSesionSonora.recorrido;
    final salida = StringBuffer()
      ..writeln(
          '${SoleraL10n.t(esRecorrido ? 'nat.ses_modo_recorrido' : 'nat.ses_modo_coro')} · ${formatoFecha.format(sesion.inicio)}, ${_hora(sesion.inicio)}–${_hora(fin)} (${_duracion(fin.difference(sesion.inicio))})')
      ..writeln(SoleraL10n.tf('nat.ses_estado_detecciones', {
        'detecciones': _deteccionesVisibles.length,
        'especies': especies.length,
      }));
    if (esRecorrido && sesion.traza.length > 1) {
      salida.writeln(SoleraL10n.tf('nat.ses_distancia', {'metros': distanciaTrazaMetros(sesion.traza).round()}));
    }
    salida
      ..writeln()
      ..writeln(SoleraL10n.t('nat.ses_primera_deteccion'));
    for (final especie in especies) {
      salida.writeln(
          '${_hora(especie.primera.momento)} · ${_nombre(especie)} (${especie.etiqueta.replaceAll('_', ' ')}) · ${especie.numeroDetecciones}× · ${_nivel(especie.nivelMejor)}');
    }
    if (!esRecorrido) {
      salida
        ..writeln()
        ..writeln(SoleraL10n.t('nat.ses_por_franjas'));
      final porEtiqueta = {for (final especie in especies) especie.etiqueta: especie};
      for (final franja in franjas) {
        final nombres = [
          for (final etiqueta in franja.especiesPorDetecciones)
            if (porEtiqueta[etiqueta] case final especie?) _nombre(especie),
        ];
        salida.writeln(
            '${_hora(franja.inicio)}–${_hora(franja.fin)} · ${SoleraL10n.tf('nat.ses_franja_resumen', {'detecciones': franja.numeroDetecciones, 'especies': franja.numeroEspecies})}${nombres.isEmpty ? '' : ': ${nombres.join(', ')}'}');
      }
    }
    salida
      ..writeln()
      ..writeln(SoleraL10n.t('nat.ses_pie_resumen'));
    return salida.toString();
  }

  Future<void> _compartirTexto(SesionSonora sesion, List<ResumenEspecieSesion> especies, List<FranjaActividad> franjas) async {
    await Share.share(_textoResumen(sesion, especies, franjas), subject: SoleraL10n.t('nat.ses_asunto'));
  }

  Future<void> _exportarCsv(SesionSonora sesion) async {
    try {
      final temporal = await getTemporaryDirectory();
      final marca = DateFormat('yyyyMMdd_HHmm').format(sesion.inicio);
      final fichero = File(path_lib.join(temporal.path, 'naturaleza_${sesion.tipo.clave}_$marca.csv'));
      await fichero.writeAsString(
        csvDeteccionesSesion(sesion, _deteccionesVisibles, nombreFicheroClip: path_lib.basename),
        flush: true,
      );
      await Share.shareXFiles([XFile(fichero.path, mimeType: 'text/csv')], subject: SoleraL10n.t('nat.ses_asunto'));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _borrarSesion() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contextoDialogo) => AlertDialog(
        title: Text(SoleraL10n.t('nat.ses_borrar_titulo')),
        content: Text(SoleraL10n.t('nat.ses_borrar_texto')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contextoDialogo, false), child: Text(SoleraL10n.t('cancelar'))),
          FilledButton(onPressed: () => Navigator.pop(contextoDialogo, true), child: Text(SoleraL10n.t('borrar'))),
        ],
      ),
    );
    if (confirmado != true) return;
    await BaseDatosNaturaleza.instancia.borrarSesionSonora(widget.sesionId);
    if (mounted) Navigator.of(context).pop();
  }

  // ---------------------------------------------------------------- Vista

  @override
  Widget build(BuildContext context) {
    final sesion = _sesion;
    if (_cargando) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    if (sesion == null) {
      return Scaffold(appBar: AppBar(), body: Center(child: Text(SoleraL10n.t('nat.ses_no_encontrada'))));
    }
    final visibles = _deteccionesVisibles;
    final especies = agruparDeteccionesPorEspecie(visibles);
    final franjas = franjasDeActividad(visibles, inicio: sesion.inicio, fin: _finEfectivo(sesion));
    final esRecorrido = sesion.tipo == TipoSesionSonora.recorrido;
    return Scaffold(
      appBar: AppBar(
        title: Text(SoleraL10n.t(esRecorrido ? 'nat.ses_resumen_recorrido' : 'nat.ses_resumen_coro')),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: SoleraL10n.t('nat.ses_compartir_texto'),
            onPressed: () => _compartirTexto(sesion, especies, franjas),
          ),
          PopupMenuButton<String>(
            onSelected: (valor) {
              if (valor == 'csv') _exportarCsv(sesion);
              if (valor == 'borrar') _borrarSesion();
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'csv', child: Text(SoleraL10n.t('nat.ses_exportar_csv'))),
              PopupMenuItem(value: 'borrar', child: Text(SoleraL10n.t('nat.ses_borrar_titulo'))),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: rellenoInferiorSeguro(context, const EdgeInsets.all(16)),
        children: [
          _tarjetaCabecera(sesion, especies),
          if (esRecorrido) ...[
            const SizedBox(height: 12),
            _tarjetaMapa(sesion, visibles),
          ] else ...[
            const SizedBox(height: 12),
            _tarjetaActividad(franjas, especies),
          ],
          const SizedBox(height: 12),
          _tarjetaEspecies(sesion, especies),
        ],
      ),
    );
  }

  Widget _tarjetaCabecera(SesionSonora sesion, List<ResumenEspecieSesion> especies) {
    final tema = Theme.of(context).textTheme;
    final fin = _finEfectivo(sesion);
    final formatoFecha = DateFormat('EEEE d MMM yyyy', SoleraL10n.idioma);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(formatoFecha.format(sesion.inicio), style: tema.titleMedium),
            Text('${_hora(sesion.inicio)}–${_hora(fin)} · ${_duracion(fin.difference(sesion.inicio))}'),
            const SizedBox(height: 4),
            Text(SoleraL10n.tf('nat.ses_estado_detecciones', {
              'detecciones': _deteccionesVisibles.length,
              'especies': especies.length,
            })),
            if (sesion.tipo == TipoSesionSonora.recorrido && sesion.traza.length > 1)
              Text(SoleraL10n.tf('nat.ses_distancia', {'metros': distanciaTrazaMetros(sesion.traza).round()})),
            if (!sesion.terminada)
              Text(SoleraL10n.t('nat.ses_sin_terminar'), style: tema.bodySmall),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(SoleraL10n.t('nat.ses_solo_probables')),
              value: _soloProbables,
              onChanged: (valor) => setState(() => _soloProbables = valor),
            ),
            Text(SoleraL10n.t('nat.ses_aviso_orientativo'), style: tema.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaMapa(SesionSonora sesion, List<DeteccionSonora> detecciones) {
    final colores = Theme.of(context).colorScheme;
    final traza = [for (final punto in sesion.traza) LatLng(punto.latitud, punto.longitud)];
    // Una marca por especie y punto de la traza (no una por trozo de 5 s).
    final marcas = <String, DeteccionSonora>{};
    for (final deteccion in detecciones) {
      if (!deteccion.tienePosicion) continue;
      marcas.putIfAbsent('${deteccion.etiqueta}|${deteccion.indicePuntoTraza}', () => deteccion);
    }
    final puntos = [...traza, for (final marca in marcas.values) LatLng(marca.latitud!, marca.longitud!)];
    if (puntos.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(SoleraL10n.t('nat.ses_sin_traza')),
        ),
      );
    }
    final capa = capasBaseDisponibles.first;
    final resaltada = _especieResaltada;
    final ordenadas = marcas.values.toList()
      ..sort((a, b) => (a.etiqueta == resaltada ? 1 : 0).compareTo(b.etiqueta == resaltada ? 1 : 0));
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 300,
            child: FlutterMap(
              options: MapOptions(
                initialCameraFit: puntos.length == 1
                    ? null
                    : CameraFit.bounds(
                        bounds: LatLngBounds.fromPoints(puntos), padding: const EdgeInsets.all(32), maxZoom: 18),
                initialCenter: puntos.first,
                initialZoom: 16,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom | InteractiveFlag.pinchMove,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: capa.urlPlantilla,
                  maxZoom: capa.maxZoom.toDouble(),
                  tileProvider: TileProviderConCache(),
                  userAgentPackageName: 'com.josu.naturaleza',
                ),
                if (traza.length > 1)
                  PolylineLayer(polylines: [Polyline(points: traza, strokeWidth: 3, color: colores.primary)]),
                MarkerLayer(markers: [
                  for (final marca in ordenadas)
                    Marker(
                      point: LatLng(marca.latitud!, marca.longitud!),
                      width: marca.etiqueta == resaltada ? 22 : 14,
                      height: marca.etiqueta == resaltada ? 22 : 14,
                      child: GestureDetector(
                        onTap: () => setState(() => _especieResaltada = marca.etiqueta),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: resaltada == null || marca.etiqueta == resaltada
                                ? colores.tertiary
                                : colores.outline.withValues(alpha: 0.6),
                            border: Border.all(color: colores.surface, width: 2),
                          ),
                        ),
                      ),
                    ),
                ]),
                RichAttributionWidget(attributions: [TextSourceAttribution(capa.atribucion)]),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              resaltada == null
                  ? SoleraL10n.t('nat.ses_mapa_ayuda')
                  : SoleraL10n.tf('nat.ses_mapa_resaltada', {
                      'nombre': agruparDeteccionesPorEspecie(
                              detecciones.where((deteccion) => deteccion.etiqueta == resaltada))
                          .map(_nombre)
                          .firstOrNull ??
                          resaltada,
                    }),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaActividad(List<FranjaActividad> franjas, List<ResumenEspecieSesion> especies) {
    final tema = Theme.of(context).textTheme;
    final colores = Theme.of(context).colorScheme;
    final maximo = franjas.fold<int>(0, (actual, franja) => franja.numeroDetecciones > actual ? franja.numeroDetecciones : actual);
    final porEtiqueta = {for (final especie in especies) especie.etiqueta: especie};
    final elegida = _franjaElegida != null && _franjaElegida! < franjas.length ? franjas[_franjaElegida!] : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(SoleraL10n.t('nat.ses_actividad'), style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(SoleraL10n.t('nat.ses_actividad_ayuda'), style: tema.bodySmall),
            const SizedBox(height: 12),
            Semantics(
              label: SoleraL10n.t('nat.ses_actividad'),
              child: SizedBox(
                height: 140,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var indice = 0; indice < franjas.length; indice++)
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _franjaElegida = _franjaElegida == indice ? null : indice),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: FractionallySizedBox(
                                    heightFactor: maximo == 0 ? 0 : franjas[indice].numeroDetecciones / maximo,
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 1),
                                      decoration: BoxDecoration(
                                        color: _franjaElegida == null || _franjaElegida == indice
                                            ? colores.primary
                                            : colores.primary.withValues(alpha: 0.35),
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Container(height: 1, color: colores.outlineVariant),
                              SizedBox(
                                height: 16,
                                child: franjas[indice].inicio.minute == 0 || franjas.length <= 6
                                    ? FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(_hora(franjas[indice].inicio), style: tema.labelSmall),
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (elegida != null) ...[
              Text(
                  '${_hora(elegida.inicio)}–${_hora(elegida.fin)} · ${SoleraL10n.tf('nat.ses_franja_resumen', {'detecciones': elegida.numeroDetecciones, 'especies': elegida.numeroEspecies})}',
                  style: tema.titleSmall),
              for (final etiqueta in elegida.especiesPorDetecciones)
                Text('${porEtiqueta[etiqueta] == null ? etiqueta : _nombre(porEtiqueta[etiqueta]!)} · ${elegida.deteccionesPorEspecie[etiqueta]}×',
                    style: tema.bodySmall),
            ] else
              Text(SoleraL10n.t('nat.ses_toca_franja'), style: tema.bodySmall),
            const Divider(height: 24),
            Text(SoleraL10n.t('nat.ses_por_franjas'), style: const TextStyle(fontWeight: FontWeight.bold)),
            for (final franja in franjas)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${_hora(franja.inicio)}–${_hora(franja.fin)} · ${franja.numeroEspecies == 0 ? '—' : [
                      for (final etiqueta in franja.especiesPorDetecciones)
                        porEtiqueta[etiqueta] == null ? etiqueta : _nombre(porEtiqueta[etiqueta]!),
                    ].join(', ')}',
                  style: tema.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaEspecies(SesionSonora sesion, List<ResumenEspecieSesion> especies) {
    final tema = Theme.of(context).textTheme;
    final esCoro = sesion.tipo == TipoSesionSonora.coro;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(SoleraL10n.t(esCoro ? 'nat.ses_primera_deteccion' : 'nat.ses_especies_oidas'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            if (especies.isEmpty) Text(SoleraL10n.t('nat.ses_sin_detecciones'), style: tema.bodySmall),
            for (final especie in especies) _filaEspecie(especie),
            const SizedBox(height: 8),
            if (especies.isNotEmpty && !_eligiendo)
              FilledButton.icon(
                icon: const Icon(Icons.add_location_alt_outlined),
                label: Text(SoleraL10n.t('nat.ses_guardar_como_hallazgos')),
                onPressed: () => setState(() {
                  _eligiendo = true;
                  _elegidas
                    ..clear()
                    ..addAll(especies
                        .where((especie) =>
                            especie.hallazgoId == null &&
                            especie.mejorConPosicion != null &&
                            especie.nivelMejor == NivelConfianzaSonido.probable)
                        .map((especie) => especie.etiqueta));
                }),
              ),
            if (_eligiendo) ...[
              Text(SoleraL10n.t('nat.ses_elige_hallazgos'), style: tema.bodySmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _guardando ? null : () => setState(() => _eligiendo = false),
                      child: Text(SoleraL10n.t('cancelar')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _guardando || _elegidas.isEmpty ? null : () => _guardarComoHallazgos(especies),
                      child: Text(SoleraL10n.tf('nat.ses_guardar_n', {'n': _elegidas.length})),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _filaEspecie(ResumenEspecieSesion especie) {
    final tema = Theme.of(context).textTheme;
    final rutaClip = especie.rutaClip;
    final yaGuardada = especie.hallazgoId != null;
    final sinPosicion = especie.mejorConPosicion == null;
    final detalle = SoleraL10n.tf('nat.ses_fila_especie', {
      'primera': _hora(especie.primera.momento),
      'ultima': _hora(especie.ultima.momento),
      'veces': especie.numeroDetecciones,
      'mejor': especie.mejor.puntuacion.toStringAsFixed(1),
      'nivel': _nivel(especie.nivelMejor),
    });
    final cabecera = Row(
      children: [
        if (_eligiendo)
          Checkbox(
            value: _elegidas.contains(especie.etiqueta),
            onChanged: yaGuardada || sinPosicion
                ? null
                : (valor) => setState(() {
                      if (valor == true) {
                        _elegidas.add(especie.etiqueta);
                      } else {
                        _elegidas.remove(especie.etiqueta);
                      }
                    }),
          ),
        Expanded(
          child: InkWell(
            onTap: () => setState(() => _especieResaltada = _especieResaltada == especie.etiqueta ? null : especie.etiqueta),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_nombre(especie), style: tema.titleSmall),
                Text(especie.etiqueta.replaceAll('_', ' '), style: const TextStyle(fontStyle: FontStyle.italic)),
                Text(detalle, style: tema.bodySmall),
                if (yaGuardada) Text(SoleraL10n.t('nat.ses_ya_guardada'), style: tema.bodySmall),
                if (sinPosicion && _eligiendo) Text(SoleraL10n.t('nat.ses_sin_posicion'), style: tema.bodySmall),
              ],
            ),
          ),
        ),
      ],
    );
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _especieResaltada == especie.etiqueta ? Theme.of(context).colorScheme.tertiaryContainer : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          cabecera,
          if (rutaClip != null) ReproductorClip(key: ValueKey(rutaClip), rutaAudio: rutaClip),
        ],
      ),
    );
  }
}
