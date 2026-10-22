import 'package:flutter/material.dart';
import '../servicios/servicio_geologia.dart';

/// «Cómo leer el mapa»: qué es cada capa geológica, dónde están las demás
/// capas y de dónde salen las sugerencias de fósiles y minerales. Se abre
/// desde el menú «⋮» del mapa y desde Ajustes → Acerca de.
class PantallaAyudaMapa extends StatelessWidget {
  const PantallaAyudaMapa({super.key});

  @override
  Widget build(BuildContext context) {
    final estiloTitulo = Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold);
    final colorApagado = Colors.grey.shade700;
    return Scaffold(
      appBar: AppBar(title: const Text('Cómo leer el mapa')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Capas geológicas del mapa', style: estiloTitulo),
          const SizedBox(height: 6),
          Text(
            'En la barra superior del mapa, el icono de la montaña abre el '
            'desplegable de capas geológicas del IGME. La app arranca con la '
            'primera de la lista (GEODE 50). Para qué sirve cada una:',
            style: TextStyle(fontSize: 13, color: colorApagado),
          ),
          const SizedBox(height: 10),
          ...capasGeologicasWms.map((capa) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ${capa.nombre}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 12, top: 2),
                      child: Text(
                        capa.descripcion,
                        style: const TextStyle(fontSize: 13, height: 1.3),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 4),
          Text(
            'Las sugerencias de fósiles y minerales del asistente y del '
            'explorador SIEMPRE consultan GEODE 50 internamente, sin '
            'importar qué capa esté pintada — así cambiar de capa visual '
            'no hace bailar la lista de fósiles probables.',
            style: TextStyle(fontSize: 13, color: colorApagado, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 24),
          Text('Otras capas y filtros', style: estiloTitulo),
          const SizedBox(height: 6),
          const Text(
            'En el menú «⋮» de la barra superior del mapa:\n'
            '• ⭐ LIG — Lugares de Interés Geológico declarados por el IGME.\n'
            '• ⛰️ Relieve sombreado (hillshade) para ver topografía.\n'
            '• 🔥 Hallazgos como mapa de calor.\n'
            '• 🏛️ Yacimientos curados — selección manual con fichas, '
            'aparecen también como pista de "yacimientos cercanos" cuando '
            'pinchas a menos de 5 km.\n\n'
            'En el botón de capas de abajo a la izquierda del mapa:\n'
            '• 🦇 Cuevas (OpenStreetMap, requiere zoom ≥ 10).\n'
            '• 🗿 Megalitos y monumentos arqueológicos (OSM, zoom ≥ 9).',
            style: TextStyle(fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 24),
          Text('Sugerencias de fósiles y minerales', style: estiloTitulo),
          const SizedBox(height: 6),
          const Text(
            'Al pinchar un punto (modo Explorar geología) o con el '
            'asistente activado en el centro del mapa, la app cruza la '
            'respuesta del IGME con sus catálogos locales:\n\n'
            '• Si la formación que devuelve GEODE coincide con el catálogo '
            'de formaciones ibéricas, se sugieren los fósiles '
            'característicos de esa formación (sello PENDIENTE_VALIDACION '
            'paleontológica hasta auditoría de comité científico).\n'
            '• Si no, se sugieren fósiles del período inferido y filtrados '
            'por el ambiente sedimentario probable de la litología '
            '(p. ej. granito o basalto → sin fósiles; caliza → marinos).\n'
            '• Los minerales se ponderan por litología: cada grupo '
            '(granítico, carbonático, basáltico, evaporítico, metamórfico…) '
            'tiene su propio set probable.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}
