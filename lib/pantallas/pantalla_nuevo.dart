import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path_lib;
import 'package:path_provider/path_provider.dart';
import '../datos/base_datos.dart';
import '../datos/configuracion.dart';
import '../datos/datos_guia.dart';
import '../modelos/hallazgo.dart';
import '../servicios/identidad_descubridor.dart';
import '../servicios/identificador_claude.dart';
import '../servicios/servicio_geologia.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../servicios/servicio_wikipedia.dart';
import '../utiles/permisos_gps.dart';
import 'modal_orientacion_estrato.dart';
import 'pantalla_anotar_foto.dart';

class PantallaNuevoHallazgo extends StatefulWidget {
  final double? latitudPredefinida;
  final double? longitudPredefinida;
  final Hallazgo? hallazgoExistente;
  const PantallaNuevoHallazgo({super.key, this.latitudPredefinida, this.longitudPredefinida, this.hallazgoExistente});

  bool get esEdicion => hallazgoExistente != null;

  @override
  State<PantallaNuevoHallazgo> createState() => _PantallaNuevoHallazgoState();
}

class _PantallaNuevoHallazgoState extends State<PantallaNuevoHallazgo> {
  final _controladorEspecie = TextEditingController();
  final _controladorEdad = TextEditingController();
  final _controladorFormacion = TextEditingController();
  final _controladorNotas = TextEditingController();
  final _selectorImagen = ImagePicker();

  final List<String> _rutasFotosExistentes = [];
  final List<File> _fotosNuevas = [];
  Position? _ubicacion;
  ContextoGeologico? _contextoGeo;
  bool _consultandoGeologia = false;
  bool _identificandoFosil = false;
  bool _guardando = false;
  String? _monedaReferencia;
  String _estadoGps = 'Obteniendo GPS…';
  double? _strikeGrados;
  double? _dipGrados;
  String _tipoHallazgo = 'fosil';

  @override
  void initState() {
    super.initState();
    final h = widget.hallazgoExistente;
    if (h != null) {
      _controladorEspecie.text = h.especie;
      _controladorEdad.text = h.edad;
      _controladorFormacion.text = h.formacion;
      _controladorNotas.text = h.notas;
      _rutasFotosExistentes.addAll(h.rutasFotos);
      _strikeGrados = h.strikeGrados;
      _dipGrados = h.dipGrados;
      _tipoHallazgo = h.tipo;
      _estadoGps = '📍 ${h.latitud.toStringAsFixed(5)}, ${h.longitud.toStringAsFixed(5)}';
    }
    _iniciarFlujo();
  }

  @override
  void dispose() {
    _controladorEspecie.dispose();
    _controladorEdad.dispose();
    _controladorFormacion.dispose();
    _controladorNotas.dispose();
    super.dispose();
  }

  Future<void> _iniciarFlujo() async {
    Position? posicion;
    if (widget.esEdicion) {
      final h = widget.hallazgoExistente!;
      _consultarGeologia(h.latitud, h.longitud);
      return;
    }
    if (widget.latitudPredefinida != null && widget.longitudPredefinida != null) {
      setState(() {
        _estadoGps = '📍 Punto marcado en mapa';
      });
    } else {
      final permitido = await asegurarPermisoUbicacion();
      if (!permitido) {
        setState(() => _estadoGps = 'Permiso de ubicación denegado.');
      } else {
        try {
          final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
          posicion = pos;
          if (!mounted) return;
          setState(() {
            _ubicacion = pos;
            _estadoGps = '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)} (±${pos.accuracy.round()} m)';
          });
        } catch (e) {
          if (!mounted) return;
          setState(() => _estadoGps = 'Error GPS: $e');
        }
      }
    }
    final lat = widget.latitudPredefinida ?? posicion?.latitude;
    final lon = widget.longitudPredefinida ?? posicion?.longitude;
    if (lat != null && lon != null) {
      _consultarGeologia(lat, lon);
    }
  }

  Future<void> _consultarGeologia(double lat, double lon) async {
    setState(() => _consultandoGeologia = true);
    final contexto = await consultarContextoGeologico(lat, lon);
    if (!mounted) return;
    setState(() {
      _contextoGeo = contexto;
      _consultandoGeologia = false;
      if (contexto != null) {
        if (contexto.edad != null && _controladorEdad.text.isEmpty) _controladorEdad.text = contexto.edad!;
        final formacionAuto = contexto.formacion ?? contexto.litologia;
        if (formacionAuto != null && _controladorFormacion.text.isEmpty) _controladorFormacion.text = formacionAuto;
      }
    });
  }

  Future<void> _hacerFoto() async {
    final foto = await _selectorImagen.pickImage(source: ImageSource.camera, imageQuality: 88, maxWidth: 2000);
    if (foto == null) return;
    setState(() => _fotosNuevas.add(File(foto.path)));
  }

  Future<void> _elegirFotoGaleria() async {
    final fotos = await _selectorImagen.pickMultiImage(imageQuality: 88, maxWidth: 2000);
    if (fotos.isEmpty) return;
    setState(() => _fotosNuevas.addAll(fotos.map((x) => File(x.path))));
  }

  File? get _primeraFotoParaIdentificar {
    if (_fotosNuevas.isNotEmpty) return _fotosNuevas.first;
    if (_rutasFotosExistentes.isNotEmpty) return File(_rutasFotosExistentes.first);
    return null;
  }

  bool get _tieneAlgunaFoto => _fotosNuevas.isNotEmpty || _rutasFotosExistentes.isNotEmpty;

  Future<void> _identificarConClaude() async {
    final fotoParaIdentificar = _primeraFotoParaIdentificar;
    if (fotoParaIdentificar == null) return;
    if (!await Configuracion.tieneApiKey()) {
      _mostrarSnack('Configura primero tu API key en Ajustes.');
      return;
    }
    setState(() => _identificandoFosil = true);
    try {
      final lat = widget.latitudPredefinida ?? _ubicacion?.latitude;
      final lon = widget.longitudPredefinida ?? _ubicacion?.longitude;
      final identificacion = await identificarFosil(
        archivoFoto: fotoParaIdentificar,
        contexto: ContextoIdentificacion(
          latitud: lat,
          longitud: lon,
          edad: _controladorEdad.text.trim().isEmpty ? _contextoGeo?.edad : _controladorEdad.text.trim(),
          formacion: _controladorFormacion.text.trim().isEmpty ? _contextoGeo?.formacion : _controladorFormacion.text.trim(),
          litologia: _contextoGeo?.litologia,
          notas: _controladorNotas.text.trim(),
          especieTentativa: _controladorEspecie.text.trim(),
          monedaReferencia: _monedaReferencia,
          tipoEsperado: _tipoHallazgo,
        ),
      );
      if (!mounted) return;
      _mostrarResultadoIdentificacion(identificacion);
    } catch (e) {
      _mostrarSnack('Error identificando: $e');
    } finally {
      if (mounted) setState(() => _identificandoFosil = false);
    }
  }

  void _mostrarResultadoIdentificacion(IdentificacionFosil identificacion) {
    showModalBottomSheet<void>(
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
              Text(identificacion.identificacionTentativa, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text('${identificacion.grupoTaxonomico} · ${identificacion.edadEstimada ?? ''}',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: switch (identificacion.confianza) {
                    'alta' => Colors.green.shade100,
                    'media' => Colors.amber.shade100,
                    _ => Colors.red.shade100,
                  },
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Confianza ${identificacion.confianza}',
                    style: TextStyle(
                      fontSize: 12,
                      color: switch (identificacion.confianza) {
                        'alta' => Colors.green.shade900,
                        'media' => Colors.amber.shade900,
                        _ => Colors.red.shade900,
                      },
                    )),
              ),
              const SizedBox(height: 16),
              if (_bannerDiscrepanciaPeriodo(identificacion) != null) _bannerDiscrepanciaPeriodo(identificacion)!,
              if (identificacion.tipoDetectado == 'mineral')
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.blueGrey.shade100, borderRadius: BorderRadius.circular(4)),
                    child: Text('💎 Detectado como mineral',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey.shade900)),
                  ),
                ),
              if (identificacion.tamanoEstimado != null && identificacion.tamanoEstimado!.isNotEmpty)
                _bloque('Tamaño estimado', identificacion.tamanoEstimado!),
              if (identificacion.durezaMohsEstimada != null && identificacion.durezaMohsEstimada!.isNotEmpty)
                _bloque('Dureza Mohs estimada', identificacion.durezaMohsEstimada!),
              _bloque('Descripción', identificacion.descripcion),
              _bloque('Razonamiento', identificacion.razonamiento),
              if (identificacion.alternativas.isNotEmpty)
                _bloque('Alternativas', identificacion.alternativas.map((a) => '• $a').join('\n')),
              _bloque('Cómo confirmar', identificacion.comoConfirmar),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        _aplicarIdentificacionAlFormulario(identificacion);
                        Navigator.of(sheetContext).pop();
                      },
                      child: const Text('Aplicar al formulario'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('Descartar'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Center(child: Text('Modelo: ${identificacion.modeloUsado}', style: const TextStyle(fontSize: 11, color: Colors.grey))),
            ],
          ),
        ),
      ),
    );
  }

  void _aplicarIdentificacionAlFormulario(IdentificacionFosil identificacion) {
    setState(() {
      if (identificacion.tipoDetectado == 'mineral' || identificacion.tipoDetectado == 'fosil') {
        _tipoHallazgo = identificacion.tipoDetectado;
      }
      _controladorEspecie.text = identificacion.identificacionTentativa;
      if (identificacion.edadEstimada != null && identificacion.edadEstimada!.isNotEmpty) {
        _controladorEdad.text = identificacion.edadEstimada!;
      }
      final notasPrev = _controladorNotas.text.trim();
      final adicion = '[Claude · ${identificacion.confianza}] ${identificacion.descripcion}';
      final altLinea = identificacion.alternativas.isNotEmpty ? 'Alt: ${identificacion.alternativas.join(", ")}' : null;
      final durezaLinea = identificacion.durezaMohsEstimada != null && identificacion.durezaMohsEstimada!.isNotEmpty
          ? 'Dureza Mohs: ${identificacion.durezaMohsEstimada}'
          : null;
      final partes = <String>[notasPrev, adicion, if (altLinea != null) altLinea, if (durezaLinea != null) durezaLinea].where((s) => s.isNotEmpty).toList();
      _controladorNotas.text = partes.join('\n\n');
    });
  }

  Widget _bloque(String titulo, String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 2),
            Text(texto),
          ],
        ),
      );

  Future<void> _guardar() async {
    final h = widget.hallazgoExistente;
    final lat = h?.latitud ?? widget.latitudPredefinida ?? _ubicacion?.latitude;
    final lon = h?.longitud ?? widget.longitudPredefinida ?? _ubicacion?.longitude;
    if (lat == null || lon == null) {
      _mostrarSnack('Esperando posición GPS…');
      return;
    }
    setState(() => _guardando = true);
    final dir = await getApplicationDocumentsDirectory();
    final dirFotos = Directory(path_lib.join(dir.path, 'fotos'));
    if (_fotosNuevas.isNotEmpty && !await dirFotos.exists()) await dirFotos.create(recursive: true);
    final rutasFinales = List<String>.from(_rutasFotosExistentes);
    for (final fotoNueva in _fotosNuevas) {
      final nombre = 'foto_${DateTime.now().millisecondsSinceEpoch}_${rutasFinales.length}.jpg';
      final destino = File(path_lib.join(dirFotos.path, nombre));
      await fotoNueva.copy(destino.path);
      rutasFinales.add(destino.path);
    }
    if (widget.esEdicion) {
      final idHallazgo = h?.id;
      if (idHallazgo == null) {
        _mostrarSnack('Error: el hallazgo no tiene ID.');
        setState(() => _guardando = false);
        return;
      }
      await BaseDatosFosiles.instancia.actualizarHallazgo(idHallazgo, {
        'especie': _controladorEspecie.text.trim(),
        'edad': _controladorEdad.text.trim(),
        'formacion': _controladorFormacion.text.trim(),
        'notas': _controladorNotas.text.trim(),
        'ruta_foto': rutasFinales.isEmpty ? null : rutasFinales.first,
        'rutas_fotos_json': rutasFinales.isEmpty ? null : jsonEncode(rutasFinales),
        'strike_grados': _strikeGrados,
        'dip_grados': _dipGrados,
        'tipo': _tipoHallazgo,
      });
    } else {
      // Firma criptográfica del descubridor (Fase A). Si el usuario aún no
      // ha rellenado su nombre en Ajustes, la firma sigue valiendo: la clave
      // pública es huella permanente. El nombre se incluye en el mensaje
      // canónico aunque sea cadena vacía — la firma cuadra mientras no se
      // cambie después. Si la generación falla por algún motivo (Keystore
      // bloqueado, dispositivo sin almacenamiento seguro), guardamos el
      // hallazgo sin firma en lugar de bloquear la captura en campo.
      final hallazgoSinFirma = Hallazgo(
        fechaMs: DateTime.now().millisecondsSinceEpoch,
        latitud: lat,
        longitud: lon,
        precision: _ubicacion?.accuracy,
        especie: _controladorEspecie.text.trim(),
        edad: _controladorEdad.text.trim(),
        formacion: _controladorFormacion.text.trim(),
        notas: _controladorNotas.text.trim(),
        rutasFotos: rutasFinales,
        contextoGeologicoCrudoJson: _contextoGeo == null ? null : jsonEncode(_contextoGeo!.crudo),
        strikeGrados: _strikeGrados,
        dipGrados: _dipGrados,
        tipo: _tipoHallazgo,
      );
      String? firma;
      String? clavePublica;
      try {
        final nombreDescubridor = await Configuracion.obtenerNombreDescubridor();
        final mensajeCanonico = IdentidadDescubridor.mensajeCanonicoHallazgo(
          hallazgoSinFirma,
          nombreDescubridor,
        );
        firma = await IdentidadDescubridor.instancia.firmar(mensajeCanonico);
        clavePublica = await IdentidadDescubridor.instancia.obtenerClavePublicaBase64();
      } catch (_) {
        firma = null;
        clavePublica = null;
      }
      final hallazgo = hallazgoSinFirma.copyWith(
        firmaDescubridor: firma,
        clavePublicaDescubridor: clavePublica,
      );
      await BaseDatosFosiles.instancia.guardarHallazgo(hallazgo);
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  void _mostrarSnack(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) {
    final partesContexto = [
      if (_contextoGeo?.edad != null) _contextoGeo!.edad!,
      if (_contextoGeo?.formacion != null) _contextoGeo!.formacion!,
      if (_contextoGeo?.litologia != null) _contextoGeo!.litologia!,
    ];
    final tieneFoto = _tieneAlgunaFoto;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.esEdicion ? 'Editar hallazgo' : 'Nuevo hallazgo'),
        actions: [
          TextButton(
            onPressed: _guardando ? null : _guardar,
            child: _guardando
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Guardar'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'fosil', label: Text('Fósil'), icon: Icon(Icons.bug_report)),
              ButtonSegment(value: 'mineral', label: Text('Mineral'), icon: Icon(Icons.diamond)),
            ],
            selected: {_tipoHallazgo},
            onSelectionChanged: (s) => setState(() => _tipoHallazgo = s.first),
          ),
          const SizedBox(height: 12),
          _galeriaFotos(tieneFoto),
          const SizedBox(height: 16),
          _campoLectura('Ubicación', _estadoGps),
          const SizedBox(height: 8),
          _campoLectura('Contexto geológico', _consultandoGeologia ? 'Consultando IGME…' : (partesContexto.isEmpty ? '—' : partesContexto.join(' · '))),
          if (_tipoHallazgo == 'fosil') _tiraFosilesProbables(),
          const SizedBox(height: 16),
          TextField(
            controller: _controladorEspecie,
            decoration: InputDecoration(
              labelText: _tipoHallazgo == 'mineral' ? 'Nombre del mineral' : 'Especie / nombre tentativo',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: _identificandoFosil
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome),
            onPressed: _tieneAlgunaFoto && !_identificandoFosil ? _identificarConClaude : null,
            label: Text(_identificandoFosil ? 'Identificando…' : 'Identificar con Claude'),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Padding(padding: EdgeInsets.only(right: 8), child: Text('Moneda en foto:', style: TextStyle(fontSize: 12))),
              Expanded(
                child: Wrap(
                  spacing: 4,
                  children: [
                    ChoiceChip(
                      label: const Text('No', style: TextStyle(fontSize: 11)),
                      selected: _monedaReferencia == null,
                      onSelected: (_) => setState(() => _monedaReferencia = null),
                    ),
                    for (final moneda in monedasReferenciaDisponibles)
                      ChoiceChip(
                        label: Text(moneda, style: const TextStyle(fontSize: 11)),
                        selected: _monedaReferencia == moneda,
                        onSelected: (_) => setState(() => _monedaReferencia = moneda),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(controller: _controladorEdad, decoration: const InputDecoration(labelText: 'Edad / periodo', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: _controladorFormacion, decoration: const InputDecoration(labelText: 'Formación geológica', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          _filaOrientacion(),
          const SizedBox(height: 8),
          TextField(
            controller: _controladorNotas,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Notas', border: OutlineInputBorder(), alignLabelWithHint: true),
          ),
        ],
      ),
    );
  }

  Widget _galeriaFotos(bool tieneFoto) {
    final items = <Widget>[];
    for (var i = 0; i < _rutasFotosExistentes.length; i++) {
      final ruta = _rutasFotosExistentes[i];
      items.add(_miniaturaFoto(
        archivo: File(ruta),
        onBorrar: () => setState(() => _rutasFotosExistentes.removeAt(i)),
      ));
    }
    for (var i = 0; i < _fotosNuevas.length; i++) {
      items.add(_miniaturaFoto(
        archivo: _fotosNuevas[i],
        onBorrar: () => setState(() => _fotosNuevas.removeAt(i)),
      ));
    }
    items.add(_botonAnadirFoto());
    if (!tieneFoto && items.length == 1) {
      return GestureDetector(
        onTap: _hacerFoto,
        child: Container(
          height: 180,
          decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8)),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('📷  Tomar foto', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.photo_library, size: 18),
                onPressed: _elegirFotoGaleria,
                label: const Text('o desde galería'),
              ),
            ],
          ),
        ),
      );
    }
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => items[i],
      ),
    );
  }

  Widget _miniaturaFoto({required File archivo, required VoidCallback onBorrar}) {
    return GestureDetector(
      onTap: () async {
        final guardado = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => PantallaAnotarFoto(archivoFoto: archivo)),
        );
        if (guardado == true) setState(() {});
      },
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            // cacheWidth 220 (110×2 para densidad hi-dpi) evita
            // decodificar 12 MP por miniatura.
            child: Image.file(
              archivo,
              width: 110,
              height: 110,
              fit: BoxFit.cover,
              cacheWidth: 220,
              cacheHeight: 220,
              key: ValueKey('${archivo.path}_${archivo.lastModifiedSync().millisecondsSinceEpoch}'),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onBorrar,
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ),
          ),
          const Positioned(
            bottom: 2,
            left: 2,
            child: Icon(Icons.edit, color: Colors.white, size: 14, shadows: [Shadow(color: Colors.black54, blurRadius: 3)]),
          ),
        ],
      ),
    );
  }

  Widget _botonAnadirFoto() {
    return SizedBox(
      width: 110,
      height: 110,
      child: Material(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            showModalBottomSheet<void>(
              context: context,
              builder: (sheetCtx) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.photo_camera),
                      title: const Text('Tomar foto'),
                      onTap: () {
                        Navigator.of(sheetCtx).pop();
                        _hacerFoto();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.photo_library),
                      title: const Text('Desde galería'),
                      onTap: () {
                        Navigator.of(sheetCtx).pop();
                        _elegirFotoGaleria();
                      },
                    ),
                  ],
                ),
              ),
            );
          },
          child: const Center(child: Icon(Icons.add_a_photo, size: 32)),
        ),
      ),
    );
  }

  Widget _filaOrientacion() {
    final tieneMedida = _strikeGrados != null && _dipGrados != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4)),
      child: Row(
        children: [
          const Icon(Icons.architecture, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: tieneMedida
                ? Text('Estrato: ${_strikeGrados!.toStringAsFixed(0)}°/${_dipGrados!.toStringAsFixed(0)}°', style: const TextStyle(fontSize: 13))
                : const Text('Orientación del estrato: sin medir', style: TextStyle(fontSize: 13, color: Colors.grey)),
          ),
          TextButton.icon(
            icon: const Icon(Icons.explore, size: 18),
            label: Text(tieneMedida ? 'Re-medir' : 'Medir'),
            onPressed: () async {
              final medida = await mostrarModalOrientacion(context);
              if (medida == null) return;
              setState(() {
                _strikeGrados = medida.strikeGrados;
                _dipGrados = medida.dipGrados;
              });
            },
          ),
          if (tieneMedida)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Borrar medida',
              onPressed: () => setState(() {
                _strikeGrados = null;
                _dipGrados = null;
              }),
            ),
        ],
      ),
    );
  }

  Widget _tiraFosilesProbables() {
    final periodoId = inferirPeriodoDesdeEdad(_contextoGeo?.edad);
    if (periodoId == null) return const SizedBox.shrink();
    final periodo = buscarPeriodo(periodoId);
    final fosiles = fosilesPorPeriodo(periodoId);
    if (fosiles.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: periodo?.color, borderRadius: BorderRadius.circular(4)),
                child: Text(
                  'Fósiles probables · ${periodo?.nombre ?? ''}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2D3A2E)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: fosiles.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final fosil = fosiles[i];
                return InkWell(
                  onTap: () => abrirDetalleFosilGuia(context, fosil.id),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 110,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                          child: FutureBuilder<ResumenWikipedia?>(
                            future: obtenerResumenWikipedia(fosil.tituloWikipedia),
                            builder: (_, snapshot) {
                              final url = snapshot.data?.thumbnailUrl;
                              if (url != null) {
                                return CachedNetworkImage(
                                  imageUrl: url,
                                  height: 65,
                                  width: 110,
                                  fit: BoxFit.cover,
                                  httpHeaders: cabecerasImagenWiki,
                                  memCacheWidth: 200,
                                  errorWidget: (_, __, ___) => Container(
                                    height: 65,
                                    color: Colors.black12,
                                    alignment: Alignment.center,
                                    child: const Text('🦴', style: TextStyle(fontSize: 28)),
                                  ),
                                );
                              }
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const SizedBox(
                                  height: 65,
                                  child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
                                );
                              }
                              return Container(
                                height: 65,
                                color: Colors.black12,
                                alignment: Alignment.center,
                                child: const Text('🦴', style: TextStyle(fontSize: 28)),
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(fosil.nombre, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 1),
                              Text(fosil.grupo, style: const TextStyle(fontSize: 10), maxLines: 2, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget? _bannerDiscrepanciaPeriodo(IdentificacionFosil identificacion) {
    final periodoIgme = inferirPeriodoDesdeEdad(_contextoGeo?.edad);
    final periodoClaude = inferirPeriodoDesdeEdad(identificacion.edadEstimada);
    if (periodoIgme == null || periodoClaude == null) return null;
    if (periodoIgme == periodoClaude) return null;
    final nIgme = buscarPeriodo(periodoIgme)?.nombre ?? periodoIgme;
    final nClaude = buscarPeriodo(periodoClaude)?.nombre ?? periodoClaude;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        border: Border.all(color: Colors.amber.shade700),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Posible incoherencia geológica',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.amber.shade900)),
                const SizedBox(height: 2),
                Text(
                    'Claude propone $nClaude pero el afloramiento IGME es $nIgme. Revisa la identificación o la posición.',
                    style: TextStyle(
                        fontSize: 12, color: Colors.amber.shade900)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _campoLectura(String etiqueta, String valor) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(6)),
            child: Text(valor),
          ),
        ],
      );
}
