import 'package:flutter/material.dart';
import 'package:nuevo_ser_core/nuevo_ser_core.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../servicios/servicio_meteo.dart';

class PantallaMeteo extends StatefulWidget {
  final double? latitudInicial;
  final double? longitudInicial;
  final String? nombreInicial;

  const PantallaMeteo({
    super.key,
    this.latitudInicial,
    this.longitudInicial,
    this.nombreInicial,
  });

  @override
  State<PantallaMeteo> createState() => _PantallaMeteoState();
}

class _PantallaMeteoState extends State<PantallaMeteo> {
  final _controladorBusqueda = TextEditingController();
  List<LugarMeteo> _resultados = [];
  bool _buscando = false;
  bool _obteniendoUbicacion = false;
  PrevisonMeteo? _prevision;
  bool _cargandoPrevision = false;
  LugarMeteo? _lugarSeleccionado;

  @override
  void initState() {
    super.initState();
    if (widget.latitudInicial != null && widget.longitudInicial != null) {
      _cargarPrevision(
        widget.latitudInicial!,
        widget.longitudInicial!,
        nombreLugar: widget.nombreInicial ?? 'Ubicación seleccionada',
      );
    }
  }

  @override
  void dispose() {
    _controladorBusqueda.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    final consulta = _controladorBusqueda.text.trim();
    if (consulta.isEmpty) return;
    setState(() => _buscando = true);
    final resultados = await buscarLugaresMeteo(consulta);
    if (!mounted) return;
    setState(() {
      _resultados = resultados;
      _buscando = false;
    });
  }

  Future<void> _usarUbicacionActual() async {
    setState(() => _obteniendoUbicacion = true);
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 10),
      );
      if (!mounted) return;
      _cargarPrevision(pos.latitude, pos.longitude,
          nombreLugar: '${pos.latitude.toStringAsFixed(3)}, ${pos.longitude.toStringAsFixed(3)}');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo obtener la ubicación. Activa el GPS.')),
      );
    } finally {
      if (mounted) setState(() => _obteniendoUbicacion = false);
    }
  }

  Future<void> _cargarPrevision(double lat, double lon, {String nombreLugar = ''}) async {
    setState(() {
      _cargandoPrevision = true;
      _resultados = [];
    });
    final prevision = await obtenerPrevision(lat, lon, nombreLugar: nombreLugar);
    if (!mounted) return;
    setState(() {
      _prevision = prevision;
      _cargandoPrevision = false;
      if (prevision != null) _lugarSeleccionado = prevision.lugar;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meteorología')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _controladorBusqueda,
                  decoration: const InputDecoration(
                    hintText: 'Buscar lugar…',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _buscar(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _buscando ? null : _buscar,
                icon: _buscando
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.search),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: _obteniendoUbicacion ? null : _usarUbicacionActual,
                icon: _obteniendoUbicacion
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location),
                tooltip: 'Usar mi ubicación',
              ),
            ]),
          ),
          if (_resultados.isNotEmpty)
            SizedBox(
              height: 140,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _resultados.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (_, i) {
                  final lugar = _resultados[i];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.location_on),
                    title: Text(lugar.nombre),
                    subtitle: Text([lugar.region, lugar.pais].where((s) => s != null && s.isNotEmpty).join(', ')),
                    onTap: () {
                      setState(() => _resultados = []);
                      _cargarPrevision(lugar.latitud, lugar.longitud, nombreLugar: lugar.nombre);
                    },
                  );
                },
              ),
            ),
          Expanded(child: _contenidoPrevision()),
        ],
      ),
    );
  }

  Widget _contenidoPrevision() {
    if (_cargandoPrevision) {
      return const Center(child: CircularProgressIndicator());
    }
    final prevision = _prevision;
    if (prevision == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🌤️', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              const Text(
                'Busca un lugar o pulsa el botón de ubicación\npara ver la previsión meteorológica',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final hoy = DateTime.now();
    final formatoDia = DateFormat('EEE d', 'es_ES');
    final formatoHora = DateFormat('HH:mm');

    // Filtrar horas: desde la hora actual en adelante
    final horasFiltradas = prevision.horas
        .where((h) => h.fecha.isAfter(DateTime.now().subtract(const Duration(hours: 1))))
        .take(24)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // ─── Cabecera del día actual ──────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4A90D9), Color(0xFF7EC8E3)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.location_on, color: Colors.white70, size: 18),
              const SizedBox(width: 4),
              Expanded(
                child: Text(prevision.lugar.nombre,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ]),
            if (prevision.lugar.region != null)
              Text(prevision.lugar.region!, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 16),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(prevision.dias.first.icono, style: const TextStyle(fontSize: 48)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${prevision.dias.first.tempMax.toStringAsFixed(0)}°',
                    style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                Text('${prevision.dias.first.tempMin.toStringAsFixed(0)}° min · ${prevision.dias.first.descripcion}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14)),
              ]),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _datoMeteo('💧', '${prevision.dias.first.precipitacionMm.toStringAsFixed(1)} mm'),
              const SizedBox(width: 16),
              _datoMeteo('💨', '${prevision.dias.first.vientoMaxKmh.toStringAsFixed(0)} km/h'),
              const SizedBox(width: 16),
              _datoMeteo('☀️', 'UV ${prevision.dias.first.uvMax.toStringAsFixed(0)}'),
            ]),
          ]),
        ),

        // ─── Previsión por horas ─────────────────────────
        if (horasFiltradas.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('Próximas horas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SizedBox(
            height: 108,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: horasFiltradas.length,
              separatorBuilder: (_, __) => const SizedBox(width: 4),
              itemBuilder: (_, i) {
                final h = horasFiltradas[i];
                final esAhora = i == 0;
                return Container(
                  width: 72,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    color: esAhora
                        ? const Color(0xFF4A90D9).withValues(alpha: 0.1)
                        : Colors.black.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(10),
                    border: esAhora
                        ? Border.all(color: const Color(0xFF4A90D9).withValues(alpha: 0.3))
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(esAhora ? 'Ahora' : formatoHora.format(h.fecha),
                          style: TextStyle(fontSize: 11, fontWeight: esAhora ? FontWeight.bold : FontWeight.normal)),
                      Text(h.icono, style: const TextStyle(fontSize: 22)),
                      Text('${h.temperatura.toStringAsFixed(0)}°',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.water_drop, size: 10, color: Colors.lightBlue),
                        Text('${h.probabilidadLluvia}%', style: const TextStyle(fontSize: 10)),
                      ]),
                      Text('${h.vientoKmh.toStringAsFixed(0)} km/h', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],

        // ─── Previsión diaria ────────────────────────────
        const SizedBox(height: 20),
        const Text('Próximos días', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...prevision.dias.map((dia) {
          final esHoy = dia.fecha.day == hoy.day &&
              dia.fecha.month == hoy.month &&
              dia.fecha.year == hoy.year;
          final etiqueta = esHoy ? 'Hoy' : formatoDia.format(dia.fecha);
          return Card(
            margin: const EdgeInsets.only(bottom: 4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(children: [
                SizedBox(width: 50, child: Text(etiqueta, style: const TextStyle(fontWeight: FontWeight.bold))),
                Text(dia.icono, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(child: Text(dia.descripcion, style: const TextStyle(fontSize: 13))),
                Text('${dia.tempMax.toStringAsFixed(0)}°', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(width: 4),
                Text('${dia.tempMin.toStringAsFixed(0)}°', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(width: 8),
                Text('${dia.precipitacionMm.toStringAsFixed(1)} mm', style: TextStyle(fontSize: 11, color: Colors.blue.shade700)),
              ]),
            ),
          );
        }),
        const SizedBox(height: 24),
        Text(
          'Datos: Open-Meteo (gratuito, sin API key)',
          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _datoMeteo(String emoji, String valor) => Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 4),
        Text(valor, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ]);
}
