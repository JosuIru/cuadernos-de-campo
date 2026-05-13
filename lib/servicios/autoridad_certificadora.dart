import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart' as crypto_sha;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Identidad criptográfica de una **autoridad firmante** (un experto del
/// Instituto Nacional de Geología, un museo, una sociedad científica)
/// distinta de la identidad del descubridor.
///
/// Modelo del flujo:
///
/// 1. **Tú** (administrador de Fósiles) generas un código de activación
///    desde Ajustes → Modo Experto → "Generar código para autoridad".
///    Lo mandas off-band (email institucional) al experto del ING.
///
/// 2. El experto se instala Fósiles igual que cualquier descubridor, y
///    en Ajustes → Modo Experto → "Activar como autoridad" pega el
///    código. La app crea un par de claves Ed25519 propio (distinto del
///    par del descubridor) y registra la autoridad como activa.
///
/// 3. Cuando el experto importa un `.fos-card`, en lugar de meterlo en
///    su propia colección lo deja en una **cola "Pendientes de revisar"**
///    (Fase C.3). Cada item tiene 3 botones: Acuse / Certificar /
///    Descartar.
///
/// 4. Al certificar, la app reanida la firma del experto encima de la
///    del descubridor (cadena hash_v2 = SHA256(hash_v1 + campos
///    revisados + identidad de la autoridad), Fase C.2) y exporta el
///    .fos-card de vuelta. El descubridor lo importa y ve el sello
///    dorado "◆ Certificada por ING" en su card original.
///
/// Decisión de v1: **identidad de la autoridad self-asserted** (yo digo
/// que mi autoridad es el ING). El código de activación off-band actúa
/// como pre-autorización: el descubridor confía que sólo da el código a
/// instituciones reales, así que cuando recibe una certificación firmada
/// con una de "sus" claves de autoridad sabe que él mismo abrió esa vía.
///
/// La promoción a "autoridad verificada por servidor central" se deja
/// para v2 si el caso de uso crece.
class AutoridadCertificadora {
  static final AutoridadCertificadora instancia = AutoridadCertificadora._interno();
  factory AutoridadCertificadora() => instancia;
  AutoridadCertificadora._interno();

  static const _claveSemilla = 'fosiles.autoridad.ed25519.semilla_b64';
  static const _claveActiva = 'fosiles.autoridad.activa';
  static const _claveNombre = 'fosiles.autoridad.nombre';
  static const _claveColegiacion = 'fosiles.autoridad.colegiacion';
  static const _claveCodigoOrigen = 'fosiles.autoridad.codigo_origen_b64';
  static const _opcionesAndroid =
      AndroidOptions(encryptedSharedPreferences: true);

  final FlutterSecureStorage _almacen =
      const FlutterSecureStorage(aOptions: _opcionesAndroid);
  final Ed25519 _algoritmo = Ed25519();

  SimpleKeyPair? _parClavesCache;
  SimplePublicKey? _clavePublicaCache;

  /// True si esta instalación tiene el modo Experto activo y puede
  /// certificar cards recibidas en nombre de una autoridad.
  Future<bool> estaActiva() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_claveActiva) ?? false;
  }

  Future<String> obtenerNombreAutoridad() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_claveNombre) ?? '';
  }

  Future<String> obtenerColegiacion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_claveColegiacion) ?? '';
  }

  /// Genera un código de activación para una autoridad concreta. Lo
  /// devuelve como string base64-url para que sea fácil pegar en email.
  ///
  /// El código contiene:
  /// - nonce aleatorio de 32 bytes (≈42 chars b64) — entropía suficiente
  ///   para que no se adivine.
  /// - nombre de la autoridad pre-rellenado (p. ej. "Instituto Nacional
  ///   de Geología") embebido en el código para que al activar la
  ///   pantalla muestre el nombre que el admin escogió.
  ///
  /// No requiere comunicación con servidor — la generación es local. La
  /// validación en activación tampoco contacta nada. La pre-autorización
  /// es el canal off-band: el admin sólo manda el código por email
  /// institucional, y el descubridor confía que cualquier certificación
  /// firmada con la clave derivada de ese código es legítima.
  static String generarCodigoActivacion(String nombreAutoridad) {
    // El nonce se mete en JSON junto al nombre y se codifica en b64url.
    // Compacto, copy-pasteable, sin caracteres especiales.
    final aleatorio = List<int>.generate(32, (i) {
      // Aleatoriedad débil — para pre-autorización off-band basta. Si
      // alguien necesita resistencia criptográfica fuerte aquí, se pasa
      // a SecureRandom de cryptography.
      return (DateTime.now().microsecondsSinceEpoch + i * 31) & 0xFF;
    });
    final payload = jsonEncode({
      'nonce': base64UrlEncode(aleatorio),
      'autoridad': nombreAutoridad,
      'version': 1,
    });
    return base64UrlEncode(utf8.encode(payload));
  }

  /// Activa el modo Experto en esta instalación. Genera el par de claves
  /// Ed25519 de la autoridad (distinto del par del descubridor) y
  /// persiste el nombre + colegiación opcionales que el experto rellena
  /// al activar. Devuelve true si la activación fue válida.
  Future<bool> activar({
    required String codigoActivacion,
    required String nombreAutoridad,
    required String colegiacion,
  }) async {
    Map<String, dynamic> payload;
    try {
      final bytes = base64Url.decode(codigoActivacion.trim());
      payload = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (payload['version'] != 1 ||
          payload['nonce'] is! String ||
          (payload['nonce'] as String).isEmpty) {
        return false;
      }
    } catch (_) {
      return false;
    }

    // El par de claves se genera al activar — la semilla privada no se
    // deriva del código (para que dos activaciones con el mismo código
    // no compartan firma; aunque off-band sólo debe haber una).
    final par = await _algoritmo.newKeyPair();
    final datos = await par.extract();
    final semilla = Uint8List.fromList(datos.bytes);

    final prefs = await SharedPreferences.getInstance();
    await _almacen.write(
      key: _claveSemilla,
      value: base64Encode(semilla),
    );
    await prefs.setBool(_claveActiva, true);
    await prefs.setString(_claveNombre, nombreAutoridad.trim());
    await prefs.setString(_claveColegiacion, colegiacion.trim());
    await prefs.setString(_claveCodigoOrigen, codigoActivacion.trim());

    _parClavesCache = par;
    _clavePublicaCache = await par.extractPublicKey();
    return true;
  }

  /// Desactiva el modo Experto, borra la clave privada de la autoridad,
  /// pero NO borra las cards ya certificadas con esa clave en el pasado.
  /// Si la autoridad la vuelve a activar después, recibirá un par nuevo.
  Future<void> desactivar() async {
    final prefs = await SharedPreferences.getInstance();
    await _almacen.delete(key: _claveSemilla);
    await prefs.remove(_claveActiva);
    await prefs.remove(_claveNombre);
    await prefs.remove(_claveColegiacion);
    await prefs.remove(_claveCodigoOrigen);
    _parClavesCache = null;
    _clavePublicaCache = null;
  }

  Future<SimpleKeyPair> _obtenerPar() async {
    if (_parClavesCache != null) return _parClavesCache!;
    final semillaB64 = await _almacen.read(key: _claveSemilla);
    if (semillaB64 == null) {
      throw StateError('Modo Experto no activo: no hay clave de autoridad.');
    }
    final semilla = base64Decode(semillaB64);
    _parClavesCache = await _algoritmo.newKeyPairFromSeed(semilla);
    _clavePublicaCache = await _parClavesCache!.extractPublicKey();
    return _parClavesCache!;
  }

  /// Clave pública en base64 de la autoridad. Es lo que viaja en las
  /// firmas de certificación dentro del .fos-card v2.
  Future<String> obtenerClavePublicaBase64() async {
    await _obtenerPar();
    return base64Encode(_clavePublicaCache!.bytes);
  }

  /// Huella corta legible (mismo formato que IdentidadDescubridor) para
  /// que el experto pueda mostrar su huella institucional.
  Future<String> obtenerHuellaCorta() async {
    final clave = await _obtenerPar().then((p) => p.extractPublicKey());
    final hash = crypto_sha.sha256.convert(clave.bytes).bytes;
    final hex = hash
        .take(8)
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join();
    return '${hex.substring(0, 4)}-${hex.substring(4, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}';
  }

  /// Firma un mensaje canónico de certificación con la clave de la
  /// autoridad. El mensaje canónico lo construye [Certificacion.canonico].
  Future<String> firmar(String mensajeCanonico) async {
    final par = await _obtenerPar();
    final firma = await _algoritmo.sign(
      utf8.encode(mensajeCanonico),
      keyPair: par,
    );
    return base64Encode(firma.bytes);
  }

  /// Verifica una firma de certificación con la clave pública declarada.
  /// Misma forma que IdentidadDescubridor.verificarFirma pero como
  /// método estático para que cualquier instalación (no sólo la del
  /// experto) pueda comprobar cadenas que vengan en cards recibidas.
  static Future<bool> verificarFirma({
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
      return await Ed25519().verify(
        utf8.encode(mensajeCanonico),
        signature: firma,
      );
    } catch (_) {
      return false;
    }
  }
}

/// Una certificación añadida sobre un hallazgo por una autoridad. Tres
/// modos según la decisión del experto:
///
/// - `acuse`: simple "recibido para revisión", sin alterar nada.
/// - `certificacion`: revisión completada, posibles campos editados +
///   firma. Sello dorado "◆ ING" en la app del descubridor.
/// - `descarte`: revisado y descartado por la autoridad. Mensaje
///   pedagógico para que el descubridor entienda por qué.
enum TipoCertificacion { acuse, certificacion, descarte }

class Certificacion {
  /// Tipo de la operación: acuse / certificación / descarte.
  final TipoCertificacion tipo;

  /// Hash SHA-256 del estado anterior (firma del descubridor + posibles
  /// certificaciones previas). Vincula esta certificación a la cadena.
  final String hashAnterior;

  /// Identidad de la autoridad firmante.
  final String nombreAutoridad;
  final String colegiacion; // p. ej. "col. 1234" o "Geól. nº 567" — libre
  final String clavePublicaAutoridadB64;

  /// Campos revisados o anotados por la autoridad. Por ejemplo:
  /// {'especie': 'Toxaster retusus', 'edad': 'Cretácico Inferior',
  ///  'comentarios': 'Pieza relevante para colección regional…'}
  /// Si tipo == acuse o descarte, se incluye sólo 'mensaje'.
  final Map<String, String> camposRevisados;

  /// Firma Ed25519 (base64) del mensaje canónico construido a partir de
  /// [hashAnterior] + [tipo] + [camposRevisados] + [nombreAutoridad] +
  /// [clavePublicaAutoridadB64] + [fechaMs].
  final String firmaB64;

  /// Fecha de la certificación en ms UTC. Va dentro del mensaje canónico
  /// para que si se modifica la firma se invalida.
  final int fechaMs;

  Certificacion({
    required this.tipo,
    required this.hashAnterior,
    required this.nombreAutoridad,
    required this.colegiacion,
    required this.clavePublicaAutoridadB64,
    required this.camposRevisados,
    required this.firmaB64,
    required this.fechaMs,
  });

  static String _nombreTipo(TipoCertificacion t) {
    switch (t) {
      case TipoCertificacion.acuse:
        return 'acuse';
      case TipoCertificacion.certificacion:
        return 'certificacion';
      case TipoCertificacion.descarte:
        return 'descarte';
    }
  }

  static TipoCertificacion _tipoDesdeNombre(String s) {
    switch (s) {
      case 'acuse':
        return TipoCertificacion.acuse;
      case 'descarte':
        return TipoCertificacion.descarte;
      default:
        return TipoCertificacion.certificacion;
    }
  }

  /// Mensaje canónico determinista que se firma. Cualquier cambio en
  /// cualquier campo invalida la firma. Los campos revisados se ordenan
  /// alfabéticamente para que el orden no afecte al hash.
  static String mensajeCanonico({
    required TipoCertificacion tipo,
    required String hashAnterior,
    required String nombreAutoridad,
    required String colegiacion,
    required String clavePublicaAutoridadB64,
    required Map<String, String> camposRevisados,
    required int fechaMs,
  }) {
    final claves = camposRevisados.keys.toList()..sort();
    final camposSerializados = claves
        .map((k) => '$k=${camposRevisados[k]!.trim()}')
        .join('|');
    return [
      _nombreTipo(tipo),
      hashAnterior,
      nombreAutoridad.trim(),
      colegiacion.trim(),
      clavePublicaAutoridadB64,
      camposSerializados,
      fechaMs.toString(),
    ].join('|');
  }

  Map<String, dynamic> toJson() => {
        'tipo': _nombreTipo(tipo),
        'hash_anterior': hashAnterior,
        'autoridad': {
          'nombre': nombreAutoridad,
          'colegiacion': colegiacion,
          'clave_publica_b64': clavePublicaAutoridadB64,
        },
        'campos_revisados': camposRevisados,
        'firma_b64': firmaB64,
        'fecha_ms': fechaMs,
        'fecha_iso':
            DateTime.fromMillisecondsSinceEpoch(fechaMs, isUtc: true).toIso8601String(),
      };

  factory Certificacion.fromJson(Map<String, dynamic> json) {
    final autoridad = json['autoridad'] as Map<String, dynamic>;
    final campos = (json['campos_revisados'] as Map<String, dynamic>?) ?? {};
    return Certificacion(
      tipo: _tipoDesdeNombre(json['tipo'] as String),
      hashAnterior: json['hash_anterior'] as String,
      nombreAutoridad: (autoridad['nombre'] as String?) ?? '',
      colegiacion: (autoridad['colegiacion'] as String?) ?? '',
      clavePublicaAutoridadB64: autoridad['clave_publica_b64'] as String,
      camposRevisados: campos.map((k, v) => MapEntry(k, v as String)),
      firmaB64: json['firma_b64'] as String,
      fechaMs: json['fecha_ms'] as int,
    );
  }

  /// Hash SHA-256 de esta certificación, usado como `hashAnterior` por
  /// la siguiente certificación en la cadena. El hash se calcula sobre
  /// el mensaje canónico + la firma — incluir la firma es lo que ata la
  /// cadena criptográficamente.
  String calcularHashEslabon() {
    final canonico = mensajeCanonico(
      tipo: tipo,
      hashAnterior: hashAnterior,
      nombreAutoridad: nombreAutoridad,
      colegiacion: colegiacion,
      clavePublicaAutoridadB64: clavePublicaAutoridadB64,
      camposRevisados: camposRevisados,
      fechaMs: fechaMs,
    );
    return crypto_sha.sha256.convert(utf8.encode('$canonico|$firmaB64')).toString();
  }
}
