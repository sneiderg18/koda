import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class AuthService {
  static const _keyAccess     = 'access_token';
  static const _keyRefresh    = 'refresh_token';
  static const _keyUsername   = 'username';
  static const _keyOnboarding = 'onboarding_done';

  // ── Headers ───────────────────────────────────────────────
  // Header ngrok eliminado — ya no aplica con Railway
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

  // ── TOKEN VÁLIDO (refresca automáticamente si expiró) ─────
  static Future<String?> getValidToken() async {
    final prefs = await SharedPreferences.getInstance();
    final access  = prefs.getString(_keyAccess);
    final refresh = prefs.getString(_keyRefresh);

    if (access == null) return null;

    try {
      final testRes = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/api/perfil/'),
            headers: _authHeaders(access),
          )
          .timeout(const Duration(seconds: 6));

      if (testRes.statusCode == 200) return access;
      if (testRes.statusCode == 401 && refresh != null) {
        return await _refreshToken(refresh);
      }
    } catch (_) {
      return access;
    }

    return null;
  }

  // ── REFRESCAR TOKEN ───────────────────────────────────────
  static Future<String?> _refreshToken(String refresh) async {
    try {
      final res = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/token/refresh/'),
            headers: _baseHeaders,
            body: jsonEncode({'refresh': refresh}),
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data       = jsonDecode(res.body);
        final newAccess  = data['access']  as String?;
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

      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/perfil/'),
        headers: _authHeaders(token),
      );

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
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/login/'),
      headers: _baseHeaders,
      body: jsonEncode({'email': email, 'password': password}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      final accessToken  = data['access']  ?? '';
      final refreshToken = data['refresh'] as String?;
      await saveTokens(access: accessToken, refresh: refreshToken);

      bool onboardingDone = false;
      try {
        final perfilRes = await http.get(
          Uri.parse('${ApiConfig.baseUrl}/api/perfil/'),
          headers: _authHeaders(accessToken),
        );
        if (perfilRes.statusCode == 200) {
          final perfil   = jsonDecode(perfilRes.body);
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

      return {
        'success': true,
        'data': data,
        'onboarding_done': onboardingDone,
      };
    } else {
      final mensaje =
          data['detail'] ??
          data['message'] ??
          data['error'] ??
          'Credenciales inválidas';
      return {'success': false, 'message': mensaje};
    }
  }

  // ── REGISTRO ──────────────────────────────────────────────
  static Future<Map<String, dynamic>> registro({
    required String email,
    required String username,
    required String password1,
    required String password2,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/registro/'),
      headers: _baseHeaders,
      body: jsonEncode({
        'email':     email,
        'username':  username,
        'password1': password1,
        'password2': password2,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      if (data['access'] != null) {
        await saveTokens(
          access:  data['access']  ?? '',
          refresh: data['refresh'],
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
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/perfil/'),
      headers: _authHeaders(token ?? ''),
    );

    if (response.statusCode == 200) {
      return {'success': true, 'data': jsonDecode(response.body)};
    }
    return {'success': false, 'message': 'No se pudo obtener el perfil'};
  }

  // ── REGISTRAR ACCESO DIARIO ───────────────────────────────
  static Future<void> registrarAcceso() async {
    try {
      final token = await getToken();
      if (token == null) return;

      await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/acceso/'),
            headers: _authHeaders(token),
          )
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      // Fire-and-forget: si falla no bloquea el arranque
    }
  }
}