import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../datos/datos_guia.dart';
import '../servicios/servicio_wikipedia.dart';

class PantallaLineaTiempo extends StatelessWidget {
  const PantallaLineaTiempo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Línea del tiempo')),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: periodos.length,
        itemBuilder: (_, i) => _bloquePeriodo(context, periodos[i]),
      ),
    );
  }

  Widget _bloquePeriodo(BuildContext context, PeriodoGeologico periodo) {
    final fosiles = fosilesPorPeriodo(periodo.id);
    // El color de fondo del período es claro y debe leerse en negro siempre.
    const colorTextoSobrePeriodo = Color(0xFF1B1F1B);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: periodo.color.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: periodo.color, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(periodo.nombre, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: colorTextoSobrePeriodo, fontWeight: FontWeight.bold)),
                      Text(periodo.edadMa, style: const TextStyle(color: colorTextoSobrePeriodo, fontSize: 13)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: Text('${fosiles.length} fósiles', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorTextoSobrePeriodo)),
                ),
              ],
            ),
          ),
          if (fosiles.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 4, 14, 12),
              child: Text('Sin fósiles en la guía para este período.', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: colorTextoSobrePeriodo)),
            )
          else
            SizedBox(
              height: 130,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
                itemCount: fosiles.length,
                itemBuilder: (_, i) {
                  final f = fosiles[i];
                  final esquema = Theme.of(context).colorScheme;
                  return GestureDetector(
                    onTap: () => abrirDetalleFosilGuia(context, f.id,
                        lista: fosiles,
                        indiceInicial: fosiles.indexOf(f)),
                    child: Container(
                      width: 100,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: esquema.surface,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                              child: _MiniFotoFosil(tituloWikipedia: f.tituloWikipedia),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            child: Text(
                              f.nombre,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: esquema.onSurface),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniFotoFosil extends StatelessWidget {
  final String tituloWikipedia;
  const _MiniFotoFosil({required this.tituloWikipedia});
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ResumenWikipedia?>(
      future: obtenerResumenWikipedia(tituloWikipedia),
      builder: (_, snapshot) {
        final url = snapshot.data?.thumbnailUrl;
        if (url == null) {
          return Container(
            color: Colors.black12,
            alignment: Alignment.center,
            child: const Text('🦴', style: TextStyle(fontSize: 32)),
          );
        }
        return CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          httpHeaders: cabecerasImagenWiki,
          memCacheWidth: 200,
          errorWidget: (_, __, ___) => Container(
            color: Colors.black12,
            alignment: Alignment.center,
            child: const Text('🦴', style: TextStyle(fontSize: 32)),
          ),
        );
      },
    );
  }
}
