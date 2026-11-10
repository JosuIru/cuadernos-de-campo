import 'dart:io';

import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import 'package:path/path.dart' as path_lib;
import 'package:path_provider/path_provider.dart';

import '../datos/base_datos.dart';
import '../modelos/hallazgo.dart';
import '../sonido/registro_sesion_sonora.dart';
import 'estado_salida_en_curso.dart';

/// Categorías cuyo campo propio `evidencia` se rellena con «vocalización»
/// (como hace el alta desde «¿Quién canta?»).
const Set<String> _categoriasConCampoEvidencia = {'animal', 'mamifero', 'reptil', 'anfibio', 'pez'};

/// «Guardar como hallazgos»: un hallazgo por especie elegida, en el punto de
/// su mejor detección con posición, con evidencia «sonido» y una copia del
/// mejor clip de la sesión (la copia es del hallazgo: borrar la sesión no
/// la toca). Las especies sin ninguna detección con posición se saltan.
/// Devuelve cuántos se han guardado.
Future<int> guardarEspeciesComoHallazgos(SesionSonora sesion, List<ResumenEspecieSesion> especies) async {
  final baseDatos = BaseDatosNaturaleza.instancia;
  final salidaId = EstadoSalidaEnCurso.instancia.salida?.id;
  final documentos = await getApplicationDocumentsDirectory();
  final carpetaAudios = Directory(path_lib.join(documentos.path, 'audios'));
  await carpetaAudios.create(recursive: true);
  var guardados = 0;
  for (final especie in especies) {
    final dondeSeOyo = especie.mejorConPosicion;
    if (dondeSeOyo == null || especie.hallazgoId != null) continue;
    String? rutaAudio;
    final rutaClip = especie.rutaClip;
    if (rutaClip != null && File(rutaClip).existsSync()) {
      final copia = File(path_lib.join(
          carpetaAudios.path, 'sonido_${DateTime.now().millisecondsSinceEpoch}_${guardados}_s${sesion.id}.wav'));
      try {
        await File(rutaClip).copy(copia.path);
        rutaAudio = copia.path;
      } catch (_) {}
    }
    final mejor = especie.mejor;
    final indicePunto = dondeSeOyo.indicePuntoTraza;
    final precision = indicePunto != null && indicePunto < sesion.traza.length
        ? sesion.traza[indicePunto].precisionMetros
        : null;
    final atributos = <String, dynamic>{
      'identificacion_sonido': {
        'modelo': 'Perch 2.0 · ${sesion.versionModelo}',
        'puntuacion': double.parse(mejor.puntuacion.toStringAsFixed(1)),
        'puntuacion_modelo': double.parse(mejor.puntuacionModelo.toStringAsFixed(1)),
        'nivel': mejor.nivel.name,
        'filtro_zona': sesion.conFiltroDeZona,
        'momento_ms': mejor.momentoMs,
      },
      'sesion_sonora': {
        'id': sesion.id,
        'tipo': sesion.tipo.clave,
        'detecciones': especie.numeroDetecciones,
        'primera_ms': especie.primera.momentoMs,
        'ultima_ms': especie.ultima.momentoMs,
      },
      if (especie.categoria == 'ave') 'tipo_observacion': 'escuchada',
      if (_categoriasConCampoEvidencia.contains(especie.categoria)) 'evidencia': 'vocalización',
    };
    final hallazgo = Hallazgo(
      fechaMs: dondeSeOyo.momentoMs,
      latitud: dondeSeOyo.latitud!,
      longitud: dondeSeOyo.longitud!,
      precision: precision,
      categoria: especie.categoria,
      especie: especie.etiqueta,
      nombreComun: especie.nombreComun,
      notas: SoleraL10n.tf(
        sesion.tipo == TipoSesionSonora.recorrido ? 'nat.ses_nota_hallazgo_recorrido' : 'nat.ses_nota_hallazgo_coro',
        {'veces': especie.numeroDetecciones},
      ),
      atributos: atributos,
      salidaId: salidaId,
      tipoEvidencia: TipoEvidencia.sonido,
      rutaAudio: rutaAudio,
    );
    final idHallazgo = await baseDatos.guardarHallazgo(hallazgo);
    final idDeteccion = mejor.id ?? dondeSeOyo.id;
    if (idDeteccion != null) {
      await baseDatos.actualizarDeteccionSonora(idDeteccion, {'hallazgo_id': idHallazgo});
    }
    guardados++;
  }
  return guardados;
}
