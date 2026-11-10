import 'package:flutter/material.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Preferencia: ya se enseñó el aviso de ética la primera vez que se abrió la
/// pantalla de escucha.
const String clavePreferenciaEticaVista = 'nat.quien_canta.etica_vista';

/// Fuentes de las pautas (leídas el 2026-11-10).
const List<({String titulo, String enlace})> fuentesEticaCampo = [
  (
    titulo: 'SEO/BirdLife (2018). Código Ético para la Observación de Aves',
    enlace: 'https://sierranortemadrid.org/wp-content/uploads/2024/10/Codigo_etico_aves_SEO_-2018.pdf',
  ),
  (
    titulo: 'American Birding Association. Code of Birding Ethics, 1(b)',
    enlace: 'https://www.aba.org/aba-code-of-birding-ethics/',
  ),
];

/// Ética de campo con el sonido: la app no hace playback, por qué, y cinco
/// pautas, con sus fuentes.
class SeccionEticaCampo extends StatelessWidget {
  const SeccionEticaCampo({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    Widget pauta(IconData icono, String clave) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icono, size: 20, color: tema.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(SoleraL10n.t(clave))),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(SoleraL10n.t('nat.etica_titulo'), style: tema.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(SoleraL10n.t('nat.etica_sin_playback'), style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(SoleraL10n.t('nat.etica_por_que')),
        const SizedBox(height: 8),
        Text(SoleraL10n.t('nat.etica_pautas'), style: tema.textTheme.titleSmall),
        pauta(Icons.social_distance_outlined, 'nat.etica_pauta_distancia'),
        pauta(Icons.egg_outlined, 'nat.etica_pauta_cria'),
        pauta(Icons.location_off_outlined, 'nat.etica_pauta_ubicaciones'),
        pauta(Icons.hiking, 'nat.etica_pauta_sendas'),
        pauta(Icons.headphones_outlined, 'nat.etica_pauta_repaso'),
        const SizedBox(height: 12),
        Text(SoleraL10n.t('nat.etica_fuentes'), style: tema.textTheme.labelLarge),
        for (final fuente in fuentesEticaCampo)
          TextButton(
            style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
            onPressed: () => launchUrl(Uri.parse(fuente.enlace), mode: LaunchMode.externalApplication),
            child: Text(fuente.titulo, textAlign: TextAlign.left),
          ),
      ],
    );
  }
}

/// La sección en una hoja inferior.
Future<void> mostrarEticaCampo(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SeccionEticaCampo(),
        ),
      ),
    );

/// La primera vez que se abre la pantalla de escucha: aviso corto con la
/// opción de leer la sección entera.
Future<void> avisarEticaCampoLaPrimeraVez(BuildContext context) async {
  try {
    final preferencias = await SharedPreferences.getInstance();
    if (preferencias.getBool(clavePreferenciaEticaVista) ?? false) return;
    if (!context.mounted) return;
    final leerMas = await showDialog<bool>(
      context: context,
      builder: (contextoDialogo) => AlertDialog(
        icon: const Icon(Icons.volume_off_outlined),
        title: Text(SoleraL10n.t('nat.etica_aviso_titulo')),
        content: Text(SoleraL10n.t('nat.etica_aviso_texto')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contextoDialogo, true),
            child: Text(SoleraL10n.t('nat.etica_leer_mas')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(contextoDialogo, false),
            child: Text(SoleraL10n.t('nat.etica_entendido')),
          ),
        ],
      ),
    );
    await preferencias.setBool(clavePreferenciaEticaVista, true);
    if (leerMas == true && context.mounted) await mostrarEticaCampo(context);
  } catch (_) {}
}
