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
        subject:
            'Card certificada — ${cert.nombreAutoridad}',
        text: 'Card revisada y certificada por la autoridad. '
            'Importa este archivo en tu app Fósiles para ver el sello.',
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _firmando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error firmando: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.parseada.hallazgo;
    return Scaffold(
      appBar: AppBar(title: const Text('Certificar hallazgo')),
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
                  'Descubridor: ${widget.parseada.nombreRemitente}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (widget.parseada.emailRemitente != null &&
                    widget.parseada.emailRemitente!.isNotEmpty)
                  Text(widget.parseada.emailRemitente!,
                      style: const TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 6),
                Text(
                  'Coords: ${h.latitud.toStringAsFixed(widget.parseada.coordenadasDifuminadas ? 2 : 5)}, '
                  '${h.longitud.toStringAsFixed(widget.parseada.coordenadasDifuminadas ? 2 : 5)}'
                  '${widget.parseada.coordenadasDifuminadas ? "  (difuminadas)" : ""}',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  'Fotos: ${widget.parseada.fotosJpeg.length}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Revisa o corrige los campos. Lo que dejes en cada caja entrará '
            'en la certificación firmada. Si un campo ya está correcto, '
            'déjalo como está.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _especie,
            decoration: const InputDecoration(
              labelText: 'Especie / determinación',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _edad,
            decoration: const InputDecoration(
              labelText: 'Edad / época geológica',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _formacion,
            decoration: const InputDecoration(
              labelText: 'Formación geológica',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _comentarios,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Comentarios del experto',
              hintText: 'Ej: pieza relevante para colección regional, '
                  'recomiendo enviar a museo X para depósito',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.verified),
            label: const Text('Firmar y devolver al descubridor'),
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
