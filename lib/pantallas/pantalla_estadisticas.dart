import 'package:flutter/material.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import 'package:intl/intl.dart';
import '../datos/base_datos.dart';
import '../datos/datos_guia.dart';
import '../modelos/hallazgo.dart';

class PantallaEstadisticas extends StatefulWidget {
  const PantallaEstadisticas({super.key});

  @override
  State<PantallaEstadisticas> createState() => _PantallaEstadisticasState();
}

class _PantallaEstadisticasState extends State<PantallaEstadisticas> {
  List<Hallazgo> _hallazgos = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final lista = await BaseDatosNaturaleza.instancia.listarHallazgos();
    if (!mounted) return;
    setState(() {
      _hallazgos = lista;
      _cargando = false;
    });
  }

  Map<String, int> _conteoPorCategoria() {
    final mapa = <String, int>{};
    for (final hallazgo in _hallazgos) {
      mapa.update(hallazgo.categoria, (valor) => valor + 1, ifAbsent: () => 1);
    }
    return mapa;
  }

  Map<String, int> _topConteo(String Function(Hallazgo) clave, {int limite = 5}) {
    final mapa = <String, int>{};
    for (final hallazgo in _hallazgos) {
      final valor = clave(hallazgo).trim();
      if (valor.isEmpty) continue;
      mapa.update(valor, (cuenta) => cuenta + 1, ifAbsent: () => 1);
    }
    final ordenado = mapa.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(ordenado.take(limite));
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return Scaffold(
        appBar: AppBar(title: const Text('Estadísticas')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_hallazgos.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Estadísticas')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Aún no hay hallazgos para analizar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    final conteoCategoria = _conteoPorCategoria();
    final maxConteo = conteoCategoria.values.fold<int>(0, (acumulado, valor) => acumulado > valor ? acumulado : valor);
    final fechas = _hallazgos.map((hallazgo) => hallazgo.fechaMs).toList()..sort();
    final primero = DateTime.fromMillisecondsSinceEpoch(fechas.first);
    final ultimo = DateTime.fromMillisecondsSinceEpoch(fechas.last);
    final formato = DateFormat('dd MMM yyyy', 'es_ES');
    final especiesUnicas = _hallazgos
        .map((hallazgo) => hallazgo.especie.trim())
        .where((especie) => especie.isNotEmpty)
        .toSet();
    final topEspecies = _topConteo((hallazgo) => hallazgo.especie);
    final topHabitats = _topConteo((hallazgo) => hallazgo.habitat);

    return Scaffold(
      appBar: AppBar(title: const Text('Estadísticas')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _filaTotales([
            ('Hallazgos', _hallazgos.length.toString()),
            ('Especies', especiesUnicas.length.toString()),
            ('Con foto', _hallazgos.where((hallazgo) => hallazgo.rutaFoto != null).length.toString()),
          ]),
          const SizedBox(height: 16),
          _tarjeta(
            titulo: 'Por categoría',
            child: Column(
              children: [
                for (final categoria in categoriasGuia)
                  _filaBarra(
                    categoria.nombre,
                    conteoCategoria[categoria.id] ?? 0,
                    maxConteo,
                    color: categoria.color,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (topEspecies.isNotEmpty)
            _tarjeta(
              titulo: 'Top especies',
              child: Column(
                children: topEspecies.entries
                    .map((entrada) => _filaTexto(entrada.key, '${entrada.value}'))
                    .toList(),
              ),
            ),
          const SizedBox(height: 16),
          if (topHabitats.isNotEmpty)
            _tarjeta(
              titulo: 'Top hábitats',
              child: Column(
                children: topHabitats.entries
                    .map((entrada) => _filaTexto(entrada.key, '${entrada.value}'))
                    .toList(),
              ),
            ),
          const SizedBox(height: 16),
          _tarjeta(
            titulo: 'Cronología',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _filaTexto('Primer hallazgo', formato.format(primero)),
                _filaTexto('Último hallazgo', formato.format(ultimo)),
                _filaTexto('Días activo', '${ultimo.difference(primero).inDays + 1}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjeta({required String titulo, required Widget child}) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              child,
            ],
          ),
        ),
      );

  Widget _filaBarra(String etiqueta, int valor, int maximo, {required Color color}) {
    final fraccion = maximo == 0 ? 0.0 : valor / maximo;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 150, child: Text(etiqueta, style: const TextStyle(fontSize: 12))),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 18,
                  decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(4)),
                ),
                FractionallySizedBox(
                  widthFactor: fraccion,
                  child: Container(
                    height: 18,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 32,
            child: Text(' $valor', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _filaTexto(String clave, String valor) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(clave, style: const TextStyle(fontSize: 13))),
            Text(valor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      );

  Widget _filaTotales(List<(String, String)> totales) => Row(
        children: totales
            .map(
              (total) => Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Text(total.$2, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        Text(total.$1, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      );
}
