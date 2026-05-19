import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart' as crypto_sha;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../modelos/hallazgo.dart';

/// Identidad criptográfica del descubridor.
///
/// Cada instalación de Fósiles genera un par de claves Ed25519 al primer uso.
/// La clave privada se guarda en Android Keystore vía flutter_secure_storage
/// (no sale del dispositivo). La clave pública es la huella permanente y
/// compartible del usuario: cuando exporta una card o firma un hallazgo, va
/// la pública para que cualquier app receptora pueda verificar offline que
/// la firma cuadra con los datos y con la identidad declarada.
///
/// Identidad "self-asserted" en v1: el nombre/email que el usuario rellena
/// no está autenticado contra una autoridad externa. Pero la **clave pública**
/// sí es única y permanente; dos cards firmadas con la misma clave vienen
/// demostrablemente de la misma instalación. La promoción a "identidad
/// institucionalmente verificada" llegará en Fase C cuando el ING firme
/// encima la clave del descubridor.
class IdentidadDescubridor {
  static final IdentidadDescubridor instancia = IdentidadDescubridor._interno();
  factory IdentidadDescubridor() => instancia;
  IdentidadDescubridor._interno();

  static const _claveStorage = 'fosiles.identidad.ed25519.privada_b64';
  static const _claveStoragePublica = 'fosiles.identidad.ed25519.publica_b64';

  static const _opcionesAndroid = AndroidOptions(encryptedSharedPreferences: true);
  final FlutterSecureStorage _almacen = const FlutterSecureStorage(aOptions: _opcionesAndroid);
  final Ed25519 _algoritmo = Ed25519();

  SimpleKeyPair? _parClavesCache;
  SimplePublicKey? _clavePublicaCache;

  /// Carga (o genera la primera vez) el par de claves Ed25519 del dispositivo.
  ///
  /// La clave privada vive cifrada bajo el Keystore Android; la pública además
  /// la cacheamos también en el storage para evitar derivarla en cada arranque.
  Future<SimpleKeyPair> obtenerParClaves() async {
    if (_parClavesCache != null) return _parClavesCache!;

    final privadaB64 = await _almacen.read(key: _claveStorage);
    if (privadaB64 != null && privadaB64.isNotEmpty) {
      final bytesPrivada = base64Decode(privadaB64);
      _parClavesCache = await _algoritmo.newKeyPairFromSeed(bytesPrivada);
      _clavePublicaCache = await _parClavesCache!.extractPublicKey();
      return _parClavesCache!;
    }

    final nuevo = await _algoritmo.newKeyPair();
    final semilla = await _extraerSemilla(nuevo);
    await _almacen.write(key: _claveStorage, value: base64Encode(semilla));
    final publica = await nuevo.extractPublicKey();
    await _almacen.write(
      key: _claveStoragePublica,
      value: base64Encode(publica.bytes),
    );
    _parClavesCache = nuevo;
    _clavePublicaCache = publica;
    return nuevo;
  }

  /// Clave pública en bytes — segura de compartir.
  Future<SimplePublicKey> obtenerClavePublica() async {
    if (_clavePublicaCache != null) return _clavePublicaCache!;
    await obtenerParClaves();
    return _clavePublicaCache!;
  }

  /// Huella corta legible de la clave pública: primeros 16 bytes hex en
  /// grupos de 4. Útil para mostrar en UI y comparar visualmente.
  /// Ejemplo: "A3F2-9B1C-DD04-7E8A"
  Future<String> obtenerHuellaCorta() async {
    final publica = await obtenerClavePublica();
    final hash = crypto_sha.sha256.convert(publica.bytes).bytes;
    final hex = hash
        .take(8)
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join();
    return '${hex.substring(0, 4)}-${hex.substring(4, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}';
  }

  /// Clave pública en formato base64 — listo para serializar a JSON al
  /// exportar una card o un hallazgo firmado.
  Future<String> obtenerClavePublicaBase64() async {
    final publica = await obtenerClavePublica();
    return base64Encode(publica.bytes);
  }

  /// Firma una cadena canónica (típicamente el hash SHA-256 del hallazgo)
  /// con la clave privada. Devuelve la firma en base64.
  Future<String> firmar(String mensajeCanonico) async {
    final par = await obtenerParClaves();
    final firma = await _algoritmo.sign(
      utf8.encode(mensajeCanonico),
      keyPair: par,
    );
    return base64Encode(firma.bytes);
  }

  /// Verifica una firma con la clave pública asociada. Útil para confirmar
  /// que un hallazgo importado de un .fos-card lo firmó la clave declarada.
  Future<bool> verificarFirma({
    required String mensajeCanonico,
    required String firmaBase64,
    required String clavePublicaBase64,
  }) async {
    try {
      final publica = SimplePublicKey(
        base64Decode(clavePublicaBase64),
        type: KeyPairType.ed25519,
      );
      final firma = Signature(base64Decode(firmaBase64), publicKey: publica);
      return await _algoritmo.verify(
        utf8.encode(mensajeCanonico),
        signature: firma,
      );
    } catch (_) {
      return false;
    }
  }

  /// Calcula el mensaje canónico (cadena determinista) sobre el que se
  /// firma un hallazgo. Cualquier campo aquí que cambie invalida la firma.
  ///
  /// Mismos campos que `calcularHashHallazgo` para preservar la
  /// trazabilidad del certificado v1.0 existente, en el mismo orden y
  /// usando el mismo separador "|". Si cambia esta función, hay que
  /// versionarla y mantener la antigua para verificar firmas viejas.
  static String mensajeCanonicoHallazgo(Hallazgo h, String nombreDescubridor) {
    return [
      h.latitud.toStringAsFixed(6),
      h.longitud.toStringAsFixed(6),
      h.fechaMs.toString(),
      h.especie.trim(),
      h.edad.trim(),
      h.formacion.trim(),
      h.tipo,
      nombreDescubridor.trim(),
    ].join('|');
  }

  /// Regenera el par de claves desde cero (botón "Regenerar identidad" en
  /// Ajustes). Operación destructiva: todas las firmas previas dejan de
  /// poder verificarse contra la nueva clave pública.
  Future<void> regenerar() async {
    await _almacen.delete(key: _claveStorage);
    await _almacen.delete(key: _claveStoragePublica);
    _parClavesCache = null;
    _clavePublicaCache = null;
    await obtenerParClaves();
  }

  /// Exporta la clave privada como semilla en base64 para incluirla en el
  /// backup .zip cifrado. El receptor del backup la restaura llamando a
  /// [importarSemilla]. Atención: cualquiera con la semilla puede firmar
  /// en nombre del descubridor.
  Future<String> exportarSemillaBase64() async {
    final par = await obtenerParClaves();
    final semilla = await _extraerSemilla(par);
    return base64Encode(semilla);
  }

  /// Restaura la identidad desde una semilla previamente exportada
  /// (típicamente al importar un backup .zip).
  Future<void> importarSemilla(String semillaBase64) async {
    final bytes = base64Decode(semillaBase64);
    final par = await _algoritmo.newKeyPairFromSeed(bytes);
    final publica = await par.extractPublicKey();
    await _almacen.write(key: _claveStorage, value: base64Encode(bytes));
    await _almacen.write(
      key: _claveStoragePublica,
      value: base64Encode(publica.bytes),
    );
    _parClavesCache = par;
    _clavePublicaCache = publica;
  }

  Future<Uint8List> _extraerSemilla(SimpleKeyPair par) async {
    final datos = await par.extract();
    return Uint8List.fromList(datos.bytes);
  }
}
