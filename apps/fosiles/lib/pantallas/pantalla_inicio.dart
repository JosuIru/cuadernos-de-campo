import 'package:flutter/material.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import 'pantalla_chat.dart';
import 'pantalla_meteo.dart';
import '../servicios/checker_actualizaciones_fosiles.dart';

class PantallaInicio extends StatelessWidget {
  final VoidCallback? alIrAMapa;
  final VoidCallback? alIrAGuia;

  const PantallaInicio({super.key, this.alIrAMapa, this.alIrAGuia});

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Fósiles')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ValueListenableBuilder<ActualizacionDisponible?>(
            valueListenable: notificadorActualizacionFosiles,
            builder: (_, actualizacion, __) {
              if (actualizacion == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: BannerActualizacionDisponible(
                  actualizacion: actualizacion,
                  onDescartar: () =>
                      notificadorActualizacionFosiles.value = null,
                ),
              );
            },
          ),
          // ─── Cabecera ───────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [esquema.primary, esquema.primary.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('🦴', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              Text(SoleraL10n.t('fos.ajus_cabecera_titulo'),
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(SoleraL10n.t('fos.ajus_cabecera_sub'),
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14)),
            ]),
          ),

          const SizedBox(height: 24),

          // ─── Acciones rápidas ───────────────────────────
          Row(children: [
            Expanded(
              child: _tarjetaAccion(
                context,
                icono: Icons.explore,
                titulo: SoleraL10n.t('fos.ajus_explorar_mapa'),
                subtitulo: SoleraL10n.t('fos.ajus_explorar_mapa_sub'),
                onTap: () => alIrAMapa?.call(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _tarjetaAccion(
                context,
                icono: Icons.wb_cloudy,
                titulo: SoleraL10n.t('fos.ajus_meteo'),
                subtitulo: SoleraL10n.t('fos.ajus_meteo_sub'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PantallaMeteo()),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          _tarjetaAccion(
            context,
            icono: Icons.chat_bubble,
            titulo: SoleraL10n.t('fos.ajus_chat_ia'),
            subtitulo: SoleraL10n.t('fos.ajus_chat_ia_sub'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PantallaChat()),
            ),
            anchoCompleto: true,
          ),

          const SizedBox(height: 24),

          // ─── Guía ética ────────────────────────────────
          Text(SoleraL10n.t('fos.ajus_etica_titulo'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(SoleraL10n.t('fos.ajus_etica_sub'),
              style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 12),
          _seccionEtica(
            icono: Icons.museum,
            titulo: SoleraL10n.t('fos.ajus_etica1_titulo'),
            texto: SoleraL10n.t('fos.ajus_etica1_texto'),
          ),
          _seccionEtica(
            icono: Icons.camera_alt,
            titulo: SoleraL10n.t('fos.ajus_etica2_titulo'),
            texto: SoleraL10n.t('fos.ajus_etica2_texto'),
          ),
          _seccionEtica(
            icono: Icons.auto_awesome,
            titulo: SoleraL10n.t('fos.ajus_etica3_titulo'),
            texto: SoleraL10n.t('fos.ajus_etica3_texto'),
          ),
          _seccionEtica(
            icono: Icons.eco,
            titulo: SoleraL10n.t('fos.ajus_etica4_titulo'),
            texto: SoleraL10n.t('fos.ajus_etica4_texto'),
          ),
          _seccionEtica(
            icono: Icons.share,
            titulo: SoleraL10n.t('fos.ajus_etica5_titulo'),
            texto: SoleraL10n.t('fos.ajus_etica5_texto'),
          ),

          const SizedBox(height: 24),

          // ─── Cómo usar la app ─────────────────────────
          Text(SoleraL10n.t('fos.ajus_como_usar'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _paso(1, SoleraL10n.t('fos.ajus_paso1_titulo'), SoleraL10n.t('fos.ajus_paso1_texto')),
          _paso(2, SoleraL10n.t('fos.ajus_paso2_titulo'), SoleraL10n.t('fos.ajus_paso2_texto')),
          _paso(3, SoleraL10n.t('fos.ajus_paso3_titulo'), SoleraL10n.t('fos.ajus_paso3_texto')),
          _paso(4, SoleraL10n.t('fos.ajus_paso4_titulo'), SoleraL10n.t('fos.ajus_paso4_texto')),
          _paso(5, SoleraL10n.t('fos.ajus_paso5_titulo'), SoleraL10n.t('fos.ajus_paso5_texto')),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _tarjetaAccion(BuildContext context,
      {required IconData icono, required String titulo, required String subtitulo, required VoidCallback onTap, bool anchoCompleto = false}) {
    final esquema = Theme.of(context).colorScheme;
    return Material(
      color: esquema.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icono, color: esquema.primary, size: 28),
            const SizedBox(height: 8),
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(subtitulo, style: TextStyle(fontSize: 12, color: esquema.onSurface.withValues(alpha: 0.6))),
          ]),
        ),
      ),
    );
  }

  Widget _seccionEtica({required IconData icono, required String titulo, required String texto}) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icono, size: 22, color: const Color(0xFF5E7D3A)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 2),
              Text(texto, style: const TextStyle(fontSize: 13, height: 1.4)),
            ]),
          ),
        ]),
      );

  Widget _paso(int numero, String titulo, String descripcion) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0xFF5E7D3A),
            child: Text('$numero', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(descripcion, style: const TextStyle(fontSize: 13)),
            ]),
          ),
        ]),
      );
}
