import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import 'package:path/path.dart' as path_lib;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../datos/base_datos.dart';
import '../servicios/autoridad_certificadora.dart';
import '../servicios/formato_fos_card.dart';
import 'pantalla_certificar.dart';

/// Pantalla de import de un `.fos-card` compartido.
///
/// Se invoca cuando:
///   - Android lanza un intent VIEW/SEND con un .fos-card (WhatsApp/email/Drive).
///   - El usuario abre manualmente un .fos-card desde un file picker.
///
/// La pantalla parsea el archivo, verifica la firma Ed25519, muestra al
/// usuario:
///   - Quién lo envía (nombre + email + organización declarados)
///   - Si la firma del remitente cuadra (✓ verde / ✗ rojo)
///   - Si las coords son difuminadas o precisas
///   - Datos del hallazgo (especie, edad, formación, etc.)
///   - Número de fotos
///
/// y dos botones: **Importar** (persiste en BD + carpeta de fotos) o
/// **Cancelar**.
class PantallaImportarFosCard extends StatefulWidget {
  final File ficheroFosCard;
  const PantallaImportarFosCard({super.key, required this.ficheroFosCard});

  @override
  State<PantallaImportarFosCard> createState() => _PantallaImportarFosCardState();
}

class _PantallaImportarFosCardState extends State<PantallaImportarFosCard> {
  FosCardParseada? _parseada;
  String? _errorParseo;
  bool _importando = false;
  bool _yaImportado = false;
  bool _modoExpertoActivo = false;

  @override
  void initState() {
    super.initState();
    _parsear();
    _comprobarModoExperto();
  }

  Future<void> _comprobarModoExperto() async {
    final activo = await AutoridadCertificadora.instancia.estaActiva();
    if (!mounted) return;
    setState(() => _modoExpertoActivo = activo);
  }

  Future<void> _parsear() async {
    try {
      final p = await parsearFosCard(widget.ficheroFosCard);
      if (!mounted) return;
      setState(() => _parseada = p);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorParseo = e is FormatException ? e.message : e.toString());
    }
  }

  Future<void> _importar() async {
    final p = _parseada;
    if (p == null) return;
    setState(() => _importando = true);
    try {
      // Persistir las fotos a la carpeta de la app con nombres únicos.
      final dirDocs = await getApplicationDocumentsDirectory();
      final dirFotos = Directory(path_lib.join(dirDocs.path, 'fotos'));
      if (!await dirFotos.exists()) await dirFotos.create(recursive: true);
      final rutas = <String>[];
      final stamp = DateTime.now().millisecondsSinceEpoch;
      for (var i = 0; i < p.fotosJpeg.length; i++) {
        final nombre = 'compartida_${stamp}_$i.jpg';
        final destino = File(path_lib.join(dirFotos.path, nombre));
        await destino.writeAsBytes(p.fotosJpeg[i]);
        rutas.add(destino.path);
      }
      final hallazgoConRutas = p.hallazgo.copyWith(rutasFotos: rutas);
      await BaseDatosFosiles.instancia.guardarHallazgo(hallazgoConRutas);
      if (!mounted) return;
      setState(() => _yaImportado = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _importando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${SoleraL10n.t('fos.iden_error_importando')}: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(SoleraL10n.t('fos.iden_importar_card_recibida'))),
      body: _construirCuerpo(),
    );
  }

  Widget _construirCuerpo() {
    if (_errorParseo != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                SoleraL10n.t('fos.iden_no_se_pudo_abrir'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(_errorParseo!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(SoleraL10n.t('cancelar')),
              ),
            ],
          ),
        ),
      );
    }
    final p = _parseada;
    if (p == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_yaImportado) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline, size: 48, color: Colors.green),
              const SizedBox(height: 12),
              Text(
                SoleraL10n.t('fos.iden_card_importada'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                SoleraL10n.t('fos.iden_aparece_en_compartidas'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(SoleraL10n.t('fos.iden_hecho')),
              ),
            ],
          ),
        ),
      );
    }
    final h = p.hallazgo;
    return ListView(
      padding: rellenoInferiorSeguro(context, const EdgeInsets.all(16)),
      children: [
        _bloqueFirma(p),
        const SizedBox(height: 16),
        _bloqueRemitente(p),
        const SizedBox(height: 16),
        _bloqueHallazgo(h, p),
        const SizedBox(height: 24),
        ..._botonesAccion(p),
        const SizedBox(height: 24),
      ],
    );
  }

  List<Widget> _botonesAccion(FosCardParseada p) {
    // Modo Experto activo: revisar para certificar en lugar de importar
    // a la colección propia.
    if (_modoExpertoActivo) {
      return [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            border: Border.all(color: Colors.amber.shade400),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified_user, color: Colors.amber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  SoleraL10n.t('fos.iden_modo_experto_aviso'),
                  style: TextStyle(fontSize: 13, color: Colors.amber.shade900),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: const Icon(Icons.verified),
          label: Text(SoleraL10n.t('fos.iden_certificar')),
          onPressed: _importando ? null : () => _abrirCertificacion(p),
          style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.mail_outline),
          label: Text(SoleraL10n.t('fos.iden_acusar_recibo')),
          onPressed: _importando ? null : () => _registrarAcuseODescarte(p, esAcuse: true),
          style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.cancel_outlined, color: Colors.red),
          label: Text(
            SoleraL10n.t('fos.iden_descartar'),
            style: const TextStyle(color: Colors.red),
          ),
          onPressed: _importando ? null : () => _registrarAcuseODescarte(p, esAcuse: false),
          style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _importando ? null : () => Navigator.of(context).pop(),
          child: Text(SoleraL10n.t('cancelar')),
        ),
      ];
    }
    // Modo descubridor normal: importar a la colección propia.
    return [
      FilledButton.icon(
        icon: const Icon(Icons.download_done),
        label: Text(SoleraL10n.t('fos.iden_importar_a_mi_coleccion')),
        onPressed: _importando ? null : _importar,
        style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
      ),
      const SizedBox(height: 8),
      OutlinedButton(
        onPressed: _importando ? null : () => Navigator.of(context).pop(),
        style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
        child: Text(SoleraL10n.t('cancelar')),
      ),
    ];
  }

  Future<void> _abrirCertificacion(FosCardParseada p) async {
    final hecho = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PantallaCertificar(parseada: p),
      ),
    );
    if (hecho == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _registrarAcuseODescarte(FosCardParseada p, {required bool esAcuse}) async {
    setState(() => _importando = true);
    try {
      final cert = await construirCertificacion(
        hallazgo: p.hallazgo,
        tipo: esAcuse ? TipoCertificacion.acuse : TipoCertificacion.descarte,
        camposRevisados: {
          'mensaje': esAcuse
              ? 'Card recibida, en cola para revisión.'
              : 'No es de interés para esta autoridad.',
        },
      );
      final hallazgoConCert = p.hallazgo.copyWith(
        certificaciones: [...p.hallazgo.certificaciones, cert],
      );
      // Exportar de vuelta directamente — para acuse/descarte no
      // necesitamos cola intermedia: el experto firma y manda al
      // momento.
      final resultado = await exportarFosCard(
        hallazgo: hallazgoConCert,
        modoCoordenadas: p.coordenadasDifuminadas
            ? ModoCompartirCoordenadas.difuminadas
            : ModoCompartirCoordenadas.precisas,
      );
      if (!mounted) return;
      final etiqueta = esAcuse
          ? SoleraL10n.t('fos.iden_acuse_de_recibo')
          : SoleraL10n.t('fos.iden_descarte');
      await _compartir(resultado.archivo.path, etiqueta);
      if (!mounted) return;
      setState(() => _yaImportado = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _importando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${SoleraL10n.t('fos.iden_error_firmando')}: $e')),
      );
    }
  }

  Future<void> _compartir(String ruta, String etiqueta) async {
    await Share.shareXFiles(
      [XFile(ruta, mimeType: 'application/x-fos-card')],
      subject: '$etiqueta — Fósiles',
      text: SoleraL10n.t('fos.iden_devolucion_firmada'),
    );
  }

  Widget _bloqueFirma(FosCardParseada p) {
    final color = p.firmaValida ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.shade50,
        border: Border.all(color: color.shade400),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(p.firmaValida ? Icons.verified : Icons.error_outline, color: color.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              p.firmaValida
                  ? SoleraL10n.t('fos.iden_firma_valida')
                  : SoleraL10n.t('fos.iden_firma_invalida'),
              style: TextStyle(color: color.shade900, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bloqueRemitente(FosCardParseada p) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(SoleraL10n.t('fos.iden_remitente'),
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 6),
          _fila(SoleraL10n.t('fos.iden_nombre_declarado'),
              p.nombreRemitente.isEmpty ? SoleraL10n.t('fos.iden_sin_rellenar') : p.nombreRemitente),
          if (p.emailRemitente != null && p.emailRemitente!.isNotEmpty)
            _fila(SoleraL10n.t('fos.iden_email'), p.emailRemitente!),
          if (p.organizacionRemitente != null && p.organizacionRemitente!.isNotEmpty)
            _fila(SoleraL10n.t('fos.iden_organizacion'), p.organizacionRemitente!),
          _fila(
            SoleraL10n.t('fos.iden_huella'),
            // Mostramos primeros 16 chars de la clave pública base64.
            // Hash visual sería más portable; para v1 con esto basta para
            // que dos cards del mismo remitente se reconozcan a ojo.
            '${p.clavePublicaRemitente.substring(0, 16)}…',
          ),
        ],
      ),
    );
  }

  Widget _bloqueHallazgo(h, FosCardParseada p) {
    final localeFecha = SoleraL10n.idioma == 'es' ? 'es_ES' : SoleraL10n.idioma;
    final fecha = DateFormat('dd MMM yyyy HH:mm',
            DateFormat.localeExists(localeFecha) ? localeFecha : 'es_ES')
        .format(DateTime.fromMillisecondsSinceEpoch(h.fechaMs));
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(SoleraL10n.t('fos.iden_hallazgo'),
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
          const SizedBox(height: 6),
          _fila(SoleraL10n.t('fos.iden_especie'), h.especie.isEmpty ? '—' : h.especie),
          _fila(SoleraL10n.t('fos.iden_edad'), h.edad.isEmpty ? '—' : h.edad),
          _fila(SoleraL10n.t('fos.iden_formacion'), h.formacion.isEmpty ? '—' : h.formacion),
          _fila(
              SoleraL10n.t('fos.iden_tipo'),
              h.tipo == 'mineral'
                  ? SoleraL10n.t('fos.iden_tipo_mineral')
                  : h.tipo == 'fosil'
                      ? SoleraL10n.t('fos.iden_tipo_fosil')
                      : h.tipo),
          _fila(SoleraL10n.t('fos.iden_fecha'), fecha),
          _fila(
            SoleraL10n.t('fos.iden_coordenadas'),
            '${h.latitud.toStringAsFixed(p.coordenadasDifuminadas ? 2 : 5)}, '
                '${h.longitud.toStringAsFixed(p.coordenadasDifuminadas ? 2 : 5)}'
                '${p.coordenadasDifuminadas ? "  ${SoleraL10n.t('fos.iden_difuminadas')}" : ""}',
          ),
          if (h.strikeGrados != null && h.dipGrados != null)
            _fila(SoleraL10n.t('fos.iden_estrato'),
                '${h.strikeGrados!.toStringAsFixed(0)}° / ${h.dipGrados!.toStringAsFixed(0)}°'),
          if (h.notas.isNotEmpty) _fila(SoleraL10n.t('fos.iden_notas'), h.notas),
          _fila(SoleraL10n.t('fos.iden_fotos'), '${p.fotosJpeg.length}'),
        ],
      ),
    );
  }

  Widget _fila(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(etiqueta,
                style:
                    const TextStyle(fontSize: 13, color: Colors.black54)),
          ),
          Expanded(
              child: Text(valor,
                  style:
                      const TextStyle(fontSize: 13, color: Colors.black87))),
        ],
      ),
    );
  }
}
