import 'dart:io';
import 'package:flutter/material.dart';

/// Muestra una imagen desde archivo local con verificación de integridad.
/// Si el archivo no existe o está corrupto, muestra un fallback en vez
/// del icono roto por defecto.
class FotoSegura extends StatelessWidget {
  final String ruta;
  final double? height;
  final double? width;
  final BoxFit? fit;
  final Widget? fallback;

  const FotoSegura({
    super.key,
    required this.ruta,
    this.height,
    this.width,
    this.fit,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final fichero = File(ruta);
    if (!fichero.existsSync()) {
      return fallback ??
          Container(
            height: height,
            width: width,
            color: Colors.black12,
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image, color: Colors.grey),
          );
    }
    return Image.file(
      fichero,
      height: height,
      width: width,
      fit: fit ?? BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback ??
          Container(
            height: height,
            width: width,
            color: Colors.black12,
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image, color: Colors.grey),
          ),
    );
  }
}
