import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../servicios/cache_teselas.dart';
import '../servicios/precache_teselas.dart';

const _centroInicial = LatLng(40.4168, -3.7038);
const _zoomInicialPantalla = 6.0;

class PantallaMapasOffline extends StatefulWidget {
  const PantallaMapasOffline({super.key});

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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona al menos una capa.')));
      return;
    }

    final resumen = calcularResumen(limites: limites, zoomMin: _zoomMin, zoomMax: _zoomMax, capas: capas);
    if (resumen.totalUrls > 8000) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          content: Text('Vas a descargar ${resumen.totalUrls} teselas (~${(resumen.totalUrls * 25 / 1024).toStringAsFixed(1)} MB). ¿Continuar?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Descargar')),
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
      SnackBar(content: Text('✅ ${_progresoActual?.descargadas ?? 0} teselas en caché (${_progresoActual?.falladas ?? 0} fallidas).')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progreso = _progresoActual;
    return Scaffold(
      appBar: AppBar(title: const Text('Descargar mapas offline')),
      body: Column(
        children: [
          SizedBox(
            height: 280,
            child: FlutterMap(
              mapController: _controladorMapa,
              options: MapOptions(
                initialCenter: _centroInicial,
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
                  userAgentPackageName: 'com.josu.naturaleza',
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Centra y haz zoom en el mapa de arriba sobre la zona donde vayas a estar.', style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: Text('Zoom mínimo: $_zoomMin')),
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
                  Expanded(child: Text('Zoom máximo: $_zoomMax')),
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
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: const Text('Callejero (OpenStreetMap)'),
                  value: _incluirCallejero,
                  onChanged: (v) => setState(() {
                    _incluirCallejero = v ?? true;
                    _recalcularResumen();
                  }),
                ),
                CheckboxListTile(
                  title: const Text('Satélite (ESRI)'),
                  value: _incluirSatelite,
                  onChanged: (v) => setState(() {
                    _incluirSatelite = v ?? false;
                    _recalcularResumen();
                  }),
                ),
                CheckboxListTile(
                  title: const Text('Topográfico (OpenTopoMap)'),
                  value: _incluirTopografico,
                  onChanged: (v) => setState(() {
                    _incluirTopografico = v ?? false;
                    _recalcularResumen();
                  }),
                ),
                if (_resumen != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      '${_resumen!.totalUrls} teselas (~${(_resumen!.totalUrls * 25 / 1024).toStringAsFixed(1)} MB) en ${_resumen!.capas} capas',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  icon: _descargando
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.download),
                  onPressed: _descargando ? null : _descargar,
                  label: Text(_descargando ? 'Descargando…' : 'Descargar ahora'),
                ),
                if (progreso != null && _descargando) ...[
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: progreso.total == 0 ? 0 : progreso.descargadas / progreso.total,
                  ),
                  const SizedBox(height: 4),
                  Text('${progreso.descargadas}/${progreso.total} (${progreso.falladas} fallidas) · ${(progreso.bytesAcumulados / 1024 / 1024).toStringAsFixed(1)} MB', style: const TextStyle(fontSize: 12)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
