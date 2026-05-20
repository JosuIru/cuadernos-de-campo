import 'dart:io';
import 'package:flutter/material.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../datos/base_datos.dart';
import '../datos/datos_guia.dart';
import '../modelos/anotacion_diferida.dart';
import '../modelos/hallazgo.dart';
import '../servicios/checker_actualizaciones_naturaleza.dart';
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

  Future<void> _abrirDetalle(Hallazgo hallazgoOriginal) async {
    // El sheet mantiene su propio estado para poder recargar el
    // hallazgo (validar/corregir) y la lista de anotaciones diferidas
    // sin cerrarse. La pantalla externa se refresca al cerrar.
    Hallazgo hallazgo = hallazgoOriginal;
    List<AnotacionDiferida> anotaciones = const [];
    if (hallazgo.id != null) {
      anotaciones = await BaseDatosNaturaleza.instancia
          .anotacionesDeHallazgo(hallazgo.id!);
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, controladorScroll) => StatefulBuilder(
          builder: (innerContext, refrescarSheet) {
            Future<void> recargarFicha() async {
              if (hallazgo.id == null) return;
              final fresco = await BaseDatosNaturaleza.instancia
                  .obtenerHallazgo(hallazgo.id!);
              final lista = await BaseDatosNaturaleza.instancia
                  .anotacionesDeHallazgo(hallazgo.id!);
              if (fresco == null) return;
              refrescarSheet(() {
                hallazgo = fresco;
                anotaciones = lista;
              });
            }

            return SingleChildScrollView(
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
              _badgesEvidencia(hallazgo),
              _filaDetalle('Categoría', _etiquetaCategoria(hallazgo.categoria)),
              _filaDetalle('Nombre común', hallazgo.nombreComun.isEmpty ? '—' : hallazgo.nombreComun),
              _filaDetalle('Especie', hallazgo.especie.isEmpty ? '—' : hallazgo.especie),
              if (hallazgo.especieCorregida.isNotEmpty)
                _filaDetalle('Corregida a', hallazgo.especieCorregida),
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
              if (hallazgo.hipotesis.isNotEmpty) ...[
                const SizedBox(height: 8),
                _bloqueHipotesis(hallazgo),
              ],
              const SizedBox(height: 16),
              _bloqueValidacion(hallazgo, recargarFicha),
              const SizedBox(height: 16),
              _bloqueAnotacionesHallazgo(hallazgo, anotaciones, recargarFicha),
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
            );
          },
        ),
      ),
    );
    if (mounted) _cargar();
  }

  // ─── Bloques de la ficha (v3) ─────────────────────────────────────

  Widget _badgesEvidencia(Hallazgo hallazgo) {
    final badges = <Widget>[];
    badges.add(_pillEvidencia(
      _etiquetaTipoEvidencia(hallazgo.tipoEvidencia),
      const Color(0xFF3A7D5A),
    ));
    if (hallazgo.confianzaIdentificacion != null) {
      final etiqueta = hallazgo.confianzaIdentificacion!;
      badges.add(_pillEvidencia(
        'Confianza: ${etiqueta[0].toUpperCase()}${etiqueta.substring(1)}',
        Colors.blueGrey,
      ));
    }
    switch (hallazgo.identificacionValidada) {
      case EstadoIdentificacion.confirmada:
        badges.add(_pillEvidencia('✓ Confirmada', Colors.green.shade700));
        break;
      case EstadoIdentificacion.corregida:
        badges.add(_pillEvidencia('→ Corregida', Colors.deepOrange));
        break;
      default:
        if (hallazgo.especie.isNotEmpty) {
          badges.add(_pillEvidencia('? Sin validar', Colors.grey));
        }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(spacing: 6, runSpacing: 6, children: badges),
    );
  }

  Widget _pillEvidencia(String etiqueta, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(etiqueta,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold)),
      );

  String _etiquetaTipoEvidencia(TipoEvidencia tipo) => tipo.etiqueta;

  Widget _bloqueHipotesis(Hallazgo hallazgo) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blueGrey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border(
              left: BorderSide(color: Colors.blueGrey.shade400, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tu hipótesis',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 4),
            Text(hallazgo.hipotesis,
                style: const TextStyle(fontSize: 13, height: 1.4)),
          ],
        ),
      );

  Widget _bloqueValidacion(Hallazgo hallazgo, Future<void> Function() recargar) {
    if (hallazgo.id == null) return const SizedBox.shrink();
    final etiquetaEspecieActual = hallazgo.especieCorregida.isNotEmpty
        ? hallazgo.especieCorregida
        : (hallazgo.especie.isNotEmpty
            ? hallazgo.especie
            : hallazgo.nombreComun);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Validar identificación',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text(
            'Tras revisar fotos o bibliografía, marca si era correcta '
            'o anota la especie real. Sirve para calcular tu tasa de '
            'acierto en el tiempo.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(
                    hallazgo.identificacionValidada ==
                            EstadoIdentificacion.confirmada
                        ? 'Confirmada ✓'
                        : 'Confirmar',
                  ),
                  onPressed: hallazgo.identificacionValidada ==
                          EstadoIdentificacion.confirmada
                      ? null
                      : () async {
                          await BaseDatosNaturaleza.instancia
                              .actualizarHallazgo(hallazgo.id!, {
                            'identificacion_validada':
                                EstadoIdentificacion.confirmada,
                            'especie_corregida': null,
                          });
                          await recargar();
                        },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Corregir'),
                  onPressed: () => _dialogoCorregirEspecie(
                      hallazgo, etiquetaEspecieActual, recargar),
                ),
              ),
            ],
          ),
          if (hallazgo.identificacionValidada !=
              EstadoIdentificacion.sinRevisar) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                await BaseDatosNaturaleza.instancia.actualizarHallazgo(
                  hallazgo.id!,
                  {
                    'identificacion_validada':
                        EstadoIdentificacion.sinRevisar,
                  },
                );
                await recargar();
              },
              child: const Text('Volver a sin revisar'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _dialogoCorregirEspecie(Hallazgo hallazgo,
      String etiquetaActual, Future<void> Function() recargar) async {
    final controlador = TextEditingController(
        text: hallazgo.especieCorregida.isNotEmpty
            ? hallazgo.especieCorregida
            : '');
    final corregida = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Corregir identificación'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Identificación actual: $etiquetaActual',
                style:
                    const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: controlador,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Especie real',
                hintText: 'nombre científico o común',
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(controlador.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (corregida == null || corregida.isEmpty) return;
    await BaseDatosNaturaleza.instancia.actualizarHallazgo(hallazgo.id!, {
      'identificacion_validada': EstadoIdentificacion.corregida,
      'especie_corregida': corregida,
    });
    await recargar();
  }

  Widget _bloqueAnotacionesHallazgo(Hallazgo hallazgo,
      List<AnotacionDiferida> anotaciones,
      Future<void> Function() recargar) {
    if (hallazgo.id == null) return const SizedBox.shrink();
    final fmt = DateFormat('d MMM HH:mm', 'es_ES');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Anotaciones al margen',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            TextButton.icon(
              onPressed: () => _aniadirAnotacionAHallazgo(hallazgo, recargar),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Añadir'),
            ),
          ],
        ),
        if (anotaciones.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Sin anotaciones. Úsalas para revisar dudas, conexiones '
              'con otra salida, correcciones de detalle.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          )
        else
          ...anotaciones.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 3),
                    ),
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fmt.format(DateTime.fromMillisecondsSinceEpoch(
                                  a.fechaAnotacionMs)),
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey),
                            ),
                            const SizedBox(height: 2),
                            Text(a.texto,
                                style: const TextStyle(
                                    fontSize: 13, height: 1.4)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            size: 18, color: Colors.grey),
                        tooltip: 'Borrar anotación',
                        onPressed: () =>
                            _borrarAnotacion(a.id, recargar),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                            minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
                ),
              )),
      ],
    );
  }

  Future<void> _borrarAnotacion(
      int? idAnotacion, Future<void> Function() recargar) async {
    if (idAnotacion == null) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Borrar anotación'),
        content: const Text(
          'Se borrará esta anotación al margen. El hallazgo y otras '
          'anotaciones se mantienen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    await BaseDatosNaturaleza.instancia
        .borrarAnotacionDiferida(idAnotacion);
    await recargar();
  }

  Future<void> _aniadirAnotacionAHallazgo(
      Hallazgo hallazgo, Future<void> Function() recargar) async {
    if (hallazgo.id == null) return;
    final controladorTexto = TextEditingController();
    final guardada = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Anotación al margen'),
        content: TextField(
          controller: controladorTexto,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Texto',
            hintText: 'p. ej. al final era hembra, no macho',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (guardada != true || controladorTexto.text.trim().isEmpty) return;
    final anotacion = AnotacionDiferida(
      fechaAnotacionMs: DateTime.now().millisecondsSinceEpoch,
      hallazgoId: hallazgo.id,
      salidaId: hallazgo.salidaId,
      texto: controladorTexto.text.trim(),
    );
    await BaseDatosNaturaleza.instancia.guardarAnotacionDiferida(anotacion);
    await recargar();
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

  /// Subtítulo de la lista: si hay corrección de identificación,
  /// muestra la especie corregida prominente y la original pequeña
  /// y tachada al lado. Si no, comportamiento normal.
  Widget _subtituloHallazgo(Hallazgo hallazgo, String fecha) {
    final lineaCoordenadas =
        '$fecha · ${hallazgo.latitud.toStringAsFixed(4)}, ${hallazgo.longitud.toStringAsFixed(4)}';
    final hayCorreccion =
        hallazgo.identificacionValidada == EstadoIdentificacion.corregida &&
            hallazgo.especieCorregida.isNotEmpty;

    if (!hayCorreccion) {
      return Text(
        '${hallazgo.especie.isEmpty ? "—" : hallazgo.especie}\n$lineaCoordenadas',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                hallazgo.especieCorregida,
                style: const TextStyle(fontStyle: FontStyle.italic),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hallazgo.especie.isNotEmpty) ...[
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  hallazgo.especie,
                  style: const TextStyle(
                    decoration: TextDecoration.lineThrough,
                    color: Colors.grey,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
        Text(lineaCoordenadas),
      ],
    );
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
          ValueListenableBuilder<ActualizacionDisponible?>(
            valueListenable: notificadorActualizacion,
            builder: (_, actualizacion, __) {
              if (actualizacion == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: BannerActualizacionDisponible(
                  actualizacion: actualizacion,
                  compacto: true,
                  onDescartar: () =>
                      notificadorActualizacion.value = null,
                ),
              );
            },
          ),
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
                      subtitle: _subtituloHallazgo(hallazgo, fecha),
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
