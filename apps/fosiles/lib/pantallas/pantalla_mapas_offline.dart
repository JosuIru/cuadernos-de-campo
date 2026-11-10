import 'package:flutter/material.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../servicios/cache_teselas.dart';
import '../servicios/precache_teselas.dart';
import '../servicios/servicio_geologia.dart';

const _centroInicialMapa = LatLng(43.05, -2.45);
const _zoomInicialPantalla = 9.0;

class PantallaMapasOffline extends StatefulWidget {
  PantallaMapasOffline({super.key});

  @override
  State<PantallaMapasOffline> createState() => _PantallaMapasOfflineState();
}

class _PantallaMapasOfflineState extends State<PantallaMapasOffline> {
  final _controladorMapa = MapController();
  final _proveedorTeselas = TileProviderConCache();
  int _zoomMin = 11;
  int _zoomMax = 14;
  bool _incluirCallejero = true;
  bool _incluirSatelite = false;
  bool _incluirTopografico = false;
  CapaGeologicaWms? _capaGeologicaIncluir;
  bool _descargando = false;
  ProgresoPrecache? _progresoActual;

  ({int totalUrls, int teselas, int capas})? _resumen;

  List<ConfiguracionCapaPrecache> _capasIncluidas() {
    return [
      if (_incluirCallejero)
        ConfiguracionCapaPrecache(nombre: 'Callejero', urlPlantilla: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
      if (_incluirSatelite)
        ConfiguracionCapaPrecache(nombre: 'Satélite', urlPlantilla: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'),
      if (_incluirTopografico)
        ConfiguracionCapaPrecache(nombre: 'Topográfico', urlPlantilla: 'https://tile.opentopomap.org/{z}/{x}/{y}.png'),
      if (_capaGeologicaIncluir != null)
        ConfiguracionCapaPrecache(
          nombre: _capaGeologicaIncluir!.nombre,
          wmsOpciones: WMSTileLayerOptions(
            baseUrl: '${_capaGeologicaIncluir!.urlBase}?',
            layers: _capaGeologicaIncluir!.capas,
            format: 'image/png',
            transparent: true,
            version: '1.1.1',
          ),
        ),
    ];
  }

  void _recalcularResumen() {
    final camara = _controladorMapa.camera;
    final bounds = camara.visibleBounds;
    final limites = LimitesPrecache(sur: bounds.south, norte: bounds.north, oeste: bounds.west, este: bounds.east);
    setState(() {
      _resumen = calcularResumen(limites: limites, zoomMin: _zoomMin, zoomMax: _zoomMax, capas: _capasIncluidas());
    });
  }

  Future<void> _descargar() async {
    final camara = _controladorMapa.camera;
    final bounds = camara.visibleBounds;
    final limites = LimitesPrecache(sur: bounds.south, norte: bounds.north, oeste: bounds.west, este: bounds.east);
    final capas = _capasIncluidas();
    if (capas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(SoleraL10n.t('fos.mapa_selecciona_capa'))));
      return;
    }

    final resumen = calcularResumen(limites: limites, zoomMin: _zoomMin, zoomMax: _zoomMax, capas: capas);
    if (resumen.totalUrls > 8000) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          content: Text(SoleraL10n.tf('fos.mapa_confirmar_descarga', {'n': '${resumen.totalUrls}', 'mb': formatearNumero(resumen.totalUrls * 25 / 1024, decimales: 1)})),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(SoleraL10n.t('cancelar'))),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(SoleraL10n.t('fos.mapa_descargar'))),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() {
      _descargando = true;
      _progresoActual = ProgresoPrecache(0, 0, resumen.totalUrls, 0);
    });
    await precachearArea(
      limites: limites,
      zoomMin: _zoomMin,
      zoomMax: _zoomMax,
      capas: capas,
      alProgreso: (progreso) {
        if (!mounted) return;
        setState(() => _progresoActual = progreso);
      },
    );
    if (!mounted) return;
    setState(() => _descargando = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(SoleraL10n.tf('fos.mapa_teselas_en_cache', {'n': '${_progresoActual?.descargadas ?? 0}', 'fallidas': '${_progresoActual?.falladas ?? 0}'}))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progreso = _progresoActual;
    return Scaffold(
      appBar: AppBar(title: Text(SoleraL10n.t('fos.mapa_descargar_mapas_offline'))),
      body: Column(
        children: [
          SizedBox(
            height: 280,
            child: FlutterMap(
              mapController: _controladorMapa,
              options: MapOptions(
                initialCenter: _centroInicialMapa,
                initialZoom: _zoomInicialPantalla,
                minZoom: 6,
                maxZoom: 18,
                onMapEvent: (evento) {
                  if (evento is MapEventMoveEnd) _recalcularResumen();
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  maxZoom: 19,
                  tileProvider: _proveedorTeselas,
                  userAgentPackageName: 'com.josu.fosiles',
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: rellenoInferiorSeguro(context, const EdgeInsets.all(16)),
              children: [
                Text(SoleraL10n.t('fos.mapa_centra_zona'), style: TextStyle(fontSize: 13, color: Colors.grey)),
                SizedBox(height: 16),
                Row(children: [
                  Expanded(child: Text(SoleraL10n.tf('fos.mapa_zoom_minimo', {'n': '$_zoomMin'}))),
                  Expanded(
                    child: Slider(
                      value: _zoomMin.toDouble(),
                      min: 9, max: 14, divisions: 5,
                      onChanged: (v) => setState(() {
                        _zoomMin = v.round();
                        if (_zoomMax < _zoomMin) _zoomMax = _zoomMin;
                        _recalcularResumen();
                      }),
                    ),
                  ),
                ]),
                Row(children: [
                  Expanded(child: Text(SoleraL10n.tf('fos.mapa_zoom_maximo', {'n': '$_zoomMax'}))),
                  Expanded(
                    child: Slider(
                      value: _zoomMax.toDouble(),
                      min: 11, max: 17, divisions: 6,
                      onChanged: (v) => setState(() {
                        _zoomMax = v.round();
                        if (_zoomMin > _zoomMax) _zoomMin = _zoomMax;
                        _recalcularResumen();
                      }),
                    ),
                  ),
                ]),
                SizedBox(height: 8),
                CheckboxListTile(
                  title: Text('${SoleraL10n.t('fos.mapa_capa_callejero')} (OpenStreetMap)'),
                  value: _incluirCallejero,
                  onChanged: (v) => setState(() {
                    _incluirCallejero = v ?? true;
                    _recalcularResumen();
                  }),
                ),
                CheckboxListTile(
                  title: Text('${SoleraL10n.t('fos.mapa_capa_satelite')} (ESRI)'),
                  value: _incluirSatelite,
                  onChanged: (v) => setState(() {
                    _incluirSatelite = v ?? false;
                    _recalcularResumen();
                  }),
                ),
                CheckboxListTile(
                  title: Text('${SoleraL10n.t('fos.mapa_capa_topografico')} (OpenTopoMap)'),
                  value: _incluirTopografico,
                  onChanged: (v) => setState(() {
                    _incluirTopografico = v ?? false;
                    _recalcularResumen();
                  }),
                ),
                SizedBox(height: 8),
                Text(SoleraL10n.t('fos.mapa_capa_geologica_igme_opcional'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Wrap(
                  spacing: 6,
                  children: [
                    ChoiceChip(
                      label: Text(SoleraL10n.t('fos.mapa_ninguna')),
                      selected: _capaGeologicaIncluir == null,
                      onSelected: (_) => setState(() {
                        _capaGeologicaIncluir = null;
                        _recalcularResumen();
                      }),
                    ),
                    ...capasGeologicasWms.map((c) => ChoiceChip(
                          label: Text(c.nombreVisible),
                          selected: _capaGeologicaIncluir?.nombre == c.nombre,
                          onSelected: (_) => setState(() {
                            _capaGeologicaIncluir = c;
                            _recalcularResumen();
                          }),
                        )),
                  ],
                ),
                if (_resumen != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      SoleraL10n.tf('fos.mapa_resumen_teselas', {'n': '${_resumen!.totalUrls}', 'mb': formatearNumero(_resumen!.totalUrls * 25 / 1024, decimales: 1), 'capas': '${_resumen!.capas}'}),
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                SizedBox(height: 16),
                FilledButton.icon(
                  icon: _descargando
                      ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Icon(Icons.download),
                  onPressed: _descargando ? null : _descargar,
                  label: Text(_descargando ? SoleraL10n.t('fos.mapa_descargando') : SoleraL10n.t('fos.mapa_descargar_ahora')),
                ),
                if (progreso != null && _descargando) ...[
                  SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: progreso.total == 0 ? 0 : progreso.descargadas / progreso.total,
                  ),
                  SizedBox(height: 4),
                  Text(SoleraL10n.tf('fos.mapa_progreso_descarga', {'descargadas': '${progreso.descargadas}', 'total': '${progreso.total}', 'fallidas': '${progreso.falladas}', 'mb': formatearNumero(progreso.bytesAcumulados / 1024 / 1024, decimales: 1)}), style: TextStyle(fontSize: 12)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
