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
      SnackBar(content: Text(SoleraL10n.t('fos.iden_huella_copiada'))),
    );
  }

  Future<void> _copiarClavePublica() async {
    if (_clavePublicaBase64 == null) return;
    await Clipboard.setData(ClipboardData(text: _clavePublicaBase64!));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(SoleraL10n.t('fos.iden_clave_publica_copiada'))),
    );
  }

  Future<void> _regenerar() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(SoleraL10n.t('fos.iden_regenerar_titulo')),
        content: Text(SoleraL10n.t('fos.iden_regenerar_aviso')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(SoleraL10n.t('cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(SoleraL10n.t('fos.iden_regenerar')),
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
      SnackBar(content: Text(SoleraL10n.t('fos.iden_identidad_regenerada'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(SoleraL10n.t('fos.iden_mi_identidad'))),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _seccion(
                  titulo: SoleraL10n.t('fos.iden_datos_declarados'),
                  textoAyuda: SoleraL10n.t('fos.iden_datos_declarados_ayuda'),
                  hijos: [
                    _filaInfo(SoleraL10n.t('fos.iden_nombre'), _nombre, vacio: _nombre.isEmpty),
                    _filaInfo(SoleraL10n.t('fos.iden_email'), _email, vacio: _email.isEmpty),
                    _filaInfo(SoleraL10n.t('fos.iden_organizacion'), _organizacion, vacio: _organizacion.isEmpty),
                  ],
                ),
                const SizedBox(height: 24),
                _seccion(
                  titulo: SoleraL10n.t('fos.iden_huella_criptografica'),
                  textoAyuda: SoleraL10n.t('fos.iden_huella_ayuda'),
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
                            tooltip: SoleraL10n.t('fos.iden_copiar_huella'),
                            onPressed: _copiarHuella,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ExpansionTile(
                      title: Text(SoleraL10n.t('fos.iden_ver_clave_publica')),
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
                          label: Text(SoleraL10n.t('fos.iden_copiar_clave_publica')),
                          onPressed: _copiarClavePublica,
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _seccion(
                  titulo: SoleraL10n.t('fos.iden_operaciones_avanzadas'),
                  textoAyuda: SoleraL10n.t('fos.iden_operaciones_avanzadas_ayuda'),
                  hijos: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.refresh, color: Colors.red),
                      label: Text(
                        SoleraL10n.t('fos.iden_regenerar_identidad'),
                        style: const TextStyle(color: Colors.red),
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

  Widget _filaInfo(String etiqueta, String valor, {required bool vacio}) {
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
              vacio ? SoleraL10n.t('fos.iden_sin_rellenar') : valor,
              style: TextStyle(
                color: vacio ? Colors.black54 : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
