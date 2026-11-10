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
import 'package:wakelock_plus/wakelock_plus.dart';

import '../datos/datos_guia.dart';
import '../modelos/resultado_escucha.dart';
import '../servicios/almacen_modelo_fauna.dart';
import '../servicios/avisos_especies_vigiladas.dart';
import '../servicios/clasificador_fauna.dart';
import '../servicios/controlador_donde_esta.dart';
import '../servicios/controlador_sesion_sonora.dart';
import '../servicios/controlador_sonidos_propios.dart';
import '../servicios/escucha_microfono.dart';
import '../servicios/ocurrencia_fauna_instalada.dart';
import '../sonido/calidad_audio.dart';
import '../sonido/clasificacion_sonido.dart';
import '../sonido/clip_audio.dart';
import '../sonido/especies_vigiladas.dart';
import '../sonido/espectrograma_mel.dart';
import '../sonido/filtro_ocurrencia.dart';
import '../sonido/manifiesto_modelo_fauna.dart';
import '../sonido/registro_sesion_sonora.dart';
import '../sonido/sesion_escucha.dart';
import '../sonido/sonidos_propios.dart';
import '../utiles/permisos_gps.dart';
import 'pantalla_especies_vigiladas.dart';
import 'pantalla_nuevo.dart';
import 'pantalla_resumen_sesion_sonora.dart';
import 'pantalla_sesiones_sonoras.dart';
import 'widgets/etica_campo.dart';
import 'widgets/indicador_calidad_audio.dart';
import 'widgets/tarjeta_donde_esta.dart';
import 'widgets/tarjeta_tus_sonidos.dart';
import 'widgets/temporada_sonido_ficha.dart';

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

/// Escucha libre (como siempre), «Escuchar mientras camino» o «Coro del
/// amanecer».
enum _ModoEscucha { libre, recorrido, coro }

/// Duraciones que se ofrecen para el coro, en minutos.
const List<int> _duracionesCoroMinutos = [30, 60, 90, 120, 180];

const _clavePreferenciaFiltro = 'nat.quien_canta.filtro_zona';
const _clavePreferenciaSoloZona = 'nat.quien_canta.solo_mi_zona';
const _clavePreferenciaPantallaEncendida = 'nat.quien_canta.pantalla_encendida';

/// El aviso de calidad se recalcula cada 5 tramas (0,5 s).
const int _tramasEntreEvaluacionesCalidad = 5;

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

  // ¿Dónde está?, aviso de calidad, tus sonidos y pantalla encendida
  final ControladorDondeEsta _dondeEsta = ControladorDondeEsta();
  ControladorSonidosPropios? _sonidosPropios;
  ResultadoSonidosPropios _coincidenciasPropias = ResultadoSonidosPropios.vacio;

  /// Embedding del último trozo sin voz humana (para «Tus sonidos»).
  Float32List? _embeddingUltimoTrozoLimpio;
  AnalizadorCalidadAudio? _analizadorCalidad;
  EvaluacionCalidad _evaluacionCalidad = EvaluacionCalidad.sinDatos;
  int _tramasDesdeEvaluacionCalidad = 0;
  bool _mantenerPantallaEncendida = true;

  // Sesiones largas (recorrido y coro del amanecer)
  _ModoEscucha _modo = _ModoEscucha.libre;
  ControladorSesionSonora? _sesionLarga;
  int _minutosCoro = 90;
  TimeOfDay? _horaFinCoro;
  TimeOfDay? _horaInicioCoro;
  DateTime? _inicioCoroProgramado;
  Timer? _temporizadorInicioCoro;
  Timer? _temporizadorFinCoro;
  bool _terminandoSesion = false;

  // «Avísame si lo oye»
  List<String> _especiesVigiladas = const [];
  VigilanteEspecies _vigilante = VigilanteEspecies(const []);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cargarPreferencias();
    _cargarEspeciesVigiladas();
    _dondeEsta.cargarPreferencias();
    _comprobarModelo();
    // La primera vez: la app nunca reproduce cantos para atraer animales.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) avisarEticaCampoLaPrimeraVez(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelacion?.cancelar();
    unawaited(_escucha?.detener());
    _escucha = null;
    _temporizadorInicioCoro?.cancel();
    _temporizadorFinCoro?.cancel();
    // Salir de la pantalla cierra la sesión larga (queda guardada).
    final sesion = _sesionLarga;
    _sesionLarga = null;
    if (sesion != null) {
      final manifiesto = _modelo?.manifiesto;
      unawaited(sesion
          .terminar(
            clases: manifiesto?.clases ?? const [],
            frecuenciaClipHz: manifiesto?.frecuenciaMuestreoHz ?? 32000,
          )
          .whenComplete(sesion.dispose));
    }
    _clasificador?.liberar();
    _clasificador = null;
    _imagenEspectrograma?.dispose();
    _dondeEsta.dispose();
    _sonidosPropios?.dispose();
    _ajustarPantallaEncendida(false);
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
        // La sesión larga queda en pausa: «Continuar» o «Terminar» al volver.
        _sesionLarga?.pausar();
        if (mounted) setState(() => _detenidaPorSegundoPlano = true);
      }
      if (_inicioCoroProgramado != null) _cancelarInicioCoroProgramado();
      // La brújula tampoco sigue en segundo plano (las tomas se conservan).
      if (_dondeEsta.activo) unawaited(_dondeEsta.desactivar());
    }
  }

  /// Pantalla encendida mientras se escucha, si la persona no lo ha quitado.
  void _ajustarPantallaEncendida(bool encender) {
    unawaited(() async {
      try {
        await WakelockPlus.toggle(enable: encender);
      } catch (_) {
        // Sin soporte en la plataforma: no pasa nada.
      }
    }());
  }

  Future<void> _cargarPreferencias() async {
    try {
      final preferencias = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _filtroActivo = preferencias.getBool(_clavePreferenciaFiltro) ?? true;
        _soloMiZona = preferencias.getBool(_clavePreferenciaSoloZona) ?? true;
        _mantenerPantallaEncendida = preferencias.getBool(_clavePreferenciaPantallaEncendida) ?? true;
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
      _prepararSonidosPropios(modelo.manifiesto.versionModelo);
    }
  }

  void _prepararSonidosPropios(String versionModelo) {
    if (_sonidosPropios?.versionModelo == versionModelo) return;
    _sonidosPropios?.dispose();
    final controlador = ControladorSonidosPropios(versionModelo: versionModelo);
    _sonidosPropios = controlador;
    unawaited(controlador.cargar());
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
    OcurrenciaFaunaInstalada.fijar(datos);
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
      _prepararSonidosPropios(modelo.manifiesto.versionModelo);
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
    await _terminarSesionLarga(abrirResumen: false);
    _clasificador?.liberar();
    await borrarModeloFaunaInstalado();
    OcurrenciaFaunaInstalada.olvidar();
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
        alRecibirAudio: _alRecibirAudio,
      );
      _analizadorCalidad = null;
      _evaluacionCalidad = EvaluacionCalidad.sinDatos;
      _embeddingUltimoTrozoLimpio = null;
      _coincidenciasPropias = ResultadoSonidosPropios.vacio;
      _trozoAnteriorLimpio = null;
      _muestraFinalAnterior = null;
      await escucha.empezar();
      if (!mounted) {
        await escucha.detener();
        return;
      }
      setState(() => _escucha = escucha);
      if (_mantenerPantallaEncendida) _ajustarPantallaEncendida(true);
      await _empezarOContinuarSesionLarga();
    } catch (error) {
      if (mounted) setState(() => _errorEscucha = error.toString());
    } finally {
      if (mounted) setState(() => _abriendoMicrofono = false);
    }
  }

  /// Botón de parar: en una sesión larga, además, la termina y abre el
  /// resumen.
  Future<void> _pararDesdeBoton() async {
    await _detenerEscucha();
    await _terminarSesionLarga(abrirResumen: true);
  }

  Future<void> _empezarOContinuarSesionLarga() async {
    final modelo = _modelo;
    if (modelo == null) return;
    final sesionEnPausa = _sesionLarga;
    if (sesionEnPausa != null) {
      final finPrevisto = sesionEnPausa.finPrevisto;
      if (finPrevisto != null && !DateTime.now().isBefore(finPrevisto)) {
        await _pararDesdeBoton();
        return;
      }
      sesionEnPausa.continuar(conUbicacion: await asegurarPermisoUbicacion(context: mounted ? context : null));
      return;
    }
    if (_modo == _ModoEscucha.libre) return;
    final tipo = _modo == _ModoEscucha.recorrido ? TipoSesionSonora.recorrido : TipoSesionSonora.coro;
    final ahora = DateTime.now();
    DateTime? finPrevisto;
    if (tipo == TipoSesionSonora.coro) {
      final horaFin = _horaFinCoro;
      finPrevisto = horaFin == null
          ? finDelCoro(inicio: ahora, duracion: Duration(minutes: _minutosCoro))
          : finDelCoro(inicio: ahora, horaFin: horaFin.hour, minutoFin: horaFin.minute);
    }
    final sesion = ControladorSesionSonora(
      tipo: tipo,
      versionModelo: modelo.manifiesto.versionModelo,
      conFiltroDeZona: _filtroActivo && _penalizaciones != null,
      finPrevisto: finPrevisto,
    );
    final conUbicacion = await asegurarPermisoUbicacion(context: mounted ? context : null);
    try {
      await sesion.empezar(conUbicacion: conUbicacion);
    } catch (error) {
      sesion.dispose();
      if (mounted) setState(() => _errorEscucha = error.toString());
      return;
    }
    if (!mounted) {
      unawaited(sesion
          .terminar(clases: modelo.manifiesto.clases, frecuenciaClipHz: modelo.manifiesto.frecuenciaMuestreoHz)
          .whenComplete(sesion.dispose));
      return;
    }
    setState(() => _sesionLarga = sesion);
    if (finPrevisto != null) {
      _temporizadorFinCoro?.cancel();
      _temporizadorFinCoro = Timer(finPrevisto.difference(DateTime.now()), () {
        if (mounted) _pararDesdeBoton();
      });
    }
  }

  /// Cierra la sesión larga (guarda los clips y la hora de fin) y, si se
  /// pide, abre su resumen.
  Future<void> _terminarSesionLarga({required bool abrirResumen}) async {
    final sesion = _sesionLarga;
    final modelo = _modelo;
    if (sesion == null || modelo == null || _terminandoSesion) return;
    _temporizadorFinCoro?.cancel();
    _temporizadorFinCoro = null;
    setState(() => _terminandoSesion = true);
    int? sesionId;
    try {
      sesionId = await sesion.terminar(
          clases: modelo.manifiesto.clases, frecuenciaClipHz: modelo.manifiesto.frecuenciaMuestreoHz);
    } finally {
      sesion.dispose();
      if (mounted) {
        setState(() {
          _sesionLarga = null;
          _terminandoSesion = false;
          _detenidaPorSegundoPlano = false;
        });
      }
    }
    if (!abrirResumen || !mounted || sesionId == null) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PantallaResumenSesionSonora(sesionId: sesionId!),
    ));
  }

  /// Coro con hora de inicio: la pantalla espera abierta (y encendida) y
  /// empieza sola.
  void _programarInicioCoro(TimeOfDay hora) {
    final inicio = proximaHoraDelReloj(DateTime.now(), hora.hour, hora.minute);
    _temporizadorInicioCoro?.cancel();
    _temporizadorInicioCoro = Timer(inicio.difference(DateTime.now()), () {
      if (!mounted) return;
      setState(() => _inicioCoroProgramado = null);
      _ajustarPantallaEncendida(false);
      _empezarEscucha();
    });
    setState(() => _inicioCoroProgramado = inicio);
    if (_mantenerPantallaEncendida) _ajustarPantallaEncendida(true);
  }

  void _cancelarInicioCoroProgramado() {
    _temporizadorInicioCoro?.cancel();
    _temporizadorInicioCoro = null;
    _ajustarPantallaEncendida(false);
    if (mounted) setState(() => _inicioCoroProgramado = null);
  }

  // ------------------------------------------------- «Avísame si lo oye»

  Future<void> _cargarEspeciesVigiladas() async {
    final etiquetas = await leerEspeciesVigiladas();
    if (!mounted) return;
    setState(() {
      _especiesVigiladas = etiquetas;
      _vigilante = VigilanteEspecies(etiquetas);
    });
  }

  Future<void> _elegirEspeciesVigiladas() async {
    final modelo = _modelo;
    if (modelo == null) return;
    final elegidas = await Navigator.of(context).push<List<String>>(MaterialPageRoute(
      builder: (_) => PantallaEspeciesVigiladas(clases: modelo.manifiesto.clases, iniciales: _especiesVigiladas),
    ));
    if (elegidas == null || !mounted) return;
    await guardarEspeciesVigiladas(elegidas);
    setState(() {
      _especiesVigiladas = elegidas;
      _vigilante = VigilanteEspecies(elegidas);
    });
    if (elegidas.isNotEmpty) {
      final permiso = await AvisosEspeciesVigiladas.instancia.pedirPermiso();
      if (!permiso && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(SoleraL10n.t('nat.vig_sin_permiso_notificaciones'))),
        );
      }
    }
  }

  void _avisarEspeciesVigiladas(List<ClaseClasificada> especiesMostradas, List<ClaseSonido> clases, DateTime momento) {
    for (final clasificada in _vigilante.avisosPara(especiesMostradas, clases, momento)) {
      final clase = clases[clasificada.indiceClase];
      final nombre = nombreVisiblePara(clase, SoleraL10n.idioma);
      unawaited(AvisosEspeciesVigiladas.instancia.avisar(
        etiqueta: clase.etiqueta,
        titulo: SoleraL10n.tf('nat.vig_aviso_titulo', {'nombre': nombre}),
        cuerpo: SoleraL10n.tf('nat.vig_aviso_cuerpo', {
          'cientifico': clase.etiqueta.replaceAll('_', ' '),
          'puntuacion': clasificada.puntuacion.toStringAsFixed(1),
        }),
      ));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(SoleraL10n.tf('nat.vig_aviso_titulo', {'nombre': nombre})),
        duration: const Duration(seconds: 6),
      ));
    }
  }

  String _nombreComunPara(ClaseSonido clase) {
    final nombreLocal = nombreVisiblePara(clase, SoleraL10n.idioma);
    if (nombreLocal == clase.etiqueta.replaceAll('_', ' ')) {
      return especieGuiaPorNombreCientifico(clase.etiqueta)?.nombreComun ?? '';
    }
    return nombreLocal;
  }

  Future<void> _detenerEscucha() async {
    final escucha = _escucha;
    _escucha = null;
    _analizadorCalidad = null;
    if (_dondeEsta.barriendo) _dondeEsta.cancelarBarrido();
    _ajustarPantallaEncendida(false);
    if (mounted) setState(() {});
    await escucha?.detener();
  }

  /// Cada bloque del micrófono: aviso de calidad y, si hay barrido, nivel
  /// frente a rumbo. No se guarda nada.
  void _alRecibirAudio(Float32List muestras, int frecuenciaHz) {
    var analizador = _analizadorCalidad;
    if (analizador == null || analizador.frecuenciaMuestreoHz != frecuenciaHz) {
      analizador = AnalizadorCalidadAudio(frecuenciaHz.toDouble(), alCerrarTrama: _alCerrarTramaCalidad);
      _analizadorCalidad = analizador;
    }
    analizador.procesar(muestras);
  }

  void _alCerrarTramaCalidad(TramaCalidad trama) {
    _dondeEsta.alCerrarTramaAudio(trama.nivelBandaCantoDecibelios);
    _tramasDesdeEvaluacionCalidad++;
    if (_tramasDesdeEvaluacionCalidad < _tramasEntreEvaluacionesCalidad) return;
    _tramasDesdeEvaluacionCalidad = 0;
    final evaluacion = _analizadorCalidad?.evaluar();
    if (evaluacion == null || !mounted) return;
    final cambiaron = evaluacion.avisos.length != _evaluacionCalidad.avisos.length ||
        !evaluacion.avisos.containsAll(_evaluacionCalidad.avisos) ||
        identical(_evaluacionCalidad, EvaluacionCalidad.sinDatos);
    _evaluacionCalidad = evaluacion;
    if (cambiaron) setState(() {});
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
      _escucha?.registrarTrozoAnalizado(trozo, conVozHumana: true);
      _embeddingUltimoTrozoLimpio = null;
      _coincidenciasPropias = ResultadoSonidosPropios.vacio;
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
    _escucha?.registrarTrozoAnalizado(trozo, conVozHumana: false);
    final embedding = trozo.clasificado.embedding;
    _embeddingUltimoTrozoLimpio = embedding.isEmpty ? null : embedding;
    _coincidenciasPropias = _sonidosPropios?.comparar(embedding) ?? ResultadoSonidosPropios.vacio;
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
    _sesionLarga?.registrarTrozo(
      especiesMostradas: resultados.especiesMostradas,
      clases: clases,
      momento: trozo.momentoFinal,
      nombreComunDe: _nombreComunPara,
      clip: resultados.especiesMostradas.isEmpty ? null : clip,
    );
    _avisarEspeciesVigiladas(resultados.especiesMostradas, clases, trozo.momentoFinal);
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
    final frecuenciaModelo = modelo.manifiesto.frecuenciaMuestreoHz;
    final segundosClip = clip == null ? 0.0 : duracionSegundos(clip.length, frecuenciaModelo);
    // Lo último oído (búfer de 10 s, solo lo analizado sin voz): se ofrece si
    // es más largo que el clip del trozo.
    final ultimoOido = _escucha?.ultimoOidoLimpio();
    final segundosUltimoOido =
        ultimoOido == null ? 0.0 : duracionSegundos(ultimoOido.muestras.length, ultimoOido.frecuenciaHz);
    final ofrecerUltimoOido = segundosUltimoOido >= segundosClip + 0.5;
    final zona = _dondeEsta.zona;
    var usarUltimoOido = false;
    final eleccion = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (contextoHoja) => StatefulBuilder(
        builder: (contextoHoja, refrescarHoja) => SafeArea(
          child: SingleChildScrollView(
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
                  usarUltimoOido
                      ? SoleraL10n.tf('nat.son_detalle_con_ultimo_oido',
                          {'segundos': segundosUltimoOido.toStringAsFixed(1)})
                      : clip == null
                          ? SoleraL10n.t('nat.son_detalle_sin_clip')
                          : SoleraL10n.tf('nat.son_detalle_con_clip', {
                              'segundos': segundosClip.toStringAsFixed(1),
                            }),
                  style: Theme.of(contextoHoja).textTheme.bodySmall,
                ),
                if (ofrecerUltimoOido)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(SoleraL10n.tf('nat.son_usar_ultimo_oido',
                        {'segundos': segundosUltimoOido.toStringAsFixed(0)})),
                    subtitle: Text(SoleraL10n.t('nat.son_usar_ultimo_oido_ayuda')),
                    value: usarUltimoOido,
                    onChanged: (valor) => refrescarHoja(() => usarUltimoOido = valor),
                  ),
                if (zona.hayZona)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(SoleraL10n.tf('nat.son_detalle_con_zona', {'tomas': zona.numeroTomas}),
                        style: Theme.of(contextoHoja).textTheme.bodySmall),
                  ),
                if (_ocurrencia case final datosOcurrencia? when clase.esEspecie)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: TarjetaTemporadaSonido(
                      datos: datosOcurrencia,
                      etiquetaEspecie: clase.etiqueta,
                      latitud: _ubicacionAproximada?.latitud,
                      longitud: _ubicacionAproximada?.longitud,
                    ),
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
      ),
    );
    if (eleccion != true || !mounted) return;
    await _elegirEspecie(
      clase: clase,
      puntuacion: puntuacion,
      puntuacionModelo: puntuacionModelo,
      momento: momento,
      clip: clip,
      // Al pulsar, lo último oído se vuelve a leer (ha seguido sonando).
      ultimoOido: usarUltimoOido ? (_escucha?.ultimoOidoLimpio() ?? ultimoOido) : null,
    );
  }

  Future<void> _elegirEspecie({
    required ClaseSonido clase,
    required double puntuacion,
    required double puntuacionModelo,
    required DateTime momento,
    required Int16List? clip,
    ({Float32List muestras, int frecuenciaHz})? ultimoOido,
  }) async {
    final modelo = _modelo;
    if (modelo == null || _guardandoEleccion) return;
    setState(() => _guardandoEleccion = true);
    await _detenerEscucha();
    // Anotar una especie cierra la sesión larga (queda en «Sesiones»).
    await _terminarSesionLarga(abrirResumen: false);
    final frecuenciaModelo = modelo.manifiesto.frecuenciaMuestreoHz;
    // El clip: lo último oído (a la frecuencia del micrófono) o el del trozo.
    final muestrasClip = ultimoOido != null ? flotanteAPcm16(ultimoOido.muestras) : clip;
    final frecuenciaClip = ultimoOido?.frecuenciaHz ?? frecuenciaModelo;
    String? rutaAudio;
    if (muestrasClip != null) {
      try {
        final documentos = await getApplicationDocumentsDirectory();
        final carpetaAudios = Directory(path_lib.join(documentos.path, 'audios'));
        await carpetaAudios.create(recursive: true);
        final fichero = File(path_lib.join(
            carpetaAudios.path, 'sonido_${DateTime.now().millisecondsSinceEpoch}.wav'));
        await fichero.writeAsBytes(codificarWavMono16(muestrasClip, frecuenciaClip), flush: true);
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
      duracionAudioSegundos:
          muestrasClip == null ? 0 : duracionSegundos(muestrasClip.length, frecuenciaClip),
      puntuacion: puntuacion,
      puntuacionModelo: puntuacionModelo,
      versionModelo: modelo.manifiesto.versionModelo,
      conFiltroDeZona: _penalizaciones != null && _filtroActivo,
      clipDeLoUltimoOido: ultimoOido != null && rutaAudio != null,
      zonaAnimal: _dondeEsta.zonaParaHallazgo(),
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
            OutlinedButton.icon(
              icon: const Icon(Icons.volume_off_outlined),
              label: Text(SoleraL10n.t('nat.etica_titulo')),
              onPressed: () => mostrarEticaCampo(contextoHoja),
            ),
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
            icon: const Icon(Icons.history),
            tooltip: SoleraL10n.t('nat.ses_lista_titulo'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const PantallaSesionesSonoras(),
            )),
          ),
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
            _tarjetaModo(),
            const SizedBox(height: 12),
            _tarjetaEscucha(),
            const SizedBox(height: 12),
            _tarjetaVigiladas(),
            const SizedBox(height: 12),
            _tarjetaFiltro(),
            const SizedBox(height: 12),
            _tarjetaResultados(),
            const SizedBox(height: 12),
            TarjetaDondeEsta(controlador: _dondeEsta, escuchando: _escucha != null),
            const SizedBox(height: 12),
            _tarjetaSesion(),
            if (_sonidosPropios != null) ...[
              const SizedBox(height: 12),
              TarjetaTusSonidos(
                controlador: _sonidosPropios!,
                embeddingUltimoTrozo: _embeddingUltimoTrozoLimpio,
              ),
            ],
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
    if (escuchando && !identical(_evaluacionCalidad, EvaluacionCalidad.sinDatos)) {
      lineasEstado.add(Padding(
        padding: const EdgeInsets.only(top: 4),
        child: IndicadorCalidadAudio(evaluacion: _evaluacionCalidad),
      ));
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
            if (_inicioCoroProgramado != null)
              _bloqueInicioProgramado()
            else
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                icon: Icon(escuchando ? Icons.stop : Icons.mic),
                label: Text(_textoBotonEscucha(escuchando)),
                onPressed: _abriendoMicrofono || _guardandoEleccion || _terminandoSesion
                    ? null
                    : (escuchando ? _pararDesdeBoton : _alPulsarEmpezar),
              ),
            if (_sesionLarga != null) _bloqueSesionLarga(),
            const SizedBox(height: 8),
            ...lineasEstado,
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(SoleraL10n.t('nat.son_pantalla_encendida')),
              value: _mantenerPantallaEncendida,
              onChanged: (valor) {
                setState(() => _mantenerPantallaEncendida = valor);
                _guardarPreferencia(_clavePreferenciaPantallaEncendida, valor);
                if (_escucha != null) _ajustarPantallaEncendida(valor);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _textoBotonEscucha(bool escuchando) {
    final sesion = _sesionLarga;
    if (escuchando) {
      if (sesion == null) return SoleraL10n.t('nat.son_detener');
      return SoleraL10n.t(
          sesion.tipo == TipoSesionSonora.recorrido ? 'nat.ses_terminar_recorrido' : 'nat.ses_terminar_coro');
    }
    if (sesion != null) return SoleraL10n.t('nat.ses_continuar');
    return switch (_modo) {
      _ModoEscucha.libre => SoleraL10n.t('nat.son_empezar'),
      _ModoEscucha.recorrido => SoleraL10n.t('nat.ses_empezar_recorrido'),
      _ModoEscucha.coro => _horaInicioCoro == null
          ? SoleraL10n.t('nat.ses_empezar_coro')
          : SoleraL10n.tf('nat.ses_programar_coro', {'hora': _formatearHora(_horaInicioCoro!)}),
    };
  }

  void _alPulsarEmpezar() {
    final horaInicio = _horaInicioCoro;
    if (_sesionLarga == null && _modo == _ModoEscucha.coro && horaInicio != null) {
      _programarInicioCoro(horaInicio);
      return;
    }
    _empezarEscucha();
  }

  String _formatearHora(TimeOfDay hora) => MaterialLocalizations.of(context).formatTimeOfDay(hora);

  String _formatearDuracion(Duration duracion) {
    final horas = duracion.inHours;
    final minutos = duracion.inMinutes % 60;
    if (horas == 0) return '$minutos min';
    return minutos == 0 ? '$horas h' : '$horas h ${minutos.toString().padLeft(2, '0')} min';
  }

  Widget _bloqueInicioProgramado() {
    final inicio = _inicioCoroProgramado!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          SoleraL10n.tf('nat.ses_esperando_inicio', {
            'hora': _formatearHora(TimeOfDay.fromDateTime(inicio)),
          }),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(SoleraL10n.t('nat.ses_esperando_inicio_ayuda'), style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.close),
          label: Text(SoleraL10n.t('nat.ses_cancelar_inicio')),
          onPressed: _cancelarInicioCoroProgramado,
        ),
      ],
    );
  }

  Widget _bloqueSesionLarga() {
    final sesion = _sesionLarga!;
    final tema = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: sesion,
      builder: (context, _) {
        final lineas = <String>[];
        final transcurrido = DateTime.now().difference(sesion.inicio);
        if (sesion.tipo == TipoSesionSonora.recorrido) {
          lineas.add(SoleraL10n.tf('nat.ses_estado_recorrido', {
            'tiempo': _formatearDuracion(transcurrido),
            'metros': sesion.distanciaMetros.round(),
            'puntos': sesion.puntosTraza,
          }));
        } else {
          final fin = sesion.finPrevisto;
          lineas.add(SoleraL10n.tf('nat.ses_estado_coro', {
            'tiempo': _formatearDuracion(transcurrido),
            'fin': fin == null ? '—' : _formatearHora(TimeOfDay.fromDateTime(fin)),
          }));
        }
        lineas.add(SoleraL10n.tf('nat.ses_estado_detecciones', {
          'detecciones': sesion.numeroDetecciones,
          'especies': sesion.numeroEspecies,
        }));
        if (sesion.errorGps != null || (sesion.puntosTraza == 0 && transcurrido.inSeconds > 60)) {
          lineas.add(SoleraL10n.t('nat.ses_sin_gps'));
        }
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final linea in lineas) Text(linea, style: tema.bodySmall),
              if (sesion.pausada && _escucha == null) ...[
                const SizedBox(height: 4),
                Text(SoleraL10n.t('nat.ses_en_pausa'), style: tema.bodyMedium),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.flag_outlined),
                    label: Text(SoleraL10n.t(sesion.tipo == TipoSesionSonora.recorrido
                        ? 'nat.ses_terminar_recorrido'
                        : 'nat.ses_terminar_coro')),
                    onPressed: _terminandoSesion ? null : () => _terminarSesionLarga(abrirResumen: true),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _tarjetaModo() {
    final tema = Theme.of(context).textTheme;
    final bloqueado = _escucha != null || _sesionLarga != null || _inicioCoroProgramado != null;
    final explicacion = switch (_modo) {
      _ModoEscucha.libre => SoleraL10n.t('nat.ses_modo_libre_ayuda'),
      _ModoEscucha.recorrido => SoleraL10n.t('nat.ses_modo_recorrido_ayuda'),
      _ModoEscucha.coro => SoleraL10n.t('nat.ses_modo_coro_ayuda'),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<_ModoEscucha>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                    value: _ModoEscucha.libre,
                    label: Text(SoleraL10n.t('nat.ses_segmento_libre'))),
                ButtonSegment(
                    value: _ModoEscucha.recorrido,
                    label: Text(SoleraL10n.t('nat.ses_segmento_recorrido'))),
                ButtonSegment(
                    value: _ModoEscucha.coro,
                    label: Text(SoleraL10n.t('nat.ses_segmento_coro'))),
              ],
              selected: {_modo},
              onSelectionChanged: bloqueado ? null : (seleccion) => setState(() => _modo = seleccion.first),
            ),
            const SizedBox(height: 8),
            Text(explicacion, style: tema.bodySmall),
            if (_modo == _ModoEscucha.coro && !bloqueado) ..._opcionesCoro(),
          ],
        ),
      ),
    );
  }

  List<Widget> _opcionesCoro() {
    final tema = Theme.of(context).textTheme;
    return [
      const SizedBox(height: 12),
      Text(SoleraL10n.t('nat.ses_coro_duracion'), style: tema.labelLarge),
      const SizedBox(height: 4),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final minutos in _duracionesCoroMinutos)
            ChoiceChip(
              label: Text(_formatearDuracion(Duration(minutes: minutos))),
              selected: _horaFinCoro == null && _minutosCoro == minutos,
              onSelected: (_) => setState(() {
                _minutosCoro = minutos;
                _horaFinCoro = null;
              }),
            ),
          ChoiceChip(
            label: Text(_horaFinCoro == null
                ? SoleraL10n.t('nat.ses_coro_hasta_hora')
                : SoleraL10n.tf('nat.ses_coro_hasta', {'hora': _formatearHora(_horaFinCoro!)})),
            selected: _horaFinCoro != null,
            onSelected: (_) async {
              final hora = await showTimePicker(
                context: context,
                initialTime: _horaFinCoro ?? TimeOfDay.fromDateTime(DateTime.now().add(const Duration(hours: 1))),
              );
              if (hora != null && mounted) setState(() => _horaFinCoro = hora);
            },
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(SoleraL10n.t('nat.ses_coro_inicio'), style: tema.labelLarge),
      const SizedBox(height: 4),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          ChoiceChip(
            label: Text(SoleraL10n.t('nat.ses_coro_inicio_ahora')),
            selected: _horaInicioCoro == null,
            onSelected: (_) => setState(() => _horaInicioCoro = null),
          ),
          ChoiceChip(
            label: Text(_horaInicioCoro == null
                ? SoleraL10n.t('nat.ses_coro_inicio_a_las')
                : SoleraL10n.tf('nat.ses_coro_inicio_hora', {'hora': _formatearHora(_horaInicioCoro!)})),
            selected: _horaInicioCoro != null,
            onSelected: (_) async {
              final hora = await showTimePicker(
                context: context,
                initialTime: _horaInicioCoro ?? const TimeOfDay(hour: 6, minute: 0),
              );
              if (hora != null && mounted) setState(() => _horaInicioCoro = hora);
            },
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(SoleraL10n.t('nat.ses_coro_pantalla_abierta'), style: tema.bodySmall),
    ];
  }

  Widget _tarjetaVigiladas() {
    final tema = Theme.of(context).textTheme;
    final clases = _modelo?.manifiesto.clases ?? const <ClaseSonido>[];
    final nombres = [
      for (final etiqueta in _especiesVigiladas)
        if (clases.where((clase) => clase.etiqueta == etiqueta).firstOrNull case final clase?)
          nombreVisiblePara(clase, SoleraL10n.idioma)
        else
          etiqueta.replaceAll('_', ' '),
    ];
    return Card(
      child: ListTile(
        leading: const Icon(Icons.notifications_active_outlined),
        title: Text(SoleraL10n.t('nat.vig_titulo')),
        subtitle: Text(
          nombres.isEmpty
              ? SoleraL10n.t('nat.vig_ninguna')
              : SoleraL10n.tf('nat.vig_resumen', {'n': nombres.length, 'especies': nombres.take(4).join(', ')}),
          style: tema.bodySmall,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: _elegirEspeciesVigiladas,
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
      for (final coincidencia in _coincidenciasPropias.coincidencias) {
        hijos.add(Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.bookmark_outline, color: Theme.of(context).colorScheme.onTertiaryContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  SoleraL10n.tf('nat.son_coincide_tuyo', {
                    'nombre': coincidencia.nombre,
                    'similitud': textoSimilitud(coincidencia.similitud),
                  }),
                  style: TextStyle(color: Theme.of(context).colorScheme.onTertiaryContainer),
                ),
              ),
            ],
          ),
        ));
      }
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
