import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path_lib;
import 'package:path_provider/path_provider.dart';
import '../datos/base_datos.dart';
import '../datos/datos_guia.dart';
import '../modelos/hallazgo.dart';
import '../servicios/identificador_claude.dart';
import '../servicios/servicio_inaturalist.dart';
import '../utiles/permisos_gps.dart';
import 'pantalla_anotar_foto.dart';

class PantallaNuevoHallazgo extends StatefulWidget {
  final double? latitudPredefinida;
  final double? longitudPredefinida;
  final Hallazgo? hallazgoExistente;
  const PantallaNuevoHallazgo({
    super.key,
    this.latitudPredefinida,
    this.longitudPredefinida,
    this.hallazgoExistente,
  });

  bool get esEdicion => hallazgoExistente != null;

  @override
  State<PantallaNuevoHallazgo> createState() => _PantallaNuevoHallazgoState();
}

class _PantallaNuevoHallazgoState extends State<PantallaNuevoHallazgo> {
  final _controladorNombreComun = TextEditingController();
  final _controladorEspecie = TextEditingController();
  final _controladorTaxonomia = TextEditingController();
  final _controladorHabitat = TextEditingController();
  final _controladorNotas = TextEditingController();

  String _categoria = 'animal';
  final List<String> _rutasFotos = [];
  final Map<String, dynamic> _atributos = {};
  final Map<String, TextEditingController> _controladoresAtributos = {};
  double? _latitud;
  double? _longitud;
  double? _precision;
  bool _capturandoGps = false;
  bool _identificando = false;
  IdentificacionEspecie? _ultimaIdentificacion;

  @override
  void initState() {
    super.initState();
    final hallazgo = widget.hallazgoExistente;
    if (hallazgo != null) {
      _categoria = hallazgo.categoria;
      _controladorNombreComun.text = hallazgo.nombreComun;
      _controladorEspecie.text = hallazgo.especie;
      _controladorTaxonomia.text = hallazgo.taxonomia;
      _controladorHabitat.text = hallazgo.habitat;
      _controladorNotas.text = hallazgo.notas;
      _rutasFotos.addAll(hallazgo.rutasFotos);
      _atributos.addAll(hallazgo.atributos);
      _latitud = hallazgo.latitud;
      _longitud = hallazgo.longitud;
      _precision = hallazgo.precision;
    } else {
      _latitud = widget.latitudPredefinida;
      _longitud = widget.longitudPredefinida;
      if (_latitud == null || _longitud == null) {
        _capturarGps();
      }
    }
  }

  @override
  void dispose() {
    _controladorNombreComun.dispose();
    _controladorEspecie.dispose();
    _controladorTaxonomia.dispose();
    _controladorHabitat.dispose();
    _controladorNotas.dispose();
    for (final controlador in _controladoresAtributos.values) {
      controlador.dispose();
    }
    super.dispose();
  }

  TextEditingController _controladorAtributo(String clave) {
    return _controladoresAtributos.putIfAbsent(clave, () {
      final valor = _atributos[clave];
      return TextEditingController(text: valor == null ? '' : valor.toString());
    });
  }

  Future<void> _capturarGps() async {
    setState(() => _capturandoGps = true);
    try {
      final permitido = await asegurarPermisoUbicacion();
      if (!permitido) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Falta permiso de ubicación.')),
          );
        }
        return;
      }
      final posicion = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() {
        _latitud = posicion.latitude;
        _longitud = posicion.longitude;
        _precision = posicion.accuracy;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error GPS: $e')));
    } finally {
      if (mounted) setState(() => _capturandoGps = false);
    }
  }

  Future<void> _anadirFoto({required ImageSource fuente}) async {
    final picker = ImagePicker();
    final imagen = await picker.pickImage(source: fuente, imageQuality: 85, maxWidth: 2048);
    if (imagen == null) return;
    final dirDocs = await getApplicationDocumentsDirectory();
    final dirFotos = Directory(path_lib.join(dirDocs.path, 'fotos'));
    if (!await dirFotos.exists()) await dirFotos.create(recursive: true);
    final nombre = 'foto_${DateTime.now().millisecondsSinceEpoch}${path_lib.extension(imagen.path)}';
    final destino = File(path_lib.join(dirFotos.path, nombre));
    await File(imagen.path).copy(destino.path);
    if (!mounted) return;
    setState(() => _rutasFotos.add(destino.path));
  }

  Future<void> _anotarFoto(int indice) async {
    final ruta = _rutasFotos[indice];
    final actualizado = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => PantallaAnotarFoto(archivoFoto: File(ruta))),
    );
    if (actualizado != null && mounted) {
      setState(() => _rutasFotos[indice] = actualizado);
    }
  }

  Future<void> _identificarConIa() async {
    if (_rutasFotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Añade una foto primero.')),
      );
      return;
    }
    setState(() => _identificando = true);
    try {
      final identificacion = await identificarEspecie(
        archivoFoto: File(_rutasFotos.first),
        contexto: ContextoIdentificacion(
          latitud: _latitud,
          longitud: _longitud,
          habitat: _controladorHabitat.text.trim().isEmpty ? null : _controladorHabitat.text.trim(),
          notas: _controladorNotas.text.trim().isEmpty ? null : _controladorNotas.text.trim(),
          especieTentativa: _controladorEspecie.text.trim().isEmpty ? null : _controladorEspecie.text.trim(),
          categoriaEsperada: _categoria,
        ),
      );
      if (!mounted) return;
      setState(() {
        _ultimaIdentificacion = identificacion;
        if (identificacion.categoriaDetectada != 'desconocido') {
          _categoria = identificacion.categoriaDetectada;
        }
        if (_controladorEspecie.text.trim().isEmpty) {
          _controladorEspecie.text = identificacion.nombreCientifico;
        }
        if (_controladorNombreComun.text.trim().isEmpty) {
          _controladorNombreComun.text = identificacion.nombreComun;
        }
        if (_controladorTaxonomia.text.trim().isEmpty) {
          _controladorTaxonomia.text = identificacion.taxonomia;
        }
        if (_controladorHabitat.text.trim().isEmpty && identificacion.habitatTipico != null) {
          _controladorHabitat.text = identificacion.habitatTipico!;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Identificación falló: $e')));
    } finally {
      if (mounted) setState(() => _identificando = false);
    }
  }

  Future<void> _guardar() async {
    if (_latitud == null || _longitud == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falta la posición GPS.')),
      );
      return;
    }
    final atributosFiltrados = _atributosRelevantesParaCategoria();
    final hallazgoExistente = widget.hallazgoExistente;
    if (hallazgoExistente != null) {
      await BaseDatosNaturaleza.instancia.actualizarHallazgo(hallazgoExistente.id!, {
        'categoria': _categoria,
        'especie': _controladorEspecie.text.trim(),
        'nombre_comun': _controladorNombreComun.text.trim(),
        'taxonomia': _controladorTaxonomia.text.trim(),
        'habitat': _controladorHabitat.text.trim(),
        'notas': _controladorNotas.text.trim(),
        'rutas_fotos_json': _rutasFotos.isEmpty ? null : _serializarRutas(_rutasFotos),
        'atributos_json': atributosFiltrados.isEmpty ? null : jsonEncode(atributosFiltrados),
      });
    } else {
      final hallazgo = Hallazgo(
        fechaMs: DateTime.now().millisecondsSinceEpoch,
        latitud: _latitud!,
        longitud: _longitud!,
        precision: _precision,
        categoria: _categoria,
        especie: _controladorEspecie.text.trim(),
        nombreComun: _controladorNombreComun.text.trim(),
        taxonomia: _controladorTaxonomia.text.trim(),
        habitat: _controladorHabitat.text.trim(),
        notas: _controladorNotas.text.trim(),
        rutasFotos: List.unmodifiable(_rutasFotos),
        atributos: Map.unmodifiable(atributosFiltrados),
      );
      await BaseDatosNaturaleza.instancia.guardarHallazgo(hallazgo);
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  String _serializarRutas(List<String> rutas) => '["${rutas.map((r) => r.replaceAll('"', '\\"')).join('","')}"]';

  Map<String, dynamic> _atributosRelevantesParaCategoria() {
    final clavesPermitidas = _clavesAtributosCategoria(_categoria);
    final filtrado = <String, dynamic>{};
    for (final entrada in _atributos.entries) {
      if (!clavesPermitidas.contains(entrada.key)) continue;
      final valor = entrada.value;
      if (valor == null) continue;
      if (valor is String && valor.trim().isEmpty) continue;
      filtrado[entrada.key] = valor;
    }
    return filtrado;
  }

  static const Map<String, List<String>> _atributosPorCategoria = {
    'planta': ['fenologia', 'porte', 'altura_estimada_cm'],
    'insecto': ['estadio', 'planta_hospedadora', 'numero_individuos'],
    'animal': ['evidencia', 'numero_individuos', 'comportamiento'],
  };

  static List<String> _clavesAtributosCategoria(String categoria) =>
      _atributosPorCategoria[categoria] ?? const [];

  Future<void> _abrirBuscadorInaturalist() async {
    final consultaInicial = _controladorNombreComun.text.trim().isNotEmpty
        ? _controladorNombreComun.text.trim()
        : _controladorEspecie.text.trim();
    final seleccion = await showModalBottomSheet<ResultadoTaxonInaturalist>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BuscadorInaturalist(consultaInicial: consultaInicial),
    );
    if (seleccion == null || !mounted) return;
    setState(() {
      _controladorEspecie.text = seleccion.nombreCientifico;
      if (seleccion.nombreComun != null && seleccion.nombreComun!.isNotEmpty) {
        _controladorNombreComun.text = seleccion.nombreComun!;
      }
      if (seleccion.ancestros.isNotEmpty) {
        _controladorTaxonomia.text = '${seleccion.ancestros.join(' › ')} › ${seleccion.nombreCientifico}';
      }
      final categoriaInferida = seleccion.categoriaInferida;
      if (categoriaInferida != null) _categoria = categoriaInferida;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.esEdicion ? 'Editar hallazgo' : 'Nuevo hallazgo'),
        actions: [
          IconButton(icon: const Icon(Icons.check), tooltip: 'Guardar', onPressed: _guardar),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _seccionCategoria(),
          const SizedBox(height: 16),
          _seccionFotos(),
          const SizedBox(height: 16),
          _seccionUbicacion(),
          const SizedBox(height: 16),
          _seccionDatos(),
          const SizedBox(height: 16),
          _seccionAtributosCategoria(),
          const SizedBox(height: 16),
          _seccionIdentificacion(),
        ],
      ),
    );
  }

  Widget _seccionCategoria() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Categoría', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                for (final categoria in categoriasGuia)
                  ButtonSegment(
                    value: categoria.id,
                    label: Text(categoria.nombre),
                    icon: Icon(categoria.icono),
                  ),
              ],
              selected: {_categoria},
              onSelectionChanged: (seleccion) => setState(() => _categoria = seleccion.first),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seccionFotos() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Fotos', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_rutasFotos.isNotEmpty)
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _rutasFotos.length,
                  itemBuilder: (_, indice) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        GestureDetector(
                          onTap: () => _anotarFoto(indice),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.file(File(_rutasFotos[indice]), width: 100, height: 100, fit: BoxFit.cover),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            style: IconButton.styleFrom(backgroundColor: Colors.black54, padding: const EdgeInsets.all(2)),
                            iconSize: 16,
                            onPressed: () => setState(() => _rutasFotos.removeAt(indice)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    onPressed: () => _anadirFoto(fuente: ImageSource.camera),
                    label: const Text('Cámara'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.photo_library),
                    onPressed: () => _anadirFoto(fuente: ImageSource.gallery),
                    label: const Text('Galería'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _seccionUbicacion() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ubicación', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_latitud != null && _longitud != null)
              Text(
                '${_latitud!.toStringAsFixed(5)}, ${_longitud!.toStringAsFixed(5)}'
                '${_precision != null ? "  (±${_precision!.round()} m)" : ""}',
              )
            else
              const Text('Sin ubicación', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              icon: _capturandoGps
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.gps_fixed),
              onPressed: _capturandoGps ? null : _capturarGps,
              label: const Text('Capturar GPS'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seccionDatos() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Datos', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.travel_explore, size: 18),
                  onPressed: _abrirBuscadorInaturalist,
                  label: const Text('Buscar en iNaturalist'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controladorNombreComun,
              decoration: const InputDecoration(labelText: 'Nombre común', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controladorEspecie,
              decoration: const InputDecoration(labelText: 'Nombre científico (binomial)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controladorTaxonomia,
              decoration: const InputDecoration(labelText: 'Taxonomía', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controladorHabitat,
              decoration: const InputDecoration(labelText: 'Hábitat', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controladorNotas,
              decoration: const InputDecoration(labelText: 'Notas', border: OutlineInputBorder()),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _seccionAtributosCategoria() {
    final categoria = categoriaPorId(_categoria);
    final etiquetaCategoria = categoria?.nombre ?? _categoria;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Detalles de $etiquetaCategoria', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._camposAtributosParaCategoria(_categoria),
          ],
        ),
      ),
    );
  }

  List<Widget> _camposAtributosParaCategoria(String categoria) {
    switch (categoria) {
      case 'planta':
        return [
          _menuDesplegable(
            etiqueta: 'Fenología',
            clave: 'fenologia',
            opciones: const ['vegetativa', 'flor', 'fruto', 'semilla', 'senescente'],
          ),
          const SizedBox(height: 8),
          _menuDesplegable(
            etiqueta: 'Porte',
            clave: 'porte',
            opciones: const ['árbol', 'arbusto', 'mata', 'herbácea', 'trepadora', 'suculenta'],
          ),
          const SizedBox(height: 8),
          _campoNumero(etiqueta: 'Altura aprox. (cm)', clave: 'altura_estimada_cm'),
        ];
      case 'insecto':
        return [
          _menuDesplegable(
            etiqueta: 'Estadio',
            clave: 'estadio',
            opciones: const ['huevo', 'larva', 'ninfa', 'pupa', 'adulto'],
          ),
          const SizedBox(height: 8),
          _campoTexto(etiqueta: 'Planta hospedadora', clave: 'planta_hospedadora'),
          const SizedBox(height: 8),
          _campoNumero(etiqueta: 'Número de individuos', clave: 'numero_individuos'),
        ];
      case 'animal':
        return [
          _menuDesplegable(
            etiqueta: 'Tipo de evidencia',
            clave: 'evidencia',
            opciones: const ['avistamiento', 'huella', 'excremento', 'pluma o pelo', 'vocalización', 'nido o madriguera', 'otro'],
          ),
          const SizedBox(height: 8),
          _campoNumero(etiqueta: 'Número de individuos', clave: 'numero_individuos'),
          const SizedBox(height: 8),
          _campoTexto(etiqueta: 'Comportamiento', clave: 'comportamiento'),
        ];
    }
    return const [];
  }

  Widget _menuDesplegable({
    required String etiqueta,
    required String clave,
    required List<String> opciones,
  }) {
    final valorActual = _atributos[clave] as String?;
    return DropdownButtonFormField<String>(
      value: opciones.contains(valorActual) ? valorActual : null,
      decoration: InputDecoration(labelText: etiqueta, border: const OutlineInputBorder()),
      items: [
        const DropdownMenuItem(value: null, child: Text('—')),
        for (final opcion in opciones)
          DropdownMenuItem(value: opcion, child: Text(opcion)),
      ],
      onChanged: (nuevo) => setState(() {
        if (nuevo == null) {
          _atributos.remove(clave);
        } else {
          _atributos[clave] = nuevo;
        }
      }),
    );
  }

  Widget _campoTexto({required String etiqueta, required String clave}) {
    return TextField(
      controller: _controladorAtributo(clave),
      decoration: InputDecoration(labelText: etiqueta, border: const OutlineInputBorder()),
      onChanged: (texto) {
        if (texto.trim().isEmpty) {
          _atributos.remove(clave);
        } else {
          _atributos[clave] = texto.trim();
        }
      },
    );
  }

  Widget _campoNumero({required String etiqueta, required String clave}) {
    return TextField(
      controller: _controladorAtributo(clave),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: etiqueta, border: const OutlineInputBorder()),
      onChanged: (texto) {
        final numero = int.tryParse(texto.trim());
        if (numero == null) {
          _atributos.remove(clave);
        } else {
          _atributos[clave] = numero;
        }
      },
    );
  }

  Widget _seccionIdentificacion() {
    final identificacion = _ultimaIdentificacion;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Identificación con IA', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            FilledButton.icon(
              icon: _identificando
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome),
              onPressed: _identificando ? null : _identificarConIa,
              label: const Text('Identificar con Claude'),
            ),
            if (identificacion != null) ...[
              const SizedBox(height: 12),
              Text(
                '${identificacion.nombreComun.isNotEmpty ? identificacion.nombreComun : identificacion.nombreCientifico} '
                '(confianza: ${identificacion.confianza})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (identificacion.nombreCientifico.isNotEmpty) ...[
                const SizedBox(height: 8),
                _FotoReferenciaInat(nombreCientifico: identificacion.nombreCientifico),
              ],
              if (identificacion.taxonomia.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(identificacion.taxonomia, style: const TextStyle(fontSize: 12)),
                ),
              if (identificacion.descripcion.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(identificacion.descripcion, style: const TextStyle(fontSize: 13)),
                ),
              if (identificacion.alternativas.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Alternativas:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                _AlternativasConFoto(alternativas: identificacion.alternativas),
              ],
              if (identificacion.comoConfirmar.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Cómo confirmar: ${identificacion.comoConfirmar}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BuscadorInaturalist extends StatefulWidget {
  final String consultaInicial;
  const _BuscadorInaturalist({required this.consultaInicial});

  @override
  State<_BuscadorInaturalist> createState() => _BuscadorInaturalistState();
}

class _BuscadorInaturalistState extends State<_BuscadorInaturalist> {
  final _controladorBusqueda = TextEditingController();
  List<ResultadoTaxonInaturalist> _resultados = [];
  bool _cargando = false;
  String? _error;
  Object? _ultimaPeticion;

  @override
  void initState() {
    super.initState();
    _controladorBusqueda.text = widget.consultaInicial;
    if (widget.consultaInicial.isNotEmpty) _ejecutarBusqueda();
  }

  @override
  void dispose() {
    _controladorBusqueda.dispose();
    super.dispose();
  }

  Future<void> _ejecutarBusqueda() async {
    final consulta = _controladorBusqueda.text.trim();
    if (consulta.isEmpty) {
      setState(() {
        _resultados = const [];
        _error = null;
      });
      return;
    }
    final marca = Object();
    _ultimaPeticion = marca;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final resultados = await buscarTaxones(consulta, limite: 12);
      if (!mounted || _ultimaPeticion != marca) return;
      setState(() {
        _resultados = resultados;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted || _ultimaPeticion != marca) return;
      setState(() {
        _cargando = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, controladorScroll) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controladorBusqueda,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _ejecutarBusqueda(),
                      decoration: InputDecoration(
                        hintText: 'Nombre común o científico…',
                        prefixIcon: const Icon(Icons.search),
                        border: const OutlineInputBorder(),
                        suffixIcon: _controladorBusqueda.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _controladorBusqueda.clear();
                                  setState(() => _resultados = const []);
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _ejecutarBusqueda, child: const Text('Buscar')),
                ],
              ),
            ),
            if (_cargando) const LinearProgressIndicator(minHeight: 2),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            Expanded(
              child: _resultados.isEmpty && !_cargando
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Escribe al menos dos letras y pulsa Buscar.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: controladorScroll,
                      itemCount: _resultados.length,
                      itemBuilder: (_, indice) {
                        final taxon = _resultados[indice];
                        final nombrePrincipal = taxon.nombreComun != null && taxon.nombreComun!.isNotEmpty
                            ? taxon.nombreComun!
                            : taxon.nombreCientifico;
                        return ListTile(
                          leading: taxon.urlFoto != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.network(
                                    taxon.urlFoto!,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const SizedBox(
                                      width: 48,
                                      height: 48,
                                      child: Icon(Icons.image_not_supported),
                                    ),
                                  ),
                                )
                              : const SizedBox(width: 48, height: 48, child: Icon(Icons.eco_outlined)),
                          title: Text(nombrePrincipal),
                          subtitle: Text(
                            '${taxon.nombreCientifico}'
                            '${taxon.rangoTaxonomico != null ? "  ·  ${taxon.rangoTaxonomico}" : ""}',
                            style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                          ),
                          onTap: () => Navigator.of(context).pop(taxon),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FotoReferenciaInat extends StatelessWidget {
  final String nombreCientifico;
  const _FotoReferenciaInat({required this.nombreCientifico});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: miniaturaPorNombreCientifico(nombreCientifico),
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (url == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  url,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Foto de referencia (iNaturalist)',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AlternativasConFoto extends StatelessWidget {
  final List<String> alternativas;
  const _AlternativasConFoto({required this.alternativas});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: alternativas.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, indice) {
          final nombre = alternativas[indice];
          return SizedBox(
            width: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FutureBuilder<String?>(
                  future: miniaturaPorNombreCientifico(nombre),
                  builder: (_, snapshot) {
                    final url = snapshot.data;
                    if (url == null) {
                      return Container(
                        width: 100,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.image_not_supported, color: Colors.grey),
                      );
                    }
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(url, width: 100, height: 80, fit: BoxFit.cover),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  nombre,
                  style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
