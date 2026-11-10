import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import 'pantalla_chat.dart';
import 'pantalla_meteo.dart';
import 'pantalla_quien_canta.dart';
import 'pantalla_salida.dart';
import 'pantalla_salidas.dart';
import '../datos/base_datos.dart';
import '../servicios/estado_salida_en_curso.dart';
import '../servicios/checker_actualizaciones_naturaleza.dart';

class PantallaInicio extends StatefulWidget {
  final VoidCallback? alIrAMapa;
  final VoidCallback? alIrAGuia;

  const PantallaInicio({super.key, this.alIrAMapa, this.alIrAGuia});

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  int? _totalHallazgos;
  int? _especiesDistintas;
  int? _totalSalidas;

  @override
  void initState() {
    super.initState();
    EstadoSalidaEnCurso.instancia.addListener(_alCambiarSalida);
    _cargarCifras();
  }

  @override
  void dispose() {
    EstadoSalidaEnCurso.instancia.removeListener(_alCambiarSalida);
    super.dispose();
  }

  void _alCambiarSalida() {
    if (mounted) setState(() {});
    _cargarCifras();
  }

  Future<void> _cargarCifras() async {
    try {
      final hallazgos = await BaseDatosNaturaleza.instancia.listarHallazgos();
      final salidas = await BaseDatosNaturaleza.instancia.listarSalidas();
      final especies = <String>{
        for (final hallazgo in hallazgos)
          if (hallazgo.especie.trim().isNotEmpty)
            hallazgo.especie.trim().toLowerCase(),
      };
      if (!mounted) return;
      setState(() {
        _totalHallazgos = hallazgos.length;
        _especiesDistintas = especies.length;
        _totalSalidas = salidas.length;
      });
    } catch (_) {
      // Sin cifras la cabecera enseña guiones; el resto de la pantalla sirve.
    }
  }

  String get _fechaDeHoy {
    final locale = switch (SoleraL10n.idioma) {
      'eu' => 'eu',
      'ca' => 'ca',
      'gl' => 'gl',
      _ => 'es_ES',
    };
    final texto = DateFormat.MMMMEEEEd(locale).format(DateTime.now());
    return texto.isEmpty ? texto : texto[0].toUpperCase() + texto.substring(1);
  }

  String _cifra(int? valor) => valor?.toString() ?? '–';

  @override
  Widget build(BuildContext context) {
    final salidaActiva = EstadoSalidaEnCurso.instancia.salida;
    return Scaffold(
      body: RefreshIndicator(
        edgeOffset: MediaQuery.paddingOf(context).top,
        onRefresh: _cargarCifras,
        child: ListView(
          padding:
              rellenoInferiorSeguro(context, const EdgeInsets.only(bottom: 32)),
          children: [
            CabeceraHoySolera(
              titulo: 'Naturaleza',
              fecha: _fechaDeHoy,
              acciones: [
                IconButton(
                  icon: const Icon(Icons.wb_cloudy_outlined),
                  tooltip: SoleraL10n.t('fos.ajus_meteo'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PantallaMeteo()),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline),
                  tooltip: SoleraL10n.t('fos.ajus_chat_ia'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const PantallaChat(
                              sistemaPrompt: PantallaChat.sistemaNaturaleza,
                            )),
                  ),
                ),
              ],
              cifras: [
                CifraCabecera(
                    valor: _cifra(_totalHallazgos),
                    etiqueta: SoleraL10n.t('fos.ajus_cifra_hallazgos')),
                CifraCabecera(
                    valor: _cifra(_especiesDistintas),
                    etiqueta: SoleraL10n.t('nat.ajus_cifra_especies')),
                CifraCabecera(
                    valor: _cifra(_totalSalidas),
                    etiqueta: SoleraL10n.t('nat.ajus_cifra_salidas')),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Aviso de actualización disponible, arriba de todo para
                  // que se vea aunque haya una salida en curso.
                  ValueListenableBuilder<ActualizacionDisponible?>(
                    valueListenable: notificadorActualizacion,
                    builder: (_, actualizacion, __) {
                      if (actualizacion == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: BannerActualizacionDisponible(
                          actualizacion: actualizacion,
                          onDescartar: () =>
                              notificadorActualizacion.value = null,
                        ),
                      );
                    },
                  ),
                  if (salidaActiva != null) ...[
                    const SizedBox(height: 16),
                    _bannerSalidaActiva(context, salidaActiva.id!,
                        salidaActiva.titulo, salidaActiva.fechaInicioMs),
                  ],
                  TituloBloqueSolera(SoleraL10n.t('fos.ajus_atajos')),
                  IntrinsicHeight(
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _tarjetaAccion(
                              context,
                              icono: Icons.explore_outlined,
                              titulo: SoleraL10n.t('fos.ajus_explorar_mapa'),
                              subtitulo:
                                  SoleraL10n.t('nat.ajus_explorar_mapa_sub'),
                              onTap: () => widget.alIrAMapa?.call(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _tarjetaAccion(
                              context,
                              icono: Icons.menu_book_outlined,
                              titulo: SoleraL10n.t('fos.ajus_nav_guia'),
                              subtitulo: SoleraL10n.t('nat.ajus_guia_sub'),
                              onTap: () => widget.alIrAGuia?.call(),
                            ),
                          ),
                        ]),
                  ),
                  const SizedBox(height: 8),
                  _tarjetaAccion(
                    context,
                    icono: Icons.hiking,
                    titulo: SoleraL10n.t('nat.ajus_salidas_campo'),
                    subtitulo: SoleraL10n.t('nat.ajus_salidas_campo_sub'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const PantallaSalidas()),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _tarjetaAccion(
                    context,
                    icono: Icons.graphic_eq,
                    titulo: SoleraL10n.t('nat.son_titulo'),
                    subtitulo: SoleraL10n.t('nat.son_atajo_sub'),
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(
                            builder: (_) => const PantallaQuienCanta()))
                        .then((_) => _cargarCifras()),
                  ),
                  TituloBloqueSolera(SoleraL10n.t('nat.ajus_etica_titulo')),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(SoleraL10n.t('nat.ajus_etica_sub'),
                                style: Theme.of(context).textTheme.bodySmall),
                          ),
                          _seccionEtica(context,
                              icono: Icons.pets_outlined,
                              titulo: SoleraL10n.t('nat.ajus_etica1_titulo'),
                              texto: SoleraL10n.t('nat.ajus_etica1_texto')),
                          _seccionEtica(context,
                              icono: Icons.eco_outlined,
                              titulo: SoleraL10n.t('nat.ajus_etica2_titulo'),
                              texto: SoleraL10n.t('nat.ajus_etica2_texto')),
                          _seccionEtica(context,
                              icono: Icons.volunteer_activism_outlined,
                              titulo: SoleraL10n.t('nat.ajus_etica3_titulo'),
                              texto: SoleraL10n.t('nat.ajus_etica3_texto')),
                          _seccionEtica(context,
                              icono: Icons.wb_sunny_outlined,
                              titulo: SoleraL10n.t('nat.ajus_etica4_titulo'),
                              texto: SoleraL10n.t('nat.ajus_etica4_texto')),
                          _seccionEtica(context,
                              icono: Icons.forest_outlined,
                              titulo: SoleraL10n.t('nat.ajus_etica5_titulo'),
                              texto: SoleraL10n.t('nat.ajus_etica5_texto')),
                        ],
                      ),
                    ),
                  ),
                  TituloBloqueSolera(SoleraL10n.t('nat.ajus_como_usar')),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Column(children: [
                        _paso(context, 1, SoleraL10n.t('fos.ajus_paso1_titulo'),
                            SoleraL10n.t('nat.ajus_paso1_texto')),
                        _paso(context, 2, SoleraL10n.t('fos.ajus_paso2_titulo'),
                            SoleraL10n.t('nat.ajus_paso2_texto')),
                        _paso(context, 3, SoleraL10n.t('nat.ajus_paso3_titulo'),
                            SoleraL10n.t('nat.ajus_paso3_texto')),
                        _paso(context, 4, SoleraL10n.t('nat.ajus_paso4_titulo'),
                            SoleraL10n.t('nat.ajus_paso4_texto')),
                        _paso(context, 5, SoleraL10n.t('nat.ajus_paso5_titulo'),
                            SoleraL10n.t('nat.ajus_paso5_texto')),
                        _paso(context, 6, SoleraL10n.t('nat.son_paso_titulo'),
                            SoleraL10n.t('nat.son_paso_texto')),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaAccion(BuildContext context,
      {required IconData icono,
      required String titulo,
      required String subtitulo,
      required VoidCallback onTap}) {
    final esquema = Theme.of(context).colorScheme;
    return Material(
      color: esquema.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radioTarjetaSolera),
        side: BorderSide(color: esquema.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(radioTarjetaSolera),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icono, color: esquema.primary, size: 28),
            const SizedBox(height: 8),
            Text(titulo, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 2),
            Text(subtitulo,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: esquema.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }

  Widget _seccionEtica(BuildContext context,
          {required IconData icono,
          required String titulo,
          required String texto}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icono, size: 22, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 2),
              Text(texto, style: const TextStyle(fontSize: 13, height: 1.4)),
            ]),
          ),
        ]),
      );

  Widget _bannerSalidaActiva(
      BuildContext context, int idSalida, String titulo, int inicioMs) {
    final fmt = DateFormat('HH:mm', SoleraL10n.idioma);
    final etiquetaInicio =
        fmt.format(DateTime.fromMillisecondsSinceEpoch(inicioMs));
    final etiquetaTitulo =
        titulo.isNotEmpty ? titulo : SoleraL10n.t('nat.ajus_salida_sin_titulo');
    return Material(
      color: context.coloresSolera.fondoPendiente,
      borderRadius: BorderRadius.circular(radioTarjetaSolera),
      child: InkWell(
        borderRadius: BorderRadius.circular(radioTarjetaSolera),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PantallaSalida(idSalida: idSalida),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.fiber_manual_record,
                  color: context.coloresSolera.pendiente, size: 14),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      SoleraL10n.tf(
                          'nat.ajus_salida_en_curso', {'hora': etiquetaInicio}),
                      style: TextStyle(
                        fontSize: 11,
                        color: context.coloresSolera.pendiente,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(etiquetaTitulo,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _paso(BuildContext context, int numero, String titulo,
          String descripcion) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Text('$numero',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              Text(descripcion, style: const TextStyle(fontSize: 13)),
            ]),
          ),
        ]),
      );
}
