import 'package:flutter/material.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import '../datos/configuracion.dart';

/// Mini-tour de primer arranque. Tres pantallas explicativas que el usuario
/// ve solo la primera vez que abre la app (o cuando lo pide manualmente desde
/// Ajustes). Al pulsar "Empezar" o "Saltar" se marca como visto en
/// [Configuracion] y se vuelve atrás.
class PantallaOnboarding extends StatefulWidget {
  /// Si es `true`, al cerrar marca el onboarding como visto en
  /// [Configuracion]. Cuando el usuario lo lanza desde Ajustes para repetirlo,
  /// se pasa `false` y no se vuelve a tocar el flag.
  final bool marcarComoVistoAlSalir;

  const PantallaOnboarding({super.key, this.marcarComoVistoAlSalir = true});

  @override
  State<PantallaOnboarding> createState() => _PantallaOnboardingState();
}

class _PantallaOnboardingState extends State<PantallaOnboarding> {
  final PageController _controladorPaginas = PageController();
  int _paginaActual = 0;

  static const List<_PaginaOnboarding> _paginas = [
    _PaginaOnboarding(
      icono: Icons.layers,
      claveTitulo: 'fos.ajus_onb1_titulo',
      claveTexto: 'fos.ajus_onb1_texto',
    ),
    _PaginaOnboarding(
      icono: Icons.add_location_alt,
      claveTitulo: 'fos.ajus_onb2_titulo',
      claveTexto: 'fos.ajus_onb2_texto',
    ),
    _PaginaOnboarding(
      icono: Icons.assistant,
      claveTitulo: 'fos.ajus_onb3_titulo',
      claveTexto: 'fos.ajus_onb3_texto',
    ),
  ];

  @override
  void dispose() {
    _controladorPaginas.dispose();
    super.dispose();
  }

  Future<void> _cerrarOnboarding() async {
    if (widget.marcarComoVistoAlSalir) {
      await Configuracion.marcarOnboardingVisto();
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  void _irAPaginaSiguiente() {
    if (_paginaActual >= _paginas.length - 1) {
      _cerrarOnboarding();
      return;
    }
    _controladorPaginas.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final esUltimaPagina = _paginaActual == _paginas.length - 1;
    final esquemaColores = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Elegir idioma desde la primera pantalla (se puede cambiar
            // luego en Ajustes).
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SelectorIdioma(onCambio: () => setState(() {})),
              ),
            ),

            // Cabecera: botón "Saltar" arriba a la derecha.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _cerrarOnboarding,
                    child: Text(SoleraL10n.t('fos.ajus_saltar')),
                  ),
                ],
              ),
            ),

            // Páginas.
            Expanded(
              child: PageView.builder(
                controller: _controladorPaginas,
                onPageChanged: (indice) =>
                    setState(() => _paginaActual = indice),
                itemCount: _paginas.length,
                itemBuilder: (_, indice) => _VistaPagina(pagina: _paginas[indice]),
              ),
            ),

            // Indicadores de página (dots).
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_paginas.length, (indice) {
                  final estaActivo = indice == _paginaActual;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: estaActivo ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: estaActivo
                          ? esquemaColores.primary
                          : esquemaColores.primary.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),

            // Botón principal abajo a la derecha.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton(
                    onPressed: _irAPaginaSiguiente,
                    child: Text(esUltimaPagina
                        ? SoleraL10n.t('fos.ajus_empezar')
                        : SoleraL10n.t('siguiente')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaginaOnboarding {
  final IconData icono;
  /// Claves de traducción: se traducen al mostrar la página.
  final String claveTitulo;
  final String claveTexto;
  const _PaginaOnboarding({
    required this.icono,
    required this.claveTitulo,
    required this.claveTexto,
  });
}

class _VistaPagina extends StatelessWidget {
  final _PaginaOnboarding pagina;
  const _VistaPagina({required this.pagina});

  @override
  Widget build(BuildContext context) {
    final esquemaColores = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: esquemaColores.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              pagina.icono,
              size: 72,
              color: esquemaColores.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 36),
          Text(
            SoleraL10n.t(pagina.claveTitulo),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 18),
          Text(
            SoleraL10n.t(pagina.claveTexto),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.45),
          ),
        ],
      ),
    );
  }
}
