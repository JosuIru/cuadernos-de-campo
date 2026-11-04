import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import 'package:share_plus/share_plus.dart';

import '../servicios/autoridad_certificadora.dart';

/// Pantalla de gestión del **Modo Experto** — la cara visible del flujo
/// de certificación institucional (Fase C).
///
/// Dos modos según el estado:
///
/// - **Sin activar**: dos secciones — "Generar código para autoridad"
///   (lo usa el administrador de Fósiles para preautorizar a un experto
///   del ING/museo) y "Activar como autoridad" (lo usa el experto al
///   recibir el código off-band).
///
/// - **Activo**: muestra los datos de la autoridad activa (nombre +
///   colegiación + huella criptográfica), botón "Ver pendientes de
///   revisar" (cola de cards recibidas) y botón "Desactivar modo
///   Experto" en rojo.
class PantallaModoExperto extends StatefulWidget {
  const PantallaModoExperto({super.key});

  @override
  State<PantallaModoExperto> createState() => _PantallaModoExpertoState();
}

class _PantallaModoExpertoState extends State<PantallaModoExperto> {
  bool _activo = false;
  String _nombreAutoridad = '';
  String _colegiacion = '';
  String _huella = '';
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final autoridad = AutoridadCertificadora.instancia;
    final activo = await autoridad.estaActiva();
    String nombre = '';
    String colegiacion = '';
    String huella = '';
    if (activo) {
      nombre = await autoridad.obtenerNombreAutoridad();
      colegiacion = await autoridad.obtenerColegiacion();
      huella = await autoridad.obtenerHuellaCorta();
    }
    if (!mounted) return;
    setState(() {
      _activo = activo;
      _nombreAutoridad = nombre;
      _colegiacion = colegiacion;
      _huella = huella;
      _cargando = false;
    });
  }

  Future<void> _generarCodigo() async {
    final controlador = TextEditingController();
    final nombre = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(SoleraL10n.t('fos.ajus_nombre_autoridad')),
        content: TextField(
          controller: controlador,
          autofocus: true,
          decoration: InputDecoration(
            hintText: SoleraL10n.t('fos.ajus_ej_autoridad'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(SoleraL10n.t('cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controlador.text.trim()),
            child: Text(SoleraL10n.t('fos.ajus_generar')),
          ),
        ],
      ),
    );
    controlador.dispose();
    if (nombre == null || nombre.isEmpty || !mounted) return;
    final codigo = AutoridadCertificadora.generarCodigoActivacion(nombre);
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(SoleraL10n.t('fos.ajus_codigo_activacion')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(SoleraL10n.tf('fos.ajus_para_nombre', {'nombre': nombre}), style: const TextStyle(fontSize: 13, color: Colors.black54)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                border: Border.all(color: Colors.amber.shade700),
                borderRadius: BorderRadius.circular(8),
              ),
              // Fondo amber.shade50 es claro fijo; sin un color
              // explícito, en dark mode el SelectableText hereda
              // blanco y queda blanco-en-blanco (bug reportado en
              // testeo 2026-05-15).
              child: SelectableText(
                codigo,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Colors.amber.shade900,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              SoleraL10n.t('fos.ajus_codigo_mandalo'),
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy),
            label: Text(SoleraL10n.t('fos.ajus_copiar')),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: codigo));
              if (!mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(SoleraL10n.t('fos.ajus_codigo_copiado'))),
              );
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.share),
            label: Text(SoleraL10n.t('compartir')),
            onPressed: () async {
              Navigator.pop(context);
              await Share.share(
                '${SoleraL10n.tf('fos.ajus_compartir_codigo', {'nombre': nombre})}\n\n$codigo',
                subject: SoleraL10n.t('fos.ajus_asunto_experto'),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _activar() async {
    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const _PantallaActivar()),
    );
    if (resultado == true) await _cargar();
  }

  Future<void> _desactivar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(SoleraL10n.t('fos.ajus_desactivar_titulo')),
        content: Text(SoleraL10n.t('fos.ajus_desactivar_texto')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(SoleraL10n.t('cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(SoleraL10n.t('fos.ajus_desactivar')),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    await AutoridadCertificadora.instancia.desactivar();
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(SoleraL10n.t('fos.ajus_modo_experto'))),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: _activo ? _seccionActiva() : _seccionInactiva(),
            ),
    );
  }

  List<Widget> _seccionInactiva() {
    return [
      Text(
        SoleraL10n.t('fos.ajus_experto_intro'),
        style: const TextStyle(fontSize: 14),
      ),
      const SizedBox(height: 24),
      _seccion(
        titulo: SoleraL10n.t('fos.ajus_activar_autoridad'),
        descripcion: SoleraL10n.t('fos.ajus_activar_autoridad_texto'),
        hijos: [
          FilledButton.icon(
            icon: const Icon(Icons.key),
            label: Text(SoleraL10n.t('fos.ajus_pegar_codigo')),
            onPressed: _activar,
            style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
          ),
        ],
      ),
      const SizedBox(height: 32),
      _seccion(
        titulo: SoleraL10n.t('fos.ajus_admin_generar'),
        descripcion: SoleraL10n.t('fos.ajus_admin_texto'),
        hijos: [
          OutlinedButton.icon(
            icon: const Icon(Icons.qr_code_2),
            label: Text(SoleraL10n.t('fos.ajus_generar_codigo_autoridad')),
            onPressed: _generarCodigo,
            style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
          ),
        ],
      ),
    ];
  }

  List<Widget> _seccionActiva() {
    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          border: Border.all(color: Colors.green.shade400),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified_user, color: Colors.green, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    SoleraL10n.t('fos.ajus_experto_activo'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.green.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _nombreAutoridad,
                    style: TextStyle(fontSize: 14, color: Colors.green.shade900),
                  ),
                  if (_colegiacion.isNotEmpty)
                    Text(_colegiacion,
                        style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _seccion(
        titulo: SoleraL10n.t('fos.ajus_huella_institucional'),
        descripcion: SoleraL10n.t('fos.ajus_huella_texto'),
        hijos: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              border: Border.all(color: Colors.amber.shade700),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.fingerprint, color: Colors.amber),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _huella,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
      OutlinedButton.icon(
        icon: const Icon(Icons.power_off, color: Colors.red),
        label: Text(
          SoleraL10n.t('fos.ajus_desactivar_titulo'),
          style: const TextStyle(color: Colors.red),
        ),
        onPressed: _desactivar,
        style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
      ),
    ];
  }

  Widget _seccion({
    required String titulo,
    required String descripcion,
    required List<Widget> hijos,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(titulo, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(descripcion,
            style: const TextStyle(fontSize: 13, color: Colors.black54)),
        const SizedBox(height: 12),
        ...hijos,
      ],
    );
  }
}

class _PantallaActivar extends StatefulWidget {
  const _PantallaActivar();

  @override
  State<_PantallaActivar> createState() => _PantallaActivarState();
}

class _PantallaActivarState extends State<_PantallaActivar> {
  final _controladorCodigo = TextEditingController();
  final _controladorNombre = TextEditingController();
  final _controladorColegiacion = TextEditingController();
  bool _activando = false;
  String? _error;

  @override
  void dispose() {
    _controladorCodigo.dispose();
    _controladorNombre.dispose();
    _controladorColegiacion.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final codigo = _controladorCodigo.text.trim();
    final nombre = _controladorNombre.text.trim();
    final colegiacion = _controladorColegiacion.text.trim();
    if (codigo.isEmpty || nombre.isEmpty) {
      setState(() => _error = SoleraL10n.t('fos.ajus_codigo_nombre_obligatorios'));
      return;
    }
    setState(() {
      _activando = true;
      _error = null;
    });
    final ok = await AutoridadCertificadora.instancia.activar(
      codigoActivacion: codigo,
      nombreAutoridad: nombre,
      colegiacion: colegiacion,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _activando = false;
        _error = SoleraL10n.t('fos.ajus_codigo_no_valido');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(SoleraL10n.t('fos.ajus_activar_autoridad_titulo'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _controladorCodigo,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: SoleraL10n.t('fos.ajus_codigo_activacion'),
              hintText: SoleraL10n.t('fos.ajus_pega_codigo_hint'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controladorNombre,
            decoration: InputDecoration(
              labelText: '${SoleraL10n.t('fos.ajus_nombre_autoridad')} *',
              hintText: SoleraL10n.t('fos.ajus_ej_autoridad'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controladorColegiacion,
            decoration: InputDecoration(
              labelText: SoleraL10n.t('fos.ajus_colegiacion'),
              hintText: SoleraL10n.t('fos.ajus_ej_colegiacion'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_error!, style: TextStyle(color: Colors.red.shade900)),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _activando ? null : _enviar,
            style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
            child: _activando
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(SoleraL10n.t('fos.ajus_activar')),
          ),
        ],
      ),
    );
  }
}
