import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../fuentes_abiertas/fotos_inaturalist.dart';
import '../../fuentes_abiertas/licencias_abiertas.dart';
import '../../fuentes_abiertas/presencia_gbif.dart';
import '../../fuentes_abiertas/servicio_fuentes_abiertas.dart';
import '../../fuentes_abiertas/ubicacion_aproximada.dart';
import '../../servicios/zona_para_consultas.dart';

Future<void> _abrirEnlace(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

/// Nombres cortos de los meses en el idioma elegido (12, enero primero).
List<String> nombresCortosMeses() {
  final nombres = SoleraL10n.t('nat.fuen_meses_cortos').split(',').map((nombre) => nombre.trim()).toList();
  return nombres.length == 12
      ? nombres
      : const ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
}

/// Fotos de iNaturalist con licencia abierta, cada una con «© autor ·
/// licencia» debajo. Se piden al abrir la ficha (una petición) y quedan en
/// caché; sin red se ve lo cacheado o nada.
class SeccionFotosInaturalist extends StatefulWidget {
  const SeccionFotosInaturalist({super.key, required this.nombreCientifico, this.alCargarTaxon});

  final String nombreCientifico;

  /// Avisa del id del taxón de iNaturalist (para el enlace de la ficha).
  final ValueChanged<int>? alCargarTaxon;

  @override
  State<SeccionFotosInaturalist> createState() => _SeccionFotosInaturalistState();
}

class _SeccionFotosInaturalistState extends State<SeccionFotosInaturalist> {
  late final Future<FotosInaturalist?> _futuroFotos;

  @override
  void initState() {
    super.initState();
    _futuroFotos = ServicioFuentesAbiertas.instancia.fotosDe(widget.nombreCientifico).then((fotos) {
      final idTaxon = fotos?.idTaxon;
      if (idTaxon != null) widget.alCargarTaxon?.call(idTaxon);
      return fotos;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return FutureBuilder<FotosInaturalist?>(
      future: _futuroFotos,
      builder: (context, instantanea) {
        if (instantanea.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          );
        }
        final fotos = instantanea.data?.fotos ?? const <FotoAbierta>[];
        if (fotos.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(SoleraL10n.t('nat.fuen_fotos_inat'), style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(SoleraL10n.t('nat.fuen_fotos_inat_nota'), style: tema.textTheme.bodySmall),
            const SizedBox(height: 8),
            SizedBox(
              height: 178,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: fotos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, indice) => _MiniaturaFotoAbierta(foto: fotos[indice]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MiniaturaFotoAbierta extends StatelessWidget {
  const _MiniaturaFotoAbierta({required this.foto});

  final FotoAbierta foto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return SizedBox(
      width: 132,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _mostrarFotoAbierta(context, foto),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: foto.urlMedia,
                width: 132,
                height: 132,
                fit: BoxFit.cover,
                memCacheWidth: 396,
                placeholder: (_, __) => Container(color: Colors.black12),
                errorWidget: (_, __, ___) => Container(
                  color: Colors.black12,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              foto.textoAtribucion,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: tema.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

void _mostrarFotoAbierta(BuildContext context, FotoAbierta foto) {
  showDialog<void>(
    context: context,
    builder: (contextoDialogo) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CachedNetworkImage(
              imageUrl: foto.urlGrande,
              fit: BoxFit.contain,
              placeholder: (_, __) => const SizedBox(
                height: 240,
                child: Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (_, __, ___) => CachedNetworkImage(imageUrl: foto.urlMedia, fit: BoxFit.contain),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(foto.textoAtribucion, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(SoleraL10n.t('nat.fuen_foto_via_inat'), style: Theme.of(context).textTheme.bodySmall),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Wrap(
                spacing: 4,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: Text(SoleraL10n.t('nat.fuen_ver_observacion')),
                    onPressed: () => _abrirEnlace(Uri.parse(foto.urlObservacion)),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.gavel, size: 16),
                    label: Text(SoleraL10n.tf('nat.fuen_ver_licencia', {'licencia': nombreLicencia(foto.licencia)})),
                    onPressed: () => _abrirEnlace(Uri.parse(urlLicencia(foto.licencia))),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(contextoDialogo),
                    child: Text(SoleraL10n.t('nat.fuen_cerrar')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// «Visto cerca de ti» y «Cuándo se ve» con registros de GBIF.
///
/// Sin zona de la sesión, los meses son de España y Portugal y hay un botón
/// para usar la zona aproximada. Las especies [sensible]s (protegidas) se
/// consultan siempre a escala amplia; las que GBIF devuelve con coordenadas
/// generalizadas, también. Nunca se enseñan puntos.
class SeccionPresenciaGbif extends StatefulWidget {
  const SeccionPresenciaGbif({
    super.key,
    required this.nombreCientifico,
    this.claveGbifConocida,
    this.sensible = false,
  });

  final String nombreCientifico;
  final int? claveGbifConocida;
  final bool sensible;

  @override
  State<SeccionPresenciaGbif> createState() => _SeccionPresenciaGbifState();
}

class _SeccionPresenciaGbifState extends State<SeccionPresenciaGbif> {
  Future<PresenciaGbif?>? _futuroPresencia;
  UbicacionAproximada? _zonaConsultada;
  bool _pidiendoZona = false;

  @override
  void initState() {
    super.initState();
    ZonaParaConsultas.zonaDeLaSesion.addListener(_alCambiarZona);
    _cargar(ZonaParaConsultas.zonaDeLaSesion.value);
  }

  @override
  void dispose() {
    ZonaParaConsultas.zonaDeLaSesion.removeListener(_alCambiarZona);
    super.dispose();
  }

  void _alCambiarZona() {
    final zona = ZonaParaConsultas.zonaDeLaSesion.value;
    if (zona != null && zona != _zonaConsultada && mounted) setState(() => _cargar(zona));
  }

  void _cargar(UbicacionAproximada? zona) {
    _zonaConsultada = zona;
    final servicio = ServicioFuentesAbiertas.instancia;
    _futuroPresencia = servicio
        .claveGbifDe(widget.nombreCientifico, claveConocida: widget.claveGbifConocida)
        .then((clave) => clave == null ? null : servicio.presenciaDe(clave, ubicacion: zona, sensible: widget.sensible));
  }

  Future<void> _usarMiZona() async {
    setState(() => _pidiendoZona = true);
    await ZonaParaConsultas.pedir(context);
    if (mounted) setState(() => _pidiendoZona = false);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return FutureBuilder<PresenciaGbif?>(
      future: _futuroPresencia,
      builder: (context, instantanea) {
        if (instantanea.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          );
        }
        final presencia = instantanea.data;
        if (presencia == null) return const SizedBox.shrink();
        final zona = presencia.ubicacion;
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(SoleraL10n.t('nat.fuen_visto_cerca'), style: tema.textTheme.titleSmall),
                const SizedBox(height: 4),
                if (zona == null) ...[
                  Text(SoleraL10n.t('nat.fuen_sin_zona'), style: tema.textTheme.bodySmall),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      onPressed: _pidiendoZona ? null : _usarMiZona,
                      icon: _pidiendoZona
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.my_location, size: 18),
                      label: Text(SoleraL10n.t('nat.fuen_usar_mi_zona')),
                    ),
                  ),
                ] else ...[
                  Text(
                    SoleraL10n.tf('nat.fuen_registros_cerca', {
                      'numero': '${presencia.total}',
                      'km': '${zona.radioKm}',
                    }),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (zona.escalaAmplia)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.shield_outlined, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(SoleraL10n.t('nat.fuen_escala_amplia'), style: tema.textTheme.bodySmall),
                          ),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 12),
                Text(SoleraL10n.t('nat.fuen_cuando_se_ve'), style: tema.textTheme.titleSmall),
                Text(
                  zona == null
                      ? SoleraL10n.t('nat.fuen_meses_iberia')
                      : SoleraL10n.tf('nat.fuen_meses_zona', {'km': '${zona.radioKm}'}),
                  style: tema.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                if (presencia.totalPorMes == 0)
                  Text(SoleraL10n.t('nat.fuen_sin_meses'), style: tema.textTheme.bodySmall)
                else ...[
                  GraficoRegistrosPorMes(porMes: presencia.porMes),
                  const SizedBox(height: 6),
                  Text(_resumenMeses(presencia.porMes), style: tema.textTheme.bodyMedium),
                  if (presencia.totalPorMes < 30)
                    Text(SoleraL10n.t('nat.fuen_pocos_registros'), style: tema.textTheme.bodySmall),
                ],
                const SizedBox(height: 8),
                Text(SoleraL10n.t('nat.fuen_nota_registros'), style: tema.textTheme.bodySmall),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () => _abrirEnlace(uriBusquedaRegistrosGbif(presencia.claveEspecie)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '${SoleraL10n.t('nat.fuen_fuente')}: ${textoCitaGbif(presencia.consultadoEn)}',
                      style: tema.textTheme.bodySmall?.copyWith(
                        color: tema.colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _resumenMeses(List<int> porMes) {
    final nombres = nombresCortosMeses();
    final tramos = tramosDeMeses(mesesConMasRegistros(porMes));
    final texto = tramos
        .map((tramo) => tramo[0] == tramo[1] ? nombres[tramo[0] - 1] : '${nombres[tramo[0] - 1]}–${nombres[tramo[1] - 1]}')
        .join(', ');
    return SoleraL10n.tf('nat.fuen_mas_registros', {'meses': texto});
  }
}

/// Barras de los 12 meses (una serie, un color, sin ejes de más). Cada barra
/// lleva su valor en un tooltip (pulsación larga o ratón) y la lectura
/// completa va en la etiqueta de accesibilidad.
class GraficoRegistrosPorMes extends StatelessWidget {
  const GraficoRegistrosPorMes({super.key, required this.porMes, this.altura = 72, this.textoValor});

  final List<int> porMes;
  final double altura;

  /// Texto del tooltip y de la lectura de cada mes; por defecto, «N registros».
  final String Function(String mes, int valor)? textoValor;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final nombres = nombresCortosMeses();
    final maximo = porMes.fold<int>(0, (mayor, valor) => valor > mayor ? valor : mayor);
    final colorBarra = tema.colorScheme.primary;
    final colorFondo = tema.colorScheme.surfaceContainerHighest;
    final lectura = [
      for (var indice = 0; indice < 12; indice++)
        textoValor?.call(nombres[indice], porMes[indice]) ?? '${nombres[indice]} ${porMes[indice]}',
    ].join(', ');
    return Semantics(
      label: lectura,
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var indice = 0; indice < 12; indice++)
            Expanded(
              child: Tooltip(
                message: textoValor?.call(nombres[indice], porMes[indice]) ??
                    SoleraL10n.tf('nat.fuen_registros_mes', {
                      'mes': nombres[indice],
                      'numero': '${porMes[indice]}',
                    }),
                triggerMode: TooltipTriggerMode.tap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: altura,
                        alignment: Alignment.bottomCenter,
                        decoration: BoxDecoration(
                          color: colorFondo.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: FractionallySizedBox(
                          heightFactor: maximo == 0 ? 0 : (porMes[indice] / maximo).clamp(0.0, 1.0),
                          widthFactor: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              color: colorBarra,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        nombres[indice].characters.first.toUpperCase(),
                        style: tema.textTheme.labelSmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Botones «Ver en iNaturalist» y «Ver en GBIF» de la ficha.
class EnlacesFuentesExternas extends StatelessWidget {
  const EnlacesFuentesExternas({
    super.key,
    required this.nombreCientifico,
    this.idTaxonInaturalist,
    this.claveGbif,
  });

  final String nombreCientifico;
  final int? idTaxonInaturalist;
  final int? claveGbif;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.open_in_new, size: 18),
          label: Text(SoleraL10n.t('nat.fuen_ver_en_inat')),
          onPressed: () => _abrirEnlace(uriPaginaInaturalist(nombreCientifico, idTaxon: idTaxonInaturalist)),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.open_in_new, size: 18),
          label: Text(SoleraL10n.t('nat.fuen_ver_en_gbif')),
          onPressed: () async {
            final clave = await ServicioFuentesAbiertas.instancia.claveGbifDe(nombreCientifico, claveConocida: claveGbif);
            await _abrirEnlace(clave != null
                ? uriPaginaEspecieGbif(clave)
                : Uri.parse('https://www.gbif.org/species/search').replace(queryParameters: {'q': nombreCientifico}));
          },
        ),
      ],
    );
  }
}

/// Todo lo de iNaturalist y GBIF en la ficha: fotos, «Visto cerca de ti»,
/// «Cuándo se ve» y los enlaces. El enlace a iNaturalist usa el taxón que
/// devuelven las fotos en cuanto llega.
class BloqueFuentesAbiertasFicha extends StatefulWidget {
  const BloqueFuentesAbiertasFicha({
    super.key,
    required this.nombreCientifico,
    this.claveGbif,
    this.sensible = false,
  });

  final String nombreCientifico;
  final int? claveGbif;
  final bool sensible;

  @override
  State<BloqueFuentesAbiertasFicha> createState() => _BloqueFuentesAbiertasFichaState();
}

class _BloqueFuentesAbiertasFichaState extends State<BloqueFuentesAbiertasFicha> {
  int? _idTaxonInaturalist;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SeccionFotosInaturalist(
          nombreCientifico: widget.nombreCientifico,
          alCargarTaxon: (idTaxon) {
            if (mounted && idTaxon != _idTaxonInaturalist) setState(() => _idTaxonInaturalist = idTaxon);
          },
        ),
        const SizedBox(height: 16),
        SeccionPresenciaGbif(
          nombreCientifico: widget.nombreCientifico,
          claveGbifConocida: widget.claveGbif,
          sensible: widget.sensible,
        ),
        const SizedBox(height: 16),
        EnlacesFuentesExternas(
          nombreCientifico: widget.nombreCientifico,
          idTaxonInaturalist: _idTaxonInaturalist,
          claveGbif: widget.claveGbif,
        ),
      ],
    );
  }
}
