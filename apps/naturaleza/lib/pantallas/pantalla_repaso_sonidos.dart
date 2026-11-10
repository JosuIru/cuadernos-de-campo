import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../datos/base_datos.dart';
import '../datos/datos_guia.dart';
import '../utiles/repaso_sonidos.dart';
import 'pantalla_primeras_veces.dart' show cientificoDeLaGuia;
import 'pantalla_quien_canta.dart';
import 'widgets/reproductor_clip.dart';

/// Preferencia con el estado de Leitner (JSON por id de hallazgo).
const String clavePreferenciaRepasoSonidos = 'nat.repaso_sonidos.estado';

/// «Aprender con tus grabaciones»: suena un clip de un hallazgo propio y se
/// elige la especie entre 4; repetición espaciada con cajas de Leitner.
class PantallaRepasoSonidos extends StatefulWidget {
  const PantallaRepasoSonidos({super.key});

  @override
  State<PantallaRepasoSonidos> createState() => _PantallaRepasoSonidosState();
}

class _PantallaRepasoSonidosState extends State<PantallaRepasoSonidos> {
  final Random _azar = Random();
  bool _cargando = true;
  List<TarjetaSonido> _tarjetas = const [];
  List<OpcionEspecie> _especiesCuaderno = const [];
  Set<String> _clavesConClip = const {};
  EstadoRepaso _estado = EstadoRepaso.vacio;

  // Ronda en curso
  List<TarjetaSonido>? _ronda;
  int _indiceRonda = 0;
  List<OpcionEspecie> _opciones = const [];
  OpcionEspecie? _respuesta;
  int _aciertos = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final hallazgos = await BaseDatosNaturaleza.instancia.listarHallazgos();
    final tarjetas = tarjetasDesdeHallazgos(
      hallazgos,
      existeAudio: (ruta) => File(ruta).existsSync(),
      cientificoPorNombreComun: cientificoDeLaGuia,
    );
    var estado = EstadoRepaso.vacio;
    try {
      final preferencias = await SharedPreferences.getInstance();
      estado = EstadoRepaso.desdeJson(preferencias.getString(clavePreferenciaRepasoSonidos))
          .soloDe(tarjetas.map((tarjeta) => tarjeta.idHallazgo));
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _tarjetas = tarjetas;
      _especiesCuaderno = especiesDelCuaderno(hallazgos, cientificoPorNombreComun: cientificoDeLaGuia);
      _clavesConClip = {for (final tarjeta in tarjetas) tarjeta.claveEspecie};
      _estado = estado;
      _cargando = false;
    });
  }

  Future<void> _guardarEstado() async {
    try {
      final preferencias = await SharedPreferences.getInstance();
      await preferencias.setString(clavePreferenciaRepasoSonidos, _estado.aJson());
    } catch (_) {}
  }

  void _empezarRonda({required bool aunqueNoToquen}) {
    final ronda = tarjetasParaRonda(_tarjetas, _estado, DateTime.now(), aunqueNoToquen: aunqueNoToquen, azar: _azar);
    if (ronda.isEmpty) return;
    setState(() {
      _ronda = ronda;
      _indiceRonda = 0;
      _aciertos = 0;
      _prepararPregunta();
    });
  }

  void _prepararPregunta() {
    final tarjeta = _ronda![_indiceRonda];
    _opciones = opcionesParaTarjeta(tarjeta, _especiesCuaderno, _clavesConClip, _azar);
    _respuesta = null;
  }

  void _responder(OpcionEspecie opcion) {
    if (_respuesta != null) return;
    final tarjeta = _ronda![_indiceRonda];
    final acierto = opcion.claveEspecie == tarjeta.claveEspecie;
    setState(() {
      _respuesta = opcion;
      if (acierto) _aciertos++;
      _estado = _estado.conRespuesta(tarjeta.idHallazgo, acierto: acierto, ahora: DateTime.now());
    });
    _guardarEstado();
  }

  void _siguiente() {
    setState(() {
      _indiceRonda++;
      if (_indiceRonda < _ronda!.length) _prepararPregunta();
    });
  }

  String _nombreOpcion(OpcionEspecie opcion) =>
      opcion.nombreComun.isNotEmpty ? opcion.nombreComun : opcion.nombreCientifico;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(SoleraL10n.t('nat.cuad_rep_titulo'))),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : especiesConClip(_tarjetas) < especiesMinimasRepaso
              ? _pocasEspecies()
              : _ronda == null
                  ? _resumen()
                  : _indiceRonda >= _ronda!.length
                      ? _finRonda()
                      : _pregunta(),
    );
  }

  Widget _pocasEspecies() {
    final tema = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Icon(Icons.library_music_outlined, size: 56, color: tema.colorScheme.primary),
        const SizedBox(height: 12),
        Text(
          SoleraL10n.tf('nat.cuad_rep_pocas', {'n': especiesConClip(_tarjetas), 'minimo': especiesMinimasRepaso}),
          style: tema.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(SoleraL10n.t('nat.cuad_rep_como_conseguir'), style: tema.textTheme.titleSmall),
                const SizedBox(height: 8),
                Text(SoleraL10n.t('nat.cuad_rep_como_conseguir_texto')),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          icon: const Icon(Icons.graphic_eq),
          label: Text(SoleraL10n.t('nat.son_titulo')),
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const PantallaQuienCanta()))
              .then((_) => _cargar()),
        ),
      ],
    );
  }

  Widget _resumen() {
    final tema = Theme.of(context);
    final ahora = DateTime.now();
    final pendientes = tarjetasPendientes(_tarjetas, _estado, ahora);
    final porCaja = List<int>.filled(cajaMaxima, 0);
    for (final tarjeta in _tarjetas) {
      porCaja[_estado.estadoDe(tarjeta.idHallazgo).caja - 1]++;
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          SoleraL10n.tf('nat.cuad_rep_resumen', {'clips': _tarjetas.length, 'especies': especiesConClip(_tarjetas)}),
          style: tema.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          pendientes == 0
              ? SoleraL10n.t('nat.cuad_rep_nada_pendiente')
              : SoleraL10n.tf('nat.cuad_rep_pendientes', {'n': pendientes}),
        ),
        const SizedBox(height: 16),
        Text(SoleraL10n.t('nat.cuad_rep_cajas'), style: tema.textTheme.titleSmall),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var caja = 1; caja <= cajaMaxima; caja++)
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      children: [
                        Text('${porCaja[caja - 1]}', style: tema.textTheme.titleLarge),
                        Text(SoleraL10n.tf('nat.cuad_rep_caja', {'n': caja}), style: tema.textTheme.labelSmall),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 16),
          child: Text(SoleraL10n.t('nat.cuad_rep_cajas_ayuda'), style: tema.textTheme.bodySmall),
        ),
        if (pendientes > 0)
          FilledButton.icon(
            icon: const Icon(Icons.play_arrow),
            label: Text(SoleraL10n.t('nat.cuad_rep_empezar')),
            onPressed: () => _empezarRonda(aunqueNoToquen: false),
          )
        else
          OutlinedButton.icon(
            icon: const Icon(Icons.replay),
            label: Text(SoleraL10n.t('nat.cuad_rep_igualmente')),
            onPressed: () => _empezarRonda(aunqueNoToquen: true),
          ),
      ],
    );
  }

  Widget _pregunta() {
    final tema = Theme.of(context);
    final tarjeta = _ronda![_indiceRonda];
    final respuesta = _respuesta;
    final acierto = respuesta?.claveEspecie == tarjeta.claveEspecie;
    final especieGuia = especieGuiaPorNombreCientifico(tarjeta.nombreCientifico) ??
        especieGuiaPorNombreComun(tarjeta.nombreComun);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        LinearProgressIndicator(value: _indiceRonda / _ronda!.length),
        const SizedBox(height: 8),
        Text(SoleraL10n.tf('nat.cuad_rep_progreso', {'n': _indiceRonda + 1, 'total': _ronda!.length}),
            style: tema.textTheme.bodySmall),
        const SizedBox(height: 12),
        Text(SoleraL10n.t('nat.cuad_rep_pregunta'), style: tema.textTheme.titleMedium),
        const SizedBox(height: 8),
        ReproductorClip(key: ValueKey(tarjeta.idHallazgo), rutaAudio: tarjeta.rutaAudio),
        const SizedBox(height: 16),
        for (final opcion in _opciones)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _botonOpcion(opcion, tarjeta),
          ),
        if (respuesta != null) ...[
          const SizedBox(height: 8),
          Card(
            color: acierto ? tema.colorScheme.primaryContainer : tema.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(acierto ? SoleraL10n.t('nat.cuad_rep_bien') : SoleraL10n.t('nat.cuad_rep_mal'),
                      style: tema.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(SoleraL10n.tf('nat.cuad_rep_era', {
                    'especie': tarjeta.nombreComun.isNotEmpty ? tarjeta.nombreComun : tarjeta.nombreCientifico,
                  })),
                  if (tarjeta.nombreCientifico.isNotEmpty)
                    Text(tarjeta.nombreCientifico, style: const TextStyle(fontStyle: FontStyle.italic)),
                  Text(
                    DateFormat.yMMMd(SoleraL10n.idioma).format(tarjeta.fecha),
                    style: tema.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    SoleraL10n.tf('nat.cuad_rep_proximo', {
                      'dias': diasPorCaja[_estado.estadoDe(tarjeta.idHallazgo).caja - 1],
                    }),
                    style: tema.textTheme.bodySmall,
                  ),
                  if (especieGuia != null)
                    TextButton.icon(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      icon: const Icon(Icons.menu_book_outlined),
                      label: Text(SoleraL10n.t('nat.son_ver_en_guia')),
                      onPressed: () => abrirDetalleEspecieGuia(context, especieGuia.id),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _siguiente,
            child: Text(SoleraL10n.t('nat.cuad_rep_siguiente')),
          ),
        ],
      ],
    );
  }

  Widget _botonOpcion(OpcionEspecie opcion, TarjetaSonido tarjeta) {
    final respuesta = _respuesta;
    final tema = Theme.of(context);
    final esCorrecta = opcion.claveEspecie == tarjeta.claveEspecie;
    final esElegida = respuesta?.claveEspecie == opcion.claveEspecie;
    Color? fondo;
    IconData? icono;
    if (respuesta != null && esCorrecta) {
      fondo = tema.colorScheme.primaryContainer;
      icono = Icons.check_circle;
    } else if (esElegida) {
      fondo = tema.colorScheme.errorContainer;
      icono = Icons.cancel;
    }
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: fondo,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      onPressed: respuesta == null ? () => _responder(opcion) : null,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_nombreOpcion(opcion), style: TextStyle(color: tema.colorScheme.onSurface)),
                if (opcion.nombreComun.isNotEmpty && opcion.nombreCientifico.isNotEmpty)
                  Text(opcion.nombreCientifico,
                      style: tema.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          if (icono != null) Icon(icono, color: tema.colorScheme.onSurface),
        ],
      ),
    );
  }

  Widget _finRonda() {
    final tema = Theme.of(context);
    final total = _ronda!.length;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(SoleraL10n.tf('nat.cuad_rep_fin', {'aciertos': _aciertos, 'total': total}),
                style: tema.textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(SoleraL10n.t('nat.cuad_rep_fin_ayuda'), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => setState(() => _ronda = null),
              child: Text(SoleraL10n.t('nat.cuad_rep_volver')),
            ),
          ],
        ),
      ),
    );
  }
}
