import 'package:flutter/material.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import '../modelos/hallazgo.dart';
import 'cliente_comunidad.dart';

/// Diálogo modal que pide los datos mínimos para enviar un hallazgo a la
/// comunidad: email (opcional pero recomendado), nombre opcional y
/// consentimiento explícito. Confirma muy claramente al usuario lo que
/// SÍ se envía y lo que NO (coords, identidad criptográfica).
///
/// Solo se llama desde la ficha del hallazgo cuando
/// `kFeatureComunidadHabilitada` está a true. La pantalla que lo abre se
/// encarga de la comprobación.
class DialogoCompartirComunidad extends StatefulWidget {
  final Hallazgo hallazgo;
  const DialogoCompartirComunidad({super.key, required this.hallazgo});

  @override
  State<DialogoCompartirComunidad> createState() =>
      _DialogoCompartirComunidadState();
}

class _DialogoCompartirComunidadState extends State<DialogoCompartirComunidad> {
  final _controladorEmail = TextEditingController();
  final _controladorNombre = TextEditingController();
  bool _consentimiento = false;
  bool _enviando = false;
  String? _errorEmail;

  static final RegExp _patronEmail =
      RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

  bool get _emailValido =>
      _controladorEmail.text.trim().isEmpty
          ? false
          : _patronEmail.hasMatch(_controladorEmail.text.trim());

  bool get _puedeEnviar =>
      !_enviando && _consentimiento && _emailValido;

  @override
  void dispose() {
    _controladorEmail.dispose();
    _controladorNombre.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_puedeEnviar) return;
    final hallazgo = widget.hallazgo;
    if (hallazgo.rutasFotos.isEmpty) {
      _mostrarSnack(SoleraL10n.t('fos.iden_com_sin_fotos'));
      return;
    }
    setState(() => _enviando = true);
    try {
      final resultado = await ClienteComunidad().subirAportacion(
        rutaFoto: hallazgo.rutasFotos.first,
        tipo: hallazgo.tipo,
        especie: hallazgo.especie,
        edad: hallazgo.edad,
        formacion: hallazgo.formacion,
        notas: hallazgo.notas,
        email: _controladorEmail.text.trim(),
        nombre: _controladorNombre.text.trim(),
        consentimientoExplicito: true,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      _mostrarSnack(SoleraL10n.tf(
          'fos.iden_com_enviada', {'id': resultado.idAportacion}));
    } on ExcepcionComunidad catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      _mostrarSnack(e.mensaje);
    } catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      _mostrarSnack('${SoleraL10n.t('fos.iden_com_error_inesperado')}: $e');
    }
  }

  void _mostrarSnack(String texto) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) {
    final hallazgo = widget.hallazgo;
    return AlertDialog(
      title: Text(SoleraL10n.t('fos.iden_com_compartir_titulo')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              SoleraL10n.t('fos.iden_com_intro'),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            _bloqueInfo(
              titulo: SoleraL10n.t('fos.iden_com_se_envia'),
              elementos: [
                SoleraL10n.t('fos.iden_com_foto_principal'),
                SoleraL10n.tf('fos.iden_com_tipo_valor', {
                  'tipo': hallazgo.tipo == 'mineral'
                      ? SoleraL10n.t('fos.iden_tipo_mineral')
                      : hallazgo.tipo == 'fosil'
                          ? SoleraL10n.t('fos.iden_tipo_fosil')
                          : hallazgo.tipo,
                }),
                SoleraL10n.tf('fos.iden_com_especie_declarada',
                    {'valor': hallazgo.especie.isEmpty ? '—' : hallazgo.especie}),
                SoleraL10n.tf('fos.iden_com_edad_declarada',
                    {'valor': hallazgo.edad.isEmpty ? '—' : hallazgo.edad}),
                SoleraL10n.tf('fos.iden_com_formacion_declarada',
                    {'valor': hallazgo.formacion.isEmpty ? '—' : hallazgo.formacion}),
                if (hallazgo.notas.isNotEmpty) SoleraL10n.t('fos.iden_com_tus_notas'),
              ],
              colorFondo: Colors.green.shade50,
              colorTexto: Colors.green.shade900,
            ),
            const SizedBox(height: 8),
            _bloqueInfo(
              titulo: SoleraL10n.t('fos.iden_com_no_se_envia'),
              elementos: [
                SoleraL10n.t('fos.iden_coordenadas'),
                SoleraL10n.t('fos.iden_com_nombre_autor'),
                SoleraL10n.t('fos.iden_com_identidad_cripto'),
              ],
              colorFondo: Colors.red.shade50,
              colorTexto: Colors.red.shade900,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controladorEmail,
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => setState(() {
                _errorEmail = _emailValido || _controladorEmail.text.isEmpty
                    ? null
                    : SoleraL10n.t('fos.iden_com_email_no_valido');
              }),
              decoration: InputDecoration(
                labelText: SoleraL10n.t('fos.iden_com_email_contacto'),
                helperText: SoleraL10n.t('fos.iden_com_email_ayuda'),
                helperMaxLines: 2,
                errorText: _errorEmail,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controladorNombre,
              decoration: InputDecoration(
                labelText: SoleraL10n.t('fos.iden_com_tu_nombre_opcional'),
                helperText: SoleraL10n.t('fos.iden_com_nombre_ayuda'),
                helperMaxLines: 2,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _consentimiento,
              onChanged: (valor) =>
                  setState(() => _consentimiento = valor ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: Text(
                SoleraL10n.t('fos.iden_com_consentimiento'),
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _enviando ? null : () => Navigator.of(context).pop(false),
          child: Text(SoleraL10n.t('cancelar')),
        ),
        FilledButton(
          onPressed: _puedeEnviar ? _enviar : null,
          child: _enviando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(SoleraL10n.t('fos.iden_com_enviar_revision')),
        ),
      ],
    );
  }

  Widget _bloqueInfo({
    required String titulo,
    required List<String> elementos,
    required Color colorFondo,
    required Color colorTexto,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorFondo,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colorTexto,
                fontSize: 12,
              )),
          const SizedBox(height: 4),
          for (final item in elementos)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: Text('• $item',
                  style: TextStyle(color: colorTexto, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
