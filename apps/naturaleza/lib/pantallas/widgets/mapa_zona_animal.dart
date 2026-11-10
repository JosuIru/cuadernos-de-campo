import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../servicios/cache_teselas.dart';
import '../../sonido/triangulacion_rumbos.dart';
import '../pantalla_mapa.dart' show capasBaseDisponibles;

/// Mapa pequeño de «¿Dónde está?»: las tomas (dónde estaba la persona),
/// sus líneas de rumbo con los bordes del margen de error y la zona estimada
/// del animal. Lo usan la pantalla de escucha y el detalle del hallazgo.
class MapaZonaAnimal extends StatelessWidget {
  final List<TomaRumbo> tomas;
  final List<({double latitud, double longitud})> contorno;
  final double altura;

  const MapaZonaAnimal({super.key, required this.tomas, required this.contorno, this.altura = 240});

  /// Desde `Hallazgo.atributos['zona_animal']`; null si no se puede leer.
  static MapaZonaAnimal? desdeAtributo(Object? zonaCruda, {double altura = 220}) {
    if (zonaCruda is! Map) return null;
    final tomas = [
      for (final tomaCruda in (zonaCruda['tomas'] as List? ?? const []))
        if (TomaRumbo.desdeJson(tomaCruda) case final toma?) toma,
    ];
    final contorno = [
      for (final vertice in (zonaCruda['contorno'] as List? ?? const []))
        if (vertice is List && vertice.length >= 2 && vertice[0] is num && vertice[1] is num)
          (latitud: (vertice[0] as num).toDouble(), longitud: (vertice[1] as num).toDouble()),
    ];
    if (tomas.isEmpty && contorno.isEmpty) return null;
    return MapaZonaAnimal(tomas: tomas, contorno: contorno, altura: altura);
  }

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final puntosZona = [for (final vertice in contorno) LatLng(vertice.latitud, vertice.longitud)];
    final centroZona = contorno.isEmpty ? null : _centroAproximado(contorno);
    // Largo de las líneas: hasta algo más allá de la zona, o 300 m.
    double largoLinea(TomaRumbo toma) {
      if (centroZona == null) return 300;
      final distancia = distanciaMetros(toma.latitud, toma.longitud, centroZona.latitud, centroZona.longitud);
      return (distancia * 1.6).clamp(80, 1500).toDouble();
    }

    final lineas = <Polyline>[];
    final puntosEncuadre = <LatLng>[...puntosZona];
    for (final toma in tomas) {
      final origen = LatLng(toma.latitud, toma.longitud);
      puntosEncuadre.add(origen);
      final largo = largoLinea(toma);
      LatLng extremo(double rumbo) {
        final punto = puntoEnRumbo(toma.latitud, toma.longitud, rumbo, largo);
        return LatLng(punto.latitud, punto.longitud);
      }

      final colorLinea = toma.orientativa ? colores.tertiary : colores.primary;
      lineas.add(Polyline(points: [origen, extremo(toma.rumboGrados)], strokeWidth: 3, color: colorLinea));
      for (final borde in [
        toma.rumboGrados - toma.incertidumbreGrados,
        toma.rumboGrados + toma.incertidumbreGrados
      ]) {
        lineas.add(Polyline(
          points: [origen, extremo(borde)],
          strokeWidth: 1,
          color: colorLinea.withValues(alpha: 0.5),
        ));
      }
      if (centroZona == null) puntosEncuadre.add(extremo(toma.rumboGrados));
    }
    if (puntosEncuadre.isEmpty) return const SizedBox.shrink();
    final capa = capasBaseDisponibles.first;
    final encuadre = LatLngBounds.fromPoints(puntosEncuadre);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: altura,
        child: FlutterMap(
          // Cambiar las tomas o la zona vuelve a encuadrar.
          key: ValueKey('${tomas.length}|${contorno.length}|${centroZona?.latitud}'),
          options: MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: encuadre,
              padding: const EdgeInsets.all(28),
              maxZoom: 18,
            ),
            interactionOptions: const InteractionOptions(
              // Sin arrastre: el mapa va dentro de una lista y se comería el desplazamiento.
              flags: InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: capa.urlPlantilla,
              maxZoom: capa.maxZoom.toDouble(),
              tileProvider: TileProviderConCache(),
              userAgentPackageName: 'com.josu.naturaleza',
            ),
            if (puntosZona.length >= 3)
              PolygonLayer(polygons: [
                Polygon(
                  points: puntosZona,
                  color: colores.error.withValues(alpha: 0.25),
                  borderColor: colores.error,
                  borderStrokeWidth: 2,
                ),
              ]),
            PolylineLayer(polylines: lineas),
            MarkerLayer(markers: [
              for (final (indice, toma) in tomas.indexed)
                Marker(
                  point: LatLng(toma.latitud, toma.longitud),
                  width: 26,
                  height: 26,
                  child: CircleAvatar(
                    backgroundColor: toma.orientativa ? colores.tertiary : colores.primary,
                    child: Text('${indice + 1}', style: TextStyle(fontSize: 12, color: colores.onPrimary)),
                  ),
                ),
              if (centroZona != null)
                Marker(
                  point: LatLng(centroZona.latitud, centroZona.longitud),
                  width: 30,
                  height: 30,
                  child: Icon(Icons.graphic_eq, color: colores.error),
                ),
            ]),
            RichAttributionWidget(attributions: [TextSourceAttribution(capa.atribucion)]),
          ],
        ),
      ),
    );
  }

  static ({double latitud, double longitud}) _centroAproximado(
      List<({double latitud, double longitud})> contorno) {
    var sumaLatitud = 0.0, sumaLongitud = 0.0;
    for (final vertice in contorno) {
      sumaLatitud += vertice.latitud;
      sumaLongitud += vertice.longitud;
    }
    return (latitud: sumaLatitud / contorno.length, longitud: sumaLongitud / contorno.length);
  }
}
