import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';

import '../datos/base_datos.dart';
import '../sonido/registro_sesion_sonora.dart';
import 'pantalla_resumen_sesion_sonora.dart';

/// Recorridos y coros del amanecer guardados, del más reciente al más
/// antiguo.
class PantallaSesionesSonoras extends StatefulWidget {
  const PantallaSesionesSonoras({super.key});

  @override
  State<PantallaSesionesSonoras> createState() => _PantallaSesionesSonorasState();
}

class _PantallaSesionesSonorasState extends State<PantallaSesionesSonoras> {
  late Future<List<({SesionSonora sesion, int detecciones, int especies})>> _futuroSesiones;

  @override
  void initState() {
    super.initState();
    _futuroSesiones = BaseDatosNaturaleza.instancia.listarSesionesSonoras();
  }

  void _recargar() => setState(() => _futuroSesiones = BaseDatosNaturaleza.instancia.listarSesionesSonoras());

  @override
  Widget build(BuildContext context) {
    final formatoFecha = DateFormat('d MMM yyyy, HH:mm', SoleraL10n.idioma);
    return Scaffold(
      appBar: AppBar(title: Text(SoleraL10n.t('nat.ses_lista_titulo'))),
      body: FutureBuilder<List<({SesionSonora sesion, int detecciones, int especies})>>(
        future: _futuroSesiones,
        builder: (context, instantanea) {
          if (instantanea.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final sesiones = instantanea.data ?? const [];
          if (sesiones.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(SoleraL10n.t('nat.ses_lista_vacia'), textAlign: TextAlign.center),
              ),
            );
          }
          return ListView.separated(
            padding: rellenoInferiorSeguro(context, EdgeInsets.zero),
            itemCount: sesiones.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, indice) {
              final fila = sesiones[indice];
              final sesion = fila.sesion;
              final esRecorrido = sesion.tipo == TipoSesionSonora.recorrido;
              final duracion = sesion.fin?.difference(sesion.inicio);
              return ListTile(
                leading: Icon(esRecorrido ? Icons.directions_walk : Icons.wb_twilight),
                title: Text(
                    '${SoleraL10n.t(esRecorrido ? 'nat.ses_modo_recorrido' : 'nat.ses_modo_coro')} · ${formatoFecha.format(sesion.inicio)}'),
                subtitle: Text(SoleraL10n.tf('nat.ses_fila_lista', {
                  'especies': fila.especies,
                  'detecciones': fila.detecciones,
                  'minutos': duracion == null ? '—' : duracion.inMinutes,
                })),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => PantallaResumenSesionSonora(sesionId: sesion.id!),
                  ));
                  _recargar();
                },
              );
            },
          );
        },
      ),
    );
  }
}
