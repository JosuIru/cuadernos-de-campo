import 'package:flutter/material.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import '../datos/configuracion.dart';
import 'pantalla_identidad.dart';
import 'pantalla_modo_experto.dart';
import 'pantalla_verificar_certificado.dart';

/// Ajustes → Perfil e identidad: datos del descubridor que salen en los
/// certificados (con su propio Guardar, junto a los campos), identidad
/// criptográfica, verificación de certificados y Modo Experto.
class PantallaPerfilIdentidad extends StatefulWidget {
  const PantallaPerfilIdentidad({super.key});

  @override
  State<PantallaPerfilIdentidad> createState() => _PantallaPerfilIdentidadState();
}

class _PantallaPerfilIdentidadState extends State<PantallaPerfilIdentidad> {
  final _controladorNombre = TextEditingController();
  final _controladorEmail = TextEditingController();
  final _controladorOrganizacion = TextEditingController();
  // Hasta que se lean los valores guardados no se deja guardar.
  bool _cargado = false;
  String? _mensajeEstado;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _controladorNombre.dispose();
    _controladorEmail.dispose();
    _controladorOrganizacion.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final nombre = await Configuracion.obtenerNombreDescubridor();
    final email = await Configuracion.obtenerEmailDescubridor();
    final organizacion = await Configuracion.obtenerOrganizacionDescubridor();
    if (!mounted) return;
    setState(() {
      _controladorNombre.text = nombre;
      _controladorEmail.text = email;
      _controladorOrganizacion.text = organizacion;
      _cargado = true;
    });
  }

  Future<void> _guardar() async {
    await Configuracion.guardarNombreDescubridor(_controladorNombre.text);
    await Configuracion.guardarEmailDescubridor(_controladorEmail.text);
    await Configuracion.guardarOrganizacionDescubridor(_controladorOrganizacion.text);
    if (!mounted) return;
    setState(() => _mensajeEstado = '✅ ${SoleraL10n.t('fos.iden_perfil_guardado')}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(SoleraL10n.t('fos.iden_perfil_e_identidad'))),
      body: ListView(
        padding: rellenoInferiorSeguro(context, const EdgeInsets.all(16)),
        children: [
          Text(SoleraL10n.t('fos.iden_perfil_descubridor'), style: Theme.of(context).textTheme.titleLarge),
          SizedBox(height: 8),
          Text(
            SoleraL10n.t('fos.iden_perfil_ayuda'),
            style: TextStyle(fontSize: 13),
          ),
          SizedBox(height: 12),
          TextField(
            controller: _controladorNombre,
            decoration: InputDecoration(
              labelText: SoleraL10n.t('fos.iden_nombre_obligatorio'),
              border: OutlineInputBorder(),
              hintText: SoleraL10n.t('fos.iden_nombre_ejemplo'),
            ),
          ),
          SizedBox(height: 8),
          TextField(
            controller: _controladorEmail,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: SoleraL10n.t('fos.iden_email_opcional'),
              border: OutlineInputBorder(),
              hintText: SoleraL10n.t('fos.iden_email_ejemplo'),
            ),
          ),
          SizedBox(height: 8),
          TextField(
            controller: _controladorOrganizacion,
            decoration: InputDecoration(
              labelText: SoleraL10n.t('fos.iden_organizacion_opcional'),
              border: OutlineInputBorder(),
              hintText: SoleraL10n.t('fos.iden_organizacion_ejemplo'),
            ),
          ),
          SizedBox(height: 12),
          FilledButton(onPressed: _cargado ? _guardar : null, child: Text(SoleraL10n.t('fos.iden_guardar_perfil'))),
          if (_mensajeEstado != null) ...[
            SizedBox(height: 12),
            Center(child: Text(_mensajeEstado!, style: TextStyle(color: Theme.of(context).colorScheme.primary))),
          ],
          SizedBox(height: 32),
          Text(SoleraL10n.t('fos.iden_identidad_y_certificados'), style: Theme.of(context).textTheme.titleLarge),
          SizedBox(height: 12),
          OutlinedButton.icon(
            icon: Icon(Icons.fingerprint),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PantallaIdentidad()),
            ),
            label: Text(SoleraL10n.t('fos.iden_mi_identidad_criptografica')),
          ),
          SizedBox(height: 8),
          OutlinedButton.icon(
            icon: Icon(Icons.verified),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => PantallaVerificarCertificado()),
            ),
            label: Text(SoleraL10n.t('fos.iden_verificar_un_certificado')),
          ),
          SizedBox(height: 8),
          OutlinedButton.icon(
            icon: Icon(Icons.school_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PantallaModoExperto()),
            ),
            label: Text(SoleraL10n.t('fos.iden_modo_experto_autoridades')),
          ),
        ],
      ),
    );
  }
}
