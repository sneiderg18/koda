import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class AuthService {
  static const _keyAccess = 'access_token';
  static const _keyRefresh = 'refresh_token';
  static const _keyUsername = 'username';
  // Nueva clave: guardamos si el onboarding fue completado
  static const _keyOnboarding = 'onboarding_done';

  // ── GUARDAR TOKEN ──────────────────────────────────────────────────────────
  static Future<void> saveTokens({
    required String access,
    required String? refresh,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccess, access);
    if (refresh != null) await prefs.setString(_keyRefresh, refresh);
  }

  // ── GUARDAR USERNAME ───────────────────────────────────────────────────────
  static Future<void> saveUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUsername, username);
  }

  // ── OBTENER USERNAME ───────────────────────────────────────────────────────
  static Future<String> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUsername) ?? 'Usuario';
  }

  // ── OBTENER TOKEN DE ACCESO ────────────────────────────────────────────────
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAccess);
  }

  // ── MARCAR ONBOARDING COMO COMPLETADO ─────────────────────────────────────
  static Future<void> setOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboarding, true);
  }

  // ── VERIFICAR SI EL ONBOARDING ESTÁ COMPLETO ──────────────────────────────
  /// Primero revisa la caché local; si no hay dato, consulta /api/perfil/
  /// y considera completo si el campo `peso` (o `edad`) no es null.
  static Future<bool> isOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Caché local (evita llamada de red si ya sabemos que está hecho)
    if (prefs.getBool(_keyOnboarding) == true) return true;

    // 2. Consultar el servidor
    try {
      final token = prefs.getString(_keyAccess);
      if (token == null) return false;

      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/perfil/'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
          'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        // Consideramos que el onboarding está completo si `peso` o `edad` no son nulos
        final bool done = data['peso'] != null || data['edad'] != null;
        if (done) await prefs.setBool(_keyOnboarding, true); // cachear
        return done;
      }
    } catch (_) {}

    return false;
  }

  // ── CERRAR SESIÓN ──────────────────────────────────────────────────────────
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccess);
    await prefs.remove(_keyRefresh);
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyOnboarding); // limpiar también el flag
  }

  // ── LOGIN ──────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/login/');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
      body: jsonEncode({'email': email, 'password': password}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      final accessToken = data['access'] ?? '';
      await saveTokens(access: accessToken, refresh: data['refresh']);

      // Intentar obtener el username real desde /api/perfil/
      bool onboardingDone = false;
      try {
        final perfilRes = await http.get(
          Uri.parse('${ApiConfig.baseUrl}/api/perfil/'),
          headers: {
            'Content-Type': 'application/json',
            'ngrok-skip-browser-warning': 'true',
            'Authorization': 'Bearer $accessToken',
          },
        );
        if (perfilRes.statusCode == 200) {
          final perfil = jsonDecode(perfilRes.body);

          // Guardar username
          final username = perfil['username'] ?? perfil['user']?['username'];
          if (username != null && username.toString().isNotEmpty) {
            await saveUsername(username.toString());
          } else {
            await saveUsername(email.split('@').first);
          }

          // Determinar si el onboarding está hecho
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
      return {'success': false, 'message': mensaje};
    }
  }

  // ── REGISTRO ───────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> registro({
    required String email,
    required String username,
    required String password1,
    required String password2,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/registro/');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
      body: jsonEncode({
        'email': email,
        'username': username,
        'password1': password1,
        'password2': password2,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      if (data['access'] != null) {
        await saveTokens(
          access: data['access'] ?? '',
          refresh: data['refresh'],
        );
      }
      await saveUsername(username);
      // Usuario nuevo → onboarding NO hecho todavía
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

  // ── OBTENER PERFIL ─────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getPerfil() async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/perfil/');

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return {'success': true, 'data': jsonDecode(response.body)};
    }
    return {'success': false, 'message': 'No se pudo obtener el perfil'};
  }
}
