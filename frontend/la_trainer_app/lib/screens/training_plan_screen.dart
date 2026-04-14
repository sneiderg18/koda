import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

const _kRed     = Color(0xFFD72105);
const _kBgLight = Color(0xFFF5F7FA);
const _kDark    = Color(0xFF1A1A2E);

class TrainingPlanScreen extends StatefulWidget {
  const TrainingPlanScreen({super.key});

  @override
  State<TrainingPlanScreen> createState() => _TrainingPlanScreenState();
}

class _TrainingPlanScreenState extends State<TrainingPlanScreen> {
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _detalle;
  List<dynamic> _ejercicios = [];

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  // ── Redirige al Login limpiando la sesión ─────────────────────────────────
  Future<void> _goToLogin() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  // ── Carga el plan completo ─────────────────────────────────────────────────
  Future<void> _loadPlan() async {
    setState(() {
      _loading = true;
      _error   = null;
    });

    try {
      // 1. Token válido (refresca automáticamente si expiró)
      final token = await AuthService.getValidToken();

      if (token == null) {
        await _goToLogin();
        return;
      }

      final headers = {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
        'Authorization': 'Bearer $token',
      };

      // 2. Obtener perfil
      final perfilRes = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/perfil/'),
        headers: headers,
      );

      if (!mounted) return;

      if (perfilRes.statusCode == 401) {
        await _goToLogin();
        return;
      }

      if (perfilRes.statusCode != 200) {
        setState(() {
          _error   = 'No se pudo obtener el perfil (${perfilRes.statusCode})';
          _loading = false;
        });
        return;
      }

      final perfil = jsonDecode(perfilRes.body) as Map<String, dynamic>;

      // 3. Construir body
      final body = <String, dynamic>{};

      const camposNum = [
        'edad', 'peso', 'altura', 'dias_entrenamiento',
        'tiempo_sesion', 'comidas_por_dia', 'agua_por_dia',
      ];
      const camposStr = [
        'genero', 'objetivo', 'motivacion', 'nivel_actividad',
        'lugar_entrenamiento', 'restricciones_alimentarias',
        'calidad_sueno', 'nivel_estres', 'objetivo_tiempo',
        'condiciones_medicas', 'alergias', 'lesiones',
      ];

      for (final k in camposNum) {
        if (perfil[k] != null) body[k] = perfil[k];
      }
      for (final k in camposStr) {
        if (perfil[k] != null && perfil[k].toString().isNotEmpty) {
          body[k] = perfil[k];
        }
      }
      if (perfil['tiene_equipo'] != null) {
        body['tiene_equipo'] = perfil['tiene_equipo'];
      }

      // 4. Llamar al endpoint del plan de entrenamiento
      final planRes = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/ia/plan/entrenamiento/'),
        headers: headers,
        body: jsonEncode(body),
      );

      if (!mounted) return;

      if (planRes.statusCode == 401) {
        await _goToLogin();
        return;
      }

      if (planRes.statusCode == 200 || planRes.statusCode == 201) {
        final respBody = jsonDecode(planRes.body) as Map<String, dynamic>;

        final plan = (respBody['plan'] is Map)
            ? Map<String, dynamic>.from(respBody['plan'] as Map)
            : <String, dynamic>{};

        final detalle = (respBody['detalle'] is Map)
            ? Map<String, dynamic>.from(respBody['detalle'] as Map)
            : <String, dynamic>{};

        final rutina = plan['rutina_ejercicios'];

        setState(() {
          _detalle    = detalle.isNotEmpty ? detalle : plan;
          _ejercicios = rutina is List ? List<dynamic>.from(rutina) : [];
          _loading    = false;
        });
      } else {
        setState(() {
          _error   = 'Error al generar el plan (${planRes.statusCode})';
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

  // ── Colores por grupo muscular ─────────────────────────────────────────────
  Color _muscleColor(String grupo) {
    final g = grupo.toLowerCase();
    if (g.contains('pierna') || g.contains('glút'))                    return const Color(0xFF4F6EF7);
    if (g.contains('pecho')  || g.contains('trícep') || g.contains('tricep')) return const Color(0xFF43C6AC);
    if (g.contains('espalda')|| g.contains('bícep')  || g.contains('bicep'))  return const Color(0xFFFF9800);
    if (g.contains('hombro'))                                           return const Color(0xFF9C27B0);
    if (g.contains('core')   || g.contains('abdomi'))                  return _kRed;
    if (g.contains('isquio'))                                           return const Color(0xFF00BCD4);
    return const Color(0xFF607D8B);
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBgLight,
      appBar: _buildAppBar(),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kRed))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  color: _kRed,
                  onRefresh: _loadPlan,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    children: [
                      _buildHeaderCard(),
                      const SizedBox(height: 20),
                      if (_detalle?['descripcion'] != null) ...[
                        _buildDescripcion(),
                        const SizedBox(height: 20),
                      ],
                      _buildSectionTitle('Rutina de ejercicios', Icons.fitness_center_rounded),
                      const SizedBox(height: 12),
                      if (_ejercicios.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'No se encontraron ejercicios en el plan.',
                              style: TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                          ),
                        )
                      else
                        ..._ejercicios.asMap().entries.map(
                              (e) => _buildExerciseCard(e.value, e.key + 1),
                            ),
                    ],
                  ),
                ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _kDark),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Plan de Entrenamiento',
        style: GoogleFonts.bebasNeue(fontSize: 22, color: _kDark, letterSpacing: 1.5),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: _kRed),
          onPressed: _loadPlan,
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFEEEEEE), height: 1),
      ),
    );
  }

  Widget _buildHeaderCard() {
    final tipo     = _detalle?['tipo_entrenamiento'] ?? _detalle?['nombre'] ?? 'Plan de Entrenamiento';
    final nivel    = _detalle?['nivel']    ?? '—';
    final duracion = _detalle?['duracion'];
    final total    = _ejercicios.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kRed, Color(0xFFD90B1C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: _kRed.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(tipo.toString(),
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _metricChip(Icons.signal_cellular_alt_rounded, nivel.toString()),
              if (duracion != null)
                _metricChip(Icons.calendar_today_rounded, '$duracion semanas'),
              _metricChip(Icons.list_alt_rounded, '$total ejercicios'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildDescripcion() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: _kRed, size: 18),
              SizedBox(width: 8),
              Text('Descripción del plan',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _kDark)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _detalle!['descripcion'].toString(),
            style: const TextStyle(color: Color(0xFF555555), fontSize: 13, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: _kRed, size: 20),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _kDark)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: _kRed.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('${_ejercicios.length}',
              style: const TextStyle(color: _kRed, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildExerciseCard(dynamic ejercicio, int index) {
    final nombre   = ejercicio['nombre']        ?? 'Ejercicio';
    final grupo    = ejercicio['grupo_muscular'] ?? '';
    final series   = ejercicio['series']         ?? 0;
    final reps     = ejercicio['repeticiones']   ?? 0;
    final descanso = ejercicio['descanso']       ?? '—';
    final color    = _muscleColor(grupo.toString());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            Container(
              width: 44,
              alignment: Alignment.center,
              child: Text(
                '$index',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color.withOpacity(0.5)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nombre.toString(),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14, color: _kDark)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(grupo.toString(),
                          style: TextStyle(
                              fontSize: 11, color: color, fontWeight: FontWeight.w500)),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _statBadge(Icons.repeat_rounded,         '$series series'),
                        _statBadge(Icons.fitness_center_rounded, '$reps reps'),
                        _statBadge(Icons.timer_outlined,          descanso.toString()),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }

  Widget _statBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _kBgLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: Colors.grey[700], fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildError() {
    final isAuthError = _error?.contains('401') == true ||
        _error?.contains('sesión') == true;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isAuthError ? Icons.lock_outline_rounded : Icons.cloud_off_rounded,
              size: 56,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 15),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: isAuthError ? _goToLogin : _loadPlan,
              icon: Icon(
                isAuthError ? Icons.login_rounded : Icons.refresh_rounded,
                size: 18,
              ),
              label: Text(isAuthError ? 'Iniciar sesión' : 'Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}