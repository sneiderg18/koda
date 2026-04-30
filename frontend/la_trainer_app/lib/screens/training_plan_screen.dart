import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'pantalla_detalles.dart';

const _kRed  = Color(0xFFD72105);
const _kBg   = Color(0xFF0D0D0D);
const _kCard = Color(0xFF1C1C1C);

class TrainingPlanScreen extends StatefulWidget {
  const TrainingPlanScreen({super.key});

  @override
  State<TrainingPlanScreen> createState() => _TrainingPlanScreenState();
}

class _TrainingPlanScreenState extends State<TrainingPlanScreen> {
  bool _loading   = true;
  bool _generando = false; // mientras la IA crea el plan
  String? _error;

  Map<String, dynamic>? _plan;
  List<dynamic> _ejercicios = [];

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  Future<void> _goToLogin() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _loadPlan() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthService.getValidToken();
      if (token == null) { await _goToLogin(); return; }

      final headers = {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
        'Authorization': 'Bearer $token',
      };

      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/planes/entrenamiento/activo/'),
        headers: headers,
      );

      if (!mounted) return;
      if (res.statusCode == 401) { await _goToLogin(); return; }

      if (res.statusCode == 200) {
        final body      = jsonDecode(res.body) as Map<String, dynamic>;
        final tienePlan = body['tiene_plan_activo'] == true;

        if (!tienePlan) {
          setState(() {
            _error   = 'Aún no tienes un plan de entrenamiento activo.\nHabla con el coach para generar uno.';
            _loading = false;
          });
          return;
        }

        final plan   = Map<String, dynamic>.from(body['plan'] as Map);
        final rutina = plan['rutina_ejercicios'];

        setState(() {
          _plan       = plan;
          _ejercicios = rutina is List ? List<dynamic>.from(rutina) : [];
          _loading    = false;
        });
      } else {
        setState(() {
          _error   = 'Error al cargar el plan (${res.statusCode})';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error   = 'No se pudo conectar con el servidor.';
          _loading = false;
        });
      }
    }
  }

  // ── Genera plan con IA ────────────────────────────────────────────────────
  Future<void> _generarPlan() async {
    setState(() => _generando = true);

    try {
      final token = await AuthService.getValidToken();
      if (token == null) { await _goToLogin(); return; }

      final headers = {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
        'Authorization': 'Bearer $token',
      };

      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/ia/plan/entrenamiento/'),
        headers: headers,
      );

      if (!mounted) return;

      if (res.statusCode == 201 || res.statusCode == 200) {
        // Plan generado — recargar la pantalla
        await _loadPlan();
      } else {
        final body = jsonDecode(res.body);
        final msg  = body['error'] ?? 'No se pudo generar el plan (${res.statusCode})';
        setState(() {
          _error    = msg.toString();
          _generando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error    = 'No se pudo conectar con el servidor.';
          _generando = false;
        });
      }
    }
  }

  // ── Inicia sesión en la API y luego navega ────────────────────────────────
  Future<void> _iniciarSesion() async {
    try {
      final token = await AuthService.getValidToken();
      if (token == null) { await _goToLogin(); return; }

      final headers = {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
        'Authorization': 'Bearer $token',
      };

      // Llama a /api/sesion/iniciar/ — si ya hay sesión abierta la reutiliza
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/sesion/iniciar/'),
        headers: headers,
      );

      if (!mounted) return;
      if (res.statusCode == 401) { await _goToLogin(); return; }

      if (res.statusCode == 200 || res.statusCode == 201) {
        // Sesión creada o retomada → ir a la pantalla de detalles
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PantallaDetalles()),
        );
      } else {
        final body = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(body['error'] ?? 'No se pudo iniciar la sesión'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo conectar con el servidor'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _duracionEstimada() => '${_ejercicios.length * 4} mins';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: _kRed))
                    : _error != null
                        ? _buildError()
                        : _buildBody(),
              ),
            ],
          ),

          // ── Botón EMPEZAR SESIÓN flotante ──────────────────────────
          if (!_loading && _error == null && _ejercicios.isNotEmpty)
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _iniciarSesion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kRed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 6,
                    shadowColor: _kRed.withOpacity(0.5),
                  ),
                  child: Text(
                    'EMPEZAR SESIÓN',
                    style: GoogleFonts.bebasNeue(
                      fontSize: 20,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Header rojo con título y botón HOME ───────────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: _kRed,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 14),
                    label: Text(
                      'HOME',
                      style: GoogleFonts.bebasNeue(
                        color: Colors.white,
                        fontSize: 15,
                        letterSpacing: 1.5,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white54),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded,
                        color: Colors.white, size: 22),
                    onPressed: _loadPlan,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'PLAN DE ENTRENAMIENTO',
                style: GoogleFonts.bebasNeue(
                  color: Colors.white,
                  fontSize: 26,
                  letterSpacing: 3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Lista principal ───────────────────────────────────────────────────────
  Widget _buildBody() {
    final tipo  = _plan?['tipo_entrenamiento'] ?? 'Entrenamiento';
    final nivel = _plan?['nivel']              ?? '';

    return RefreshIndicator(
      color: _kRed,
      backgroundColor: _kCard,
      onRefresh: _loadPlan,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        children: [
          Text(
            tipo.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.timer_outlined, color: _kRed, size: 16),
              const SizedBox(width: 6),
              Text(
                _duracionEstimada(),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              if (nivel.toString().isNotEmpty) ...[
                const SizedBox(width: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: _kRed.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    nivel.toString().toUpperCase(),
                    style: const TextStyle(
                      color: _kRed,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          ..._ejercicios.map((e) => _buildEjercicioTile(e)),
        ],
      ),
    );
  }

  // ── Tile individual de ejercicio ──────────────────────────────────────────
  Widget _buildEjercicioTile(dynamic ejercicio) {
    final nombre = ejercicio['nombre']        ?? 'Ejercicio';
    final series = ejercicio['series']        ?? 0;
    final reps   = ejercicio['repeticiones']  ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // Círculo placeholder imagen
          Container(
            width: 64,
            height: 64,
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey[850],
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.fitness_center_rounded,
                color: Colors.white24, size: 28),
          ),
          Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$series sets x $reps reps',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    nombre.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  // ── Pantalla de error ─────────────────────────────────────────────────────
  Widget _buildError() {
    final sinPlan = _error!.contains('plan');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              sinPlan
                  ? Icons.fitness_center_rounded
                  : Icons.cloud_off_rounded,
              size: 56,
              color: Colors.grey[700],
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white54, fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 24),

            // Si no tiene plan → botón para generar con IA
            if (sinPlan)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _generando ? null : _generarPlan,
                  icon: _generando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_rounded,
                          color: Colors.white, size: 20),
                  label: Text(
                    _generando ? 'Generando plan...' : 'GENERAR MI PLAN CON IA',
                    style: GoogleFonts.bebasNeue(
                      fontSize: 18,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kRed,
                    disabledBackgroundColor: _kRed.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    elevation: 6,
                    shadowColor: _kRed.withOpacity(0.5),
                  ),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: _loadPlan,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  elevation: 0,
                ),
              ),
          ],
        ),
      ),
    );
  }
}