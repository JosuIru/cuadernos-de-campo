import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import '../servicios/certificado_hallazgo.dart';

class PantallaVerificarCertificado extends StatefulWidget {
  const PantallaVerificarCertificado({super.key});

  @override
  State<PantallaVerificarCertificado> createState() => _PantallaVerificarCertificadoState();
}

class _PantallaVerificarCertificadoState extends State<PantallaVerificarCertificado> {
  Map<String, dynamic>? _certificado;
  bool? _valido;
  String? _error;

  Future<void> _seleccionarYVerificar() async {
    final resultado = await FilePicker.platform.pickFiles(type: FileType.any);
    if (resultado == null || resultado.files.isEmpty) return;
    final ruta = resultado.files.first.path;
    if (ruta == null) return;
    setState(() {
      _certificado = null;
      _valido = null;
      _error = null;
    });
    try {
      final contenido = await File(ruta).readAsString();
      final json = jsonDecode(contenido) as Map<String, dynamic>;
      if (json['tipo'] != 'certificado_hallazgo_fosiles') {
        setState(() => _error = SoleraL10n.t('fos.iden_no_es_certificado'));
        return;
      }
      final esValido = verificarCertificado(json);
      setState(() {
        _certificado = json;
        _valido = esValido;
      });
    } catch (e) {
      setState(() => _error = '${SoleraL10n.t('fos.iden_error_leer_fichero')}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(SoleraL10n.t('fos.iden_verificar_certificado'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            SoleraL10n.t('fos.iden_verificar_ayuda'),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _seleccionarYVerificar,
            icon: const Icon(Icons.file_open),
            label: Text(SoleraL10n.t('fos.iden_seleccionar_certificado')),
          ),
          const SizedBox(height: 24),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red))),
              ]),
            ),
          if (_certificado != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _valido! ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _valido! ? Colors.green.shade300 : Colors.red.shade300,
                  width: 2,
                ),
              ),
              child: Column(children: [
                Icon(
                  _valido! ? Icons.verified : Icons.gpp_bad,
                  size: 48,
                  color: _valido! ? Colors.green : Colors.red,
                ),
                const SizedBox(height: 8),
                Text(
                  _valido!
                      ? SoleraL10n.t('fos.iden_certificado_verificado')
                      : SoleraL10n.t('fos.iden_certificado_no_valido'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _valido! ? Colors.green.shade800 : Colors.red.shade800,
                  ),
                ),
                if (!_valido!)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      SoleraL10n.t('fos.iden_hash_no_coincide'),
                      style: TextStyle(
                          fontSize: 13, color: Colors.red.shade900),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 16),
            _seccion('Hash', (_certificado!['hash'] as String?) ?? '—'),
            const SizedBox(height: 12),
            _seccion(SoleraL10n.t('fos.iden_especie'), _certificado!['hallazgo']?['especie']?.toString() ?? '—'),
            _seccion(SoleraL10n.t('fos.iden_edad'), _certificado!['hallazgo']?['edad']?.toString() ?? '—'),
            _seccion(SoleraL10n.t('fos.iden_formacion'), _certificado!['hallazgo']?['formacion']?.toString() ?? '—'),
            _seccion(SoleraL10n.t('fos.iden_fecha_descubrimiento'),
                _certificado!['hallazgo']?['fecha_descubrimiento_iso']?.toString() ?? '—'),
            _seccion(SoleraL10n.t('fos.iden_descubridor'), _certificado!['descubridor']?['nombre']?.toString() ?? '—'),
            if (_certificado!['descubridor']?['email'] != null)
              _seccion(SoleraL10n.t('fos.iden_email_descubridor'), _certificado!['descubridor']['email'].toString()),
            if (_certificado!['descubridor']?['organizacion'] != null)
              _seccion(SoleraL10n.t('fos.iden_organizacion'), _certificado!['descubridor']['organizacion'].toString()),
            _seccion(SoleraL10n.t('fos.iden_fecha_certificacion'),
                _certificado!['fecha_certificacion_iso']?.toString() ?? '—'),
          ],
        ],
      ),
    );
  }

  Widget _seccion(String clave, String valor) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(clave, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 2),
          Text(valor, style: const TextStyle(fontSize: 14)),
        ],
      );
}
