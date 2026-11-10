import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import 'package:path/path.dart' as path_lib;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../datos/base_datos.dart';
import '../datos/datos_guia.dart';
import '../modelos/hallazgo.dart';
import '../utiles/darwin_core.dart';
import '../utiles/primeras_veces.dart';

const String _clavePreferenciaLicencia = 'nat.dwc.licencia';
const String _clavePreferenciaRegistradoPor = 'nat.dwc.registrado_por';
const String _clavePreferenciaSensibles = 'nat.dwc.especies_sensibles';
const String _clavePreferenciaIdInstalacion = 'nat.dwc.id_instalacion';

enum _FormatoExportacion { darwinCore, inaturalist }

/// Una especie del cuaderno en la lista de sensibles.
class _EspecieExportable {
  final String clave;
  final String nombre;
  final String nombreCientifico;

  /// Protegida en la guía: siempre se generaliza.
  final bool protegida;
  final int hallazgos;

  const _EspecieExportable({
    required this.clave,
    required this.nombre,
    required this.nombreCientifico,
    required this.protegida,
    required this.hallazgos,
  });
}

/// Exportar los hallazgos en Darwin Core (o con la plantilla de iNaturalist),
/// con licencia elegida y las especies sensibles generalizadas.
class PantallaExportarDwc extends StatefulWidget {
  const PantallaExportarDwc({super.key});

  @override
  State<PantallaExportarDwc> createState() => _PantallaExportarDwcState();
}

class _PantallaExportarDwcState extends State<PantallaExportarDwc> {
  bool _cargando = true;
  bool _exportando = false;
  List<Hallazgo> _hallazgos = const [];
  List<_EspecieExportable> _especies = const [];
  Set<String> _marcadasSensibles = {};
  String _identificadorInstalacion = '';
  LicenciaExportacion _licencia = LicenciaExportacion.ccBy;
  _FormatoExportacion _formato = _FormatoExportacion.darwinCore;
  bool _conMedios = false;
  final TextEditingController _controladorNombre = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _controladorNombre.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final hallazgos = await BaseDatosNaturaleza.instancia.listarHallazgos();
    final preferencias = await SharedPreferences.getInstance();
    var identificador = preferencias.getString(_clavePreferenciaIdInstalacion);
    if (identificador == null || identificador.isEmpty) {
      identificador = nuevoIdentificadorInstalacion();
      await preferencias.setString(_clavePreferenciaIdInstalacion, identificador);
    }
    final porClave = <String, ({EspecieDeHallazgo especie, int cuenta})>{};
    for (final hallazgo in hallazgos) {
      final especie = especieDeHallazgo(hallazgo);
      if (especie == null || especie.nombreCientifico.isEmpty) continue;
      final anterior = porClave[especie.clave];
      porClave[especie.clave] = (especie: especie, cuenta: (anterior?.cuenta ?? 0) + 1);
    }
    final especies = [
      for (final MapEntry(key: clave, value: datos) in porClave.entries)
        _EspecieExportable(
          clave: clave,
          nombre: datos.especie.nombreComun.isNotEmpty ? datos.especie.nombreComun : datos.especie.nombreCientifico,
          nombreCientifico: datos.especie.nombreCientifico,
          protegida: switch (especieGuiaPorNombreCientifico(datos.especie.nombreCientifico)) {
            final guia? => esEspecieSensible(guia),
            null => false,
          },
          hallazgos: datos.cuenta,
        ),
    ]..sort((a, b) {
        if (a.protegida != b.protegida) return a.protegida ? -1 : 1;
        return a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
      });
    if (!mounted) return;
    setState(() {
      _hallazgos = hallazgos;
      _especies = especies;
      _identificadorInstalacion = identificador!;
      _marcadasSensibles = (preferencias.getStringList(_clavePreferenciaSensibles) ?? const []).toSet();
      _licencia = LicenciaExportacion.values.firstWhere(
        (licencia) => licencia.name == preferencias.getString(_clavePreferenciaLicencia),
        orElse: () => LicenciaExportacion.ccBy,
      );
      _controladorNombre.text = preferencias.getString(_clavePreferenciaRegistradoPor) ?? '';
      _cargando = false;
    });
  }

  Set<String> get _clavesSensibles => {
        for (final especie in _especies)
          if (especie.protegida || _marcadasSensibles.contains(especie.clave)) especie.clave,
      };

  OpcionesExportacionDwc _opciones() => OpcionesExportacionDwc(
        identificadorInstalacion: _identificadorInstalacion,
        licencia: _licencia,
        registradoPor: _controladorNombre.text,
        clavesSensibles: _clavesSensibles,
        conMedios: _formato == _FormatoExportacion.darwinCore && _conMedios,
        existeMedio: (ruta) => File(ruta).existsSync(),
      );

  Future<void> _guardarPreferencias() async {
    try {
      final preferencias = await SharedPreferences.getInstance();
      await preferencias.setString(_clavePreferenciaLicencia, _licencia.name);
      await preferencias.setString(_clavePreferenciaRegistradoPor, _controladorNombre.text.trim());
      await preferencias.setStringList(_clavePreferenciaSensibles, _marcadasSensibles.toList()..sort());
    } catch (_) {}
  }

  Future<void> _exportar() async {
    setState(() => _exportando = true);
    await _guardarPreferencias();
    try {
      final opciones = _opciones();
      final exportacion = _formato == _FormatoExportacion.darwinCore
          ? generarCsvDarwinCore(_hallazgos, opciones)
          : generarCsvInaturalist(_hallazgos, opciones);
      final carpeta = await getTemporaryDirectory();
      final marca = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final File fichero;
      if (_formato == _FormatoExportacion.inaturalist) {
        fichero = File(path_lib.join(carpeta.path, 'naturaleza_inaturalist_$marca.csv'));
        await fichero.writeAsString(exportacion.csv, flush: true);
      } else if (!opciones.conMedios) {
        fichero = File(path_lib.join(carpeta.path, 'naturaleza_dwc_occurrence_$marca.csv'));
        await fichero.writeAsString(exportacion.csv, flush: true);
      } else {
        final archivo = Archive();
        final bytesCsv = utf8.encode(exportacion.csv);
        archivo.addFile(ArchiveFile('occurrence.csv', bytesCsv.length, bytesCsv));
        for (final hallazgo in _hallazgos) {
          final ocurrencia = ocurrenciaDarwinCore(hallazgo, opciones);
          if (ocurrencia == null) continue;
          final sensible = ocurrencia['dataGeneralizations']!.isNotEmpty;
          for (final medio in mediosDeHallazgo(hallazgo, sensible: sensible)) {
            final origen = File(medio.rutaOrigen);
            if (!await origen.exists()) continue;
            final bytes = await origen.readAsBytes();
            archivo.addFile(ArchiveFile(medio.rutaEnZip, bytes.length, bytes));
          }
        }
        final bytesZip = ZipEncoder().encode(archivo);
        if (bytesZip == null) throw Exception(SoleraL10n.t('fos.hall_error_generar_zip'));
        fichero = File(path_lib.join(carpeta.path, 'naturaleza_dwc_$marca.zip'));
        await fichero.writeAsBytes(bytesZip, flush: true);
      }
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(fichero.path)],
        subject: SoleraL10n.t('nat.dwc_asunto'),
        text: SoleraL10n.tf('nat.dwc_resultado', {
          'n': exportacion.exportados,
          'generalizados': exportacion.generalizados,
        }),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(SoleraL10n.tf('fos.hall_error_exportando', {'error': error}))));
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    if (_cargando) {
      return Scaffold(
        appBar: AppBar(title: Text(SoleraL10n.t('nat.dwc_titulo'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final vistaPrevia = generarCsvDarwinCore(_hallazgos, _opciones());
    return Scaffold(
      appBar: AppBar(title: Text(SoleraL10n.t('nat.dwc_titulo'))),
      body: ListView(
        padding: rellenoInferiorSeguro(context, const EdgeInsets.fromLTRB(16, 12, 16, 32)),
        children: [
          Text(SoleraL10n.t('nat.dwc_intro'), style: tema.textTheme.bodyMedium),
          const SizedBox(height: 16),
          Text(SoleraL10n.t('nat.dwc_formato'), style: tema.textTheme.titleSmall),
          const SizedBox(height: 6),
          SegmentedButton<_FormatoExportacion>(
            segments: [
              ButtonSegment(value: _FormatoExportacion.darwinCore, label: Text(SoleraL10n.t('nat.dwc_formato_dwc'))),
              ButtonSegment(value: _FormatoExportacion.inaturalist, label: Text(SoleraL10n.t('nat.dwc_formato_inat'))),
            ],
            selected: {_formato},
            onSelectionChanged: (seleccion) => setState(() => _formato = seleccion.first),
          ),
          const SizedBox(height: 4),
          Text(
            _formato == _FormatoExportacion.darwinCore
                ? SoleraL10n.t('nat.dwc_formato_dwc_ayuda')
                : SoleraL10n.t('nat.dwc_formato_inat_ayuda'),
            style: tema.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Text(SoleraL10n.t('nat.dwc_licencia'), style: tema.textTheme.titleSmall),
          RadioGroup<LicenciaExportacion>(
            groupValue: _licencia,
            onChanged: (valor) => setState(() => _licencia = valor ?? _licencia),
            child: Column(
              children: [
                RadioListTile<LicenciaExportacion>(
                  contentPadding: EdgeInsets.zero,
                  value: LicenciaExportacion.cc0,
                  title: const Text('CC0 1.0'),
                  subtitle: Text(SoleraL10n.t('nat.dwc_licencia_cc0')),
                ),
                RadioListTile<LicenciaExportacion>(
                  contentPadding: EdgeInsets.zero,
                  value: LicenciaExportacion.ccBy,
                  title: const Text('CC BY 4.0'),
                  subtitle: Text(SoleraL10n.t('nat.dwc_licencia_ccby')),
                ),
              ],
            ),
          ),
          TextButton.icon(
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text(SoleraL10n.t('nat.dwc_licencias_gbif')),
            onPressed: () => launchUrl(Uri.parse('https://www.gbif.org/terms/licences'),
                mode: LaunchMode.externalApplication),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controladorNombre,
            decoration: InputDecoration(
              labelText: SoleraL10n.t('nat.dwc_registrado_por'),
              helperText: SoleraL10n.t('nat.dwc_registrado_por_ayuda'),
              helperMaxLines: 3,
              border: const OutlineInputBorder(),
            ),
          ),
          if (_formato == _FormatoExportacion.darwinCore)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(SoleraL10n.t('nat.dwc_con_medios')),
              subtitle: Text(SoleraL10n.t('nat.dwc_con_medios_ayuda')),
              value: _conMedios,
              onChanged: (valor) => setState(() => _conMedios = valor),
            ),
          const SizedBox(height: 16),
          Text(SoleraL10n.t('nat.dwc_sensibles'), style: tema.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(SoleraL10n.t('nat.dwc_sensibles_ayuda'), style: tema.textTheme.bodySmall),
          if (_especies.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(SoleraL10n.t('nat.dwc_sin_especies')),
            ),
          for (final especie in _especies)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: especie.protegida || _marcadasSensibles.contains(especie.clave),
              onChanged: especie.protegida
                  ? null
                  : (marcada) => setState(() {
                        if (marcada == true) {
                          _marcadasSensibles.add(especie.clave);
                        } else {
                          _marcadasSensibles.remove(especie.clave);
                        }
                      }),
              title: Text(especie.nombre),
              subtitle: Text(
                [
                  if (especie.nombre != especie.nombreCientifico) especie.nombreCientifico,
                  SoleraL10n.tf('nat.dwc_n_hallazgos', {'n': especie.hallazgos}),
                  if (especie.protegida) SoleraL10n.t('nat.dwc_protegida_guia'),
                ].join(' · '),
              ),
              secondary: especie.protegida ? const Icon(Icons.shield_outlined) : null,
            ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(SoleraL10n.tf('nat.dwc_resumen', {
                'n': vistaPrevia.exportados,
                'sin_nombre': vistaPrevia.sinNombreCientifico,
                'generalizados': vistaPrevia.generalizados,
              })),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            icon: _exportando
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.ios_share),
            label: Text(SoleraL10n.t('nat.dwc_exportar')),
            onPressed: _exportando || vistaPrevia.exportados == 0 ? null : _exportar,
          ),
          const SizedBox(height: 24),
          Text(SoleraL10n.t('nat.dwc_como_subir'), style: tema.textTheme.titleMedium),
          _apartadoAyuda(
            'iNaturalist',
            SoleraL10n.t('nat.dwc_subir_inat'),
            'https://www.inaturalist.org/observations/import',
          ),
          _apartadoAyuda(
            'Observation.org',
            SoleraL10n.t('nat.dwc_subir_observation'),
            'https://observation.org',
          ),
          _apartadoAyuda(
            'GBIF',
            SoleraL10n.t('nat.dwc_subir_gbif'),
            'https://www.gbif.org/become-a-publisher',
          ),
          const SizedBox(height: 8),
          Text(SoleraL10n.t('nat.dwc_decisiones'), style: tema.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _apartadoAyuda(String titulo, String texto, String enlace) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: tema.textTheme.titleSmall),
          const SizedBox(height: 2),
          Text(texto),
          TextButton.icon(
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text(enlace.replaceFirst('https://', '')),
            onPressed: () => launchUrl(Uri.parse(enlace), mode: LaunchMode.externalApplication),
          ),
        ],
      ),
    );
  }
}
