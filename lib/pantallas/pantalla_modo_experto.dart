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
        title: const Text('Nombre de la autoridad'),
        content: TextField(
          controller: controlador,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Ej: Instituto Nacional de Geología',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(SoleraL10n.t('cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controlador.text.trim()),
            child: const Text('Generar'),
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
        title: const Text('Código de activación'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Para: $nombre', style: const TextStyle(fontSize: 13, color: Colors.black54)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                border: Border.all(color: Colors.amber.shade700),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                codigo,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Mándalo por email institucional al experto. Sólo le sirve a la '
              'primera persona que lo use — no se puede reusar.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Copiar'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: codigo));
              if (!mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Código copiado al portapapeles')),
              );
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.share),
            label: const Text('Compartir'),
            onPressed: () async {
              Navigator.pop(context);
              await Share.share(
                'Código de activación para $nombre:\n\n$codigo',
                subject: 'Modo Experto — Fósiles',
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
        title: const Text('Desactivar modo Experto'),
        content: const Text(
          'La clave de la autoridad se borrará de este dispositivo. Las cards '
          'que ya certificaste siguen siendo válidas, pero esta instalación '
          'no podrá firmar nuevas certificaciones hasta que vuelvas a activar '
          'con un código nuevo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(SoleraL10n.t('cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Desactivar'),
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
      appBar: AppBar(title: const Text('Modo Experto')),
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
      const Text(
        'El Modo Experto permite a una autoridad firmante (Instituto Nacional '
        'de Geología, museo, sociedad científica) revisar y certificar cards '
        'compartidas por los descubridores.',
        style: TextStyle(fontSize: 14),
      ),
      const SizedBox(height: 24),
      _seccion(
        titulo: 'Activar como autoridad',
        descripcion: 'Si has recibido un código de activación por email '
            'institucional, pégalo aquí para empezar a recibir cards para '
            'revisión.',
        hijos: [
          FilledButton.icon(
            icon: const Icon(Icons.key),
            label: const Text('Pegar código de activación'),
            onPressed: _activar,
            style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
          ),
        ],
      ),
      const SizedBox(height: 32),
      _seccion(
        titulo: 'Administrador: generar código',
        descripcion: 'Si tú gestionas Fósiles y quieres preautorizar a una '
            'autoridad para que pueda certificar cards, genera un código y '
            'mándaselo por email institucional. Sólo le sirve a la primera '
            'persona que lo use.',
        hijos: [
          OutlinedButton.icon(
            icon: const Icon(Icons.qr_code_2),
            label: const Text('Generar código para una autoridad'),
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
                  const Text(
                    'Modo Experto activo',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _nombreAutoridad,
                    style: const TextStyle(fontSize: 14),
                  ),
                  if (_colegiacion.isNotEmpty)
                    Text(_colegiacion,
                        style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _seccion(
        titulo: 'Huella institucional',
        descripcion: 'Esta huella criptográfica viaja en cada certificación '
            'que firmas. Los descubridores la verán al recibir sus cards de '
            'vuelta.',
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
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
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
        label: const Text(
          'Desactivar modo Experto',
          style: TextStyle(color: Colors.red),
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
      setState(() => _error = 'Código y nombre son obligatorios.');
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
        _error = 'Código no válido. Pídele al administrador uno nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activar autoridad')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _controladorCodigo,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Código de activación',
              hintText: 'Pega aquí el código del email institucional',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controladorNombre,
            decoration: const InputDecoration(
              labelText: 'Nombre de la autoridad *',
              hintText: 'Ej: Instituto Nacional de Geología',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controladorColegiacion,
            decoration: const InputDecoration(
              labelText: 'Persona responsable / colegiación (opcional)',
              hintText: 'Ej: Dra. X. Y. (col. nº 1234)',
              border: OutlineInputBorder(),
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
                : const Text('Activar'),
          ),
        ],
      ),
    );
  }
}
