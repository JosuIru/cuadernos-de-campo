import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../datos/datos_guia.dart';
import '../datos/datos_minerales.dart';
import '../servicios/servicio_wikipedia.dart';
import 'pantalla_linea_tiempo.dart';
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

  List<FosilGuia> _filtrar(List<FosilGuia> entrada) {
    if (_consulta.isEmpty) return entrada;
    return entrada.where((f) {
      final texto = '${f.nombre} ${f.grupo} ${f.descripcionCorta} ${f.dondeEncontrar}'.toLowerCase();
      return texto.contains(_consulta);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Guía'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.bug_report), text: 'Fósiles'),
              Tab(icon: Icon(Icons.diamond), text: 'Minerales'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.timeline),
              tooltip: 'Línea del tiempo',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PantallaLineaTiempo()),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.quiz),
              tooltip: 'Quiz',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => PantallaQuiz()),
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
                  ListView(
                    padding: const EdgeInsets.all(8),
                    children: [
                      for (final periodo in periodos) ..._construirBloquePeriodo(periodo),
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.all(8),
                    children: [
                      for (final clase in clasesMinerales) ..._construirBloqueClaseMineral(clase),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _construirBloqueClaseMineral(ClaseMineralStrunz clase) {
    final mineralesClase = mineralesPorClase(clase.id).where((m) {
      if (_consulta.isEmpty) return true;
      final texto = '${m.nombre} ${m.formulaQuimica} ${m.colorTipico} ${m.descripcionCorta} ${m.dondeEncontrar}'.toLowerCase();
      return texto.contains(_consulta);
    }).toList();
    if (mineralesClase.isEmpty) return [];
    return [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: clase.color, borderRadius: BorderRadius.circular(4)),
          child: Row(
            children: [
              Expanded(child: Text(clase.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2D3A2E)))),
              Text(clase.descripcion, style: const TextStyle(fontSize: 11, color: Color(0xFF2D3A2E))),
            ],
          ),
        ),
      ),
      ...mineralesClase.map((m) => Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              leading: SizedBox(
                width: 56,
                height: 56,
                child: FutureBuilder<ResumenWikipedia?>(
                  future: obtenerResumenWikipedia(m.tituloWikipedia),
                  builder: (context, snapshot) {
                    final url = snapshot.data?.thumbnailUrl;
                    if (url == null) {
                      return Container(
                        decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(4)),
                        alignment: Alignment.center,
                        child: const Text('💎', style: TextStyle(fontSize: 24)),
                      );
                    }
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        httpHeaders: cabecerasImagenWiki,
                        memCacheWidth: 200,
                        errorWidget: (_, __, ___) => Container(color: Colors.black12, alignment: Alignment.center, child: const Text('💎', style: TextStyle(fontSize: 24))),
                      ),
                    );
                  },
                ),
              ),
              title: Text(m.nombre),
              subtitle: Text('${m.formulaQuimica}  ·  Mohs ${m.durezaMohs}', style: const TextStyle(fontSize: 11)),
              onTap: () => abrirDetalleMineral(context, m.id,
                  lista: mineralesClase,
                  indiceInicial: mineralesClase.indexOf(m)),
            ),
          )),
    ];
  }

  List<Widget> _construirBloquePeriodo(PeriodoGeologico periodo) {
    final fosilesDelPeriodo = _filtrar(fosilesPorPeriodo(periodo.id));
    if (fosilesDelPeriodo.isEmpty) return [];
    return [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: periodo.color, borderRadius: BorderRadius.circular(4)),
          child: Row(
            children: [
              Text(periodo.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2D3A2E))),
              const Spacer(),
              Text(periodo.edadMa, style: const TextStyle(fontSize: 12, color: Color(0xFF2D3A2E))),
            ],
          ),
        ),
      ),
      ...fosilesDelPeriodo.map((f) => Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              leading: SizedBox(
                width: 56,
                height: 56,
                child: FutureBuilder<ResumenWikipedia?>(
                  future: obtenerResumenWikipedia(f.tituloWikipedia),
                  builder: (context, snapshot) {
                    final url = snapshot.data?.thumbnailUrl;
                    if (url == null) {
                      return Container(
                        decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(4)),
                        alignment: Alignment.center,
                        child: const Text('🦴', style: TextStyle(fontSize: 24)),
                      );
                    }
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        httpHeaders: cabecerasImagenWiki,
                        memCacheWidth: 200,
                        errorWidget: (_, __, ___) => Container(
                          color: Colors.black12,
                          alignment: Alignment.center,
                          child: const Text('🦴', style: TextStyle(fontSize: 24)),
                        ),
                      ),
                    );
                  },
                ),
              ),
              title: Text(f.nombre),
              subtitle: Text(f.descripcionCorta, maxLines: 2, overflow: TextOverflow.ellipsis),
              onTap: () => abrirDetalleFosilGuia(context, f.id,
                  lista: fosilesDelPeriodo,
                  indiceInicial: fosilesDelPeriodo.indexOf(f)),
            ),
          )),
    ];
  }
}
