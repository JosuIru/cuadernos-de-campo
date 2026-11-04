import 'package:flutter/material.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';

import '../datos/base_datos.dart';
import '../datos/datos_guia.dart';
import '../modelos/hallazgo.dart';
import '../utiles/agregados_naturaleza.dart';

/// "Tasa de acierto": agregado de identificaciones validadas por el
/// propio usuario tras revisar fotos/bibliografía. Cierra el círculo
/// de hipótesis → validación → aprendizaje.
class PantallaTasaAcierto extends StatefulWidget {
  const PantallaTasaAcierto({super.key});

  @override
  State<PantallaTasaAcierto> createState() => _PantallaTasaAciertoState();
}

class _PantallaTasaAciertoState extends State<PantallaTasaAcierto> {
  TasaAcierto? _tasa;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final hallazgos = await BaseDatosNaturaleza.instancia.listarHallazgos();
    if (!mounted) return;
    setState(() {
      _tasa = calcularTasaAcierto(hallazgos);
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(SoleraL10n.t('nat.hall_tasa_acierto'))),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : (_tasa == null || !_tasa!.tieneDatos)
              ? _vistaVacia(_tasa?.sinRevisar ?? 0)
              : _vistaConDatos(_tasa!),
    );
  }

  Widget _vistaVacia(int sinRevisar) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.fact_check_outlined,
                size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              SoleraL10n.t('nat.hall_sin_validaciones'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              sinRevisar > 0
                  ? (sinRevisar == 1
                      ? SoleraL10n.t('nat.hall_un_sin_revisar')
                      : SoleraL10n.tf('nat.hall_n_sin_revisar', {'n': sinRevisar}))
                  : SoleraL10n.t('nat.hall_explicacion_tasa_vacia'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      );

  Widget _vistaConDatos(TasaAcierto tasa) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _bloqueGlobal(tasa),
        const SizedBox(height: 16),
        if (tasa.porCategoria.isNotEmpty)
          _bloqueCategoria(tasa.porCategoria),
        if (tasa.porCategoria.isNotEmpty) const SizedBox(height: 16),
        if (tasa.porConfianza.isNotEmpty) _bloqueConfianza(tasa.porConfianza),
      ],
    );
  }

  Widget _bloqueGlobal(TasaAcierto tasa) {
    final porcentaje = tasa.global.porcentajeAcierto!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '${(porcentaje * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: _colorPorcentaje(porcentaje),
              ),
            ),
            Text(
              SoleraL10n.t('nat.hall_de_acierto_global'),
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _miniTotal(
                  '${tasa.global.confirmados}',
                  SoleraL10n.t('nat.hall_confirmadas'),
                  Colors.green.shade700,
                ),
                _miniTotal(
                  '${tasa.global.corregidos}',
                  SoleraL10n.t('nat.hall_corregidas'),
                  Colors.deepOrange,
                ),
                _miniTotal(
                  '${tasa.sinRevisar}',
                  SoleraL10n.t('nat.hall_sin_revisar'),
                  Colors.grey,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniTotal(String numero, String etiqueta, Color color) => Column(
        children: [
          Text(numero,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(etiqueta,
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      );

  Widget _bloqueCategoria(Map<String, DesgloseTasa> porCategoria) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(SoleraL10n.t('nat.hall_por_categoria'),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            ...porCategoria.entries.map(
              (entrada) => _filaDesglose(
                etiqueta: _etiquetaCategoria(entrada.key),
                desglose: entrada.value,
                colorEtiqueta:
                    categoriaPorId(entrada.key)?.color ?? Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bloqueConfianza(Map<String, DesgloseTasa> porConfianza) {
    // Orden semántico: segura → probable → tentativa.
    const orden = [
      ConfianzaIdentificacion.segura,
      ConfianzaIdentificacion.probable,
      ConfianzaIdentificacion.tentativa,
    ];
    final etiquetas = {
      ConfianzaIdentificacion.segura: SoleraL10n.t('nat.hall_cuando_dijiste_segura'),
      ConfianzaIdentificacion.probable: SoleraL10n.t('nat.hall_cuando_dijiste_probable'),
      ConfianzaIdentificacion.tentativa: SoleraL10n.t('nat.hall_cuando_dijiste_tentativa'),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(SoleraL10n.t('nat.hall_calibracion_por_confianza'),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Text(
              SoleraL10n.t('nat.hall_pregunta_calibracion'),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            ...orden.where((c) => porConfianza.containsKey(c)).map(
                  (clave) => _filaDesglose(
                    etiqueta: etiquetas[clave] ?? clave,
                    desglose: porConfianza[clave]!,
                    colorEtiqueta: Colors.blueGrey,
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _filaDesglose({
    required String etiqueta,
    required DesgloseTasa desglose,
    required Color colorEtiqueta,
  }) {
    final porcentaje = desglose.porcentajeAcierto ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 170,
            child: Text(
              etiqueta,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: porcentaje.clamp(0.0, 1.0),
                  child: Container(
                    height: 16,
                    decoration: BoxDecoration(
                      color: _colorPorcentaje(porcentaje),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 70,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                '${(porcentaje * 100).toStringAsFixed(0)}% · ${desglose.totalRevisado}',
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _colorPorcentaje(double p) {
    if (p >= 0.8) return Colors.green.shade700;
    if (p >= 0.6) return Colors.lime.shade800;
    if (p >= 0.4) return Colors.orange.shade700;
    return Colors.red.shade700;
  }

  String _etiquetaCategoria(String idCategoria) {
    return categoriaPorId(idCategoria)?.nombre ?? idCategoria;
  }
}
