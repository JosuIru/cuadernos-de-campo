import 'dart:math';
import 'package:flutter/material.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import '../datos/datos_guia.dart';

enum _ModoQuiz { comunACientifico, cientificoAComun, distintivos }

class PantallaQuiz extends StatefulWidget {
  PantallaQuiz({super.key});

  @override
  State<PantallaQuiz> createState() => _PantallaQuizState();
}

class _PantallaQuizState extends State<PantallaQuiz> {
  String _filtroCategoria = 'todos';
  _ModoQuiz _modo = _ModoQuiz.comunACientifico;
  final _aleatorio = Random();

  EspecieGuia? _correcta;
  List<EspecieGuia> _opciones = const [];
  EspecieGuia? _respuestaSeleccionada;
  int _aciertos = 0;
  int _intentos = 0;

  @override
  void initState() {
    super.initState();
    _siguientePregunta();
  }

  List<EspecieGuia> get _bancoDisponible {
    if (_filtroCategoria == 'todos') return especiesGuia;
    return especiesGuia.where((especie) => especie.categoriaId == _filtroCategoria).toList();
  }

  void _siguientePregunta() {
    final banco = _bancoDisponible;
    if (banco.length < 3) {
      setState(() {
        _correcta = null;
        _opciones = const [];
      });
      return;
    }
    final indiceCorrecta = _aleatorio.nextInt(banco.length);
    final correcta = banco[indiceCorrecta];
    final distractoresPosibles = banco.where((especie) => especie.id != correcta.id).toList()..shuffle(_aleatorio);
    final distractores = distractoresPosibles.take(3).toList();
    final opciones = [correcta, ...distractores]..shuffle(_aleatorio);
    setState(() {
      _correcta = correcta;
      _opciones = opciones;
      _respuestaSeleccionada = null;
    });
  }

  void _responder(EspecieGuia opcion) {
    if (_respuestaSeleccionada != null) return;
    setState(() {
      _respuestaSeleccionada = opcion;
      _intentos++;
      if (opcion.id == _correcta?.id) _aciertos++;
    });
  }

  String _enunciado(EspecieGuia especie) {
    return switch (_modo) {
      _ModoQuiz.comunACientifico => '¿Cuál es el nombre científico de "${especie.nombreComun}"?',
      _ModoQuiz.cientificoAComun => '¿Cuál es el nombre común de "${especie.nombreCientifico}"?',
      _ModoQuiz.distintivos => '${especie.descripcionCorta}\n\n¿Qué especie es?',
    };
  }

  String _textoOpcion(EspecieGuia especie) {
    return switch (_modo) {
      _ModoQuiz.comunACientifico => especie.nombreCientifico,
      _ModoQuiz.cientificoAComun => especie.nombreComun,
      _ModoQuiz.distintivos => '${especie.nombreComun} (${especie.nombreCientifico})',
    };
  }

  @override
  Widget build(BuildContext context) {
    final correcta = _correcta;
    final banco = _bancoDisponible;

    return Scaffold(
      appBar: AppBar(
        title: Text('Quiz'),
        actions: [
          if (_intentos > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  '$_aciertos / $_intentos',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
      body: especiesGuia.length < 3
          ? _SinSuficientesEspecies()
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            label: Text(SoleraL10n.t('todos')),
                            avatar: Icon(Icons.apps, size: 18),
                            selected: _filtroCategoria == 'todos',
                            onSelected: (_) {
                              setState(() {
                                _filtroCategoria = 'todos';
                                _aciertos = 0;
                                _intentos = 0;
                              });
                              _siguientePregunta();
                            },
                          ),
                        ),
                        for (final categoria in categoriasGuia)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: Text(categoria.nombre),
                              avatar: Icon(categoria.icono, size: 18),
                              selected: _filtroCategoria == categoria.id,
                              onSelected: (_) {
                                setState(() {
                                  _filtroCategoria = categoria.id;
                                  _aciertos = 0;
                                  _intentos = 0;
                                });
                                _siguientePregunta();
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: SegmentedButton<_ModoQuiz>(
                    segments: const [
                      ButtonSegment(value: _ModoQuiz.comunACientifico, label: Text('Común→Cient.')),
                      ButtonSegment(value: _ModoQuiz.cientificoAComun, label: Text('Cient.→Común')),
                      ButtonSegment(value: _ModoQuiz.distintivos, label: Text('Por descripción')),
                    ],
                    selected: {_modo},
                    onSelectionChanged: (seleccion) {
                      setState(() => _modo = seleccion.first);
                      _siguientePregunta();
                    },
                  ),
                ),
                Expanded(
                  child: banco.length < 3
                      ? _PocasEspeciesEnCategoria()
                      : correcta == null
                          ? Center(child: CircularProgressIndicator())
                          : _vistaPregunta(correcta),
                ),
              ],
            ),
    );
  }

  Widget _vistaPregunta(EspecieGuia correcta) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _enunciado(correcta),
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: _opciones.length,
              separatorBuilder: (_, __) => SizedBox(height: 8),
              itemBuilder: (_, indice) {
                final opcion = _opciones[indice];
                final esCorrecta = opcion.id == correcta.id;
                final esSeleccionada = _respuestaSeleccionada?.id == opcion.id;
                Color? colorFondo;
                if (_respuestaSeleccionada != null) {
                  if (esCorrecta) {
                    colorFondo = Colors.green.withValues(alpha: 0.2);
                  } else if (esSeleccionada) {
                    colorFondo = Colors.red.withValues(alpha: 0.2);
                  }
                }
                return Card(
                  color: colorFondo,
                  child: ListTile(
                    title: Text(_textoOpcion(opcion)),
                    trailing: _respuestaSeleccionada == null
                        ? null
                        : esCorrecta
                            ? Icon(Icons.check_circle, color: Colors.green)
                            : esSeleccionada
                                ? Icon(Icons.cancel, color: Colors.red)
                                : null,
                    onTap: _respuestaSeleccionada == null ? () => _responder(opcion) : null,
                  ),
                );
              },
            ),
          ),
          if (_respuestaSeleccionada != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: FilledButton.icon(
                icon: Icon(Icons.arrow_forward),
                onPressed: _siguientePregunta,
                label: Text(SoleraL10n.t('siguiente')),
              ),
            ),
        ],
      ),
    );
  }
}

class _SinSuficientesEspecies extends StatelessWidget {
  _SinSuficientesEspecies();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.quiz_outlined, size: 72, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Hacen falta al menos 3 especies para el quiz',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Añade más entradas en lib/datos/datos_guia.dart',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _PocasEspeciesEnCategoria extends StatelessWidget {
  _PocasEspeciesEnCategoria();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Esta categoría tiene menos de 3 especies. Cambia a "Todos" o añade más entradas a la guía.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}
