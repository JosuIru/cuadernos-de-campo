import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';

import '../datos/base_datos.dart';
import '../datos/datos_guia.dart';
import '../utiles/primeras_veces.dart';

/// Nombre visible de una primera vez: el común si lo hay; si no, el
/// científico.
String nombreVisiblePrimeraVez(PrimeraVez primeraVez) =>
    primeraVez.nombreComun.isNotEmpty ? primeraVez.nombreComun : primeraVez.nombreCientifico;

/// «10 días antes que en 2025 (2 abr)», «el mismo día que en 2025»…
String textoComparacionPrimeraVez(ComparacionPrimeraVez comparacion) {
  final fecha = DateFormat('d MMM', SoleraL10n.idioma).format(comparacion.fechaAnterior);
  final dias = comparacion.diasDiferencia.abs();
  final valores = {'dias': dias, 'anio': comparacion.anioAnterior, 'fecha': fecha};
  if (comparacion.diasDiferencia == 0) return SoleraL10n.tf('nat.cuad_pv_mismo_dia', valores);
  if (comparacion.esAdelanto) {
    return SoleraL10n.tf(dias == 1 ? 'nat.cuad_pv_un_dia_antes' : 'nat.cuad_pv_dias_antes', valores);
  }
  return SoleraL10n.tf(dias == 1 ? 'nat.cuad_pv_un_dia_despues' : 'nat.cuad_pv_dias_despues', valores);
}

/// Mensaje al guardar un hallazgo que es la primera vez del año de su
/// especie.
String textoAvisoPrimeraVez(PrimeraVezNueva nueva) {
  final aviso = SoleraL10n.tf('nat.cuad_pv_aviso', {
    'especie': nombreVisiblePrimeraVez(nueva.primeraVez),
    'anio': nueva.primeraVez.anio,
  });
  final comparacion = nueva.comparacion;
  return comparacion == null ? aviso : '$aviso · ${textoComparacionPrimeraVez(comparacion)}';
}

/// Traduce un nombre común a científico con la guía (para que «cuco» y
/// *Cuculus canorus* cuenten como la misma especie).
String? cientificoDeLaGuia(String nombreComun) => especieGuiaPorNombreComun(nombreComun)?.nombreCientifico;

enum _VistaPrimerasVeces { porAnio, porEspecie }

/// «Tu calendario de primeras veces»: la primera observación de cada especie
/// cada año, por meses, y su comparación con años anteriores.
class PantallaPrimerasVeces extends StatefulWidget {
  const PantallaPrimerasVeces({super.key});

  @override
  State<PantallaPrimerasVeces> createState() => _PantallaPrimerasVecesState();
}

class _PantallaPrimerasVecesState extends State<PantallaPrimerasVeces> {
  bool _cargando = true;
  Map<String, PrimerasVecesEspecie> _primerasVeces = const {};
  List<int> _anios = const [];
  int? _anioElegido;
  _VistaPrimerasVeces _vista = _VistaPrimerasVeces.porAnio;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final hallazgos = await BaseDatosNaturaleza.instancia.listarHallazgos();
    final primerasVeces = calcularPrimerasVeces(hallazgos, cientificoPorNombreComun: cientificoDeLaGuia);
    if (!mounted) return;
    final anios = aniosConPrimerasVeces(primerasVeces);
    setState(() {
      _primerasVeces = primerasVeces;
      _anios = anios;
      _anioElegido = anios.isEmpty ? null : anios.first;
      _cargando = false;
    });
  }

  void _abrirFicha(PrimeraVez primeraVez) {
    final especieGuia = especieGuiaPorNombreCientifico(primeraVez.nombreCientifico) ??
        especieGuiaPorNombreComun(primeraVez.nombreComun);
    if (especieGuia != null) abrirDetalleEspecieGuia(context, especieGuia.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(SoleraL10n.t('nat.cuad_pv_titulo'))),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _anios.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(SoleraL10n.t('nat.cuad_pv_vacio'), textAlign: TextAlign.center),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: SegmentedButton<_VistaPrimerasVeces>(
                        segments: [
                          ButtonSegment(
                            value: _VistaPrimerasVeces.porAnio,
                            icon: const Icon(Icons.calendar_month_outlined),
                            label: Text(SoleraL10n.t('nat.cuad_pv_vista_anio')),
                          ),
                          ButtonSegment(
                            value: _VistaPrimerasVeces.porEspecie,
                            icon: const Icon(Icons.compare_arrows),
                            label: Text(SoleraL10n.t('nat.cuad_pv_vista_especie')),
                          ),
                        ],
                        selected: {_vista},
                        onSelectionChanged: (seleccion) => setState(() => _vista = seleccion.first),
                      ),
                    ),
                    Expanded(child: _vista == _VistaPrimerasVeces.porAnio ? _vistaPorAnio() : _vistaPorEspecie()),
                  ],
                ),
    );
  }

  Widget _vistaPorAnio() {
    final anio = _anioElegido ?? _anios.first;
    final delAnio = primerasVecesDelAnio(_primerasVeces, anio);
    final nombresMeses = DateFormat.MMMM(SoleraL10n.idioma);
    final formatoDia = DateFormat('d MMM', SoleraL10n.idioma);
    final tema = Theme.of(context);
    final filas = <Widget>[
      SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            for (final otro in _anios)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text('$otro'),
                  selected: otro == anio,
                  onSelected: (_) => setState(() => _anioElegido = otro),
                ),
              ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Text(SoleraL10n.tf('nat.cuad_pv_resumen_anio', {'n': delAnio.length, 'anio': anio}),
            style: tema.textTheme.bodySmall),
      ),
    ];
    int? mesActual;
    for (final primeraVez in delAnio) {
      if (primeraVez.fecha.month != mesActual) {
        mesActual = primeraVez.fecha.month;
        final nombreMes = nombresMeses.format(primeraVez.fecha);
        filas.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(nombreMes[0].toUpperCase() + nombreMes.substring(1),
              style: tema.textTheme.titleSmall?.copyWith(color: tema.colorScheme.primary)),
        ));
      }
      final comparacion = compararConAnioAnterior(_primerasVeces[primeraVez.claveEspecie]!, anio);
      final categoria = categoriaPorId(primeraVez.categoria);
      filas.add(ListTile(
        leading: CircleAvatar(
          backgroundColor: (categoria?.color ?? Colors.grey).withValues(alpha: 0.18),
          child: Text(formatoDia.format(primeraVez.fecha).split(' ').first,
              style: TextStyle(fontWeight: FontWeight.bold, color: categoria?.color)),
        ),
        title: Text(nombreVisiblePrimeraVez(primeraVez)),
        subtitle: Text([
          if (primeraVez.nombreComun.isNotEmpty && primeraVez.nombreCientifico.isNotEmpty) primeraVez.nombreCientifico,
          comparacion == null ? SoleraL10n.t('nat.cuad_pv_sin_anterior') : textoComparacionPrimeraVez(comparacion),
        ].join('\n')),
        isThreeLine: primeraVez.nombreComun.isNotEmpty && primeraVez.nombreCientifico.isNotEmpty,
        trailing: comparacion == null || comparacion.diasDiferencia == 0
            ? null
            : Icon(comparacion.esAdelanto ? Icons.fast_rewind_outlined : Icons.fast_forward_outlined,
                semanticLabel: comparacion.esAdelanto
                    ? SoleraL10n.t('nat.cuad_pv_adelanto')
                    : SoleraL10n.t('nat.cuad_pv_retraso')),
        onTap: () => _abrirFicha(primeraVez),
      ));
    }
    return ListView(padding: rellenoInferiorSeguro(context, const EdgeInsets.only(bottom: 24)), children: filas);
  }

  Widget _vistaPorEspecie() {
    final formatoDia = DateFormat('d MMM', SoleraL10n.idioma);
    final especies = _primerasVeces.values.toList()
      ..sort((a, b) {
        final porAnios = b.porAnio.length.compareTo(a.porAnio.length);
        if (porAnios != 0) return porAnios;
        return nombreVisiblePrimeraVez(a.masReciente).toLowerCase().compareTo(nombreVisiblePrimeraVez(b.masReciente).toLowerCase());
      });
    final tema = Theme.of(context);
    return ListView(
      padding: rellenoInferiorSeguro(context, const EdgeInsets.fromLTRB(12, 8, 12, 24)),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(SoleraL10n.t('nat.cuad_pv_por_especie_ayuda'), style: tema.textTheme.bodySmall),
        ),
        for (final especie in especies)
          Card(
            child: InkWell(
              onTap: () => _abrirFicha(especie.masReciente),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nombreVisiblePrimeraVez(especie.masReciente), style: tema.textTheme.titleSmall),
                    if (especie.masReciente.nombreComun.isNotEmpty && especie.masReciente.nombreCientifico.isNotEmpty)
                      Text(especie.masReciente.nombreCientifico,
                          style: tema.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                    const SizedBox(height: 6),
                    for (final anio in (especie.porAnio.keys.toList()..sort((a, b) => b.compareTo(a))))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Text.rich(TextSpan(children: [
                          TextSpan(text: '$anio  ', style: const TextStyle(fontWeight: FontWeight.bold)),
                          TextSpan(text: formatoDia.format(especie.porAnio[anio]!.fecha)),
                          if (compararConAnioAnterior(especie, anio) case final comparacion?)
                            TextSpan(
                              text: '  ·  ${textoComparacionPrimeraVez(comparacion)}',
                              style: tema.textTheme.bodySmall,
                            ),
                        ])),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
