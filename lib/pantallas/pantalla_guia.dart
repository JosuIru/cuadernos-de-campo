import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import '../datos/datos_guia.dart';
import '../servicios/servicio_inaturalist.dart';
import '../servicios/servicio_wikipedia.dart';
import 'pantalla_quiz.dart';

class PantallaGuia extends StatefulWidget {
  const PantallaGuia({super.key});

  @override
  State<PantallaGuia> createState() => _PantallaGuiaState();
}

class _PantallaGuiaState extends State<PantallaGuia> with SingleTickerProviderStateMixin {
  final _controladorBusqueda = TextEditingController();
  String _consulta = '';
  final Set<String> _usosFiltrados = {};
  late final TabController _controladorTab;

  @override
  void initState() {
    super.initState();
    _controladorBusqueda.addListener(() {
      setState(() => _consulta = _controladorBusqueda.text.trim().toLowerCase());
    });
    _controladorTab = TabController(length: categoriasGuia.length, vsync: this);
    _controladorTab.addListener(() {
      // Al cambiar de pestaña, los chips disponibles cambian. También
      // depuramos los que ya no aplican (si tenías 'medicinal' activo
      // y pasas a Mamíferos, lo eliminamos para no devolver lista
      // vacía sin razón aparente).
      if (!_controladorTab.indexIsChanging) {
        final categoriaActiva = categoriasGuia[_controladorTab.index];
        final usosDisponibles = _usosDisponiblesEnCategoria(categoriaActiva.id);
        setState(() {
          _usosFiltrados.removeWhere((id) => !usosDisponibles.contains(id));
        });
      }
    });
  }

  @override
  void dispose() {
    _controladorTab.dispose();
    _controladorBusqueda.dispose();
    super.dispose();
  }

  /// Conjunto de usos que tienen al menos una especie etiquetada en
  /// [categoriaId]. Si la categoría no contiene ningún animal con
  /// 'medicinal', no tiene sentido mostrar el chip.
  Set<String> _usosDisponiblesEnCategoria(String categoriaId) {
    final disponibles = <String>{};
    for (final especie in especiesPorCategoria(categoriaId)) {
      disponibles.addAll(especie.usos);
    }
    return disponibles;
  }

  @override
  Widget build(BuildContext context) {
    final categoriaActiva = categoriasGuia[_controladorTab.index];
    final usosDisponibles = _usosDisponiblesEnCategoria(categoriaActiva.id);
    final usosVisibles = usosCatalogo.where((u) => usosDisponibles.contains(u.id)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Guía'),
        bottom: TabBar(
          controller: _controladorTab,
          isScrollable: true,
          tabs: [
            for (final categoria in categoriasGuia)
              Tab(icon: Icon(categoria.icono), text: categoria.nombre),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.quiz),
            tooltip: 'Quiz',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PantallaQuiz()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _controladorBusqueda,
              decoration: const InputDecoration(
                hintText: 'Buscar…',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          if (usosVisibles.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  for (final uso in usosVisibles)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        avatar: Icon(uso.icono, size: 16, color: uso.color),
                        label: Text(uso.nombre),
                        selected: _usosFiltrados.contains(uso.id),
                        onSelected: (seleccionado) => setState(() {
                          if (seleccionado) {
                            _usosFiltrados.add(uso.id);
                          } else {
                            _usosFiltrados.remove(uso.id);
                          }
                        }),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Expanded(
            child: TabBarView(
              controller: _controladorTab,
              children: [
                for (final categoria in categoriasGuia)
                  _ListaEspeciesCategoria(
                    categoria: categoria,
                    consulta: _consulta,
                    usosFiltrados: _usosFiltrados,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ListaEspeciesCategoria extends StatelessWidget {
  final CategoriaGuia categoria;
  final String consulta;
  final Set<String> usosFiltrados;
  const _ListaEspeciesCategoria({
    required this.categoria,
    required this.consulta,
    required this.usosFiltrados,
  });

  @override
  Widget build(BuildContext context) {
    final especies = especiesPorCategoria(categoria.id).where((e) {
      if (consulta.isNotEmpty) {
        final texto = '${e.nombreCientifico} ${e.nombreComun} ${e.descripcionCorta} ${e.habitat}'.toLowerCase();
        if (!texto.contains(consulta)) return false;
      }
      // Si hay filtros de uso activos, la especie debe coincidir en
      // **al menos uno** (OR semántico). Es lo que el usuario espera al
      // marcar "medicinal + comestible" — quiere ver lo que cumple
      // alguno de los dos, no algo que cumpla los dos.
      if (usosFiltrados.isNotEmpty) {
        final coincide = e.usos.any(usosFiltrados.contains);
        if (!coincide) return false;
      }
      return true;
    }).toList();

    if (especies.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(categoria.icono, size: 64, color: categoria.color),
              const SizedBox(height: 16),
              Text(
                'Sin especies en la guía de ${categoria.nombre.toLowerCase()}',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Añade entradas en lib/datos/datos_guia.dart',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: especies.length,
      itemBuilder: (context, indice) {
        final especie = especies[indice];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: _MiniaturaEspecie(especie: especie, categoria: categoria),
            title: Text(especie.nombreComun.isNotEmpty ? especie.nombreComun : especie.nombreCientifico),
            subtitle: Text(
              especie.descripcionCorta,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => abrirDetalleEspecieGuia(context, especie.id,
                lista: especies, indiceInicial: indice),
          ),
        );
      },
    );
  }
}

class _MiniaturaEspecie extends StatelessWidget {
  final EspecieGuia especie;
  final CategoriaGuia categoria;
  const _MiniaturaEspecie({required this.especie, required this.categoria});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: FutureBuilder<String?>(
        // Wikipedia primero (artículo del taxón); cae a iNaturalist si
        // Wikipedia no responde con foto.
        future: () async {
          final wiki = especie.tituloWikipedia.isNotEmpty
              ? await miniaturaPorTituloWikipedia(especie.tituloWikipedia)
              : null;
          return wiki ?? await miniaturaPorNombreCientifico(especie.nombreCientifico);
        }(),
        builder: (context, snapshot) {
          final url = snapshot.data;
          if (url == null) {
            return CircleAvatar(
              radius: 28,
              backgroundColor: categoria.color.withValues(alpha: 0.2),
              child: Icon(categoria.icono, color: categoria.color),
            );
          }
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: url,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              memCacheWidth: 168,
              httpHeaders: cabecerasImagenWiki,
              errorWidget: (_, __, ___) => CircleAvatar(
                radius: 28,
                backgroundColor: categoria.color.withValues(alpha: 0.2),
                child: Icon(categoria.icono, color: categoria.color),
              ),
            ),
          );
        },
      ),
    );
  }
}
