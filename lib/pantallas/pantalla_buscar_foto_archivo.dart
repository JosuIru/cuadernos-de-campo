import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path_lib;
import 'package:path_provider/path_provider.dart';

import '../modelos/atribucion_foto.dart';
import '../servicios/buscador_foto_archivo.dart';

/// Resultado del modal: la ruta absoluta donde se descargó la foto +
/// la atribución que el llamador debe persistir paralela a esa ruta.
class FotoArchivoSeleccionada {
  const FotoArchivoSeleccionada({
    required this.rutaAbsoluta,
    required this.atribucion,
  });

  final String rutaAbsoluta;
  final AtribucionFoto atribucion;
}

/// Modal de selección de foto de archivo desde Wikipedia Commons +
/// iNaturalist. Sólo muestra resultados con licencia CC-BY/CC-BY-SA/CC0
/// — el filtrado lo hace el servicio antes de devolver.
///
/// Al pulsar una thumbnail descarga la imagen original a
/// `dirDocs/fotos/` y devuelve [FotoArchivoSeleccionada] con la ruta
/// y la atribución. Si el usuario cancela (botón atrás), devuelve
/// `null`.
class PantallaBuscarFotoArchivo extends StatefulWidget {
  const PantallaBuscarFotoArchivo({super.key, required this.consulta});

  /// Texto que se busca en los repositorios. Suele ser nombre
  /// científico o nombre común del taxón en la ficha.
  final String consulta;

  @override
  State<PantallaBuscarFotoArchivo> createState() =>
      _EstadoPantallaBuscarFotoArchivo();
}

class _EstadoPantallaBuscarFotoArchivo
    extends State<PantallaBuscarFotoArchivo> {
  late Future<List<ResultadoFotoArchivo>> _resultados;
  bool _descargando = false;

  @override
  void initState() {
    super.initState();
    _resultados = buscarFotosDeArchivo(widget.consulta);
  }

  Future<void> _seleccionar(ResultadoFotoArchivo foto) async {
    if (_descargando) return;
    setState(() => _descargando = true);
    try {
      final dirDocs = await getApplicationDocumentsDirectory();
      final dirFotos = Directory(path_lib.join(dirDocs.path, 'fotos'));
      if (!await dirFotos.exists()) {
        await dirFotos.create(recursive: true);
      }
      final extension = _extraerExtension(foto.urlCompleta);
      final nombre =
          'foto_archivo_${DateTime.now().millisecondsSinceEpoch}$extension';
      final destino = File(path_lib.join(dirFotos.path, nombre));

      final respuesta = await http
          .get(Uri.parse(foto.urlCompleta))
          .timeout(const Duration(seconds: 30));
      if (respuesta.statusCode != 200) {
        throw Exception('Descarga falló (${respuesta.statusCode})');
      }
      await destino.writeAsBytes(respuesta.bodyBytes);

      if (!mounted) return;
      Navigator.of(context).pop(
        FotoArchivoSeleccionada(
          rutaAbsoluta: destino.path,
          atribucion: AtribucionFoto(
            urlOrigen: foto.urlPagina,
            fuente: foto.fuente,
            autor: foto.autor,
            licencia: foto.licencia,
            tituloPagina: foto.titulo,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo descargar la foto: $e')),
      );
      setState(() => _descargando = false);
    }
  }

  static String _extraerExtension(String url) {
    final uri = Uri.tryParse(url);
    final pathRaw = uri?.path ?? url;
    final ext = path_lib.extension(pathRaw).toLowerCase();
    if (ext.isEmpty || ext.length > 5) return '.jpg';
    return ext;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Foto de archivo · ${widget.consulta}'),
      ),
      body: SafeArea(
        child: FutureBuilder<List<ResultadoFotoArchivo>>(
          future: _resultados,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _BloqueError(
                mensaje:
                    'No se pudo conectar a los archivos. Comprueba conexión.',
                alReintentar: () {
                  setState(() {
                    _resultados = buscarFotosDeArchivo(widget.consulta);
                  });
                },
              );
            }
            final fotos = snapshot.data ?? const [];
            if (fotos.isEmpty) {
              return const _BloqueVacio();
            }
            return _GrillaFotos(
              fotos: fotos,
              descargando: _descargando,
              alSeleccionar: _seleccionar,
            );
          },
        ),
      ),
    );
  }
}

class _GrillaFotos extends StatelessWidget {
  const _GrillaFotos({
    required this.fotos,
    required this.descargando,
    required this.alSeleccionar,
  });

  final List<ResultadoFotoArchivo> fotos;
  final bool descargando;
  final void Function(ResultadoFotoArchivo) alSeleccionar;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 180,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.85,
          ),
          itemCount: fotos.length,
          itemBuilder: (context, indice) {
            final foto = fotos[indice];
            return _CeldaFoto(
              foto: foto,
              alPulsar: descargando ? null : () => alSeleccionar(foto),
            );
          },
        ),
        if (descargando)
          Container(
            color: Colors.black54,
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

class _CeldaFoto extends StatelessWidget {
  const _CeldaFoto({required this.foto, required this.alPulsar});

  final ResultadoFotoArchivo foto;
  final VoidCallback? alPulsar;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Material(
      color: esquema.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: alPulsar,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: CachedNetworkImage(
                imageUrl: foto.thumbnailUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                errorWidget: (_, __, ___) => Container(
                  color: esquema.surfaceContainerLow,
                  child: const Center(
                    child: Icon(Icons.broken_image_outlined),
                  ),
                ),
                placeholder: (_, __) => const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
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
                    foto.fuente == 'wikipedia' ? 'Wikipedia' : 'iNaturalist',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (foto.autor != null)
                    Text(
                      foto.autor!,
                      style: Theme.of(context).textTheme.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (foto.licencia != null)
                    Text(
                      foto.licencia!.toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: esquema.tertiary,
                          ),
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

class _BloqueError extends StatelessWidget {
  const _BloqueError({required this.mensaje, required this.alReintentar});

  final String mensaje;
  final VoidCallback alReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 12),
            Text(mensaje, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: alReintentar,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BloqueVacio extends StatelessWidget {
  const _BloqueVacio();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_search_outlined, size: 48),
            SizedBox(height: 12),
            Text(
              'No se encontraron fotos con licencia abierta para esta '
              'especie. Prueba con el nombre científico exacto o con '
              'el nombre común.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
