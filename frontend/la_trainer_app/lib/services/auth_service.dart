import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class AuthService {
  static const _keyAccess = 'access_token';
  static const _keyRefresh = 'refresh_token';

  // ── GUARDAR TOKEN ──────────────────────────────────────────────────────────
  static Future<void> saveTokens({
    required String access,
    required String? refresh,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccess, access);
    if (refresh != null) await prefs.setString(_keyRefresh, refresh);
  }

  // ── OBTENER TOKEN DE ACCESO ────────────────────────────────────────────────
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAccess);
  }

  // ── CERRAR SESIÓN ──────────────────────────────────────────────────────────
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccess);
    await prefs.remove(_keyRefresh);
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
      // Guarda los tokens automáticamente
      await saveTokens(access: data['access'] ?? '', refresh: data['refresh']);
      return {'success': true, 'data': data};
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
  /*static Future<Map<String, dynamic>> getPerfil() async {
    final token = await getToken();
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
  */
}
