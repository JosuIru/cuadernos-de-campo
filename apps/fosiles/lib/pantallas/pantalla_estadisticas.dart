import 'package:flutter/material.dart';
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

  Map<String, int> _conteoPeriodoCache = const {};
  Map<String, int> _topEspeciesCache = const {};
  Map<String, int> _topFormacionesCache = const {};
  int _maxConteoPeriodoCache = 0;
  int _especiesUnicasCache = 0;
  int _conFotoCache = 0;
  DateTime? _primeraFechaCache;
  DateTime? _ultimaFechaCache;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final lista = await BaseDatosFosiles.instancia.listarHallazgos();
    if (!mounted) return;
    _recalcularAgregados(lista);
    setState(() {
      _hallazgos = lista;
      _cargando = false;
    });
  }

  void _recalcularAgregados(List<Hallazgo> lista) {
    _conteoPeriodoCache = _calcularConteoPorPeriodo(lista);
    _maxConteoPeriodoCache = _conteoPeriodoCache.values.fold<int>(0, (a, b) => a > b ? a : b);
    _topEspeciesCache = _calcularTopConteo(lista, (h) => h.especie);
    _topFormacionesCache = _calcularTopConteo(lista, (h) => h.formacion);
    final especiesUnicas = <String>{};
    var conFoto = 0;
    int? primeraMs;
    int? ultimaMs;
    for (final h in lista) {
      final especie = h.especie.trim();
      if (especie.isNotEmpty) especiesUnicas.add(especie);
      if (h.rutaFoto != null) conFoto++;
      if (primeraMs == null || h.fechaMs < primeraMs) primeraMs = h.fechaMs;
      if (ultimaMs == null || h.fechaMs > ultimaMs) ultimaMs = h.fechaMs;
    }
    _especiesUnicasCache = especiesUnicas.length;
    _conFotoCache = conFoto;
    _primeraFechaCache = primeraMs != null ? DateTime.fromMillisecondsSinceEpoch(primeraMs) : null;
    _ultimaFechaCache = ultimaMs != null ? DateTime.fromMillisecondsSinceEpoch(ultimaMs) : null;
  }

  Map<String, int> _calcularConteoPorPeriodo(List<Hallazgo> lista) {
    final mapa = <String, int>{};
    for (final h in lista) {
      final periodoId = inferirPeriodoDesdeEdad(h.edad) ?? 'desconocido';
      mapa.update(periodoId, (v) => v + 1, ifAbsent: () => 1);
    }
    return mapa;
  }

  Map<String, int> _calcularTopConteo(List<Hallazgo> lista, String Function(Hallazgo) clave, {int limite = 5}) {
    final mapa = <String, int>{};
    for (final h in lista) {
      final v = clave(h).trim();
      if (v.isEmpty) continue;
      mapa.update(v, (n) => n + 1, ifAbsent: () => 1);
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
            child: Text('Aún no hay hallazgos para analizar.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          ),
        ),
      );
    }

    final formato = DateFormat('dd MMM yyyy', 'es_ES');
    final primero = _primeraFechaCache!;
    final ultimo = _ultimaFechaCache!;

    return Scaffold(
      appBar: AppBar(title: const Text('Estadísticas')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _filaTotales([
            ('Hallazgos', _hallazgos.length.toString()),
            ('Especies', _especiesUnicasCache.toString()),
            ('Con foto', _conFotoCache.toString()),
          ]),
          const SizedBox(height: 16),
          _tarjeta(
            titulo: 'Periodo',
            child: Column(
              children: [
                ...periodos.map((p) {
                  final n = _conteoPeriodoCache[p.id] ?? 0;
                  return _filaBarra(p.nombre, n, _maxConteoPeriodoCache, color: p.color);
                }),
                if ((_conteoPeriodoCache['desconocido'] ?? 0) > 0)
                  _filaBarra('Sin clasificar', _conteoPeriodoCache['desconocido']!, _maxConteoPeriodoCache, color: Colors.grey.shade400),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_topEspeciesCache.isNotEmpty)
            _tarjeta(
              titulo: 'Top especies',
              child: Column(
                children: _topEspeciesCache.entries.map((e) => _filaTexto(e.key, '${e.value}')).toList(),
              ),
            ),
          const SizedBox(height: 16),
          if (_topFormacionesCache.isNotEmpty)
            _tarjeta(
              titulo: 'Top formaciones',
              child: Column(
                children: _topFormacionesCache.entries.map((e) => _filaTexto(e.key, '${e.value}')).toList(),
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
    final frac = maximo == 0 ? 0.0 : valor / maximo;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 130, child: Text(etiqueta, style: const TextStyle(fontSize: 12))),
          Expanded(
            child: Stack(
              children: [
                Container(height: 18, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(4))),
                FractionallySizedBox(
                  widthFactor: frac,
                  child: Container(height: 18, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
                ),
              ],
            ),
          ),
          SizedBox(width: 32, child: Text(' $valor', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
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
        children: totales.map((t) => Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text(t.$2, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      Text(t.$1, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            )).toList(),
      );
}
