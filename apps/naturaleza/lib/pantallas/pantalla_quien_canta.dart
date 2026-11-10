import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import 'package:path/path.dart' as path_lib;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../datos/datos_guia.dart';
import '../modelos/resultado_escucha.dart';
import '../servicios/almacen_modelo_fauna.dart';
import '../servicios/clasificador_fauna.dart';
import '../servicios/escucha_microfono.dart';
import '../sonido/clasificacion_sonido.dart';
import '../sonido/clip_audio.dart';
import '../sonido/espectrograma_mel.dart';
import '../sonido/filtro_ocurrencia.dart';
import '../sonido/manifiesto_modelo_fauna.dart';
import '../sonido/sesion_escucha.dart';
import '../utiles/permisos_gps.dart';
import 'pantalla_nuevo.dart';

/// «¿Quién canta?»: identifica aves, anfibios, insectos y mamíferos por el
/// sonido con Perch 2.0 (Google) en el propio móvil, sin conexión una vez
/// descargado el modelo. Al elegir una especie se anota como hallazgo con
/// evidencia «sonido» y el clip de audio. Portado de Laboratorio de Bolsillo.
class PantallaQuienCanta extends StatefulWidget {
  /// true: al elegir una especie se devuelve un [ResultadoEscucha] a quien
  /// abrió la pantalla (el alta de hallazgo). false: se abre el alta con ella.
  final bool devolverResultado;

  const PantallaQuienCanta({super.key, this.devolverResultado = false});

  @override
  State<PantallaQuienCanta> createState() => _PantallaQuienCantaState();
}

enum _EstadoDescarga { inactiva, consultando, descargando, error }

enum _EstadoOcurrencia { sinModelo, cargando, lista, noDisponible }

const _clavePreferenciaFiltro = 'nat.quien_canta.filtro_zona';
const _clavePreferenciaSoloZona = 'nat.quien_canta.solo_mi_zona';

/// Por debajo de este nivel se avisa de que el micrófono apenas capta nada.
const double _nivelSilencioDecibelios = -70;

/// Grabaciones de la validación del modelo (ver Laboratorio de Bolsillo,
/// scripts/fauna-model/README.md).
const int _aciertosValidacion = 6;
const int _grabacionesValidacion = 7;

class _PantallaQuienCantaState extends State<PantallaQuienCanta> with WidgetsBindingObserver {
  // Modelo
  bool _comprobandoModelo = true;
  ModeloFaunaInstalado? _modelo;
  _EstadoDescarga _estadoDescarga = _EstadoDescarga.inactiva;
  int _bytesRecibidos = 0;
  int _bytesTotales = 0;
  String? _errorDescarga;
  CancelacionDescarga? _cancelacion;
  ClasificadorFauna? _clasificador;
  bool _cargandoClasificador = false;
  String? _errorCarga;

  // Filtro por lugar y época
  bool _filtroActivo = true;
  bool _soloMiZona = true;
  DatosOcurrencia? _ocurrencia;
  _EstadoOcurrencia _estadoOcurrencia = _EstadoOcurrencia.sinModelo;
  ({double latitud, double longitud})? _ubicacionAproximada;
  bool _buscandoUbicacion = false;
  bool _sinUbicacion = false;
  PenalizacionesClases? _penalizaciones;
  ContextoOcurrencia? _contextoOcurrencia;
  String? _clavePenalizaciones;

  // Escucha
  EscuchaMicrofonoFauna? _escucha;
  bool _abriendoMicrofono = false;
  String? _errorEscucha;
  bool _detenidaPorSegundoPlano = false;
  final SesionEscucha _sesion = SesionEscucha();

  // Último trozo
  TrozoAnalizado? _ultimoTrozo;
  bool _ultimoTrozoConVoz = false;
  ResultadosMostrados _ultimosResultados = const ResultadosMostrados();
  Int16List? _clipUltimoTrozo;
  Int16List? _trozoAnteriorLimpio;
  int? _muestraFinalAnterior;
  ui.Image? _imagenEspectrograma;
  final Uint8List _paleta = paletaEspectrograma();
  bool _mostrarDudosas = false;
  bool _guardandoEleccion = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cargarPreferencias();
    _comprobarModelo();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelacion?.cancelar();
    unawaited(_escucha?.detener());
    _escucha = null;
    _clasificador?.liberar();
    _clasificador = null;
    _imagenEspectrograma?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    // El micrófono se para al pasar la app a segundo plano (o bloquear el
    // móvil). `inactive` no cuenta: salta también con un diálogo de permisos.
    if (estado == AppLifecycleState.paused ||
        estado == AppLifecycleState.hidden ||
        estado == AppLifecycleState.detached) {
      if (_escucha != null) {
        _detenerEscucha();
        if (mounted) setState(() => _detenidaPorSegundoPlano = true);
      }
    }
  }

  Future<void> _cargarPreferencias() async {
    try {
      final preferencias = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _filtroActivo = preferencias.getBool(_clavePreferenciaFiltro) ?? true;
        _soloMiZona = preferencias.getBool(_clavePreferenciaSoloZona) ?? true;
      });
    } catch (_) {}
  }

  Future<void> _guardarPreferencia(String clave, bool valor) async {
    try {
      final preferencias = await SharedPreferences.getInstance();
      await preferencias.setBool(clave, valor);
    } catch (_) {}
  }

  // ---------------------------------------------------------------- Modelo

  Future<void> _comprobarModelo() async {
    final modelo = await leerModeloFaunaInstalado();
    if (!mounted) return;
    setState(() {
      _modelo = modelo;
      _comprobandoModelo = false;
    });
    if (modelo != null) {
      _cargarClasificador(modelo);
      _prepararOcurrencia(modelo.manifiesto);
    }
  }

  Future<void> _cargarClasificador(ModeloFaunaInstalado modelo) async {
    setState(() {
      _cargandoClasificador = true;
      _errorCarga = null;
    });
    try {
      final clasificador = await ClasificadorFauna.cargar(modelo.manifiesto, modelo.rutaModelo);
      if (!mounted) {
        clasificador.liberar();
        return;
      }
      setState(() => _clasificador = clasificador);
    } catch (error) {
      if (mounted) setState(() => _errorCarga = error.toString());
    } finally {
      if (mounted) setState(() => _cargandoClasificador = false);
    }
  }

  Future<void> _prepararOcurrencia(ManifiestoFauna manifiesto) async {
    setState(() => _estadoOcurrencia = _EstadoOcurrencia.cargando);
    var datos = await leerOcurrenciaInstalada(manifiesto);
    if (datos == null) {
      try {
        datos = await descargarOcurrencia(manifiesto);
      } catch (_) {
        datos = null;
      }
    }
    if (!mounted) return;
    setState(() {
      _ocurrencia = datos;
      _estadoOcurrencia = datos == null ? _EstadoOcurrencia.noDisponible : _EstadoOcurrencia.lista;
      _clavePenalizaciones = null;
    });
  }

  Future<void> _pedirDescargaModelo() async {
    setState(() {
      _estadoDescarga = _EstadoDescarga.consultando;
      _errorDescarga = null;
    });
    ManifiestoFauna manifiesto;
    try {
      manifiesto = await descargarManifiestoFaunaRemoto();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _estadoDescarga = _EstadoDescarga.error;
        _errorDescarga = error.toString();
      });
      return;
    }
    if (!mounted) return;
    setState(() => _estadoDescarga = _EstadoDescarga.inactiva);
    final megabytes = _megabytes(manifiesto.bytesModelo);
    final confirmada = await showDialog<bool>(
      context: context,
      builder: (contextoDialogo) => AlertDialog(
        title: Text(SoleraL10n.t('nat.son_confirmar_descarga_titulo')),
        content: Text(SoleraL10n.tf('nat.son_confirmar_descarga_texto', {'megabytes': megabytes})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contextoDialogo, false),
            child: Text(SoleraL10n.t('cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(contextoDialogo, true),
            child: Text(SoleraL10n.t('nat.son_descargar')),
          ),
        ],
      ),
    );
    if (confirmada != true || !mounted) return;
    final cancelacion = CancelacionDescarga();
    var ultimoRefresco = DateTime.fromMillisecondsSinceEpoch(0);
    setState(() {
      _cancelacion = cancelacion;
      _estadoDescarga = _EstadoDescarga.descargando;
      _bytesRecibidos = 0;
      _bytesTotales = manifiesto.bytesModelo;
    });
    try {
      final modelo = await descargarModeloFauna(
        manifiesto,
        cancelacion: cancelacion,
        alProgreso: (recibidos, totales) {
          final ahora = DateTime.now();
          // Los avisos de progreso llegan muy seguidos: se refresca cada 250 ms.
          if (ahora.difference(ultimoRefresco).inMilliseconds < 250 && recibidos < totales) return;
          ultimoRefresco = ahora;
          if (mounted) {
            setState(() {
              _bytesRecibidos = recibidos;
              _bytesTotales = totales;
            });
          }
        },
      );
      if (!mounted) return;
      setState(() {
        _modelo = modelo;
        _estadoDescarga = _EstadoDescarga.inactiva;
        _cancelacion = null;
      });
      _cargarClasificador(modelo);
      _prepararOcurrencia(modelo.manifiesto);
    } on DescargaCancelada {
      if (mounted) {
        setState(() {
          _estadoDescarga = _EstadoDescarga.inactiva;
          _cancelacion = null;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _estadoDescarga = _EstadoDescarga.error;
        _errorDescarga = error.toString();
        _cancelacion = null;
      });
    }
  }

  Future<void> _borrarModelo() async {
    final modelo = _modelo;
    if (modelo == null) return;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contextoDialogo) => AlertDialog(
        title: Text(SoleraL10n.t('nat.son_borrar_modelo_titulo')),
        content: Text(SoleraL10n.tf('nat.son_borrar_modelo_texto',
            {'megabytes': _megabytes(modelo.manifiesto.bytesModelo)})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contextoDialogo, false),
            child: Text(SoleraL10n.t('cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(contextoDialogo, true),
            child: Text(SoleraL10n.t('borrar')),
          ),
        ],
      ),
    );
    if (confirmado != true) return;
    await _detenerEscucha();
    _clasificador?.liberar();
    await borrarModeloFaunaInstalado();
    if (!mounted) return;
    setState(() {
      _clasificador = null;
      _modelo = null;
      _ocurrencia = null;
      _estadoOcurrencia = _EstadoOcurrencia.sinModelo;
      _clavePenalizaciones = null;
      _penalizaciones = null;
    });
  }

  String _megabytes(int bytes) => (bytes / 1000000).toStringAsFixed(1);

  // ---------------------------------------------------------------- Filtro

  Future<void> _actualizarUbicacionAproximada() async {
    if (_buscandoUbicacion) return;
    setState(() {
      _buscandoUbicacion = true;
      _sinUbicacion = false;
    });
    try {
      final permiso = await comprobarPermisoUbicacion();
      if (permiso != ResultadoPermisoGps.concedido) {
        if (mounted) setState(() => _sinUbicacion = true);
        return;
      }
      Position? posicion;
      try {
        posicion = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 15),
        );
      } catch (_) {
        posicion = await Geolocator.getLastKnownPosition();
      }
      if (!mounted) return;
      if (posicion == null) {
        setState(() => _sinUbicacion = true);
        return;
      }
      setState(() {
        // Solo hace falta saber la zona: se redondea a ≈1 km y no se guarda.
        _ubicacionAproximada = (
          latitud: redondearCoordenada(posicion!.latitude),
          longitud: redondearCoordenada(posicion.longitude),
        );
        _clavePenalizaciones = null;
      });
    } catch (_) {
      if (mounted) setState(() => _sinUbicacion = true);
    } finally {
      if (mounted) setState(() => _buscandoUbicacion = false);
    }
  }

  /// Penalizaciones del lugar y el mes actuales (se recalculan solo si
  /// cambian), o null si el filtro no se aplica.
  PenalizacionesClases? _penalizacionesActuales() {
    final datos = _ocurrencia;
    final ubicacion = _ubicacionAproximada;
    final modelo = _modelo;
    if (!_filtroActivo || datos == null || ubicacion == null || modelo == null) {
      _contextoOcurrencia = null;
      return null;
    }
    final indiceMes = DateTime.now().month - 1;
    final clave = '${ubicacion.latitud}|${ubicacion.longitud}|$indiceMes|$_soloMiZona';
    if (clave != _clavePenalizaciones) {
      final contexto =
          contextoOcurrenciaPara(datos, ubicacion.latitud, ubicacion.longitud, indiceMes);
      _contextoOcurrencia = contexto;
      _penalizaciones = contexto.estado == EstadoContextoOcurrencia.activo
          ? calcularPenalizacionesClases(
              datos,
              contexto,
              modelo.manifiesto.clases,
              tratamiento:
                  _soloMiZona ? TratamientoFueraDeZona.excluir : TratamientoFueraDeZona.penalizar,
            )
          : null;
      _clavePenalizaciones = clave;
    }
    return _penalizaciones;
  }

  // ---------------------------------------------------------------- Escucha

  Future<bool> _asegurarPermisoMicrofono() async {
    var estado = await Permission.microphone.status;
    if (estado.isGranted) return true;
    estado = await Permission.microphone.request();
    if (estado.isGranted) return true;
    if (!mounted) return false;
    if (estado.isPermanentlyDenied) {
      final abrirAjustes = await showDialog<bool>(
        context: context,
        builder: (contextoDialogo) => AlertDialog(
          title: Text(SoleraL10n.t('nat.son_permiso_microfono_titulo')),
          content: Text(SoleraL10n.t('nat.son_permiso_microfono_ajustes')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(contextoDialogo, false),
              child: Text(SoleraL10n.t('cancelar')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(contextoDialogo, true),
              child: Text(SoleraL10n.t('nat.son_abrir_ajustes')),
            ),
          ],
        ),
      );
      if (abrirAjustes == true) await openAppSettings();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(SoleraL10n.t('nat.son_permiso_microfono_denegado'))),
      );
    }
    return false;
  }

  Future<void> _empezarEscucha() async {
    final clasificador = _clasificador;
    if (clasificador == null || _escucha != null || _abriendoMicrofono) return;
    setState(() {
      _abriendoMicrofono = true;
      _errorEscucha = null;
      _detenidaPorSegundoPlano = false;
    });
    try {
      if (!await _asegurarPermisoMicrofono()) return;
      if (_filtroActivo && _ubicacionAproximada == null) {
        unawaited(_actualizarUbicacionAproximada());
      }
      final escucha = EscuchaMicrofonoFauna(
        clasificador: clasificador,
        alAnalizarTrozo: _alAnalizarTrozo,
        alFallarAnalisis: (mensaje) {
          if (mounted) setState(() => _errorEscucha = mensaje);
        },
      );
      _trozoAnteriorLimpio = null;
      _muestraFinalAnterior = null;
      await escucha.empezar();
      if (!mounted) {
        await escucha.detener();
        return;
      }
      setState(() => _escucha = escucha);
    } catch (error) {
      if (mounted) setState(() => _errorEscucha = error.toString());
    } finally {
      if (mounted) setState(() => _abriendoMicrofono = false);
    }
  }

  Future<void> _detenerEscucha() async {
    final escucha = _escucha;
    _escucha = null;
    if (mounted) setState(() {});
    await escucha?.detener();
  }

  void _alAnalizarTrozo(TrozoAnalizado trozo) {
    final modelo = _modelo;
    if (!mounted || modelo == null) return;
    final clases = modelo.manifiesto.clases;
    final top = clasificarConPenalizaciones(
        trozo.clasificado.logits, _penalizacionesActuales(), clasesMostradasPorTrozo);
    final decision = decidirTrozo(top, clases);
    if (decision.tipo == TipoDecisionTrozo.vozHumana) {
      // Privacidad: de un trozo con voz humana no se guarda nada, ni se
      // junta con el siguiente para hacer el clip.
      _sesion.registrarTrozoConVozHumana();
      _trozoAnteriorLimpio = null;
      _muestraFinalAnterior = null;
      _imagenEspectrograma?.dispose();
      setState(() {
        _ultimoTrozo = trozo;
        _ultimoTrozoConVoz = true;
        _ultimosResultados = const ResultadosMostrados();
        _clipUltimoTrozo = null;
        _imagenEspectrograma = null;
      });
      return;
    }
    final frecuenciaModelo = modelo.manifiesto.frecuenciaMuestreoHz;
    final trozoPcm = flotanteAPcm16(trozo.clasificado.trozoModelo);
    final muestraFinalAnterior = _muestraFinalAnterior;
    final clip = componerClip(
      trozoActual: trozoPcm,
      trozoAnterior: _trozoAnteriorLimpio,
      separacionMuestras: muestraFinalAnterior == null
          ? 0
          : separacionEnFrecuenciaModelo(trozo.muestraFinalMicrofono - muestraFinalAnterior,
              trozo.frecuenciaMicrofonoHz, frecuenciaModelo),
    );
    _trozoAnteriorLimpio = trozoPcm;
    _muestraFinalAnterior = trozo.muestraFinalMicrofono;
    final resultados = seleccionarResultadosMostrados(top, clases);
    _sesion.registrarTrozo(
      especiesMostradas: resultados.especiesMostradas,
      momento: trozo.momentoFinal,
      clip: resultados.especiesMostradas.isEmpty ? null : clip,
    );
    setState(() {
      _ultimoTrozo = trozo;
      _ultimoTrozoConVoz = false;
      _ultimosResultados = resultados;
      _clipUltimoTrozo = clip;
    });
    _pintarEspectrograma(trozo.clasificado);
  }

  void _pintarEspectrograma(TrozoClasificado clasificado) {
    final tramas = clasificado.tramasEspectrograma;
    final bandas = clasificado.bandasEspectrograma;
    if (tramas <= 0 || bandas <= 0 || clasificado.espectrograma.length < tramas * bandas) return;
    final pixeles = Uint8List(tramas * bandas * 4);
    pintarEspectrogramaMel(clasificado.espectrograma, tramas, bandas, pixeles, _paleta);
    ui.decodeImageFromPixels(pixeles, tramas, bandas, ui.PixelFormat.rgba8888, (imagen) {
      if (!mounted || _ultimoTrozoConVoz) {
        imagen.dispose();
        return;
      }
      setState(() {
        _imagenEspectrograma?.dispose();
        _imagenEspectrograma = imagen;
      });
    });
  }

  // ---------------------------------------------------------------- Elegir

  Future<void> _mostrarDetalleEspecie({
    required int indiceClase,
    required double puntuacion,
    required double puntuacionModelo,
    required DateTime momento,
    required Int16List? clip,
    PlausibilidadEspecie? plausibilidad,
  }) async {
    final modelo = _modelo;
    if (modelo == null) return;
    final clase = modelo.manifiesto.clases[indiceClase];
    final especieGuia = especieGuiaPorNombreCientifico(clase.etiqueta);
    final anotar = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (contextoHoja) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nombreVisiblePara(clase, SoleraL10n.idioma),
                  style: Theme.of(contextoHoja).textTheme.titleLarge),
              Text(clase.etiqueta, style: const TextStyle(fontStyle: FontStyle.italic)),
              const SizedBox(height: 8),
              _FilaConfianza(puntuacion: puntuacion, puntuacionModelo: puntuacionModelo,
                  plausibilidad: plausibilidad),
              const SizedBox(height: 12),
              Text(
                SoleraL10n.tf('nat.son_detalle_orientativo',
                    {'aciertos': _aciertosValidacion, 'total': _grabacionesValidacion}),
                style: Theme.of(contextoHoja).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Text(
                clip == null
                    ? SoleraL10n.t('nat.son_detalle_sin_clip')
                    : SoleraL10n.tf('nat.son_detalle_con_clip', {
                        'segundos': duracionSegundos(clip.length, modelo.manifiesto.frecuenciaMuestreoHz)
                            .toStringAsFixed(1),
                      }),
                style: Theme.of(contextoHoja).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              if (especieGuia != null) ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.menu_book_outlined),
                  label: Text(SoleraL10n.t('nat.son_ver_en_guia')),
                  onPressed: () => abrirDetalleEspecieGuia(contextoHoja, especieGuia.id),
                ),
                const SizedBox(height: 8),
              ],
              FilledButton.icon(
                icon: const Icon(Icons.add_location_alt_outlined),
                label: Text(SoleraL10n.t('nat.son_anotar_hallazgo')),
                onPressed: () => Navigator.pop(contextoHoja, true),
              ),
            ],
          ),
        ),
      ),
    );
    if (anotar != true || !mounted) return;
    await _elegirEspecie(
      clase: clase,
      puntuacion: puntuacion,
      puntuacionModelo: puntuacionModelo,
      momento: momento,
      clip: clip,
    );
  }

  Future<void> _elegirEspecie({
    required ClaseSonido clase,
    required double puntuacion,
    required double puntuacionModelo,
    required DateTime momento,
    required Int16List? clip,
  }) async {
    final modelo = _modelo;
    if (modelo == null || _guardandoEleccion) return;
    setState(() => _guardandoEleccion = true);
    await _detenerEscucha();
    final frecuenciaModelo = modelo.manifiesto.frecuenciaMuestreoHz;
    String? rutaAudio;
    if (clip != null) {
      try {
        final documentos = await getApplicationDocumentsDirectory();
        final carpetaAudios = Directory(path_lib.join(documentos.path, 'audios'));
        await carpetaAudios.create(recursive: true);
        final fichero = File(path_lib.join(
            carpetaAudios.path, 'sonido_${DateTime.now().millisecondsSinceEpoch}.wav'));
        await fichero.writeAsBytes(codificarWavMono16(clip, frecuenciaModelo), flush: true);
        rutaAudio = fichero.path;
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${SoleraL10n.t('nat.son_error_guardar_clip')}: $error')),
          );
        }
      }
    }
    final especieGuia = especieGuiaPorNombreCientifico(clase.etiqueta);
    final nombreLocal = nombreVisiblePara(clase, SoleraL10n.idioma);
    final resultado = ResultadoEscucha(
      nombreCientifico: clase.etiqueta,
      nombreComun: nombreLocal == clase.etiqueta.replaceAll('_', ' ')
          ? (especieGuia?.nombreComun ?? '')
          : nombreLocal,
      categoria: especieGuia?.categoriaId ?? clase.grupo?.categoriaNaturaleza ?? 'animal',
      momento: momento,
      rutaAudio: rutaAudio,
      duracionAudioSegundos: clip == null ? 0 : duracionSegundos(clip.length, frecuenciaModelo),
      puntuacion: puntuacion,
      puntuacionModelo: puntuacionModelo,
      versionModelo: modelo.manifiesto.versionModelo,
      conFiltroDeZona: _penalizaciones != null && _filtroActivo,
    );
    if (!mounted) return;
    setState(() => _guardandoEleccion = false);
    if (widget.devolverResultado) {
      Navigator.of(context).pop(resultado);
    } else {
      await Navigator.of(context).pushReplacement(MaterialPageRoute<bool>(
        builder: (_) => PantallaNuevoHallazgo(resultadoEscucha: resultado),
      ));
    }
  }

  // ---------------------------------------------------------------- Ayuda

  void _mostrarAyuda() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (contextoHoja) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        builder: (_, controladorScroll) => ListView(
          controller: controladorScroll,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text(SoleraL10n.t('nat.son_ayuda_titulo'),
                style: Theme.of(contextoHoja).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(SoleraL10n.t('nat.son_ayuda_como_funciona')),
            const SizedBox(height: 12),
            Text(SoleraL10n.t('nat.son_ayuda_consejos_titulo'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(SoleraL10n.t('nat.son_ayuda_consejos')),
            const SizedBox(height: 12),
            Text(SoleraL10n.t('nat.son_ayuda_puntuacion_titulo'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(SoleraL10n.tf('nat.son_ayuda_puntuacion', {
              'posible': puntuacionMinimaPosible.toStringAsFixed(0),
              'probable': puntuacionMinimaProbable.toStringAsFixed(0),
              'margen': margenRelativoPuntuacion.toStringAsFixed(0),
            })),
            const SizedBox(height: 12),
            Text(SoleraL10n.t('nat.son_ayuda_filtro_titulo'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(SoleraL10n.tf('nat.son_ayuda_filtro', {
              'zona': penalizacionFueraDeZona.toStringAsFixed(0),
              'temporada': penalizacionFueraDeTemporada.toStringAsFixed(0),
            })),
            const SizedBox(height: 12),
            Text(SoleraL10n.t('nat.son_privacidad_titulo'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(SoleraL10n.t('nat.son_privacidad')),
            const SizedBox(height: 12),
            Text(SoleraL10n.t('nat.son_ayuda_fiabilidad_titulo'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(SoleraL10n.tf('nat.son_ayuda_fiabilidad',
                {'aciertos': _aciertosValidacion, 'total': _grabacionesValidacion})),
            const SizedBox(height: 12),
            Text(SoleraL10n.t('nat.son_creditos_titulo'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(SoleraL10n.t('nat.son_creditos')),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text(SoleraL10n.t('nat.son_ver_licencia_apache')),
                onPressed: () => launchUrl(
                  Uri.parse('https://www.apache.org/licenses/LICENSE-2.0'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text(SoleraL10n.t('nat.son_ver_release_modelo')),
                onPressed: () => launchUrl(
                  Uri.parse(
                      'https://github.com/JosuIru/laboratorio-de-bolsillo/releases/tag/modelo-fauna-europa-1'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- Vista

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(SoleraL10n.t('nat.son_titulo')),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: SoleraL10n.t('nat.son_ayuda_titulo'),
            onPressed: _mostrarAyuda,
          ),
        ],
      ),
      body: ListView(
        padding: rellenoInferiorSeguro(context, const EdgeInsets.all(16)),
        children: [
          _avisoOrientativo(),
          const SizedBox(height: 12),
          _tarjetaModelo(),
          if (_clasificador != null) ...[
            const SizedBox(height: 12),
            _tarjetaEscucha(),
            const SizedBox(height: 12),
            _tarjetaFiltro(),
            const SizedBox(height: 12),
            _tarjetaResultados(),
            const SizedBox(height: 12),
            _tarjetaSesion(),
          ],
        ],
      ),
    );
  }

  Widget _avisoOrientativo() {
    final colores = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colores.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: colores.onSecondaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              SoleraL10n.tf('nat.son_aviso_orientativo',
                  {'aciertos': _aciertosValidacion, 'total': _grabacionesValidacion}),
              style: TextStyle(color: colores.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaModelo() {
    final modelo = _modelo;
    final tema = Theme.of(context).textTheme;
    final List<Widget> contenido;
    if (_comprobandoModelo) {
      contenido = [const LinearProgressIndicator()];
    } else if (_estadoDescarga == _EstadoDescarga.descargando) {
      final fraccion = _bytesTotales > 0 ? _bytesRecibidos / _bytesTotales : null;
      final verificando = _bytesTotales > 0 && _bytesRecibidos >= _bytesTotales;
      contenido = [
        Text(verificando
            ? SoleraL10n.t('nat.son_comprobando_fichero')
            : SoleraL10n.tf('nat.son_descargando', {
                'porcentaje': fraccion == null ? '0' : (fraccion * 100).floor().toString(),
                'descargados': _megabytes(_bytesRecibidos),
                'total': _megabytes(_bytesTotales),
              })),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: verificando ? null : fraccion),
        const SizedBox(height: 8),
        if (!verificando)
          TextButton(
            onPressed: () => _cancelacion?.cancelar(),
            child: Text(SoleraL10n.t('nat.son_cancelar_descarga')),
          ),
      ];
    } else if (modelo == null) {
      contenido = [
        Text(SoleraL10n.tf('nat.son_modelo_falta', {'megabytes': megabytesAproximadosModelo})),
        const SizedBox(height: 8),
        if (_estadoDescarga == _EstadoDescarga.error && _errorDescarga != null) ...[
          Text(SoleraL10n.tf('nat.son_error_descarga', {'mensaje': _errorDescarga}),
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 8),
        ],
        FilledButton.icon(
          icon: _estadoDescarga == _EstadoDescarga.consultando
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.download),
          label: Text(_estadoDescarga == _EstadoDescarga.consultando
              ? SoleraL10n.t('nat.son_consultando_tamano')
              : SoleraL10n.t('nat.son_descargar_modelo')),
          onPressed: _estadoDescarga == _EstadoDescarga.consultando ? null : _pedirDescargaModelo,
        ),
        const SizedBox(height: 8),
        Text(SoleraL10n.t('nat.son_licencia_breve'), style: tema.bodySmall),
      ];
    } else {
      contenido = [
        Row(
          children: [
            Expanded(
              child: Text(SoleraL10n.tf('nat.son_modelo_instalado', {
                'version': modelo.manifiesto.versionModelo,
                'megabytes': _megabytes(modelo.manifiesto.bytesModelo),
              })),
            ),
            PopupMenuButton<String>(
              onSelected: (_) => _borrarModelo(),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'borrar', child: Text(SoleraL10n.t('nat.son_borrar_modelo'))),
              ],
            ),
          ],
        ),
        if (_cargandoClasificador) ...[
          const SizedBox(height: 8),
          Text(SoleraL10n.t('nat.son_cargando_modelo'), style: tema.bodySmall),
          const SizedBox(height: 4),
          const LinearProgressIndicator(),
        ],
        if (_errorCarga != null) ...[
          const SizedBox(height: 8),
          Text(SoleraL10n.tf('nat.son_error_carga', {'mensaje': _errorCarga}),
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
          TextButton(
            onPressed: () => _cargarClasificador(modelo),
            child: Text(SoleraL10n.t('fos.ficha_reintentar')),
          ),
        ],
        const SizedBox(height: 4),
        Text(SoleraL10n.t('nat.son_licencia_breve'), style: tema.bodySmall),
      ];
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(SoleraL10n.t('nat.son_modelo'), style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...contenido,
          ],
        ),
      ),
    );
  }

  Widget _tarjetaEscucha() {
    final escucha = _escucha;
    final tema = Theme.of(context).textTheme;
    final ultimoTrozo = _ultimoTrozo;
    final escuchando = escucha != null;
    final lineasEstado = <Widget>[];
    if (_abriendoMicrofono) {
      lineasEstado.add(Text(SoleraL10n.t('nat.son_abriendo_microfono'), style: tema.bodySmall));
    } else if (escuchando) {
      lineasEstado.add(Text(
        SoleraL10n.tf('nat.son_escuchando', {
          'frecuencia': escucha.frecuenciaMicrofonoHz,
          'salto': escucha.saltoActualSegundos.toStringAsFixed(1),
        }),
        style: tema.bodySmall,
      ));
      if (ultimoTrozo == null) {
        lineasEstado.add(Text(SoleraL10n.t('nat.son_esperando_primeros'), style: tema.bodySmall));
      }
    } else if (_detenidaPorSegundoPlano) {
      lineasEstado.add(Text(SoleraL10n.t('nat.son_detenida_segundo_plano'), style: tema.bodySmall));
    } else {
      lineasEstado.add(Text(SoleraL10n.t('nat.son_microfono_se_para'), style: tema.bodySmall));
    }
    if (escuchando && ultimoTrozo != null) {
      lineasEstado.add(Text(
        SoleraL10n.tf('nat.son_tiempos', {
          'total': ultimoTrozo.clasificado.milisegundosTotales,
          'remuestreo': ultimoTrozo.clasificado.milisegundosRemuestreo,
          'modelo': ultimoTrozo.clasificado.milisegundosModelo,
        }),
        style: tema.bodySmall,
      ));
      if (ultimoTrozo.nivelDecibelios < _nivelSilencioDecibelios) {
        lineasEstado.add(Text(
          SoleraL10n.tf('nat.son_silencio', {'nivel': ultimoTrozo.nivelDecibelios.toStringAsFixed(0)}),
          style: tema.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
        ));
      }
    }
    if (_errorEscucha != null) {
      lineasEstado.add(Text(SoleraL10n.tf('nat.son_error_analisis', {'mensaje': _errorEscucha}),
          style: tema.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error)));
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              icon: Icon(escuchando ? Icons.stop : Icons.mic),
              label: Text(SoleraL10n.t(escuchando ? 'nat.son_detener' : 'nat.son_empezar')),
              onPressed: _abriendoMicrofono || _guardandoEleccion
                  ? null
                  : (escuchando ? _detenerEscucha : _empezarEscucha),
            ),
            const SizedBox(height: 8),
            ...lineasEstado,
          ],
        ),
      ),
    );
  }

  Widget _tarjetaFiltro() {
    final tema = Theme.of(context).textTheme;
    String estado;
    if (!_filtroActivo) {
      estado = SoleraL10n.t('nat.son_filtro_apagado');
    } else if (_estadoOcurrencia == _EstadoOcurrencia.cargando) {
      estado = SoleraL10n.t('nat.son_filtro_cargando');
    } else if (_estadoOcurrencia == _EstadoOcurrencia.noDisponible) {
      estado = SoleraL10n.t('nat.son_filtro_no_disponible');
    } else if (_buscandoUbicacion) {
      estado = SoleraL10n.t('nat.son_filtro_esperando_ubicacion');
    } else if (_sinUbicacion) {
      estado = SoleraL10n.t('nat.son_filtro_sin_ubicacion');
    } else if (_ubicacionAproximada == null) {
      estado = SoleraL10n.t('nat.son_filtro_al_empezar');
    } else {
      final penalizaciones = _penalizacionesActuales();
      final contexto = _contextoOcurrencia;
      if (contexto?.estado == EstadoContextoOcurrencia.fueraDeRejilla) {
        estado = SoleraL10n.t('nat.son_filtro_fuera_rejilla');
      } else if (contexto?.estado == EstadoContextoOcurrencia.celdaSinDatos) {
        estado = SoleraL10n.t('nat.son_filtro_sin_datos_celda');
      } else if (penalizaciones != null) {
        estado = _soloMiZona
            ? SoleraL10n.tf('nat.son_filtro_activo_excluye', {
                'excluidas': penalizaciones.clasesExcluidas,
                'penalizadas': penalizaciones.clasesPenalizadas,
              })
            : SoleraL10n.tf('nat.son_filtro_activo_penaliza', {
                'penalizadas': penalizaciones.clasesPenalizadas,
              });
      } else {
        estado = SoleraL10n.t('nat.son_filtro_apagado');
      }
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: Text(SoleraL10n.t('nat.son_filtro_titulo')),
              subtitle: Text(SoleraL10n.t('nat.son_filtro_ubicacion_aproximada')),
              value: _filtroActivo,
              onChanged: (valor) {
                setState(() {
                  _filtroActivo = valor;
                  _clavePenalizaciones = null;
                });
                _guardarPreferencia(_clavePreferenciaFiltro, valor);
                if (valor && _ubicacionAproximada == null) _actualizarUbicacionAproximada();
              },
            ),
            if (_filtroActivo)
              SwitchListTile(
                title: Text(SoleraL10n.t('nat.son_solo_mi_zona')),
                subtitle: Text(SoleraL10n.tf('nat.son_solo_mi_zona_ayuda',
                    {'zona': penalizacionFueraDeZona.toStringAsFixed(0)})),
                value: _soloMiZona,
                onChanged: (valor) {
                  setState(() {
                    _soloMiZona = valor;
                    _clavePenalizaciones = null;
                  });
                  _guardarPreferencia(_clavePreferenciaSoloZona, valor);
                },
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(child: Text(estado, style: tema.bodySmall)),
                  if (_filtroActivo && _estadoOcurrencia == _EstadoOcurrencia.noDisponible && _modelo != null)
                    TextButton(
                      onPressed: () => _prepararOcurrencia(_modelo!.manifiesto),
                      child: Text(SoleraL10n.t('fos.ficha_reintentar')),
                    ),
                  if (_filtroActivo && _sinUbicacion)
                    TextButton(
                      onPressed: _actualizarUbicacionAproximada,
                      child: Text(SoleraL10n.t('fos.ficha_reintentar')),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaResultados() {
    final modelo = _modelo!;
    final clases = modelo.manifiesto.clases;
    final tema = Theme.of(context).textTheme;
    final ultimoTrozo = _ultimoTrozo;
    final resultados = _ultimosResultados;
    final hijos = <Widget>[
      Text(SoleraL10n.t('nat.son_que_se_oye'), style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
    ];
    if (ultimoTrozo == null) {
      hijos.add(Text(SoleraL10n.t('nat.son_sin_resultados'), style: tema.bodySmall));
    } else if (_ultimoTrozoConVoz) {
      hijos.add(Text(SoleraL10n.t('nat.son_voz_humana')));
    } else {
      if (_imagenEspectrograma != null) {
        hijos.add(Semantics(
          label: SoleraL10n.t('nat.son_espectrograma_accesible'),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 88,
              width: double.infinity,
              child: RawImage(image: _imagenEspectrograma, fit: BoxFit.fill),
            ),
          ),
        ));
        hijos.add(const SizedBox(height: 8));
      }
      if (resultados.especiesMostradas.isEmpty) {
        hijos.add(Text(SoleraL10n.t('nat.son_no_se_reconoce')));
      }
      for (final clasificada in resultados.especiesMostradas) {
        hijos.add(_filaEspecie(clases, clasificada, ultimoTrozo.momentoFinal, _clipUltimoTrozo));
      }
      if (resultados.sonidosTambienOidos.isNotEmpty) {
        hijos.add(Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            SoleraL10n.tf('nat.son_tambien_se_oye', {
              'sonidos': resultados.sonidosTambienOidos
                  .map((clasificada) => nombreVisiblePara(clases[clasificada.indiceClase], SoleraL10n.idioma))
                  .join(', '),
            }),
            style: tema.bodySmall,
          ),
        ));
      }
      if (resultados.especiesDudosas.isNotEmpty) {
        hijos.add(Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => setState(() => _mostrarDudosas = !_mostrarDudosas),
            child: Text(_mostrarDudosas
                ? SoleraL10n.t('nat.son_ocultar_dudosas')
                : SoleraL10n.tf('nat.son_ver_dudosas', {'n': resultados.especiesDudosas.length})),
          ),
        ));
        if (_mostrarDudosas) {
          hijos.add(Text(
            SoleraL10n.tf('nat.son_dudosas_ayuda', {
              'posible': puntuacionMinimaPosible.toStringAsFixed(0),
              'margen': margenRelativoPuntuacion.toStringAsFixed(0),
            }),
            style: tema.bodySmall,
          ));
          for (final clasificada in resultados.especiesDudosas) {
            hijos.add(Opacity(
              opacity: 0.7,
              child: _filaEspecie(clases, clasificada, ultimoTrozo.momentoFinal, _clipUltimoTrozo),
            ));
          }
        }
      }
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: hijos),
      ),
    );
  }

  Widget _filaEspecie(
      List<ClaseSonido> clases, ClaseClasificada clasificada, DateTime momento, Int16List? clip) {
    final clase = clases[clasificada.indiceClase];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(nombreVisiblePara(clase, SoleraL10n.idioma)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(clase.etiqueta, style: const TextStyle(fontStyle: FontStyle.italic)),
          const SizedBox(height: 4),
          _FilaConfianza(
            puntuacion: clasificada.puntuacion,
            puntuacionModelo: clasificada.puntuacionModelo,
            plausibilidad: clasificada.plausibilidad,
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: _guardandoEleccion
          ? null
          : () => _mostrarDetalleEspecie(
                indiceClase: clasificada.indiceClase,
                puntuacion: clasificada.puntuacion,
                puntuacionModelo: clasificada.puntuacionModelo,
                momento: momento,
                clip: clip,
                plausibilidad: clasificada.plausibilidad,
              ),
    );
  }

  Widget _tarjetaSesion() {
    final modelo = _modelo!;
    final clases = modelo.manifiesto.clases;
    final tema = Theme.of(context).textTheme;
    final especies = _sesion.especiesPorPuntuacion;
    final formatoHora = MaterialLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(SoleraL10n.t('nat.son_lista_sesion'), style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              SoleraL10n.tf('nat.son_resumen_sesion', {
                'trozos': _sesion.trozosAnalizados,
                'especies': _sesion.numeroEspecies,
                'voz': _sesion.trozosConVozHumana,
              }),
              style: tema.bodySmall,
            ),
            const SizedBox(height: 4),
            if (especies.isEmpty)
              Text(SoleraL10n.t('nat.son_sesion_vacia'), style: tema.bodySmall)
            else ...[
              Text(SoleraL10n.t('nat.son_sesion_ayuda'), style: tema.bodySmall),
              for (final especie in especies)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(nombreVisiblePara(clases[especie.indiceClase], SoleraL10n.idioma)),
                  subtitle: Text(SoleraL10n.tf('nat.son_fila_sesion', {
                    'veces': especie.vecesOida,
                    'primera': formatoHora.formatTimeOfDay(TimeOfDay.fromDateTime(especie.primeraVez)),
                    'ultima': formatoHora.formatTimeOfDay(TimeOfDay.fromDateTime(especie.ultimaVez)),
                    'mejor': especie.mejorPuntuacion.toStringAsFixed(1),
                  })),
                  trailing: Text(_etiquetaNivel(nivelConfianzaPara(especie.mejorPuntuacion)),
                      style: tema.labelSmall),
                  onTap: _guardandoEleccion
                      ? null
                      : () => _mostrarDetalleEspecie(
                            indiceClase: especie.indiceClase,
                            puntuacion: especie.mejorPuntuacion,
                            puntuacionModelo: especie.mejorPuntuacionModelo,
                            momento: especie.momentoMejor,
                            clip: especie.clipMejor,
                          ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

String _etiquetaNivel(NivelConfianzaSonido nivel) => switch (nivel) {
      NivelConfianzaSonido.probable => SoleraL10n.t('nat.son_nivel_probable'),
      NivelConfianzaSonido.posible => SoleraL10n.t('nat.son_nivel_posible'),
      NivelConfianzaSonido.dudoso => SoleraL10n.t('nat.son_nivel_dudoso'),
    };

/// Nivel de confianza, barra y puntuación (y, si el filtro la corrigió, la
/// del modelo y por qué).
class _FilaConfianza extends StatelessWidget {
  final double puntuacion;
  final double puntuacionModelo;
  final PlausibilidadEspecie? plausibilidad;

  const _FilaConfianza({
    required this.puntuacion,
    required this.puntuacionModelo,
    this.plausibilidad,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final marcas = <String>[
      if (plausibilidad?.esImprobableAqui ?? false) SoleraL10n.t('nat.son_marca_improbable_aqui'),
      if (plausibilidad?.esFueraDeTemporada ?? false) SoleraL10n.t('nat.son_marca_fuera_temporada'),
      if (puntuacion != puntuacionModelo)
        SoleraL10n.tf('nat.son_puntuacion_modelo', {'puntuacion': puntuacionModelo.toStringAsFixed(1)}),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(_etiquetaNivel(nivelConfianzaPara(puntuacion)), style: tema.labelMedium),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: fraccionBarraConfianza(puntuacion), minHeight: 6),
              ),
            ),
            const SizedBox(width: 8),
            Text(SoleraL10n.tf('nat.son_puntuacion', {'puntuacion': puntuacion.toStringAsFixed(1)}),
                style: tema.bodySmall),
          ],
        ),
        if (marcas.isNotEmpty) Text(marcas.join(' · '), style: tema.bodySmall),
      ],
    );
  }
}
