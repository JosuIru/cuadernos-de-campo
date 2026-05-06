import 'package:flutter/material.dart';
import '../datos/datos_guia.dart';
import '../servicios/servicio_inaturalist.dart';
import 'pantalla_quiz.dart';

class PantallaGuia extends StatefulWidget {
  const PantallaGuia({super.key});

  @override
  State<PantallaGuia> createState() => _PantallaGuiaState();
}

class _PantallaGuiaState extends State<PantallaGuia> {
  final _controladorBusqueda = TextEditingController();
  String _consulta = '';

  @override
  void initState() {
    super.initState();
    _controladorBusqueda.addListener(() {
      setState(() => _consulta = _controladorBusqueda.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _controladorBusqueda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: categoriasGuia.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Guía'),
          bottom: TabBar(
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
            Expanded(
              child: TabBarView(
                children: [
                  for (final categoria in categoriasGuia)
                    _ListaEspeciesCategoria(
                      categoria: categoria,
                      consulta: _consulta,
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

class _ListaEspeciesCategoria extends StatelessWidget {
  final CategoriaGuia categoria;
  final String consulta;
  const _ListaEspeciesCategoria({required this.categoria, required this.consulta});

  @override
  Widget build(BuildContext context) {
    final especies = especiesPorCategoria(categoria.id).where((e) {
      if (consulta.isEmpty) return true;
      final texto = '${e.nombreCientifico} ${e.nombreComun} ${e.descripcionCorta} ${e.habitat}'.toLowerCase();
      return texto.contains(consulta);
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
            onTap: () => abrirDetalleEspecieGuia(context, especie.id),
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
        future: miniaturaPorNombreCientifico(especie.nombreCientifico),
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
            child: Image.network(
              url,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => CircleAvatar(
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
