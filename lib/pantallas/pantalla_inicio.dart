import 'package:flutter/material.dart';
import 'pantalla_chat.dart';
import 'pantalla_meteo.dart';

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
              const Text('Cuaderno de campo de fósiles',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Para el aficionado a la paleontología',
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
                titulo: 'Explorar mapa',
                subtitulo: 'Yacimientos y geología',
                onTap: () => alIrAMapa?.call(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _tarjetaAccion(
                context,
                icono: Icons.wb_cloudy,
                titulo: 'Meteorología',
                subtitulo: 'Previsión para tu excursión',
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
            titulo: 'Chat IA',
            subtitulo: 'Resuelve dudas, identifica hallazgos, pide consejos de campo',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PantallaChat()),
            ),
            anchoCompleto: true,
          ),

          const SizedBox(height: 24),

          // ─── Guía ética ────────────────────────────────
          const Text('Explora, descubre y comparte',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Unas pautas para que tu afición sume y deje huella solo en el conocimiento.',
              style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 12),
          _seccionEtica(
            icono: Icons.museum,
            titulo: 'Tu hallazgo puede ser importante',
            texto: 'Cada fósil cuenta una historia. Si encuentras algo que te parezca especial, '
                'compártelo con un museo, una universidad o una sociedad geológica. '
                'Ellos sabrán valorarlo y tú formarás parte del descubrimiento. '
                'La app te ayuda a documentarlo con certificado verificable.',
          ),
          _seccionEtica(
            icono: Icons.camera_alt,
            titulo: 'Primero observa y fotografía',
            texto: 'El contexto es tan valioso como la pieza. Fotografía el fósil en su capa, '
                'mide la orientación del estrato, registra la formación. '
                'Una buena documentación multiplica el valor científico de lo que encuentras. '
                'Y muchas veces la foto es suficiente: no siempre hace falta recoger.',
          ),
          _seccionEtica(
            icono: Icons.auto_awesome,
            titulo: 'Infórmate para disfrutar más',
            texto: 'Cada comunidad autónoma tiene sus propias normas de protección del patrimonio. '
                'Conocerlas te convierte en mejor aficionado: sabrás dónde puedes recoger '
                'y dónde es mejor solo fotografiar. Ante la duda, disfruta del hallazgo in situ.',
          ),
          _seccionEtica(
            icono: Icons.eco,
            titulo: 'Deja el lugar como te gustaría encontrarlo',
            texto: 'No excaves sin permiso del propietario. No dañes afloramientos. '
                'Cierra las cancelas. Llévate tu basura… y quizá alguna ajena. '
                'Cada persona que pasa después de ti merece la misma emoción del descubrimiento.',
          ),
          _seccionEtica(
            icono: Icons.share,
            titulo: 'Comparte para que la ciencia avance',
            texto: 'Usa el certificado verificable de la app para compartir tus hallazgos. '
                'Cada registro documentado ayuda a completar el mapa paleontológico '
                'de tu región. Tu contribución, sumada a la de otros aficionados, '
                'es ciencia ciudadana real.',
          ),

          const SizedBox(height: 24),

          // ─── Cómo usar la app ─────────────────────────
          const Text('Cómo usar Fósiles',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _paso(1, 'Explora el mapa', 'Activa las capas geológicas (MAGNA, GEODE) para ver qué edad tiene el suelo que pisas.'),
          _paso(2, 'Registra un hallazgo', 'Toca + para añadir un fósil con foto, coordenadas, edad y formación. La app consulta al IGME automáticamente.'),
          _paso(3, 'Identifica con Claude', 'Con tu API key de Anthropic, la app identifica el fósil por imagen y te da pistas para confirmar.'),
          _paso(4, 'Genera un certificado', 'Cada hallazgo recibe un hash SHA-256 verificable. Compártelo con quien quieras; nadie podrá alterarlo.'),
          _paso(5, 'Registra su trazabilidad', 'Si el fósil acaba en un museo o lo estudia un geólogo, añade eventos a su historial.'),

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
