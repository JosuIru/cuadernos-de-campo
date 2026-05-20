import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../datos/base_datos.dart';
import '../utiles/agregados_naturaleza.dart';

/// "Mi fenología": por cada especie con registros en ≥2 años,
/// muestra el primer avistamiento de cada año y la desviación del
/// año actual respecto a la media de los anteriores. Adelantos y
/// retrasos significativos (≥14 días) se resaltan.
class PantallaFenologia extends StatefulWidget {
  const PantallaFenologia({super.key});

  @override
  State<PantallaFenologia> createState() => _PantallaFenologiaState();
}

class _PantallaFenologiaState extends State<PantallaFenologia> {
  List<FenologiaEspecie> _fenologia = const [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final hallazgos = await BaseDatosNaturaleza.instancia.listarHallazgos();
    if (!mounted) return;
    setState(() {
      _fenologia = calcularFenologia(hallazgos);
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi fenología')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _fenologia.isEmpty
              ? _vistaVacia()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  itemCount: _fenologia.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, indice) {
                    if (indice == 0) return _cabeceraExplicativa();
                    return _tarjetaEspecie(_fenologia[indice - 1]);
                  },
                ),
    );
  }

  Widget _vistaVacia() => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_today, size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Aún no hay fenología que mostrar',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'La fenología compara el primer avistamiento de cada especie '
              'entre años distintos. Cuando lleves dos primaveras anotando '
              'la misma especie, verás aquí si llegó antes o después.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      );

  Widget _cabeceraExplicativa() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'Para cada especie con observaciones en al menos dos años, '
          'el primer avistamiento de cada año. La desviación compara '
          'el año actual con la media de los anteriores.',
          style: TextStyle(fontSize: 12, color: Colors.black87),
        ),
      );

  Widget _tarjetaEspecie(FenologiaEspecie fenologia) {
    final fmt = DateFormat('d MMM', 'es_ES');
    final desviacion = fenologia.desviacionAnioActual;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    fenologia.etiquetaPrincipal,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                if (desviacion != null)
                  _pillDesviacion(desviacion),
              ],
            ),
            if (fenologia.hallazgoMuestra.especie.isNotEmpty &&
                fenologia.hallazgoMuestra.especie !=
                    fenologia.etiquetaPrincipal)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 2),
                child: Text(
                  fenologia.hallazgoMuestra.especie,
                  style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey),
                ),
              ),
            const SizedBox(height: 8),
            // Tabla mínima de años — alineamos para que se lea como
            // un diario fenológico.
            Column(
              children: fenologia.primerosPorAnio.map((p) {
                final fecha = DateTime.fromMillisecondsSinceEpoch(p.fechaMs);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 50,
                        child: Text(
                          '${p.anio}',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        fmt.format(fecha),
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'día ${p.diaDelAnio}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pillDesviacion(int dias) {
    final adelanto = dias > 0;
    final magnitudGrande = dias.abs() >= 14;
    final color = magnitudGrande
        ? (adelanto ? Colors.green.shade700 : Colors.deepOrange)
        : Colors.grey.shade600;
    final etiqueta = dias == 0
        ? 'en fecha'
        : (adelanto ? '↑ ${dias}d antes' : '↓ ${dias.abs()}d después');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        etiqueta,
        style: const TextStyle(
            color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
