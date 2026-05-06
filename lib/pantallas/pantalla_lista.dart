import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../datos/base_datos.dart';
import '../modelos/hallazgo.dart';
import '../servicios/exportar_zip.dart';
import '../servicios/tarjeta_imagen.dart';
import 'pantalla_estadisticas.dart';
import 'pantalla_nuevo.dart';

class PantallaLista extends StatefulWidget {
  const PantallaLista({super.key});

  @override
  State<PantallaLista> createState() => _PantallaListaState();
}

class _PantallaListaState extends State<PantallaLista> {
  final _controladorBusqueda = TextEditingController();
  List<Hallazgo> _hallazgos = [];
  String _consulta = '';
  String _filtroTipo = 'todos'; // 'todos' | 'fosil' | 'mineral'

  @override
  void initState() {
    super.initState();
    _cargar();
    _controladorBusqueda.addListener(() {
      setState(() => _consulta = _controladorBusqueda.text.trim().toLowerCase());
    });
  }

  Future<void> _cargar() async {
    final lista = await BaseDatosFosiles.instancia.listarHallazgos();
    if (!mounted) return;
    setState(() => _hallazgos = lista);
  }

  List<Hallazgo> get _filtrados {
    return _hallazgos.where((h) {
      if (_filtroTipo != 'todos' && h.tipo != _filtroTipo) return false;
      if (_consulta.isEmpty) return true;
      final texto = '${h.especie} ${h.edad} ${h.formacion} ${h.notas}'.toLowerCase();
      return texto.contains(_consulta);
    }).toList();
  }

  Future<void> _abrirDetalle(Hallazgo hallazgo) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hallazgo.rutasFotos.isNotEmpty)
                SizedBox(
                  height: 240,
                  child: PageView.builder(
                    itemCount: hallazgo.rutasFotos.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(File(hallazgo.rutasFotos[i]), height: 240, width: double.infinity, fit: BoxFit.cover),
                          ),
                          if (hallazgo.rutasFotos.length > 1)
                            Positioned(
                              right: 8,
                              bottom: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                                child: Text('${i + 1} / ${hallazgo.rutasFotos.length}', style: const TextStyle(color: Colors.white, fontSize: 11)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              _filaDetalle('Especie', hallazgo.especie.isEmpty ? '—' : hallazgo.especie),
              _filaDetalle('Edad', hallazgo.edad.isEmpty ? '—' : hallazgo.edad),
              _filaDetalle('Formación', hallazgo.formacion.isEmpty ? '—' : hallazgo.formacion),
              _filaDetalle('Fecha', DateFormat('dd MMM yyyy HH:mm', 'es_ES').format(DateTime.fromMillisecondsSinceEpoch(hallazgo.fechaMs))),
              _filaDetalle('Coordenadas', '${hallazgo.latitud.toStringAsFixed(5)}, ${hallazgo.longitud.toStringAsFixed(5)}${hallazgo.precision != null ? " (±${hallazgo.precision!.round()} m)" : ""}'),
              if (hallazgo.strikeGrados != null && hallazgo.dipGrados != null)
                _filaDetalle('Estrato', '${hallazgo.strikeGrados!.toStringAsFixed(0)}° / ${hallazgo.dipGrados!.toStringAsFixed(0)}°'),
              _filaDetalle('Notas', hallazgo.notas.isEmpty ? '—' : hallazgo.notas),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        final actualizado = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(builder: (_) => PantallaNuevoHallazgo(hallazgoExistente: hallazgo)),
                        );
                        if (actualizado == true) _cargar();
                      },
                      label: const Text('Editar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        final confirmar = await _confirmar(context, '¿Borrar este hallazgo?');
                        if (confirmar != true) return;
                        await BaseDatosFosiles.instancia.borrarHallazgo(hallazgo.id!);
                        if (!mounted) return;
                        Navigator.of(sheetContext).pop();
                        _cargar();
                      },
                      label: const Text('Borrar', style: TextStyle(color: Colors.red)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.share),
                      onPressed: () => _compartir(hallazgo),
                      label: const Text('Compartir texto'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.image),
                      onPressed: () => _compartirComoTarjeta(hallazgo),
                      label: const Text('Tarjeta'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportar() async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final fichero = await generarZipHallazgos(_hallazgos);
      if (!mounted) return;
      Navigator.of(context).pop(); // cerrar progress
      await Share.shareXFiles([XFile(fichero.path)], subject: 'Hallazgos de fósiles', text: '${_hallazgos.length} hallazgos exportados.');
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error exportando: $e')));
    }
  }

  Future<void> _compartirComoTarjeta(Hallazgo hallazgo) async {
    showDialog<void>(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      final fichero = await generarTarjetaHallazgo(hallazgo);
      if (!mounted) return;
      Navigator.of(context).pop();
      await Share.shareXFiles([XFile(fichero.path)], subject: 'Hallazgo: ${hallazgo.especie}');
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generando tarjeta: $e')));
    }
  }

  Future<void> _compartir(Hallazgo hallazgo) async {
    final fecha = DateFormat('dd MMM yyyy', 'es_ES').format(DateTime.fromMillisecondsSinceEpoch(hallazgo.fechaMs));
    final texto = StringBuffer()
      ..writeln('Hallazgo de fósil')
      ..writeln('Especie: ${hallazgo.especie.isEmpty ? "?" : hallazgo.especie}')
      ..writeln('Edad: ${hallazgo.edad.isEmpty ? "?" : hallazgo.edad}')
      ..writeln('Formación: ${hallazgo.formacion.isEmpty ? "?" : hallazgo.formacion}')
      ..writeln('Coordenadas: ${hallazgo.latitud.toStringAsFixed(5)}, ${hallazgo.longitud.toStringAsFixed(5)}')
      ..writeln('Fecha: $fecha')
      ..writeln('Mapa: https://www.openstreetmap.org/?mlat=${hallazgo.latitud}&mlon=${hallazgo.longitud}#map=16/${hallazgo.latitud}/${hallazgo.longitud}');
    if (hallazgo.notas.isNotEmpty) {
      texto..writeln()..writeln(hallazgo.notas);
    }
    if (hallazgo.rutaFoto != null) {
      await Share.shareXFiles([XFile(hallazgo.rutaFoto!)], text: texto.toString(), subject: 'Hallazgo: ${hallazgo.especie}');
    } else {
      await Share.share(texto.toString(), subject: 'Hallazgo: ${hallazgo.especie}');
    }
  }

  Widget _filaDetalle(String clave, String valor) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 100, child: Text(clave, style: const TextStyle(fontWeight: FontWeight.bold))),
            Expanded(child: Text(valor)),
          ],
        ),
      );

  Future<bool?> _confirmar(BuildContext context, String texto) => showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          content: Text(texto),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Borrar', style: TextStyle(color: Colors.red))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hallazgos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Estadísticas',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PantallaEstadisticas())),
          ),
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            tooltip: 'Exportar ZIP',
            onPressed: _hallazgos.isEmpty ? null : _exportar,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: TextField(
              controller: _controladorBusqueda,
              decoration: const InputDecoration(
                hintText: 'Buscar por nombre, edad, notas…',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'todos', label: Text('Todos'), icon: Icon(Icons.apps)),
                ButtonSegment(value: 'fosil', label: Text('Fósiles'), icon: Icon(Icons.bug_report)),
                ButtonSegment(value: 'mineral', label: Text('Minerales'), icon: Icon(Icons.diamond)),
              ],
              selected: {_filtroTipo},
              onSelectionChanged: (s) => setState(() => _filtroTipo = s.first),
            ),
          ),
          if (_filtrados.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _hallazgos.isEmpty
                        ? 'Aún no hay hallazgos.\nToca el + para registrar el primero.'
                        : 'Ningún hallazgo coincide con la búsqueda.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _cargar,
                child: ListView.builder(
                  itemCount: _filtrados.length,
                  itemBuilder: (_, i) {
                    final h = _filtrados[i];
                    final fecha = DateFormat('dd MMM yyyy', 'es_ES').format(DateTime.fromMillisecondsSinceEpoch(h.fechaMs));
                    return ListTile(
                      leading: h.rutaFoto != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.file(File(h.rutaFoto!), width: 48, height: 48, fit: BoxFit.cover),
                            )
                          : const CircleAvatar(child: Icon(Icons.image_not_supported)),
                      title: Text(h.especie.isEmpty ? 'Sin nombre' : h.especie),
                      subtitle: Text('${h.edad.isEmpty ? "—" : h.edad}\n$fecha · ${h.latitud.toStringAsFixed(4)}, ${h.longitud.toStringAsFixed(4)}'),
                      isThreeLine: true,
                      onTap: () => _abrirDetalle(h),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
