import 'package:flutter/material.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';

import '../sonido/clasificacion_sonido.dart';
import '../sonido/especies_vigiladas.dart';
import '../sonido/manifiesto_modelo_fauna.dart';

/// «Avísame si lo oye»: elegir las especies vigiladas entre las del
/// manifiesto del modelo. Devuelve la lista al salir con «Guardar».
class PantallaEspeciesVigiladas extends StatefulWidget {
  final List<ClaseSonido> clases;
  final List<String> iniciales;

  const PantallaEspeciesVigiladas({super.key, required this.clases, required this.iniciales});

  @override
  State<PantallaEspeciesVigiladas> createState() => _PantallaEspeciesVigiladasState();
}

class _PantallaEspeciesVigiladasState extends State<PantallaEspeciesVigiladas> {
  late final List<String> _elegidas = List.of(widget.iniciales);
  final TextEditingController _controladorBusqueda = TextEditingController();
  String _consulta = '';

  /// Resultados de búsqueda que se enseñan como mucho (el manifiesto tiene
  /// cientos de especies).
  static const int _maximoResultados = 60;

  @override
  void dispose() {
    _controladorBusqueda.dispose();
    super.dispose();
  }

  ClaseSonido? _clasePorEtiqueta(String etiqueta) =>
      widget.clases.where((clase) => clase.etiqueta == etiqueta).firstOrNull;

  void _alternar(ClaseSonido clase) {
    setState(() {
      if (_elegidas.contains(clase.etiqueta)) {
        _elegidas.remove(clase.etiqueta);
      } else if (_elegidas.length < maximoEspeciesVigiladas) {
        _elegidas.add(clase.etiqueta);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(SoleraL10n.tf('nat.vig_maximo', {'maximo': maximoEspeciesVigiladas})),
        ));
      }
    });
  }

  Widget _filaClase(ClaseSonido clase) {
    final elegida = _elegidas.contains(clase.etiqueta);
    return CheckboxListTile(
      value: elegida,
      onChanged: (_) => _alternar(clase),
      title: Text(nombreVisiblePara(clase, SoleraL10n.idioma)),
      subtitle: Text(clase.etiqueta.replaceAll('_', ' '), style: const TextStyle(fontStyle: FontStyle.italic)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final resultados = _consulta.trim().isEmpty
        ? const <ClaseSonido>[]
        : clasesVigilables(widget.clases, _consulta, idioma: SoleraL10n.idioma).take(_maximoResultados).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(SoleraL10n.t('nat.vig_titulo')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(List<String>.of(_elegidas)),
            child: Text(SoleraL10n.t('guardar')),
          ),
        ],
      ),
      body: ListView(
        padding: rellenoInferiorSeguro(context, const EdgeInsets.symmetric(vertical: 8)),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              SoleraL10n.tf('nat.vig_explicacion', {
                'minutos': intervaloMinimoEntreAvisos.inMinutes,
              }),
              style: tema.bodySmall,
            ),
          ),
          if (_elegidas.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(SoleraL10n.tf('nat.vig_elegidas', {'n': _elegidas.length}), style: tema.titleSmall),
            ),
            for (final etiqueta in _elegidas)
              if (_clasePorEtiqueta(etiqueta) case final clase?)
                _filaClase(clase)
              else
                ListTile(
                  title: Text(etiqueta.replaceAll('_', ' ')),
                  subtitle: Text(SoleraL10n.t('nat.vig_no_en_modelo')),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: SoleraL10n.t('borrar'),
                    onPressed: () => setState(() => _elegidas.remove(etiqueta)),
                  ),
                ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _controladorBusqueda,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                labelText: SoleraL10n.t('nat.vig_buscar'),
                border: const OutlineInputBorder(),
              ),
              onChanged: (texto) => setState(() => _consulta = texto),
            ),
          ),
          if (_consulta.trim().isNotEmpty && resultados.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(SoleraL10n.t('nat.vig_sin_resultados'), style: tema.bodySmall),
            ),
          for (final clase in resultados)
            if (!_elegidas.contains(clase.etiqueta)) _filaClase(clase),
        ],
      ),
    );
  }
}
