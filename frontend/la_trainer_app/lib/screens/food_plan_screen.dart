import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/auth_service.dart';

const _kGreen   = Color(0xFF43C6AC);
const _kBgLight = Color(0xFFF5F7FA);
const _kDark    = Color(0xFF1A1A2E);
const _kRed     = Color(0xFFD72105);
const _kGold    = Color(0xFFFFB800);

class FoodPlanScreen extends StatefulWidget {
  const FoodPlanScreen({super.key});
  @override
  State<FoodPlanScreen> createState() => _FoodPlanScreenState();
}

class _FoodPlanScreenState extends State<FoodPlanScreen> {
  bool  _loading  = true;
  bool  _generando = false;
  String? _error;

  Map<String, dynamic>? _plan;
  List<dynamic> _comidas = [];

  // Datos de progreso del JSON raíz
  int    _diasCompletados  = 0;
  int    _duracionDias     = 0;
  int    _diasRestantes    = 0;
  double _pctCompletado    = 0;
  bool   _yaRegistroHoy   = false;

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  Future<Map<String, String>> get _headers async {
    final token = await AuthService.getValidToken();
    return {
      'Content-Type': 'application/json',
      'ngrok-skip-browser-warning': 'true',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> _loadPlan() async {
    setState(() { _loading = true; _error = null; });
    try {
      final h   = await _headers;
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/planes/alimentacion/activo/'),
        headers: h,
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;

        if (body['tiene_plan_activo'] != true) {
          setState(() {
            _error   = 'Aún no tienes un plan alimenticio activo.\nHabla con el coach para generar uno.';
            _loading = false;
          });
          return;
        }

        final plan   = Map<String, dynamic>.from(body['plan'] as Map);
        final rutina = plan['rutina_comidas'];

        setState(() {
          _plan             = plan;
          _comidas          = rutina is List ? List<dynamic>.from(rutina) : [];
          _diasCompletados  = (body['dias_completados'] ?? 0) as int;
          _duracionDias     = (body['duracion_dias']    ?? 0) as int;
          _diasRestantes    = (body['dias_restantes']   ?? 0) as int;
          _pctCompletado    = ((body['porcentaje_completado'] ?? 0.0) as num).toDouble();
          _yaRegistroHoy    = body['ya_registro_hoy'] == true;
          _loading          = false;
        });
      } else {
        setState(() {
          _error   = 'Error al cargar el plan (${res.statusCode})';
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() {
        _error   = 'No se pudo conectar con el servidor.';
        _loading = false;
      });
    }
  }

  Future<void> _generarPlan() async {
    setState(() => _generando = true);
    try {
      final h   = await _headers;
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/ia/plan/alimentacion/'),
        headers: h,
      );
      if (!mounted) return;
      if (res.statusCode == 200 || res.statusCode == 201) {
        await _loadPlan();
      } else {
        final body = jsonDecode(res.body);
        setState(() {
          _error    = body['error'] ?? 'No se pudo generar el plan (${res.statusCode})';
          _generando = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() {
        _error    = 'No se pudo conectar con el servidor.';
        _generando = false;
      });
    }
  }

  // ── Configuración por momento del día ─────────────────────────────────────
  _MomentoConfig _momentoConfig(String momento) {
    switch (momento.toLowerCase()) {
      case 'desayuno':
        return _MomentoConfig('Desayuno', Icons.wb_sunny_rounded,
            const Color(0xFFFF9800));
      case 'almuerzo':
        return _MomentoConfig('Almuerzo', Icons.wb_cloudy_rounded,
            const Color(0xFF4F6EF7));
      case 'cena':
        return _MomentoConfig('Cena', Icons.nights_stay_rounded,
            const Color(0xFF9C27B0));
      case 'merienda':
      default:
        return _MomentoConfig('Merienda', Icons.local_cafe_rounded,
            _kGreen);
    }
  }

  // ── Totales de macros ──────────────────────────────────────────────────────
  Map<String, double> get _totales {
    double cal = 0, prot = 0, carbs = 0, grasas = 0;
    for (final c in _comidas) {
      cal    += (c['calorias']      as num? ?? 0).toDouble();
      prot   += (c['proteinas']     as num? ?? 0).toDouble();
      carbs  += (c['carbohidratos'] as num? ?? 0).toDouble();
      grasas += (c['grasas']        as num? ?? 0).toDouble();
    }
    return {'cal': cal, 'prot': prot, 'carbs': carbs, 'grasas': grasas};
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBgLight,
      appBar: _buildAppBar(),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kGreen))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  color: _kGreen,
                  onRefresh: _loadPlan,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    children: [
                      _buildHeaderCard(),
                      const SizedBox(height: 16),
                      _buildProgressCard(),
                      const SizedBox(height: 20),
                      _buildMacroSummary(),
                      const SizedBox(height: 20),
                      _buildSectionTitle(),
                      const SizedBox(height: 12),
                      ..._comidas.map((c) => _buildMealCard(c)),
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
      title: Text('Plan Alimenticio',
          style: GoogleFonts.bebasNeue(
              fontSize: 22, color: _kDark, letterSpacing: 1.5)),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: _kGreen),
          onPressed: _loadPlan,
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFEEEEEE), height: 1),
      ),
    );
  }

  // ── Tarjeta cabecera ───────────────────────────────────────────────────────
  Widget _buildHeaderCard() {
    final objetivo = _plan?['objetivo'] ?? 'Plan alimenticio';
    final calTotal = _plan?['calorias'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF43C6AC), Color(0xFF2EA890)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
            color: _kGreen.withOpacity(0.3), blurRadius: 12,
            offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.restaurant_rounded, color: Colors.white70, size: 16),
          const SizedBox(width: 8),
          const Text('PLAN ACTIVO',
              style: TextStyle(color: Colors.white70, fontSize: 11,
                  fontWeight: FontWeight.w600, letterSpacing: 1.5)),
          const Spacer(),
          if (_yaRegistroHoy)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(20)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 13),
                SizedBox(width: 4),
                Text('Registrado hoy',
                    style: TextStyle(color: Colors.white, fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
        ]),
        const SizedBox(height: 10),
        Text(objetivo.toString(),
            style: const TextStyle(color: Colors.white, fontSize: 16,
                fontWeight: FontWeight.bold, height: 1.3)),
        const SizedBox(height: 14),
        Wrap(spacing: 10, runSpacing: 8, children: [
          _chip(Icons.local_fire_department_rounded, '$calTotal kcal/día'),
          _chip(Icons.calendar_today_rounded, '$_duracionDias días'),
          _chip(Icons.restaurant_menu_rounded, '${_comidas.length} comidas'),
        ]),
      ]),
    );
  }

  Widget _chip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(30)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: Colors.white, size: 13),
      const SizedBox(width: 5),
      Text(label,
          style: const TextStyle(color: Colors.white, fontSize: 12,
              fontWeight: FontWeight.w500)),
    ]),
  );

  // ── Tarjeta de progreso del plan ───────────────────────────────────────────
  Widget _buildProgressCard() {
    final pct = (_pctCompletado / 100).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05), blurRadius: 10,
            offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              const Icon(Icons.bolt_rounded, color: _kGold, size: 20),
              const SizedBox(width: 6),
              const Text('Progreso del plan',
                  style: TextStyle(fontWeight: FontWeight.bold,
                      fontSize: 14, color: _kDark)),
            ]),
            Text('${_pctCompletado.toStringAsFixed(0)}%',
                style: const TextStyle(fontWeight: FontWeight.bold,
                    fontSize: 14, color: _kGreen)),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 14,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation(
                pct >= 1.0 ? _kGold : _kGreen),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _progressStat(Icons.check_circle_outline_rounded,
                '$_diasCompletados días completados', _kGreen),
            _progressStat(Icons.hourglass_bottom_rounded,
                '$_diasRestantes días restantes', Colors.grey),
          ],
        ),
      ]),
    );
  }

  Widget _progressStat(IconData icon, String label, Color color) {
    return Row(children: [
      Icon(icon, color: color, size: 15),
      const SizedBox(width: 5),
      Text(label,
          style: TextStyle(fontSize: 12, color: color,
              fontWeight: FontWeight.w500)),
    ]);
  }

  // ── Resumen de macros ──────────────────────────────────────────────────────
  Widget _buildMacroSummary() {
    final t = _totales;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04), blurRadius: 8,
            offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _macroStat('Calorías', '${t['cal']!.toInt()} kcal',
              Icons.local_fire_department_rounded, const Color(0xFFFF6B6B)),
          _divider(),
          _macroStat('Proteínas', '${t['prot']!.toStringAsFixed(1)}g',
              Icons.egg_rounded, const Color(0xFF4F6EF7)),
          _divider(),
          _macroStat('Carbos', '${t['carbs']!.toStringAsFixed(1)}g',
              Icons.grain_rounded, const Color(0xFFFF9800)),
          _divider(),
          _macroStat('Grasas', '${t['grasas']!.toStringAsFixed(1)}g',
              Icons.opacity_rounded, _kGreen),
        ],
      ),
    );
  }

  Widget _macroStat(String label, String value, IconData icon, Color color) {
    return Column(children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(height: 4),
      Text(value,
          style: const TextStyle(fontWeight: FontWeight.bold,
              fontSize: 12, color: _kDark)),
      const SizedBox(height: 2),
      Text(label,
          style: TextStyle(fontSize: 10, color: Colors.grey[500])),
    ]);
  }

  Widget _divider() => Container(
      width: 1, height: 36,
      color: Colors.grey[200]);

  // ── Título sección ─────────────────────────────────────────────────────────
  Widget _buildSectionTitle() {
    return Row(children: [
      const Icon(Icons.restaurant_menu_rounded, color: _kGreen, size: 20),
      const SizedBox(width: 8),
      const Text('Comidas del día',
          style: TextStyle(fontWeight: FontWeight.bold,
              fontSize: 16, color: _kDark)),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
            color: _kGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20)),
        child: Text('${_comidas.length}',
            style: const TextStyle(color: _kGreen, fontSize: 12,
                fontWeight: FontWeight.bold)),
      ),
    ]);
  }

  // ── Tarjeta de comida ──────────────────────────────────────────────────────
  Widget _buildMealCard(dynamic comida) {
    final nombre      = comida['nombre']         ?? '—';
    final momento     = comida['momento']        ?? 'merienda';
    final cal         = (comida['calorias']      as num? ?? 0).toInt();
    final prot        = (comida['proteinas']     as num? ?? 0).toDouble();
    final carbs       = (comida['carbohidratos'] as num? ?? 0).toDouble();
    final grasas      = (comida['grasas']        as num? ?? 0).toDouble();
    final descripcion = comida['descripcion']    ?? '';
    final orden       = comida['orden']          ?? 0;
    final cfg         = _momentoConfig(momento.toString());

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05), blurRadius: 10,
            offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cabecera ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: cfg.color.withOpacity(0.08),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18)),
            ),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    color: cfg.color.withOpacity(0.15),
                    shape: BoxShape.circle),
                child: Icon(cfg.icon, color: cfg.color, size: 18),
              ),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(cfg.label.toUpperCase(),
                    style: TextStyle(fontSize: 10, color: cfg.color,
                        fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                Text('Comida $orden',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ]),
              const Spacer(),
              // Badge calorías
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: const Color(0xFFFF6B6B).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.local_fire_department_rounded,
                      color: Color(0xFFFF6B6B), size: 13),
                  const SizedBox(width: 3),
                  Text('$cal kcal',
                      style: const TextStyle(color: Color(0xFFFF6B6B),
                          fontSize: 12, fontWeight: FontWeight.bold)),
                ]),
              ),
            ]),
          ),
          // ── Cuerpo ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre.toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold,
                        fontSize: 15, color: _kDark)),
                if (descripcion.toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(descripcion.toString(),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600],
                          height: 1.4)),
                ],
                const SizedBox(height: 12),
                // Macros
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                      color: _kBgLight,
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _inlineMacro('P', '${prot.toStringAsFixed(1)}g',
                          const Color(0xFF4F6EF7)),
                      _vDivider(),
                      _inlineMacro('C', '${carbs.toStringAsFixed(1)}g',
                          const Color(0xFFFF9800)),
                      _vDivider(),
                      _inlineMacro('G', '${grasas.toStringAsFixed(1)}g',
                          _kGreen),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inlineMacro(String letter, String value, Color color) {
    return Column(children: [
      Text(letter,
          style: TextStyle(fontSize: 10, color: color,
              fontWeight: FontWeight.bold)),
      const SizedBox(height: 2),
      Text(value,
          style: const TextStyle(fontSize: 12, color: _kDark,
              fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _vDivider() => Container(
      width: 1, height: 28, color: Colors.grey[200]);

  // ── Error ──────────────────────────────────────────────────────────────────
  Widget _buildError() {
    final isNoPlan = _error?.contains('plan') == true;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            isNoPlan ? Icons.no_meals_rounded : Icons.cloud_off_rounded,
            size: 56, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(_error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 15, height: 1.5)),
          const SizedBox(height: 24),

          if (isNoPlan)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _generando ? null : _generarPlan,
                icon: _generando
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.auto_awesome_rounded,
                        color: Colors.white, size: 20),
                label: Text(
                  _generando ? 'Generando plan...' : 'GENERAR MI PLAN CON IA',
                  style: GoogleFonts.bebasNeue(
                      fontSize: 18, color: Colors.white, letterSpacing: 1.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kGreen,
                  disabledBackgroundColor: _kGreen.withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  elevation: 4,
                  shadowColor: _kGreen.withOpacity(0.4),
                ),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: _loadPlan,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                elevation: 0,
              ),
            ),
        ]),
      ),
    );
  }
}

// ── Modelo helper ─────────────────────────────────────────────────────────────
class _MomentoConfig {
  final String label;
  final IconData icon;
  final Color color;
  const _MomentoConfig(this.label, this.icon, this.color);
}