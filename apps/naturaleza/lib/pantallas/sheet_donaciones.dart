import 'package:flutter/material.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Sheet modal con las opciones de donación / apoyo.
///
/// Replica el patrón del proyecto hermano `flavor-news-hub` (mismas
/// cuentas, misma estructura) para unificar la caja común entre apps:
/// Ko-fi, PayPal y dos direcciones Bitcoin. La app sigue siendo 100%
/// gratuita y abierta — esto sólo expone canales para quien quiera
/// apoyar voluntariamente.
///
/// Las direcciones se copian al portapapeles con feedback; los enlaces
/// abren en navegador externo para no bloquear la app con un WebView.
Future<void> mostrarSheetDonaciones(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ContenidoSheet(),
  );
}

class _ContenidoSheet extends StatelessWidget {
  _ContenidoSheet();

  static const String _kofiUrl = 'https://ko-fi.com/codigodespierto';
  static const String _paypalUrl =
      'https://www.paypal.com/paypalme/codigodespierto';
  static const String _btcSegwit = 'bc1qjnva46wy92ldhsv4w0j26jmu8c5wm5cxvgdfd7';
  static const String _btcTaproot =
      'bc1p29l9vjelerljlwhg6dhr0uldldus4zgn8vjaecer0spj7273d7rss4gnyk';
  static const String _urlEcosistema = 'https://coleccion-nuevo-ser.gailu.net/';
  static const String _mensajeCompartir =
      'Naturaleza — cuaderno de campo digital para anotar fauna y flora '
      'con georreferencia y guía de identificación. App libre, sin '
      'anuncios ni tracking. Pruébala: https://coleccion-nuevo-ser.gailu.net/';

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, controlador) => ListView(
        controller: controlador,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Text(
            'Apoyar el proyecto',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'La app es y seguirá siendo gratuita y abierta para todos. '
            'Si te ha sido útil y puedes permitírtelo, una pequeña '
            'aportación voluntaria ayuda al mantenimiento, soporte y '
            'actualizaciones. Gracias.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          SizedBox(height: 20),
          _TarjetaEnlace(
            icono: Icons.local_cafe,
            titulo: 'Ko-fi',
            subtitulo: 'Pago puntual o mensual con tarjeta',
            url: _kofiUrl,
            colorFondo: Color(0xFFC06A34),
          ),
          SizedBox(height: 10),
          _TarjetaEnlace(
            icono: Icons.credit_card,
            titulo: 'PayPal',
            subtitulo: 'Donación con tu cuenta PayPal',
            url: _paypalUrl,
            colorFondo: Color(0xFF2E5CB8),
          ),
          SizedBox(height: 10),
          _TarjetaBitcoin(
            etiqueta: 'Bitcoin (SegWit)',
            direccion: _btcSegwit,
            colorFondo: Color(0xFFB26B19),
          ),
          SizedBox(height: 10),
          _TarjetaBitcoin(
            etiqueta: 'Bitcoin (Taproot)',
            direccion: _btcTaproot,
            colorFondo: Color(0xFFA07818),
          ),
          SizedBox(height: 24),
          _SeccionCompartir(mensaje: _mensajeCompartir),
          SizedBox(height: 20),
          _OtrasFormas(),
          SizedBox(height: 16),
          _TarjetaEcosistema(url: _urlEcosistema),
        ],
      ),
    );
  }
}

class _TarjetaEcosistema extends StatelessWidget {
  _TarjetaEcosistema({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Material(
      color: esquema.tertiaryContainer,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final uri = Uri.parse(url);
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.auto_awesome, color: esquema.onTertiaryContainer),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Colección Nuevo Ser',
                      style: TextStyle(
                        color: esquema.onTertiaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Esta app forma parte del ecosistema. Conoce el resto de proyectos.',
                      style: TextStyle(
                        color: esquema.onTertiaryContainer.withValues(alpha: 0.85),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.open_in_new, color: esquema.onTertiaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}

class _TarjetaEnlace extends StatelessWidget {
  _TarjetaEnlace({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.url,
    required this.colorFondo,
  });

  final IconData icono;
  final String titulo;
  final String subtitulo;
  final String url;
  final Color colorFondo;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colorFondo,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final uri = Uri.tryParse(url);
          if (uri == null) return;
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icono, color: Colors.white, size: 32),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      subtitulo,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _TarjetaBitcoin extends StatelessWidget {
  _TarjetaBitcoin({
    required this.etiqueta,
    required this.direccion,
    required this.colorFondo,
  });

  final String etiqueta;
  final String direccion;
  final Color colorFondo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorFondo,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.currency_bitcoin, color: Colors.white, size: 28),
              SizedBox(width: 10),
              Text(
                etiqueta,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          SelectableText(
            direccion,
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'monospace',
              fontSize: 11,
              height: 1.4,
            ),
          ),
          SizedBox(height: 10),
          FilledButton.tonalIcon(
            icon: Icon(Icons.copy),
            label: Text('Copiar dirección'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: direccion));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Dirección copiada al portapapeles.'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SeccionCompartir extends StatelessWidget {
  _SeccionCompartir({required this.mensaje});
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Compartir la app',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        SizedBox(height: 8),
        Text(
          'Recomendarla a alguien también ayuda. Es donar tiempo en lugar de dinero.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            icon: Icon(Icons.share),
            label: Text(SoleraL10n.t('compartir')),
            onPressed: () => Share.share(mensaje),
          ),
        ),
      ],
    );
  }
}

class _OtrasFormas extends StatelessWidget {
  _OtrasFormas();

  @override
  Widget build(BuildContext context) {
    const items = <(IconData, String)>[
      (Icons.star_border, 'Valorar la app con cinco estrellas si te ha gustado.'),
      (Icons.bug_report_outlined, 'Reportar un fallo o sugerir mejoras.'),
      (Icons.translate, 'Ayudar con traducciones o textos.'),
      (Icons.code, 'Contribuir con código o ideas de funciones.'),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Otras formas de ayudar',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          SizedBox(height: 8),
          for (final (icono, texto) in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icono, size: 18),
                  SizedBox(width: 10),
                  Expanded(child: Text(texto)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
