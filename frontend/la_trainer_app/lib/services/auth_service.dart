import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class AuthService {
  static const _keyAccess = 'access_token';
  static const _keyRefresh = 'refresh_token';
  static const _keyUsername = 'username';
  static const _keyOnboarding = 'onboarding_done';

  // ── Headers ───────────────────────────────────────────────
  static Map<String, String> get _baseHeaders => {
    'Content-Type': 'application/json',
  };

  static Map<String, String> _authHeaders(String token) => {
    ..._baseHeaders,
    'Authorization': 'Bearer $token',
  };

  // ── GUARDAR TOKENS ────────────────────────────────────────
  static Future<void> saveTokens({
    required String access,
    required String? refresh,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccess, access);
    if (refresh != null) await prefs.setString(_keyRefresh, refresh);
  }

  // ── USERNAME ──────────────────────────────────────────────
  static Future<void> saveUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUsername, username);
  }

  static Future<String> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUsername) ?? 'Usuario';
  }

  // ── TOKEN CRUDO ───────────────────────────────────────────
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAccess);
  }

  // ── TOKEN VÁLIDO (valida localmente el JWT, refresca si expiró) ──────────
  // Decodifica el JWT localmente (sin verificar firma, solo el exp)
  // para ver si expiró, evitando una petición HTTP innecesaria.
  static Future<String?> getValidToken() async {
    final prefs = await SharedPreferences.getInstance();
    final access = prefs.getString(_keyAccess);
    final refresh = prefs.getString(_keyRefresh);

    if (access == null) return null;

    if (!_isTokenExpired(access)) return access;

    // Expiró → intentar refrescar
    if (refresh != null) {
      return await _refreshToken(refresh);
    }

    return null; // sesión inválida sin posibilidad de refrescar
  }

  /// Decodifica el payload del JWT y comprueba si ya expiró.
  /// No verifica la firma (eso lo hace el servidor), solo el campo `exp`.
  static bool _isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;

      // Base64url → Base64 estándar
      String payload = parts[1];
      payload = payload.replaceAll('-', '+').replaceAll('_', '/');
      // Padding
      while (payload.length % 4 != 0) {
        payload += '=';
      }

      final decoded = utf8.decode(base64Decode(payload));
      final map = jsonDecode(decoded) as Map<String, dynamic>;
      final exp = map['exp'] as int?;
      if (exp == null) return false;

      final expDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      // Considera expirado 30 s antes para evitar race conditions
      return DateTime.now().isAfter(
        expDate.subtract(const Duration(seconds: 30)),
      );
    } catch (_) {
      return true; // Si no se puede parsear, asumir expirado
    }
  }

  // ── REFRESCAR TOKEN ───────────────────────────────────────
  static Future<String?> _refreshToken(String refresh) async {
    try {
      final res = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/token/refresh/'),
            headers: {
              'Content-Type': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
            body: jsonEncode({'refresh': refresh}),
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final newAccess = data['access'] as String?;
        final newRefresh = data['refresh'] as String?;
        if (newAccess != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_keyAccess, newAccess);
          if (newRefresh != null) {
            await prefs.setString(_keyRefresh, newRefresh);
          }
          return newAccess;
        }
      }
    } catch (_) {}
    return null;
  }

  // ── ONBOARDING ────────────────────────────────────────────
  static Future<void> setOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboarding, true);
  }

  static Future<bool> isOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_keyOnboarding) == true) return true;

    try {
      final token = prefs.getString(_keyAccess);
      if (token == null) return false;

      final res = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/api/perfil/'),
            headers: _authHeaders(token),
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final bool done = data['peso'] != null || data['edad'] != null;
        if (done) await prefs.setBool(_keyOnboarding, true);
        return done;
      }
    } catch (_) {}

    return false;
  }

  // ── CERRAR SESIÓN ─────────────────────────────────────────
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccess);
    await prefs.remove(_keyRefresh);
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyOnboarding);
  }

  // ── LOGIN ─────────────────────────────────────────────────
  // Envuelto en try/catch con timeout para evitar que el spinner
  // quede girando infinitamente si no hay red o el servidor no responde.
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    http.Response response;

    try {
      response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/login/'),
            headers: _baseHeaders,
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 12));
    } catch (e) {
      return {
        'success': false,
        'message': 'No se pudo conectar con el servidor. Verifica tu conexión.',
      };
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      return {
        'success': false,
        'message': 'Respuesta inesperada del servidor.',
      };
    }

    if (response.statusCode == 200) {
      final accessToken = data['access'] as String? ?? '';
      final refreshToken = data['refresh'] as String?;

      if (accessToken.isEmpty) {
        return {
          'success': false,
          'message': 'El servidor no devolvió un token.',
        };
      }

      await saveTokens(access: accessToken, refresh: refreshToken);

      bool onboardingDone = false;
      try {
        final perfilRes = await http
            .get(
              Uri.parse('${ApiConfig.baseUrl}/api/perfil/'),
              headers: _authHeaders(accessToken),
            )
            .timeout(const Duration(seconds: 8));

        if (perfilRes.statusCode == 200) {
          final perfil = jsonDecode(perfilRes.body);
          final username = perfil['username'] ?? perfil['user']?['username'];
          if (username != null && username.toString().isNotEmpty) {
            await saveUsername(username.toString());
          } else {
            await saveUsername(email.split('@').first);
          }
          onboardingDone = perfil['peso'] != null || perfil['edad'] != null;
          if (onboardingDone) await setOnboardingDone();
        } else {
          await saveUsername(email.split('@').first);
        }
      } catch (_) {
        await saveUsername(email.split('@').first);
      }

      return {'success': true, 'data': data, 'onboarding_done': onboardingDone};
    } else {
      final mensaje =
          data['detail'] ??
          data['message'] ??
          data['error'] ??
          'Credenciales inválidas';
      return {'success': false, 'message': mensaje.toString()};
    }
  }

  // ── REGISTRO ──────────────────────────────────────────────
  static Future<Map<String, dynamic>> registro({
    required String email,
    required String username,
    required String password1,
    required String password2,
  }) async {
    http.Response response;

    try {
      response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/registro/'),
            headers: _baseHeaders,
            body: jsonEncode({
              'email': email,
              'username': username,
              'password1': password1,
              'password2': password2,
              'acepto_terminos': true,
            }),
          )
          .timeout(const Duration(seconds: 12));
    } catch (e) {
      return {
        'success': false,
        'message': 'No se pudo conectar con el servidor. Verifica tu conexión.',
      };
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      return {
        'success': false,
        'message': 'Respuesta inesperada del servidor.',
      };
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      if (data['access'] != null) {
        await saveTokens(
          access: data['access'] as String? ?? '',
          refresh: data['refresh'] as String?,
        );
      }
      await saveUsername(username);
      return {'success': true, 'data': data};
    } else {
      String mensaje = 'Error al registrarse';
      if (data is Map) {
        final firstVal = data.values.firstWhere(
          (v) => v != null,
          orElse: () => null,
        );
        if (firstVal is List && firstVal.isNotEmpty) {
          mensaje = firstVal.first.toString();
        } else if (firstVal is String) {
          mensaje = firstVal;
        }
      }
      return {'success': false, 'message': mensaje};
    }
  }

  // ── OBTENER PERFIL ────────────────────────────────────────
  static Future<Map<String, dynamic>> getPerfil() async {
    final token = await getToken();
    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/api/perfil/'),
            headers: _authHeaders(token ?? ''),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
    } catch (_) {}
    return {'success': false, 'message': 'No se pudo obtener el perfil'};
  }

  // ── REGISTRAR ACCESO DIARIO (racha y calendario) ──────────
  /// Llama a /api/acceso/ con el token actual. Se hace fire-and-forget:
  /// no bloquea el arranque si falla (sin red, token inválido, etc.).
  static Future<void> registrarAcceso() async {
    try {
      final token = await getToken();
      if (token == null) return;

      await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/acceso/'),
            headers: {
              'Content-Type': 'application/json',
              'ngrok-skip-browser-warning': 'true',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      // Si falla (sin red, 4xx, timeout) simplemente lo ignoramos.
      // La racha se actualizará la próxima vez que haya conexión.
    }
  }
}