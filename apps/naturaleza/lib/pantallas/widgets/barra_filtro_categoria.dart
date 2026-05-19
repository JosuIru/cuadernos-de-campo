import 'package:flutter/material.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';

import '../../datos/datos_guia.dart';

/// Barra de filtro horizontal de categorías de hallazgo (animales,
/// insectos, plantas…) presentada de forma consistente entre la lista
/// y el mapa.
///
/// Antes había dos implementaciones distintas (lista usaba `FilterChip`
/// sin Card en una banda apretada, mapa usaba `ChoiceChip` dentro de
/// Card flotante), lo que daba sensación de pantallas "distintas". Este
/// widget unifica el patrón visual.
class BarraFiltroCategoria extends StatelessWidget {
  /// Id de categoría activo. `'todos'` (constante reservada) muestra
  /// todas las categorías.
  final String filtroActual;

  /// Notifica el cambio de filtro. Se invoca con el id de categoría o
  /// con `'todos'` cuando se pulsa el chip "todos".
  final ValueChanged<String> onCambio;

  /// Si `true` envuelve los chips en una `Card` (estilo barra flotante
  /// del mapa). En `false` queda como banda plana — útil dentro de
  /// columnas con padding propio (lista). Por defecto `true`.
  final bool conTarjeta;

  const BarraFiltroCategoria({
    super.key,
    required this.filtroActual,
    required this.onCambio,
    this.conTarjeta = true,
  });

  @override
  Widget build(BuildContext context) {
    final fila = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          ChoiceChip(
            label: Text(SoleraL10n.t('todos')),
            avatar: const Icon(Icons.apps, size: 18),
            selected: filtroActual == 'todos',
            onSelected: (_) => onCambio('todos'),
          ),
          for (final categoria in categoriasGuia)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: ChoiceChip(
                avatar: Icon(categoria.icono, size: 18),
                label: Text(categoria.nombre),
                selected: filtroActual == categoria.id,
                onSelected: (_) => onCambio(categoria.id),
              ),
            ),
        ],
      ),
    );
    if (!conTarjeta) return fila;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: fila,
    );
  }
}
