import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path_lib;
import 'package:path_provider/path_provider.dart';
import '../datos/base_datos.dart';
import '../datos/configuracion.dart';
import '../datos/datos_guia.dart';
import '../modelos/atribucion_foto.dart';
import '../modelos/hallazgo.dart';
import '../modelos/salida.dart';
import '../servicios/estado_salida_en_curso.dart';
import '../servicios/identificador_claude.dart';
import '../servicios/servicio_inaturalist.dart';
import '../servicios/servicio_plantnet.dart';
import '../utiles/permisos_gps.dart';
import 'pantalla_anotar_foto.dart';
import 'pantalla_buscar_foto_archivo.dart';

class PantallaNuevoHallazgo extends StatefulWidget {
  final double? latitudPredefinida;
  final double? longitudPredefinida;
  final Hallazgo? hallazgoExistente;
  PantallaNuevoHallazgo({
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
  final _controladorHipotesis = TextEditingController();

  String _categoria = 'animal';
  TipoEvidencia _tipoEvidencia = TipoEvidencia.avistamiento;

  /// Confianza del propio aficionado en su identificación. null = no
  /// marcada (lo más habitual al anotar rápido). Cuando se rellena
  /// toma uno de los valores de [ConfianzaIdentificacion].
  String? _confianza;
  final List<String> _rutasFotos = [];

  /// Atribución por foto, paralela a [_rutasFotos] (mismo índice).
  /// `null` en una posición = foto del usuario (cámara/galería).
  /// No-null = foto de archivo descargada de un repositorio externo
  /// con licencia abierta — necesita atribución al exportar.
  final List<AtribucionFoto?> _atribucionesFotos = [];

  final Map<String, dynamic> _atributos = {};
  final Map<String, TextEditingController> _controladoresAtributos = {};
  double? _latitud;
  double? _longitud;
  double? _precision;
  bool _capturandoGps = false;
  bool _identificando = false;
  IdentificacionEspecie? _ultimaIdentificacion;
  bool _identificandoPlantNet = false;
  String? _claveApiKeyPlantNetCacheada;

  /// Salida en curso a la que se autoasociará el hallazgo nuevo. Se
  /// captura al entrar a la pantalla; si el usuario destilda el
  /// checkbox la dejamos a null y el hallazgo queda suelto.
  Salida? _salidaAsociarAuto;
  bool _asociarASalida = true;

  @override
  void initState() {
    super.initState();
    // Sólo en hallazgos nuevos miramos la salida en curso. En edición
    // se respeta el salida_id existente (no se cambia desde aquí).
    if (widget.hallazgoExistente == null) {
      _salidaAsociarAuto = EstadoSalidaEnCurso.instancia.salida;
    }
    final hallazgo = widget.hallazgoExistente;
    if (hallazgo != null) {
      _categoria = hallazgo.categoria;
      _controladorNombreComun.text = hallazgo.nombreComun;
      _controladorEspecie.text = hallazgo.especie;
      _controladorTaxonomia.text = hallazgo.taxonomia;
      _controladorHabitat.text = hallazgo.habitat;
      _controladorNotas.text = hallazgo.notas;
      _controladorHipotesis.text = hallazgo.hipotesis;
      _tipoEvidencia = hallazgo.tipoEvidencia;
      _confianza = hallazgo.confianzaIdentificacion;
      _rutasFotos.addAll(hallazgo.rutasFotos);
      // Mantenemos la lista paralela alineada en longitud — si el
      // hallazgo viejo no tenía atribuciones, rellenamos con nulls.
      _atribucionesFotos.addAll(hallazgo.atribucionesFotos);
      while (_atribucionesFotos.length < _rutasFotos.length) {
        _atribucionesFotos.add(null);
      }
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
    _cargarClavePlantNet();
  }

  Future<void> _cargarClavePlantNet() async {
    final clave = await Configuracion.obtenerApiKeyPlantNet();
    if (!mounted) return;
    setState(() => _claveApiKeyPlantNetCacheada = clave.trim().isEmpty ? null : clave);
  }

  @override
  void dispose() {
    _controladorNombreComun.dispose();
    _controladorEspecie.dispose();
    _controladorTaxonomia.dispose();
    _controladorHabitat.dispose();
    _controladorNotas.dispose();
    _controladorHipotesis.dispose();
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
            SnackBar(content: Text('Falta permiso de ubicación.')),
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
    setState(() {
      _rutasFotos.add(destino.path);
      _atribucionesFotos.add(null); // foto del usuario
    });
  }

  /// Abre el modal de búsqueda en repositorios externos
  /// (Wikipedia + iNaturalist). Si el usuario selecciona una, la
  /// foto se descarga al disco local y se añade al registro junto
  /// con su atribución. Encarna el caso "no siempre se puede sacar
  /// foto": animal lejos, peligroso, esquivo, o que no debería
  /// molestarse — el usuario reconoce la especie y deja una imagen
  /// de archivo como ilustración del avistamiento.
  Future<void> _anadirFotoDeArchivo() async {
    final consulta = _controladorEspecie.text.trim().isNotEmpty
        ? _controladorEspecie.text.trim()
        : _controladorNombreComun.text.trim();
    if (consulta.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Escribe primero la especie o el nombre común para buscar.',
          ),
        ),
      );
      return;
    }
    final seleccion = await Navigator.of(context).push<FotoArchivoSeleccionada>(
      MaterialPageRoute(
        builder: (_) => PantallaBuscarFotoArchivo(consulta: consulta),
      ),
    );
    if (seleccion == null || !mounted) return;
    setState(() {
      _rutasFotos.add(seleccion.rutaAbsoluta);
      _atribucionesFotos.add(seleccion.atribucion);
    });
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
        SnackBar(content: Text('Añade una foto primero.')),
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

  Future<void> _identificarConPlantNet() async {
    final clave = _claveApiKeyPlantNetCacheada;
    if (clave == null || clave.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Configura tu clave de Pl@ntNet en Ajustes.')),
      );
      return;
    }
    if (_rutasFotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Añade una foto primero.')),
      );
      return;
    }
    final organo = await _elegirOrganoPlantNet();
    if (organo == null) return;
    setState(() => _identificandoPlantNet = true);
    try {
      final resultado = await identificarPlantaConPlantNet(
        rutaFotoLocal: _rutasFotos.first,
        apiKey: clave,
        organo: organo,
      );
      if (!mounted) return;
      if (resultado.candidatos.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pl@ntNet no encontró candidatos. Prueba con otra foto u otro órgano.')),
        );
        return;
      }
      final elegido = await _mostrarCandidatosPlantNet(resultado);
      if (!mounted || elegido == null) return;
      setState(() {
        _categoria = 'planta';
        _controladorEspecie.text = elegido.nombreCientifico;
        if (_controladorNombreComun.text.trim().isEmpty &&
            elegido.nombreComunPreferido != null) {
          _controladorNombreComun.text = elegido.nombreComunPreferido!;
        }
        if (_controladorTaxonomia.text.trim().isEmpty &&
            (elegido.familia != null || elegido.genero != null)) {
          final partes = <String>[
            if (elegido.familia != null) elegido.familia!,
            if (elegido.genero != null) elegido.genero!,
          ];
          _controladorTaxonomia.text = partes.join(' / ');
        }
      });
      if (resultado.quedanHoy != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pl@ntNet: te quedan ${resultado.quedanHoy} identificaciones hoy.')),
        );
      }
    } on PlantNetClaveInvalida catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
    } on PlantNetCuotaAgotada catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pl@ntNet falló: $e')));
    } finally {
      if (mounted) setState(() => _identificandoPlantNet = false);
    }
  }

  Future<OrganoPlantNet?> _elegirOrganoPlantNet() async {
    return showModalBottomSheet<OrganoPlantNet>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '¿Qué órgano se ve mejor en la foto?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            for (final entrada in const [
              (OrganoPlantNet.hoja, 'Hoja'),
              (OrganoPlantNet.flor, 'Flor'),
              (OrganoPlantNet.fruto, 'Fruto'),
              (OrganoPlantNet.corteza, 'Corteza'),
              (OrganoPlantNet.habito, 'Hábito (planta entera)'),
              (OrganoPlantNet.otro, 'Otro / no estoy seguro'),
            ])
              ListTile(
                leading: Icon(Icons.local_florist),
                title: Text(entrada.$2),
                onTap: () => Navigator.of(sheetContext).pop(entrada.$1),
              ),
          ],
        ),
      ),
    );
  }

  Future<CandidatoPlantNet?> _mostrarCandidatosPlantNet(ResultadoPlantNet resultado) async {
    return showModalBottomSheet<CandidatoPlantNet>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, controlador) => ListView(
          controller: controlador,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Candidatos de Pl@ntNet',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 4),
            Text(
              'Pulsa el que mejor se ajuste para rellenar la ficha.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            SizedBox(height: 12),
            for (final candidato in resultado.candidatos)
              Card(
                child: ListTile(
                  title: Text(
                    candidato.nombreComunPreferido ?? candidato.nombreCientifico,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(candidato.nombreCientifico, style: TextStyle(fontStyle: FontStyle.italic)),
                      if (candidato.familia != null || candidato.genero != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            [if (candidato.familia != null) candidato.familia!, if (candidato.genero != null) candidato.genero!].join(' / '),
                            style: TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ),
                    ],
                  ),
                  trailing: Text(
                    '${(candidato.score * 100).toStringAsFixed(0)}%',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () => Navigator.of(sheetContext).pop(candidato),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _guardar() async {
    if (_latitud == null || _longitud == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falta la posición GPS.')),
      );
      return;
    }
    final atributosFiltrados = _atributosRelevantesParaCategoria();
    // Lista paralela alineada — defensivo en caso de que durante la
    // sesión se haya añadido una foto sin propagar atribución.
    final atribucionesAlineadas =
        List<AtribucionFoto?>.generate(_rutasFotos.length, (i) {
      return i < _atribucionesFotos.length ? _atribucionesFotos[i] : null;
    });
    final hallazgoExistente = widget.hallazgoExistente;
    try {
      if (hallazgoExistente != null) {
        // Para mantener una sola fuente de verdad sobre cómo se
        // serializa `atributos_json` (que ahora también lleva
        // `atribuciones_fotos`), construimos un Hallazgo temporal y
        // reusamos su `toMap()` para coger las dos columnas relevantes.
        final hallazgoActualizado = hallazgoExistente.copyWith(
          categoria: _categoria,
          especie: _controladorEspecie.text.trim(),
          nombreComun: _controladorNombreComun.text.trim(),
          taxonomia: _controladorTaxonomia.text.trim(),
          habitat: _controladorHabitat.text.trim(),
          notas: _controladorNotas.text.trim(),
          rutasFotos: List.unmodifiable(_rutasFotos),
          atribucionesFotos: List.unmodifiable(atribucionesAlineadas),
          atributos: Map<String, dynamic>.unmodifiable(atributosFiltrados),
          tipoEvidencia: _tipoEvidencia,
          hipotesis: _controladorHipotesis.text.trim(),
          confianzaIdentificacion: _confianza,
          limpiarConfianza: _confianza == null,
        );
        final idHallazgo = hallazgoExistente.id;
        if (idHallazgo == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: el hallazgo no tiene ID.')),
          );
          return;
        }
        final mapa = hallazgoActualizado.toMap();
        await BaseDatosNaturaleza.instancia.actualizarHallazgo(
          idHallazgo,
          {
            'categoria': mapa['categoria'],
            'especie': mapa['especie'],
            'nombre_comun': mapa['nombre_comun'],
            'taxonomia': mapa['taxonomia'],
            'habitat': mapa['habitat'],
            'notas': mapa['notas'],
            'rutas_fotos_json': mapa['rutas_fotos_json'],
            'atributos_json': mapa['atributos_json'],
            'tipo_evidencia': mapa['tipo_evidencia'],
            'hipotesis': mapa['hipotesis'],
            'confianza_identificacion': mapa['confianza_identificacion'],
          },
        );
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
          atribucionesFotos: List.unmodifiable(atribucionesAlineadas),
          atributos: Map<String, dynamic>.unmodifiable(atributosFiltrados),
          salidaId: (_asociarASalida ? _salidaAsociarAuto?.id : null),
          tipoEvidencia: _tipoEvidencia,
          hipotesis: _controladorHipotesis.text.trim(),
          confianzaIdentificacion: _confianza,
        );
        await BaseDatosNaturaleza.instancia.guardarHallazgo(hallazgo);
      }
    } catch (e) {
      // Si SQLite (u otra capa) lanza, no perdemos el formulario:
      // mostramos el error y dejamos al usuario reintentar. Antes el
      // throw burbujeaba y desmontaba la pantalla.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar el hallazgo: $e')),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

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
    // Aves: atributos específicos del campo. Reusa
    // 'numero_individuos' (¿solitario, pareja, bandada?) y añade
    // 'comportamiento_ave' (cantando/posada/volando/comiendo) y
    // 'tipo_observacion' (vista/escuchada — la observación auditiva
    // es legítima en aves).
    'ave': ['comportamiento_ave', 'tipo_observacion', 'numero_individuos'],
    // Mamíferos, reptiles y anfibios: separados de 'animal' para
    // afinar la guía pero comparten los mismos atributos de campo
    // (evidencia indirecta, individuos, comportamiento) — son todos
    // vertebrados terrestres con dinámicas de avistamiento similares.
    'mamifero': ['evidencia', 'numero_individuos', 'comportamiento'],
    'reptil': ['evidencia', 'numero_individuos', 'comportamiento'],
    'anfibio': ['evidencia', 'numero_individuos', 'comportamiento'],
    'pez': ['evidencia', 'numero_individuos', 'comportamiento'],
    // Setas / hongos: campos que el recolector reconoce sobre el
    // terreno. Tamaño y color del sombrero son las pistas más
    // inmediatas; el sustrato (madera muerta, hojarasca, suelo bajo
    // pinos…) es lo que más reduce posibilidades junto con el árbol
    // hospedante asociado en especies micorrícicas.
    'seta': ['sustrato', 'color_sombrero', 'sombrero_diametro_cm', 'numero_individuos'],
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
          IconButton(icon: Icon(Icons.check), tooltip: 'Guardar', onPressed: _guardar),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_salidaAsociarAuto != null) ...[
            _bannerSalidaAsociacion(_salidaAsociarAuto!),
            const SizedBox(height: 16),
          ],
          _seccionCategoria(),
          SizedBox(height: 16),
          _seccionEvidencia(),
          SizedBox(height: 16),
          _seccionFotos(),
          SizedBox(height: 16),
          _seccionUbicacion(),
          SizedBox(height: 16),
          _seccionDatos(),
          SizedBox(height: 16),
          _seccionHipotesisYConfianza(),
          SizedBox(height: 16),
          _seccionAtributosCategoria(),
          SizedBox(height: 16),
          _seccionIdentificacion(),
        ],
      ),
    );
  }

  Widget _seccionEvidencia() {
    // Filtramos los tipos aplicables a la categoría actual. Si el
    // tipo seleccionado deja de aplicar (cambio de animal a planta),
    // lo reseteamos a avistamiento — invariante de UI: el chip
    // seleccionado siempre está visible.
    final tiposAplicables =
        TipoEvidencia.aplicablesParaCategoria(_categoria);
    if (!tiposAplicables.contains(_tipoEvidencia)) {
      // No llamamos a setState dentro del build: dejamos que el
      // próximo rebuild lo recoja vía addPostFrameCallback.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !tiposAplicables.contains(_tipoEvidencia)) {
          setState(() => _tipoEvidencia = TipoEvidencia.avistamiento);
        }
      });
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tipo de evidencia',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              'Si no viste el bicho, no pasa nada. Una huella, una '
              'pluma o un canto son hallazgo de pleno derecho.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tiposAplicables.map((tipo) {
                final seleccionado = _tipoEvidencia == tipo;
                return ChoiceChip(
                  avatar:
                      Icon(_iconoEvidencia(tipo), size: 16, color: Colors.white),
                  showCheckmark: false,
                  label: Text(tipo.etiqueta),
                  labelStyle: TextStyle(
                    color: seleccionado ? Colors.white : null,
                    fontWeight: seleccionado
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  selected: seleccionado,
                  selectedColor: const Color(0xFF3A7D5A),
                  backgroundColor: Colors.grey.shade100,
                  onSelected: (sel) {
                    if (sel) setState(() => _tipoEvidencia = tipo);
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seccionHipotesisYConfianza() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tu hipótesis',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              'Lo que crees que es y por qué. Útil para revisar después '
              'qué pistas usaste y cuándo aciertas.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controladorHipotesis,
              decoration: const InputDecoration(
                labelText: 'Hipótesis',
                hintText:
                    'creo que es X porque…  (vuelo, canto, hábitat…)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            const Text('Confianza',
                style:
                    TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                _chipConfianza('Sin marcar', null),
                _chipConfianza('Tentativa', ConfianzaIdentificacion.tentativa),
                _chipConfianza('Probable', ConfianzaIdentificacion.probable),
                _chipConfianza('Segura', ConfianzaIdentificacion.segura),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipConfianza(String etiqueta, String? valor) {
    final seleccionado = _confianza == valor;
    return ChoiceChip(
      label: Text(etiqueta),
      labelStyle: TextStyle(
        color: seleccionado ? Colors.white : null,
        fontWeight:
            seleccionado ? FontWeight.bold : FontWeight.normal,
      ),
      selected: seleccionado,
      selectedColor: const Color(0xFF3A7D5A),
      backgroundColor: Colors.grey.shade100,
      onSelected: (sel) {
        if (sel) setState(() => _confianza = valor);
      },
    );
  }

  IconData _iconoEvidencia(TipoEvidencia tipo) {
    switch (tipo) {
      case TipoEvidencia.avistamiento:
        return Icons.visibility;
      case TipoEvidencia.huella:
        return Icons.pets;
      case TipoEvidencia.pluma:
        return Icons.air;
      case TipoEvidencia.excremento:
        return Icons.circle_outlined;
      case TipoEvidencia.restosAlimentacion:
        return Icons.set_meal;
      case TipoEvidencia.marcaCorteza:
        return Icons.park;
      case TipoEvidencia.nidoVacio:
        return Icons.egg;
      case TipoEvidencia.refugio:
        return Icons.house_outlined;
      case TipoEvidencia.sonido:
        return Icons.graphic_eq;
      case TipoEvidencia.interaccion:
        return Icons.compare_arrows;
    }
  }

  Widget _bannerSalidaAsociacion(Salida salida) {
    final etiqueta = salida.titulo.isNotEmpty
        ? salida.titulo
        : (salida.zona.isNotEmpty ? salida.zona : 'Salida sin título');
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.hiking, color: Colors.orange.shade700, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _asociarASalida
                      ? 'Esta observación entrará en la salida'
                      : 'Se guardará como hallazgo suelto',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade900,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  etiqueta,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Switch(
            value: _asociarASalida,
            onChanged: (valor) => setState(() => _asociarASalida = valor),
          ),
        ],
      ),
    );
  }

  Widget _seccionCategoria() {
    // Wrap de ChoiceChip en lugar de SegmentedButton: 8 categorías
    // con etiquetas largas ("Insectos y artrópodos", "Otros animales")
    // se amontonaban en SegmentedButton sobre pantalla móvil. Wrap
    // hace flow natural en varias líneas y deja icono + texto
    // legibles, manteniendo selección única.
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Categoría', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final categoria in categoriasGuia)
                  ChoiceChip(
                    avatar: Icon(
                      categoria.icono,
                      size: 18,
                      color: _categoria == categoria.id ? Colors.white : categoria.color,
                    ),
                    label: Text(categoria.nombre),
                    selected: _categoria == categoria.id,
                    selectedColor: categoria.color,
                    labelStyle: TextStyle(
                      color: _categoria == categoria.id ? Colors.white : null,
                      fontWeight: _categoria == categoria.id ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (sel) {
                      if (sel) setState(() => _categoria = categoria.id);
                    },
                  ),
              ],
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
            Text('Fotos', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            if (_rutasFotos.isNotEmpty)
              SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _rutasFotos.length,
                  itemBuilder: (_, indice) {
                    final atribucion = indice < _atribucionesFotos.length
                        ? _atribucionesFotos[indice]
                        : null;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          GestureDetector(
                            onTap: () => _anotarFoto(indice),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.file(
                                File(_rutasFotos[indice]),
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          if (atribucion != null)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                color: Colors.black54,
                                child: Text(
                                  atribucion.etiquetaCorta(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: IconButton(
                              icon: Icon(Icons.close, color: Colors.white),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black54,
                                padding: const EdgeInsets.all(2),
                              ),
                              iconSize: 16,
                              onPressed: () => setState(() {
                                _rutasFotos.removeAt(indice);
                                if (indice < _atribucionesFotos.length) {
                                  _atribucionesFotos.removeAt(indice);
                                }
                              }),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(Icons.camera_alt),
                    onPressed: () => _anadirFoto(fuente: ImageSource.camera),
                    label: Text(SoleraL10n.t('camara')),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(Icons.photo_library),
                    onPressed: () => _anadirFoto(fuente: ImageSource.gallery),
                    label: Text(SoleraL10n.t('galeria')),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            // Tercer botón: foto de archivo (Wikipedia + iNaturalist).
            // Útil cuando sacar foto al animal es inviable (esquivo,
            // lejos) o desaconsejable (peligroso o estresante para el
            // animal). El registro se marca con badge para que quede
            // claro que la imagen es de archivo, no propia.
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: Icon(Icons.image_search_outlined),
                onPressed: _anadirFotoDeArchivo,
                label: Text('Foto de archivo'),
              ),
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
            Text('Ubicación', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            if (_latitud != null && _longitud != null)
              Text(
                '${_latitud!.toStringAsFixed(5)}, ${_longitud!.toStringAsFixed(5)}'
                '${_precision != null ? "  (±${_precision!.round()} m)" : ""}',
              )
            else
              Text('Sin ubicación', style: TextStyle(color: Colors.grey)),
            SizedBox(height: 8),
            FilledButton.tonalIcon(
              icon: _capturandoGps
                  ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.gps_fixed),
              onPressed: _capturandoGps ? null : _capturarGps,
              label: Text('Capturar GPS'),
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
                Expanded(
                  child: Text('Datos', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                TextButton.icon(
                  icon: Icon(Icons.travel_explore, size: 18),
                  onPressed: _abrirBuscadorInaturalist,
                  label: Text('Buscar en iNaturalist'),
                ),
              ],
            ),
            SizedBox(height: 8),
            TextField(
              controller: _controladorNombreComun,
              decoration: InputDecoration(labelText: 'Nombre común', border: OutlineInputBorder()),
            ),
            SizedBox(height: 8),
            TextField(
              controller: _controladorEspecie,
              decoration: InputDecoration(labelText: 'Nombre científico (binomial)', border: OutlineInputBorder()),
            ),
            SizedBox(height: 8),
            TextField(
              controller: _controladorTaxonomia,
              decoration: InputDecoration(labelText: 'Taxonomía', border: OutlineInputBorder()),
            ),
            SizedBox(height: 8),
            TextField(
              controller: _controladorHabitat,
              decoration: InputDecoration(labelText: 'Hábitat', border: OutlineInputBorder()),
            ),
            SizedBox(height: 8),
            TextField(
              controller: _controladorNotas,
              decoration: InputDecoration(labelText: 'Notas', border: OutlineInputBorder()),
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
            Text('Detalles de $etiquetaCategoria', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
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
          SizedBox(height: 8),
          _menuDesplegable(
            etiqueta: 'Porte',
            clave: 'porte',
            opciones: const ['árbol', 'arbusto', 'mata', 'herbácea', 'trepadora', 'suculenta'],
          ),
          SizedBox(height: 8),
          _campoNumero(etiqueta: 'Altura aprox. (cm)', clave: 'altura_estimada_cm'),
        ];
      case 'insecto':
        return [
          _menuDesplegable(
            etiqueta: 'Estadio',
            clave: 'estadio',
            opciones: const ['huevo', 'larva', 'ninfa', 'pupa', 'adulto'],
          ),
          SizedBox(height: 8),
          _campoTexto(etiqueta: 'Planta hospedadora', clave: 'planta_hospedadora'),
          SizedBox(height: 8),
          _campoNumero(etiqueta: 'Número de individuos', clave: 'numero_individuos'),
        ];
      case 'animal':
      case 'mamifero':
      case 'reptil':
      case 'anfibio':
      case 'pez':
        return [
          _menuDesplegable(
            etiqueta: 'Tipo de evidencia',
            clave: 'evidencia',
            opciones: const ['avistamiento', 'huella', 'excremento', 'pluma o pelo', 'vocalización', 'nido o madriguera', 'otro'],
          ),
          SizedBox(height: 8),
          _campoNumero(etiqueta: 'Número de individuos', clave: 'numero_individuos'),
          SizedBox(height: 8),
          _campoTexto(etiqueta: 'Comportamiento', clave: 'comportamiento'),
        ];
      case 'seta':
        return [
          _menuDesplegable(
            etiqueta: 'Sustrato',
            clave: 'sustrato',
            opciones: const [
              'suelo / hojarasca',
              'bajo conífera',
              'bajo planifolio',
              'pradera / herbazal',
              'madera muerta',
              'tocón',
              'otro',
            ],
          ),
          SizedBox(height: 8),
          _menuDesplegable(
            etiqueta: 'Color del sombrero',
            clave: 'color_sombrero',
            opciones: const [
              'blanco / crema',
              'pardo / marrón',
              'naranja / rojizo',
              'amarillo',
              'rojo escarlata',
              'verde oliva',
              'gris / negruzco',
              'violáceo',
              'otro',
            ],
          ),
          SizedBox(height: 8),
          _campoNumero(etiqueta: 'Diámetro sombrero (cm)', clave: 'sombrero_diametro_cm'),
          SizedBox(height: 8),
          _campoNumero(etiqueta: 'Número de ejemplares', clave: 'numero_individuos'),
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
      decoration: InputDecoration(labelText: etiqueta, border: OutlineInputBorder()),
      items: [
        DropdownMenuItem(value: null, child: Text('—')),
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
      decoration: InputDecoration(labelText: etiqueta, border: OutlineInputBorder()),
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
      decoration: InputDecoration(labelText: etiqueta, border: OutlineInputBorder()),
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
            Text('Identificación con IA', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            FilledButton.icon(
              icon: _identificando
                  ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.auto_awesome),
              onPressed: _identificando ? null : _identificarConIa,
              label: Text('Identificar con Claude'),
            ),
            if (_claveApiKeyPlantNetCacheada != null) ...[
              SizedBox(height: 8),
              OutlinedButton.icon(
                icon: _identificandoPlantNet
                    ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.local_florist),
                onPressed: _identificandoPlantNet ? null : _identificarConPlantNet,
                label: Text('Identificar planta con Pl@ntNet (gratis)'),
              ),
            ],
            if (identificacion != null) ...[
              SizedBox(height: 12),
              Text(
                '${identificacion.nombreComun.isNotEmpty ? identificacion.nombreComun : identificacion.nombreCientifico} '
                '(confianza: ${identificacion.confianza})',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              if (identificacion.nombreCientifico.isNotEmpty) ...[
                SizedBox(height: 8),
                _FotoReferenciaInat(nombreCientifico: identificacion.nombreCientifico),
              ],
              if (identificacion.taxonomia.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(identificacion.taxonomia, style: TextStyle(fontSize: 12)),
                ),
              if (identificacion.descripcion.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(identificacion.descripcion, style: TextStyle(fontSize: 13)),
                ),
              if (identificacion.alternativas.isNotEmpty) ...[
                SizedBox(height: 8),
                Text('Alternativas:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                _AlternativasConFoto(alternativas: identificacion.alternativas),
              ],
              if (identificacion.comoConfirmar.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Cómo confirmar: ${identificacion.comoConfirmar}',
                    style: TextStyle(fontSize: 12),
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
  _BuscadorInaturalist({required this.consultaInicial});

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
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        suffixIcon: _controladorBusqueda.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear),
                                onPressed: () {
                                  _controladorBusqueda.clear();
                                  setState(() => _resultados = const []);
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  FilledButton(onPressed: _ejecutarBusqueda, child: Text('Buscar')),
                ],
              ),
            ),
            if (_cargando) LinearProgressIndicator(minHeight: 2),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error!, style: TextStyle(color: Colors.red)),
              ),
            Expanded(
              child: _resultados.isEmpty && !_cargando
                  ? Center(
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
                                  child: CachedNetworkImage(
                                    imageUrl: taxon.urlFoto!,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 144,
                                    errorWidget: (_, __, ___) => SizedBox(
                                      width: 48,
                                      height: 48,
                                      child: Icon(Icons.image_not_supported),
                                    ),
                                  ),
                                )
                              : SizedBox(width: 48, height: 48, child: Icon(Icons.eco_outlined)),
                          title: Text(nombrePrincipal),
                          subtitle: Text(
                            '${taxon.nombreCientifico}'
                            '${taxon.rangoTaxonomico != null ? "  ·  ${taxon.rangoTaxonomico}" : ""}',
                            style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
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
  _FotoReferenciaInat({required this.nombreCientifico});

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
                child: CachedNetworkImage(
                  imageUrl: url,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  memCacheWidth: 300,
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
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
  _AlternativasConFoto({required this.alternativas});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: alternativas.length,
        separatorBuilder: (_, __) => SizedBox(width: 8),
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
                        child: Icon(Icons.image_not_supported, color: Colors.grey),
                      );
                    }
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: CachedNetworkImage(
                        imageUrl: url,
                        width: 100,
                        height: 80,
                        fit: BoxFit.cover,
                        memCacheWidth: 300,
                      ),
                    );
                  },
                ),
                SizedBox(height: 4),
                Text(
                  nombre,
                  style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic),
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
