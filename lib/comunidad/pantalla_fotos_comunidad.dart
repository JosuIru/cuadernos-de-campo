import 'package:flutter/material.dart';
import 'cliente_comunidad.dart';
import 'modelo_foto_comunidad.dart';

/// Galería de fotos aprobadas para una formación catalogada. Se entra
/// desde la ficha de Explorar Geología cuando GEODE identifica una
/// formación con aportaciones aprobadas.
///
/// NUNCA muestra nombre del autor, NUNCA coordenadas. Solo la foto y los
/// datos curados por el geólogo (especie corregida, edad, comentarios).
class PantallaFotosComunidad extends StatefulWidget {
  final String formacionCodigo;
  final String? nombreFormacionParaCabecera;

  const PantallaFotosComunidad({
    super.key,
    required this.formacionCodigo,
    this.nombreFormacionParaCabecera,
  });

  @override
  State<PantallaFotosComunidad> createState() => _PantallaFotosComunidadState();
}

class _PantallaFotosComunidadState extends State<PantallaFotosComunidad> {
  late Future<List<FotoComunidad>> _futuroFotos;

  @override
  void initState() {
    super.initState();
    _futuroFotos = ClienteComunidad().listarFotosPorFormacion(widget.formacionCodigo);
  }

  @override
  Widget build(BuildContext context) {
    final titulo = widget.nombreFormacionParaCabecera ??
        'Formación · ${widget.formacionCodigo}';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fotos de la comunidad'),
      ),
      body: FutureBuilder<List<FotoComunidad>>(
        future: _futuroFotos,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final fotos = snapshot.data ?? const <FotoComunidad>[];
          if (fotos.isEmpty) {
            return _estadoVacio(titulo);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  titulo,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: fotos.length,
                  itemBuilder: (_, indice) => _TarjetaFotoComunidad(
                    foto: fotos[indice],
                    alPulsar: () => _abrirDetalleFoto(fotos[indice]),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _estadoVacio(String tituloFormacion) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library_outlined,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(tituloFormacion,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Aún no hay fotos de la comunidad para esta formación. '
              'Si encuentras algo aquí, puedes ser el primero — comparte '
              'tu hallazgo desde la pestaña Lista.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirDetalleFoto(FotoComunidad foto) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _VisorFotoComunidad(foto: foto),
    ));
  }
}

class _TarjetaFotoComunidad extends StatelessWidget {
  final FotoComunidad foto;
  final VoidCallback alPulsar;
  const _TarjetaFotoComunidad({required this.foto, required this.alPulsar});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 1,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: alPulsar,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                child: Image.network(
                  foto.thumbnailUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey.shade200,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined,
                        color: Colors.grey),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    foto.especieCurada.isEmpty
                        ? '(sin especie)'
                        : foto.especieCurada,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (foto.edadCurada.isNotEmpty)
                    Text(
                      foto.edadCurada,
                      style: const TextStyle(fontSize: 11, color: Colors.black54),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisorFotoComunidad extends StatelessWidget {
  final FotoComunidad foto;
  const _VisorFotoComunidad({required this.foto});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(foto.especieCurada),
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 6.0,
              child: Center(
                child: Image.network(
                  foto.fotoUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 64),
                ),
              ),
            ),
          ),
          if (foto.edadCurada.isNotEmpty || foto.comentariosCurador.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.black87,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (foto.edadCurada.isNotEmpty)
                    Text(
                      foto.edadCurada,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (foto.comentariosCurador.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      foto.comentariosCurador,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
