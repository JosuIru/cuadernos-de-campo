import 'package:flutter/material.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../datos/claves_gbif.dart';
import '../datos/datos_guia.dart';
import '../fuentes_abiertas/presencia_gbif.dart';
import '../fuentes_abiertas/servicio_fuentes_abiertas.dart';
import '../fuentes_abiertas/ubicacion_aproximada.dart';
import '../servicios/zona_para_consultas.dart';

/// Especies de la guía con registros en GBIF cerca de la persona (zona
/// redondeada a 0,1°, radio de 20 km). Las protegidas no se piden ni se
/// listan: a esta escala se sabría dónde están.
class PantallaEspeciesCerca extends StatefulWidget {
  const PantallaEspeciesCerca({super.key});

  @override
  State<PantallaEspeciesCerca> createState() => _PantallaEspeciesCercaState();
}

class _PantallaEspeciesCercaState extends State<PantallaEspeciesCerca> {
  Future<EspeciesCercaGbif?>? _futuroEspecies;
  bool _pidiendoZona = false;

  /// Especies de la guía que se pueden listar: con clave de GBIF y no
  /// protegidas.
  static final Map<int, EspecieGuia> _especiesPorClave = {
    for (final especie in especiesGuia)
      if (!especie.usos.contains('protegida') && clavesGbifPorEspecie[especie.id] != null)
        clavesGbifPorEspecie[especie.id]!: especie,
  };

  @override
  void initState() {
    super.initState();
    final zona = ZonaParaConsultas.zonaDeLaSesion.value;
    if (zona != null) _cargar(zona);
  }

  void _cargar(UbicacionAproximada zona) {
    _futuroEspecies = ServicioFuentesAbiertas.instancia.especiesCerca(zona, _especiesPorClave.keys);
  }

  Future<void> _usarMiZona() async {
    setState(() => _pidiendoZona = true);
    final zona = await ZonaParaConsultas.pedir(context);
    if (!mounted) return;
    setState(() {
      _pidiendoZona = false;
      if (zona != null) _cargar(zona);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final zona = ZonaParaConsultas.zonaDeLaSesion.value;
    return Scaffold(
      appBar: AppBar(title: Text(SoleraL10n.t('nat.fuen_especies_cerca'))),
      body: _futuroEspecies == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.travel_explore, size: 56),
                    const SizedBox(height: 12),
                    Text(SoleraL10n.t('nat.fuen_especies_cerca_explica'), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _pidiendoZona ? null : _usarMiZona,
                      icon: const Icon(Icons.my_location),
                      label: Text(SoleraL10n.t('nat.fuen_usar_mi_zona')),
                    ),
                  ],
                ),
              ),
            )
          : FutureBuilder<EspeciesCercaGbif?>(
              future: _futuroEspecies,
              builder: (context, instantanea) {
                if (instantanea.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final resultado = instantanea.data;
                if (resultado == null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(SoleraL10n.t('nat.fuen_sin_conexion'), textAlign: TextAlign.center),
                    ),
                  );
                }
                final filas = [
                  for (final entrada in resultado.recuentos.entries)
                    if (_especiesPorClave[entrada.key] != null) (especie: _especiesPorClave[entrada.key]!, registros: entrada.value),
                ]..sort((a, b) => b.registros.compareTo(a.registros));
                final especiesOrdenadas = [for (final fila in filas) fila.especie];
                return ListView(
                  padding: rellenoInferiorSeguro(context, const EdgeInsets.all(12)),
                  children: [
                    Text(
                      SoleraL10n.tf('nat.fuen_especies_cerca_resumen', {
                        'numero': '${filas.length}',
                        'km': '${zona?.radioKm ?? UbicacionAproximada.radioNormalKm}',
                      }),
                      style: tema.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(SoleraL10n.t('nat.fuen_especies_cerca_protegidas'), style: tema.textTheme.bodySmall),
                    const SizedBox(height: 8),
                    for (var indice = 0; indice < filas.length; indice++)
                      Card(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        child: ListTile(
                          leading: Icon(
                            categoriaPorId(filas[indice].especie.categoriaId)?.icono ?? Icons.eco,
                            color: categoriaPorId(filas[indice].especie.categoriaId)?.color,
                          ),
                          title: Text(filas[indice].especie.nombreComun),
                          subtitle: Text(filas[indice].especie.nombreCientifico,
                              style: const TextStyle(fontStyle: FontStyle.italic)),
                          trailing: Text(
                            SoleraL10n.tf('nat.fuen_n_registros', {'numero': '${filas[indice].registros}'}),
                            style: tema.textTheme.bodySmall,
                          ),
                          onTap: () => abrirDetalleEspecieGuia(
                            context,
                            filas[indice].especie.id,
                            lista: especiesOrdenadas,
                            indiceInicial: indice,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(SoleraL10n.t('nat.fuen_nota_registros'), style: tema.textTheme.bodySmall),
                    InkWell(
                      onTap: () => launchUrl(Uri.parse('https://www.gbif.org/occurrence/search'),
                          mode: LaunchMode.externalApplication),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          '${SoleraL10n.t('nat.fuen_fuente')}: ${textoCitaGbif(resultado.consultadoEn)}',
                          style: tema.textTheme.bodySmall?.copyWith(
                            color: tema.colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
