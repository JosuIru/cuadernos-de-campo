import 'package:flutter/material.dart';
import 'pantalla_chat.dart';
import 'pantalla_meteo.dart';

class PantallaInicio extends StatelessWidget {
  final VoidCallback? alIrAMapa;
  final VoidCallback? alIrAGuia;

  const PantallaInicio({super.key, this.alIrAMapa, this.alIrAGuia});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Naturaleza')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── Cabecera ───────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF3A7D5A), const Color(0xFF3A7D5A).withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('🌿', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              const Text('Cuaderno de campo de naturaleza',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Observa, aprende y convive con la biodiversidad que te rodea',
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
                subtitulo: 'Especies y observaciones',
                onTap: () => alIrAMapa?.call(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _tarjetaAccion(
                context,
                icono: Icons.wb_cloudy,
                titulo: 'Meteorología',
                subtitulo: 'Previsión para tu salida',
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
            subtitulo: 'Resuelve dudas, identifica especies, pide consejos de observación',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PantallaChat(
                sistemaPrompt: PantallaChat.sistemaNaturaleza,
              )),
            ),
            anchoCompleto: true,
          ),

          const SizedBox(height: 24),

          // ─── Código ético ───────────────────────────────
          const Text('Explora, observa y convive',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Unas pautas para disfrutar de la naturaleza sumando, sin restar.',
              style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 12),
          _seccionEtica(
            icono: Icons.pets,
            titulo: 'Observa con curiosidad y respeto',
            texto: 'Acércate a los animales con calma, mantén la distancia y disfruta viendo '
                'cómo se comportan cuando no se sienten amenazados. '
                'Unos prismáticos o el zoom de la cámara te darán mejores recuerdos '
                'que intentar tocarlos. Si se van, es que estabas demasiado cerca.',
          ),
          _seccionEtica(
            icono: Icons.eco,
            titulo: 'Las plantas también son protagonistas',
            texto: 'Muchas especies son frágiles y tardan años en florecer. Fotografíalas '
                'en su sitio: la imagen dura para siempre y la planta sigue viva. '
                'Quédate en los senderos en zonas sensibles; las raíces y los brotes '
                'te lo agradecerán.',
          ),
          _seccionEtica(
            icono: Icons.volunteer_activism,
            titulo: 'Cada observación tuya suma',
            texto: 'Tus registros ayudan a científicas y conservacionistas a entender '
                'cómo se mueven, cuándo florecen o dónde anidan las especies. '
                'La app te permite identificar y geolocalizar. Es ciencia ciudadana: '
                'tú exploras, la ciencia avanza.',
          ),
          _seccionEtica(
            icono: Icons.wb_sunny,
            titulo: 'Disfruta con seguridad',
            texto: 'Lleva agua, protección solar y calzado cómodo. Consulta la previsión '
                'meteorológica antes de salir — la app te la da. '
                'Comparte tu ruta con alguien si vas a zonas sin cobertura. '
                'Una buena excursión es la que termina con una sonrisa.',
          ),
          _seccionEtica(
            icono: Icons.forest,
            titulo: 'Que tu paso sea invisible',
            texto: 'Llévate tu basura… y alguna más si la encuentras. No hagas fuego. '
                'Deja piedras, plumas y restos donde estaban: forman parte del paisaje '
                'y del ciclo de la vida. La naturaleza no necesita recuerdos; '
                'tú ya te llevas la experiencia.',
          ),

          const SizedBox(height: 24),

          // ─── Cómo usar la app ─────────────────────────
          const Text('Cómo usar Naturaleza',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _paso(1, 'Explora el mapa', 'Activa los lugares de interés (miradores, humedales, reservas) y consulta observaciones GBIF cercanas.'),
          _paso(2, 'Registra un hallazgo', 'Toca + para añadir una especie con foto, coordenadas y categoría (animal, insecto, planta).'),
          _paso(3, 'Identifica con IA', 'La app identifica la especie por imagen usando Claude o Pl@ntNet.'),
          _paso(4, 'Consulta la guía', 'Accede a la guía de especies con fotos de Wikipedia, distintivos, hábitat y usos.'),
          _paso(5, 'Haz el quiz', 'Pon a prueba tus conocimientos con el quiz de identificación por imagen.'),

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
          Icon(icono, size: 22, color: const Color(0xFF3A7D5A)),
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
            backgroundColor: const Color(0xFF3A7D5A),
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
