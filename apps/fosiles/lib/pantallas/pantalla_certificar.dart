import 'package:flutter/material.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import 'package:share_plus/share_plus.dart';

import '../servicios/autoridad_certificadora.dart';
import '../servicios/formato_fos_card.dart';

/// Pantalla de certificación (modo Experto). El experto recibe una card,
/// la revisa, edita 2-3 campos (especie corregida, época refinada,
/// comentarios) y firma con la clave de la autoridad activa.
///
/// Al firmar, la app genera un nuevo `.fos-card` con la certificación
/// añadida a la cadena y dispara share_plus para que el experto se lo
/// devuelva al descubridor por el mismo canal por el que llegó (WhatsApp,
/// email).
class PantallaCertificar extends StatefulWidget {
  final FosCardParseada parseada;
  const PantallaCertificar({super.key, required this.parseada});

  @override
  State<PantallaCertificar> createState() => _PantallaCertificarState();
}

class _PantallaCertificarState extends State<PantallaCertificar> {
  late final TextEditingController _especie;
  late final TextEditingController _edad;
  late final TextEditingController _formacion;
  late final TextEditingController _comentarios;
  bool _firmando = false;

  @override
  void initState() {
    super.initState();
    final h = widget.parseada.hallazgo;
    _especie = TextEditingController(text: h.especie);
    _edad = TextEditingController(text: h.edad);
    _formacion = TextEditingController(text: h.formacion);
    _comentarios = TextEditingController();
  }

  @override
  void dispose() {
    _especie.dispose();
    _edad.dispose();
    _formacion.dispose();
    _comentarios.dispose();
    super.dispose();
  }

  Future<void> _firmarYDevolver() async {
    setState(() => _firmando = true);
    try {
      final cert = await construirCertificacion(
        hallazgo: widget.parseada.hallazgo,
        tipo: TipoCertificacion.certificacion,
        camposRevisados: {
          if (_especie.text.trim().isNotEmpty) 'especie': _especie.text.trim(),
          if (_edad.text.trim().isNotEmpty) 'edad': _edad.text.trim(),
          if (_formacion.text.trim().isNotEmpty) 'formacion': _formacion.text.trim(),
          if (_comentarios.text.trim().isNotEmpty) 'comentarios': _comentarios.text.trim(),
        },
      );
      // Aplicamos también los nuevos valores a los campos del hallazgo
      // que devolvemos al descubridor — además de quedar firmados en la
      // certificación, el descubridor ve la versión actualizada de los
      // campos en su ficha.
      final hallazgoCertificado = widget.parseada.hallazgo.copyWith(
        especie: _especie.text.trim().isNotEmpty
            ? _especie.text.trim()
            : widget.parseada.hallazgo.especie,
        edad: _edad.text.trim().isNotEmpty
            ? _edad.text.trim()
            : widget.parseada.hallazgo.edad,
        formacion: _formacion.text.trim().isNotEmpty
            ? _formacion.text.trim()
            : widget.parseada.hallazgo.formacion,
        certificaciones: [...widget.parseada.hallazgo.certificaciones, cert],
      );
      final resultado = await exportarFosCard(
        hallazgo: hallazgoCertificado,
        modoCoordenadas: widget.parseada.coordenadasDifuminadas
            ? ModoCompartirCoordenadas.difuminadas
            : ModoCompartirCoordenadas.precisas,
      );
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(resultado.archivo.path, mimeType: 'application/x-fos-card')],
        subject: SoleraL10n.tf('fos.iden_card_certificada_asunto',
            {'autoridad': cert.nombreAutoridad}),
        text: SoleraL10n.t('fos.iden_card_certificada_texto'),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _firmando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${SoleraL10n.t('fos.iden_error_firmando')}: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.parseada.hallazgo;
    return Scaffold(
      appBar: AppBar(title: Text(SoleraL10n.t('fos.iden_certificar_hallazgo'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  SoleraL10n.tf('fos.iden_descubridor_valor',
                      {'nombre': widget.parseada.nombreRemitente}),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                  ),
                ),
                if (widget.parseada.emailRemitente != null &&
                    widget.parseada.emailRemitente!.isNotEmpty)
                  Text(widget.parseada.emailRemitente!,
                      style: TextStyle(
                          fontSize: 12, color: Colors.amber.shade700)),
                const SizedBox(height: 6),
                Text(
                  '${SoleraL10n.t('fos.iden_coords')}: ${h.latitud.toStringAsFixed(widget.parseada.coordenadasDifuminadas ? 2 : 5)}, '
                  '${h.longitud.toStringAsFixed(widget.parseada.coordenadasDifuminadas ? 2 : 5)}'
                  '${widget.parseada.coordenadasDifuminadas ? "  ${SoleraL10n.t('fos.iden_difuminadas')}" : ""}',
                  style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                ),
                Text(
                  '${SoleraL10n.t('fos.iden_fotos')}: ${widget.parseada.fotosJpeg.length}',
                  style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            SoleraL10n.t('fos.iden_revisa_campos'),
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _especie,
            decoration: InputDecoration(
              labelText: SoleraL10n.t('fos.iden_especie_determinacion'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _edad,
            decoration: InputDecoration(
              labelText: SoleraL10n.t('fos.iden_edad_epoca'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _formacion,
            decoration: InputDecoration(
              labelText: SoleraL10n.t('fos.iden_formacion_geologica'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _comentarios,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: SoleraL10n.t('fos.iden_comentarios_experto'),
              hintText: SoleraL10n.t('fos.iden_comentarios_ejemplo'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.verified),
            label: Text(SoleraL10n.t('fos.iden_firmar_y_devolver')),
            onPressed: _firmando ? null : _firmarYDevolver,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              backgroundColor: Colors.amber.shade800,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _firmando ? null : () => Navigator.of(context).pop(),
            child: Text(SoleraL10n.t('cancelar')),
          ),
        ],
      ),
    );
  }
}
