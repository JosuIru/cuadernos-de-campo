import 'package:flutter/material.dart';
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
      _mostrarSnack('Este hallazgo no tiene fotos. Edítalo y añade una.');
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
      _mostrarSnack(
          'Enviada (#${resultado.idAportacion}). Si se aprueba, te avisaremos.');
    } on ExcepcionComunidad catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      _mostrarSnack(e.mensaje);
    } catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      _mostrarSnack('Error inesperado: $e');
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
      title: const Text('Compartir con la comunidad'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Un geólogo revisará tu aportación. Si la aprueba, '
              'aparecerá en la app asociada a esta formación geológica, '
              'para que otros aficionados puedan ver lo que se encuentra '
              'aquí.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            _bloqueInfo(
              titulo: 'Se envía:',
              elementos: [
                'Foto principal del hallazgo',
                'Tipo (${hallazgo.tipo})',
                'Especie/grupo declarado: '
                    '${hallazgo.especie.isEmpty ? "—" : hallazgo.especie}',
                'Edad declarada: '
                    '${hallazgo.edad.isEmpty ? "—" : hallazgo.edad}',
                'Formación declarada: '
                    '${hallazgo.formacion.isEmpty ? "—" : hallazgo.formacion}',
                if (hallazgo.notas.isNotEmpty) 'Tus notas',
              ],
              colorFondo: Colors.green.shade50,
              colorTexto: Colors.green.shade900,
            ),
            const SizedBox(height: 8),
            _bloqueInfo(
              titulo: 'NO se envía:',
              elementos: const [
                'Coordenadas',
                'Tu nombre como autor visible',
                'Tu identidad criptográfica del hallazgo',
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
                    : 'Email no válido';
              }),
              decoration: InputDecoration(
                labelText: 'Email de contacto',
                helperText:
                    'Para avisarte si la foto se aprueba o rechaza. NUNCA se publica.',
                helperMaxLines: 2,
                errorText: _errorEmail,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controladorNombre,
              decoration: const InputDecoration(
                labelText: 'Tu nombre (opcional)',
                helperText: 'Solo lo verá el curador. Nunca aparece en la app.',
                helperMaxLines: 2,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _consentimiento,
              onChanged: (valor) =>
                  setState(() => _consentimiento = valor ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Acepto la política de privacidad y entiendo que la app '
                'no es un canal oficial para reportar patrimonio '
                'paleontológico — para hallazgos importantes contacta '
                'también con el servicio de Patrimonio de tu CCAA.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _enviando ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _puedeEnviar ? _enviar : null,
          child: _enviando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enviar para revisión'),
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
