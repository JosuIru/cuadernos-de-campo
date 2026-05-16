import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';

import '../datos/configuracion.dart';
import '../servicios/identidad_descubridor.dart';

/// Pantalla "Mi identidad" — gestión de la identidad criptográfica del
/// descubridor (clave Ed25519 generada al primer arranque).
///
/// Muestra:
/// - Nombre + email + organización declarados (auto-asertados).
/// - Huella corta legible de la clave pública.
/// - Clave pública completa en base64 (con botón copiar y compartir).
/// - Botón regenerar (advertencia roja: rompe la trazabilidad de hallazgos
///   firmados con la clave antigua).
class PantallaIdentidad extends StatefulWidget {
  const PantallaIdentidad({super.key});

  @override
  State<PantallaIdentidad> createState() => _PantallaIdentidadState();
}

class _PantallaIdentidadState extends State<PantallaIdentidad> {
  String? _huellaCorta;
  String? _clavePublicaBase64;
  String _nombre = '';
  String _email = '';
  String _organizacion = '';
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final huella = await IdentidadDescubridor.instancia.obtenerHuellaCorta();
    final publica = await IdentidadDescubridor.instancia.obtenerClavePublicaBase64();
    final nombre = await Configuracion.obtenerNombreDescubridor();
    final email = await Configuracion.obtenerEmailDescubridor();
    final organizacion = await Configuracion.obtenerOrganizacionDescubridor();
    if (!mounted) return;
    setState(() {
      _huellaCorta = huella;
      _clavePublicaBase64 = publica;
      _nombre = nombre;
      _email = email;
      _organizacion = organizacion;
      _cargando = false;
    });
  }

  Future<void> _copiarHuella() async {
    if (_huellaCorta == null) return;
    await Clipboard.setData(ClipboardData(text: _huellaCorta!));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Huella copiada al portapapeles')),
    );
  }

  Future<void> _copiarClavePublica() async {
    if (_clavePublicaBase64 == null) return;
    await Clipboard.setData(ClipboardData(text: _clavePublicaBase64!));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Clave pública copiada al portapapeles')),
    );
  }

  Future<void> _regenerar() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Regenerar identidad criptográfica'),
        content: const Text(
          'Esto crea un par de claves nuevo. Los hallazgos firmados con tu '
          'clave anterior seguirán existiendo pero ya no podrán verificarse '
          'como tuyos cripcográficamente. Tu nombre y email no cambian. '
          'Sólo deberías hacer esto si crees que tu clave se ha comprometido '
          '(por ejemplo, tras restaurar un backup en un dispositivo prestado).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(SoleraL10n.t('cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Regenerar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;
    setState(() => _cargando = true);
    await IdentidadDescubridor.instancia.regenerar();
    await _cargar();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Identidad regenerada')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi identidad')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _seccion(
                  titulo: 'Datos declarados',
                  textoAyuda:
                      'Estos datos los rellenas tú en Ajustes. Acompañan a la firma '
                      'cuando compartes una card o un certificado, pero no están '
                      'autenticados contra una autoridad externa: cualquiera puede '
                      'decir que se llama como quiera. Lo que sí es único y permanente '
                      'es tu clave criptográfica.',
                  hijos: [
                    _filaInfo('Nombre', _nombre.isEmpty ? '(sin rellenar)' : _nombre),
                    _filaInfo('Email', _email.isEmpty ? '(sin rellenar)' : _email),
                    _filaInfo('Organización', _organizacion.isEmpty ? '(sin rellenar)' : _organizacion),
                  ],
                ),
                const SizedBox(height: 24),
                _seccion(
                  titulo: 'Huella criptográfica',
                  textoAyuda:
                      'Esta huella se deriva de tu clave pública. Es única, '
                      'permanente y se genera la primera vez que abriste Fósiles. '
                      'Cuando alguien recibe un hallazgo firmado por ti, puede '
                      'verificar que la firma coincide con esta huella.',
                  hijos: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        border: Border.all(color: Colors.amber.shade700, width: 1.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.fingerprint, color: Colors.amber),
                          const SizedBox(width: 12),
                          Expanded(
                            // Color explícito para que la huella sea
                            // legible sobre amber.shade50 también en
                            // dark mode (sin esto el Text heredaba
                            // blanco — bug reportado en testeo
                            // 2026-05-15).
                            child: Text(
                              _huellaCorta ?? '',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy),
                            tooltip: 'Copiar huella',
                            onPressed: _copiarHuella,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ExpansionTile(
                      title: const Text('Ver clave pública completa'),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8),
                          // SelectableText sin color heredaba el del
                          // tema y en algunos modos quedaba ilegible.
                          child: SelectableText(
                            _clavePublicaBase64 ?? '',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.copy),
                          label: const Text('Copiar clave pública'),
                          onPressed: _copiarClavePublica,
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _seccion(
                  titulo: 'Operaciones avanzadas',
                  textoAyuda:
                      'Tu clave privada se guarda cifrada en el almacenamiento '
                      'seguro de Android (no sale del dispositivo). El backup .zip '
                      'cifrado que generas desde Ajustes la incluye para que puedas '
                      'recuperarla si cambias de móvil.',
                  hijos: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.refresh, color: Colors.red),
                      label: const Text(
                        'Regenerar identidad',
                        style: TextStyle(color: Colors.red),
                      ),
                      onPressed: _regenerar,
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _seccion({
    required String titulo,
    required String textoAyuda,
    required List<Widget> hijos,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(titulo, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(textoAyuda, style: const TextStyle(fontSize: 13, color: Colors.black54)),
        const SizedBox(height: 12),
        ...hijos,
      ],
    );
  }

  Widget _filaInfo(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              etiqueta,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: TextStyle(
                color: valor.startsWith('(') ? Colors.black54 : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
