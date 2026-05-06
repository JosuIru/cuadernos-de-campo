import 'dart:math';
import 'package:flutter/material.dart';
import '../datos/datos_guia.dart';
import '../datos/datos_minerales.dart';
import '../servicios/servicio_wikipedia.dart';

class _ItemQuiz {
  final String id;
  final String nombre;
  final String grupo;
  final String tituloWikipedia;
  final String tipo;
  final String? subtituloEdad;
  final Color? colorEtiqueta;
  _ItemQuiz({required this.id, required this.nombre, required this.grupo, required this.tituloWikipedia, required this.tipo, this.subtituloEdad, this.colorEtiqueta});
}

List<_ItemQuiz> _itemsFosiles() => fosilesGuia.map((f) {
      final p = buscarPeriodo(f.periodoId);
      return _ItemQuiz(
        id: f.id,
        nombre: f.nombre,
        grupo: f.grupo,
        tituloWikipedia: f.tituloWikipedia,
        tipo: 'fosil',
        subtituloEdad: p?.nombre,
        colorEtiqueta: p?.color,
      );
    }).toList();

List<_ItemQuiz> _itemsMinerales() => mineralesGuia.map((m) {
      final c = buscarClaseMineral(m.claseStrunzId);
      return _ItemQuiz(
        id: m.id,
        nombre: m.nombre,
        grupo: '${m.formulaQuimica} · Mohs ${m.durezaMohs}',
        tituloWikipedia: m.tituloWikipedia,
        tipo: 'mineral',
        subtituloEdad: c?.nombre,
        colorEtiqueta: c?.color,
      );
    }).toList();

class PantallaQuiz extends StatefulWidget {
  const PantallaQuiz({super.key});

  @override
  State<PantallaQuiz> createState() => _PantallaQuizState();
}

class _PantallaQuizState extends State<PantallaQuiz> {
  final _aleatorio = Random();
  String _modo = 'fosiles'; // fosiles | minerales | mixto
  late _ItemQuiz _correcto;
  late List<_ItemQuiz> _opciones;
  int? _eleccion;
  int _aciertos = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _generarPregunta();
  }

  List<_ItemQuiz> _baseSegunModo() {
    switch (_modo) {
      case 'minerales':
        return _itemsMinerales();
      case 'mixto':
        return [..._itemsFosiles(), ..._itemsMinerales()];
      default:
        return _itemsFosiles();
    }
  }

  void _generarPregunta() {
    final candidatos = _baseSegunModo()..shuffle(_aleatorio);
    if (candidatos.isEmpty) return;
    _correcto = candidatos.first;
    final distractores = candidatos.skip(1).take(3).toList();
    _opciones = [_correcto, ...distractores]..shuffle(_aleatorio);
    _eleccion = null;
  }

  void _siguiente() {
    setState(() => _generarPregunta());
  }

  void _elegir(int indice) {
    if (_eleccion != null) return;
    setState(() {
      _eleccion = indice;
      _total++;
      if (_opciones[indice].id == _correcto.id) _aciertos++;
    });
  }

  void _cambiarModo(String nuevo) {
    setState(() {
      _modo = nuevo;
      _aciertos = 0;
      _total = 0;
      _generarPregunta();
    });
  }

  @override
  Widget build(BuildContext context) {
    final emojiPlaceholder = _correcto.tipo == 'mineral' ? '💎' : '🦴';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz de identificación'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('$_aciertos / $_total', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'fosiles', label: Text('Fósiles'), icon: Icon(Icons.bug_report)),
                ButtonSegment(value: 'minerales', label: Text('Minerales'), icon: Icon(Icons.diamond)),
                ButtonSegment(value: 'mixto', label: Text('Mixto')),
              ],
              selected: {_modo},
              onSelectionChanged: (s) => _cambiarModo(s.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FutureBuilder<ResumenWikipedia?>(
                  future: obtenerResumenWikipedia(_correcto.tituloWikipedia),
                  builder: (_, snapshot) {
                    final url = snapshot.data?.imagenOriginalUrl ?? snapshot.data?.thumbnailUrl;
                    if (url == null) {
                      return Container(
                        color: Colors.black12,
                        alignment: Alignment.center,
                        child: Text(emojiPlaceholder, style: const TextStyle(fontSize: 80)),
                      );
                    }
                    return Image.network(
                      url,
                      fit: BoxFit.cover,
                      headers: cabecerasImagenWiki,
                      cacheWidth: 1200,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.black12,
                        alignment: Alignment.center,
                        child: Text(emojiPlaceholder, style: const TextStyle(fontSize: 80)),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          if (_correcto.subtituloEdad != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: _correcto.colorEtiqueta ?? Colors.grey, borderRadius: BorderRadius.circular(20)),
              child: Text(_correcto.subtituloEdad!, style: const TextStyle(color: Color(0xFF2D3A2E), fontWeight: FontWeight.bold)),
            ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _opciones.length,
              itemBuilder: (_, i) {
                final item = _opciones[i];
                final esCorrecta = item.id == _correcto.id;
                final yaElegido = _eleccion != null;
                Color? colorFondo;
                if (yaElegido) {
                  if (esCorrecta) {
                    colorFondo = Colors.green.withValues(alpha: 0.2);
                  } else if (_eleccion == i) {
                    colorFondo = Colors.red.withValues(alpha: 0.2);
                  }
                }
                return Card(
                  color: colorFondo,
                  child: ListTile(
                    title: Text(item.nombre),
                    subtitle: Text(item.grupo, style: const TextStyle(fontSize: 12)),
                    trailing: yaElegido
                        ? Icon(esCorrecta ? Icons.check_circle : (_eleccion == i ? Icons.cancel : null),
                            color: esCorrecta ? Colors.green : Colors.red)
                        : const Icon(Icons.touch_app, color: Colors.black26),
                    onTap: () => _elegir(i),
                  ),
                );
              },
            ),
          ),
          if (_eleccion != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (_correcto.tipo == 'mineral') {
                          abrirDetalleMineral(context, _correcto.id);
                        } else {
                          abrirDetalleFosilGuia(context, _correcto.id);
                        }
                      },
                      icon: const Icon(Icons.info_outline),
                      label: const Text('Ver ficha'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _siguiente,
                      icon: const Icon(Icons.skip_next),
                      label: const Text('Siguiente'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
