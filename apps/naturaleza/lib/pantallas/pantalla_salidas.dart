import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';

import '../datos/base_datos.dart';
import '../modelos/salida.dart';
import '../servicios/estado_salida_en_curso.dart';
import '../servicios/grabador_track.dart';
import '../utiles/permisos_gps.dart';
import 'pantalla_salida.dart';

/// Listado de salidas (la unidad narrativa del cuaderno). Permite
/// abrir una nueva con un diálogo mínimo y entrar al detalle de las
/// existentes.
class PantallaSalidas extends StatefulWidget {
  const PantallaSalidas({super.key});

  @override
  State<PantallaSalidas> createState() => _PantallaSalidasState();
}

class _PantallaSalidasState extends State<PantallaSalidas> {
  List<Salida> _salidas = const [];
  // hallazgosPorSalida[i] = nº de hallazgos de la salida en posición i
  Map<int, int> _conteoHallazgos = const {};
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
    EstadoSalidaEnCurso.instancia.addListener(_alCambiarSalidaActiva);
  }

  @override
  void dispose() {
    EstadoSalidaEnCurso.instancia.removeListener(_alCambiarSalidaActiva);
    super.dispose();
  }

  void _alCambiarSalidaActiva() {
    if (mounted) _cargar();
  }

  Future<void> _cargar() async {
    final lista = await BaseDatosNaturaleza.instancia.listarSalidas();
    final conteos = <int, int>{};
    for (final salida in lista) {
      if (salida.id != null) {
        conteos[salida.id!] = await BaseDatosNaturaleza.instancia
            .contarHallazgosDeSalida(salida.id!);
      }
    }
    if (!mounted) return;
    setState(() {
      _salidas = lista;
      _conteoHallazgos = conteos;
      _cargando = false;
    });
  }

  Future<void> _iniciarSalida() async {
    final controladorTitulo = TextEditingController();
    final controladorZona = TextEditingController();
    final controladorHipotesis = TextEditingController();
    // Mutable dentro del diálogo: arranca por defecto activo.
    bool arrancarTrack = true;

    final iniciada = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (innerCtx, refrescar) => AlertDialog(
          title: Text(SoleraL10n.t('nat.mapa_nueva_salida')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controladorTitulo,
                  decoration: InputDecoration(
                    labelText: SoleraL10n.t('nat.mapa_titulo_opcional'),
                    hintText: SoleraL10n.t('nat.mapa_titulo_ejemplo'),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: separacionCamposSolera),
                TextField(
                  controller: controladorZona,
                  decoration: InputDecoration(
                    labelText: SoleraL10n.t('nat.mapa_zona_opcional'),
                    hintText: SoleraL10n.t('nat.mapa_zona_ejemplo'),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: separacionCamposSolera),
                TextField(
                  controller: controladorHipotesis,
                  decoration: InputDecoration(
                    labelText: SoleraL10n.t('nat.mapa_hipotesis_opcional'),
                    hintText: SoleraL10n.t('nat.mapa_hipotesis_ejemplo'),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                // Checkbox + etiqueta envueltos en InkWell para que el
                // tap en el texto también funcione (Material Design
                // estándar: tocar la fila entera, no sólo el cuadradito).
                InkWell(
                  onTap: () => refrescar(() => arrancarTrack = !arrancarTrack),
                  child: Row(
                    children: [
                      Checkbox(
                        value: arrancarTrack,
                        onChanged: (v) =>
                            refrescar(() => arrancarTrack = v ?? false),
                      ),
                      Expanded(
                        child: Text(
                          SoleraL10n.t('nat.mapa_arrancar_track'),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  SoleraL10n.t('nat.mapa_salida_explicacion'),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(innerCtx).pop(false),
              child: Text(SoleraL10n.t('cancelar')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(innerCtx).pop(true),
              child: Text(SoleraL10n.t('nat.mapa_iniciar')),
            ),
          ],
        ),
      ),
    );

    if (iniciada != true) return;
    final salidaNueva = await EstadoSalidaEnCurso.instancia.iniciar(
      titulo: controladorTitulo.text.trim(),
      zona: controladorZona.text.trim(),
      hipotesisJornada: controladorHipotesis.text.trim(),
    );

    if (arrancarTrack && !GrabadorTrack.instancia.grabando) {
      final permisoUbicacion = await asegurarPermisoUbicacion();
      if (permisoUbicacion) {
        await asegurarPermisoNotificaciones();
        GrabadorTrack.instancia.iniciar();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(SoleraL10n.t('nat.mapa_sin_permiso_track')),
          ),
        );
      }
    }

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PantallaSalida(idSalida: salidaNueva.id!),
      ),
    );
    if (mounted) _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final activa = EstadoSalidaEnCurso.instancia.salida;
    return Scaffold(
      appBar: AppBar(title: Text(SoleraL10n.t('nat.mapa_salidas'))),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(SoleraL10n.t('nat.mapa_iniciar_salida')),
        onPressed: activa != null ? null : _iniciarSalida,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _salidas.isEmpty
              ? _vistaVacia()
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView.separated(
                    padding: rellenoInferiorSeguro(context, const EdgeInsets.fromLTRB(16, 16, 16, 96)),
                    itemCount: _salidas.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _tarjetaSalida(_salidas[i]),
                  ),
                ),
    );
  }

  Widget _vistaVacia() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.hiking, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                SoleraL10n.t('nat.mapa_sin_salidas'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                SoleraL10n.t('nat.mapa_sin_salidas_ayuda'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );

  Widget _tarjetaSalida(Salida salida) {
    final fmtFecha = DateFormat('EEE d MMM y · HH:mm', SoleraL10n.idioma);
    final fechaInicio =
        DateTime.fromMillisecondsSinceEpoch(salida.fechaInicioMs);
    final etiquetaFecha = fmtFecha.format(fechaInicio);
    final etiquetaTitulo = salida.titulo.isNotEmpty
        ? salida.titulo
        : (salida.zona.isNotEmpty ? salida.zona : SoleraL10n.t('nat.mapa_salida_sin_titulo'));
    final cuenta = (salida.id != null
            ? _conteoHallazgos[salida.id!]
            : 0) ??
        0;
    final duracion = Duration(milliseconds: salida.duracionMs());
    final horas = duracion.inHours;
    final minutos = duracion.inMinutes % 60;
    final etiquetaDuracion = horas > 0 ? '${horas}h ${minutos}min' : '${minutos}min';

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: salida.enCurso
              ? Colors.orange.shade100
              : Colors.green.shade50,
          child: Icon(
            salida.enCurso ? Icons.fiber_manual_record : Icons.check,
            color: salida.enCurso ? Colors.orange.shade700 : Colors.green,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                etiquetaTitulo,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (salida.enCurso)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  SoleraL10n.t('nat.mapa_en_curso'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(etiquetaFecha, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 2),
              Text(
                '${cuenta == 1 ? SoleraL10n.t('nat.mapa_una_observacion') : SoleraL10n.tf('nat.mapa_n_observaciones', {'n': '$cuenta'})} · $etiquetaDuracion',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PantallaSalida(idSalida: salida.id!),
            ),
          );
          if (mounted) _cargar();
        },
      ),
    );
  }
}
