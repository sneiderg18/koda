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
<<<<<<< HEAD
  bool _generando = false; // mientras la IA crea el plan
=======
  bool _generando = false;
  bool _iniciando = false;
>>>>>>> 6ece595 (Progreso, login, Formulario, registro, plan alimenticio, plan ejercicio, fotos de perfil corregidos)
  String? _error;

  Map<String, dynamic>? _plan;
  List<dynamic> _ejercicios     = [];
  bool _yaEntrenoHoy            = false;
  int  _sesionesCompletadas     = 0;
  int  _sesionesTotales         = 0;

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
      final token = await AuthService.getToken();
      if (token == null) { await _goToLogin(); return; }

      final headers = {
        'Content-Type': 'application/json',
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
          _plan                 = plan;
          _ejercicios           = rutina is List ? List<dynamic>.from(rutina) : [];
          _sesionesCompletadas  = body['sesiones_completadas'] ?? 0;
          _sesionesTotales      = body['sesiones_totales']     ?? 0;
          _yaEntrenoHoy         = false; // se actualiza al intentar iniciar
          _loading              = false;
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
      final token = await AuthService.getToken();
      if (token == null) { await _goToLogin(); return; }

      final headers = {
        'Content-Type': 'application/json',
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
      } else if (res.statusCode == 500) {
        await Future.delayed(const Duration(milliseconds: 1000));
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
    if (_iniciando) return;
    setState(() => _iniciando = true);

    try {
      final token = await AuthService.getToken();
      if (token == null) { await _goToLogin(); return; }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      // Llama a /api/sesion/iniciar/ — si ya hay sesión abierta la reutiliza
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/sesion/iniciar/'),
        headers: headers,
      );

      if (!mounted) return;
      if (res.statusCode == 401) { await _goToLogin(); return; }

      final body = jsonDecode(res.body) as Map<String, dynamic>;

      // ── El backend dice que ya entrenó hoy ──────────────────────────────
      if (body['puede_entrenar_hoy'] == false ||
          body['sesion_completada_hoy'] == true) {
        setState(() {
          _yaEntrenoHoy        = true;
          _sesionesCompletadas = body['sesiones_completadas'] ?? _sesionesCompletadas;
          _sesionesTotales     = body['sesiones_totales']     ?? _sesionesTotales;
          _iniciando           = false;
        });
        return;
      }

      if (res.statusCode == 200 || res.statusCode == 201) {
<<<<<<< HEAD
        // Sesión creada o retomada → ir a la pantalla de detalles
        Navigator.push(
=======
        final sesionId = body['id'] as int?
            ?? body['sesion_id'] as int?
            ?? (body['sesion'] as Map<String, dynamic>?)?['id'] as int?;

        setState(() => _iniciando = false);

        await Navigator.push(
>>>>>>> 6ece595 (Progreso, login, Formulario, registro, plan alimenticio, plan ejercicio, fotos de perfil corregidos)
          context,
          MaterialPageRoute(
            builder: (_) => PantallaDetalles(sesionId: sesionId),
          ),
        );

        // Al regresar recargamos el plan
        await _loadPlan();

      } else {
<<<<<<< HEAD
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
=======
        setState(() => _iniciando = false);
        final msg = body['error'] ?? body['detail'] ?? body['mensaje'] ?? 'Error ${res.statusCode}';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg.toString()),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _iniciando = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se pudo conectar con el servidor'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
>>>>>>> 6ece595 (Progreso, login, Formulario, registro, plan alimenticio, plan ejercicio, fotos de perfil corregidos)
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
<<<<<<< HEAD
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
=======
              child: _yaEntrenoHoy
                  ? _buildYaEntrenoHoyBanner()
                  : _buildStartSessionButton(),
            ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFD72105), Color(0xFFB01A04)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: const Icon(Icons.refresh_rounded,
                        color: Colors.white70, size: 20),
                    onPressed: _loadPlan,
>>>>>>> 6ece595 (Progreso, login, Formulario, registro, plan alimenticio, plan ejercicio, fotos de perfil corregidos)
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
<<<<<<< HEAD
=======
              ],
            ),
          ),
        ),
        Container(
          color: _kBg,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.80,
              child: _buildHomeButton(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHomeButton() {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF25050),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF25050).withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 14),
            const SizedBox(width: 6),
            Text(
              'HOME',
              style: GoogleFonts.bebasNeue(
                color: Colors.white,
                fontSize: 15,
                letterSpacing: 1.5,
>>>>>>> 6ece595 (Progreso, login, Formulario, registro, plan alimenticio, plan ejercicio, fotos de perfil corregidos)
              ),
            ),
        ],
      ),
    );
  }

<<<<<<< HEAD
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
=======
  // ── Banner: ya entrenó hoy ────────────────────────────────────────────────
  Widget _buildYaEntrenoHoyBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: Colors.green, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '¡Sesión completada hoy!',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Vuelve mañana para continuar 💪',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Barra de progreso del plan
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progreso del plan',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.5), fontSize: 11),
              ),
              Text(
                '$_sesionesCompletadas / $_sesionesTotales sesiones',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.5), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _sesionesTotales > 0
                  ? _sesionesCompletadas / _sesionesTotales
                  : 0,
              backgroundColor: Colors.white12,
              color: Colors.green,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  // ── Botón empezar sesión ──────────────────────────────────────────────────
  Widget _buildStartSessionButton() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: _kRed.withOpacity(0.6),
            blurRadius: 20,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _iniciando ? null : _iniciarSesion,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kRed.withOpacity(0.85),
          disabledBackgroundColor: _kRed.withOpacity(0.4),
          shadowColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
            side: BorderSide(
                color: Colors.white.withOpacity(0.25), width: 1.2),
          ),
        ),
        child: _iniciando
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'EMPEZAR SESIÓN',
                    style: GoogleFonts.bebasNeue(
                      fontSize: 20,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                ],
>>>>>>> 6ece595 (Progreso, login, Formulario, registro, plan alimenticio, plan ejercicio, fotos de perfil corregidos)
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
<<<<<<< HEAD
          Text(
            tipo.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
=======
          // Progreso del plan
          
>>>>>>> 6ece595 (Progreso, login, Formulario, registro, plan alimenticio, plan ejercicio, fotos de perfil corregidos)
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

<<<<<<< HEAD
  // ── Tile individual de ejercicio ──────────────────────────────────────────
  Widget _buildEjercicioTile(dynamic ejercicio) {
    final nombre = ejercicio['nombre']        ?? 'Ejercicio';
    final series = ejercicio['series']        ?? 0;
    final reps   = ejercicio['repeticiones']  ?? 0;
=======
  // ── Progreso del plan ─────────────────────────────────────────────────────
  Widget _buildProgresoPlam() {
    final porcentaje = _sesionesTotales > 0
        ? _sesionesCompletadas / _sesionesTotales
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Progreso del plan',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$_sesionesCompletadas / $_sesionesTotales sesiones',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: porcentaje,
              backgroundColor: Colors.white12,
              color: _kRed,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  // ── Tile de ejercicio ─────────────────────────────────────────────────────
  Widget _buildEjercicioTile(dynamic ejercicio, int index) {
    final nombre = ejercicio['nombre']       ?? 'Ejercicio';
    final series = ejercicio['series']       ?? 0;
    final reps   = ejercicio['repeticiones'] ?? 0;
>>>>>>> 6ece595 (Progreso, login, Formulario, registro, plan alimenticio, plan ejercicio, fotos de perfil corregidos)

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