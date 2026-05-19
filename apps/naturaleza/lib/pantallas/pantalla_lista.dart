import 'dart:io';
import 'package:flutter/material.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../datos/base_datos.dart';
import '../datos/datos_guia.dart';
import '../modelos/hallazgo.dart';
import '../servicios/exportar_zip.dart';
import '../servicios/tarjeta_imagen.dart';
import 'pantalla_estadisticas.dart';
import 'pantalla_nuevo.dart';
import 'widgets/barra_filtro_categoria.dart';

class PantallaLista extends StatefulWidget {
  PantallaLista({super.key});

  @override
  State<PantallaLista> createState() => _PantallaListaState();
}

class _PantallaListaState extends State<PantallaLista> {
  final _controladorBusqueda = TextEditingController();
  List<Hallazgo> _hallazgos = [];
  String _consulta = '';
  String _filtroCategoria = 'todos'; // 'todos' | 'animal' | 'insecto' | 'planta'

  @override
  void initState() {
    super.initState();
    _cargar();
    _controladorBusqueda.addListener(() {
      setState(() => _consulta = _controladorBusqueda.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _controladorBusqueda.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final lista = await BaseDatosNaturaleza.instancia.listarHallazgos();
    if (!mounted) return;
    setState(() => _hallazgos = lista);
  }

  List<Hallazgo> get _filtrados {
    return _hallazgos.where((hallazgo) {
      if (_filtroCategoria != 'todos' && hallazgo.categoria != _filtroCategoria) return false;
      if (_consulta.isEmpty) return true;
      final texto =
          '${hallazgo.especie} ${hallazgo.nombreComun} ${hallazgo.taxonomia} ${hallazgo.habitat} ${hallazgo.notas}'
              .toLowerCase();
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
        builder: (_, controladorScroll) => SingleChildScrollView(
          controller: controladorScroll,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hallazgo.rutasFotos.isNotEmpty)
                SizedBox(
                  height: 240,
                  child: PageView.builder(
                    itemCount: hallazgo.rutasFotos.length,
                    itemBuilder: (_, indice) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(hallazgo.rutasFotos[indice]),
                              height: 240,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          if (hallazgo.rutasFotos.length > 1)
                            Positioned(
                              right: 8,
                              bottom: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${indice + 1} / ${hallazgo.rutasFotos.length}',
                                  style: TextStyle(color: Colors.white, fontSize: 11),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              SizedBox(height: 12),
              _filaDetalle('Categoría', _etiquetaCategoria(hallazgo.categoria)),
              _filaDetalle('Nombre común', hallazgo.nombreComun.isEmpty ? '—' : hallazgo.nombreComun),
              _filaDetalle('Especie', hallazgo.especie.isEmpty ? '—' : hallazgo.especie),
              _filaDetalle('Taxonomía', hallazgo.taxonomia.isEmpty ? '—' : hallazgo.taxonomia),
              _filaDetalle('Hábitat', hallazgo.habitat.isEmpty ? '—' : hallazgo.habitat),
              _filaDetalle(
                'Fecha',
                DateFormat('dd MMM yyyy HH:mm', 'es_ES')
                    .format(DateTime.fromMillisecondsSinceEpoch(hallazgo.fechaMs)),
              ),
              _filaDetalle(
                'Coordenadas',
                '${hallazgo.latitud.toStringAsFixed(5)}, ${hallazgo.longitud.toStringAsFixed(5)}'
                '${hallazgo.precision != null ? " (±${hallazgo.precision!.round()} m)" : ""}',
              ),
              _filaDetalle('Notas', hallazgo.notas.isEmpty ? '—' : hallazgo.notas),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.edit_outlined),
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        final actualizado = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(builder: (_) => PantallaNuevoHallazgo(hallazgoExistente: hallazgo)),
                        );
                        if (actualizado == true) _cargar();
                      },
                      label: Text(SoleraL10n.t('editar')),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        final confirmar = await _confirmar(context, '¿Borrar este hallazgo?');
                        if (confirmar != true) return;
                        await BaseDatosNaturaleza.instancia.borrarHallazgo(hallazgo.id!);
                        if (!mounted) return;
                        Navigator.of(sheetContext).pop();
                        _cargar();
                      },
                      label: Text('Borrar', style: TextStyle(color: Colors.red)),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.share),
                      onPressed: () => _compartir(hallazgo),
                      label: Text('Compartir texto'),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      icon: Icon(Icons.image),
                      onPressed: () => _compartirComoTarjeta(hallazgo),
                      label: Text('Tarjeta'),
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
      builder: (_) => Center(child: CircularProgressIndicator()),
    );
    try {
      final fichero = await generarZipHallazgos(_hallazgos);
      if (!mounted) return;
      Navigator.of(context).pop();
      await Share.shareXFiles(
        [XFile(fichero.path)],
        subject: 'Hallazgos de naturaleza',
        text: '${_hallazgos.length} hallazgos exportados.',
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error exportando: $e')));
    }
  }

  Future<void> _compartirComoTarjeta(Hallazgo hallazgo) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(child: CircularProgressIndicator()),
    );
    try {
      final fichero = await generarTarjetaHallazgo(hallazgo);
      if (!mounted) return;
      Navigator.of(context).pop();
      await Share.shareXFiles([XFile(fichero.path)], subject: 'Hallazgo: ${_tituloHallazgo(hallazgo)}');
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generando tarjeta: $e')));
    }
  }

  Future<void> _compartir(Hallazgo hallazgo) async {
    final fecha =
        DateFormat('dd MMM yyyy', 'es_ES').format(DateTime.fromMillisecondsSinceEpoch(hallazgo.fechaMs));
    final texto = StringBuffer()
      ..writeln('Hallazgo de naturaleza')
      ..writeln('Categoría: ${_etiquetaCategoria(hallazgo.categoria)}')
      ..writeln('Nombre común: ${hallazgo.nombreComun.isEmpty ? "?" : hallazgo.nombreComun}')
      ..writeln('Especie: ${hallazgo.especie.isEmpty ? "?" : hallazgo.especie}')
      ..writeln('Hábitat: ${hallazgo.habitat.isEmpty ? "?" : hallazgo.habitat}')
      ..writeln('Coordenadas: ${hallazgo.latitud.toStringAsFixed(5)}, ${hallazgo.longitud.toStringAsFixed(5)}')
      ..writeln('Fecha: $fecha')
      ..writeln(
        'Mapa: https://www.openstreetmap.org/?mlat=${hallazgo.latitud}&mlon=${hallazgo.longitud}'
        '#map=16/${hallazgo.latitud}/${hallazgo.longitud}',
      );
    if (hallazgo.notas.isNotEmpty) {
      texto
        ..writeln()
        ..writeln(hallazgo.notas);
    }
    final titulo = _tituloHallazgo(hallazgo);
    if (hallazgo.rutaFoto != null) {
      await Share.shareXFiles([XFile(hallazgo.rutaFoto!)], text: texto.toString(), subject: 'Hallazgo: $titulo');
    } else {
      await Share.share(texto.toString(), subject: 'Hallazgo: $titulo');
    }
  }

  String _tituloHallazgo(Hallazgo hallazgo) {
    if (hallazgo.nombreComun.isNotEmpty) return hallazgo.nombreComun;
    if (hallazgo.especie.isNotEmpty) return hallazgo.especie;
    return 'Hallazgo';
  }

  String _etiquetaCategoria(String idCategoria) {
    return categoriaPorId(idCategoria)?.nombre ?? idCategoria;
  }

  Widget _filaDetalle(String clave, String valor) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 110, child: Text(clave, style: TextStyle(fontWeight: FontWeight.bold))),
            Expanded(child: Text(valor)),
          ],
        ),
      );

  Future<bool?> _confirmar(BuildContext context, String texto) => showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          content: Text(texto),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(SoleraL10n.t('cancelar'))),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Borrar', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hallazgos'),
        actions: [
          IconButton(
            icon: Icon(Icons.bar_chart),
            tooltip: 'Estadísticas',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => PantallaEstadisticas()),
            ),
          ),
          IconButton(
            icon: Icon(Icons.archive_outlined),
            tooltip: 'Exportar ZIP',
            onPressed: _hallazgos.isEmpty ? null : _exportar,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              controller: _controladorBusqueda,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, taxonomía, hábitat, notas…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _consulta.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Limpiar búsqueda',
                        onPressed: () => _controladorBusqueda.clear(),
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          BarraFiltroCategoria(
            filtroActual: _filtroCategoria,
            onCambio: (nuevo) => setState(() => _filtroCategoria = nuevo),
            conTarjeta: false,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _filtrados.length == _hallazgos.length
                    ? '${_hallazgos.length} hallazgo${_hallazgos.length == 1 ? "" : "s"}'
                    : '${_filtrados.length} de ${_hallazgos.length} hallazgos',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
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
                    style: TextStyle(color: Colors.grey),
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
                  itemBuilder: (_, indice) {
                    final hallazgo = _filtrados[indice];
                    final fecha = DateFormat('dd MMM yyyy', 'es_ES')
                        .format(DateTime.fromMillisecondsSinceEpoch(hallazgo.fechaMs));
                    final categoria = categoriaPorId(hallazgo.categoria);
                    return ListTile(
                      leading: hallazgo.rutaFoto != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.file(
                                File(hallazgo.rutaFoto!),
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                              ),
                            )
                          : CircleAvatar(
                              backgroundColor: (categoria?.color ?? Colors.grey).withValues(alpha: 0.2),
                              child: Icon(categoria?.icono ?? Icons.help_outline, color: categoria?.color),
                            ),
                      title: Text(_tituloHallazgo(hallazgo)),
                      subtitle: Text(
                        '${hallazgo.especie.isEmpty ? "—" : hallazgo.especie}\n'
                        '$fecha · ${hallazgo.latitud.toStringAsFixed(4)}, ${hallazgo.longitud.toStringAsFixed(4)}',
                      ),
                      isThreeLine: true,
                      onTap: () => _abrirDetalle(hallazgo),
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
