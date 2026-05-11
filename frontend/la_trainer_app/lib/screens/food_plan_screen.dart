import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/auth_service.dart';

// ── Paleta ─────────────────────────────────────────────────────────────────────
const _kRed    = Color(0xFFF25050);   // secundario (botón home, acentos)
const _kBg     = Color(0xFF000000);   // primario
const _kCard   = Color(0xFF0D0D0D);   // terciario
const _kCard2  = Color(0xFF1A1A1A);   // cards internas
const _kGreen  = Color(0xFF43C6AC);   // iconos / acciones (no modificar)
const _kGold   = Color(0xFFFFB800);
const _kDark   = Color(0xFF1A1A2E);

class FoodPlanScreen extends StatefulWidget {
  const FoodPlanScreen({super.key});
  @override
  State<FoodPlanScreen> createState() => _FoodPlanScreenState();
}

class _FoodPlanScreenState extends State<FoodPlanScreen> {
  bool  _loading    = true;
  bool  _generando  = false;
  bool  _registrando = false;
  String? _error;

  Map<String, dynamic>? _plan;
  List<dynamic> _comidas = [];

  int    _diasCompletados = 0;
  int    _duracionDias    = 0;
  int    _diasRestantes   = 0;
  double _pctCompletado   = 0;
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
          _plan            = plan;
          _comidas         = rutina is List ? List<dynamic>.from(rutina) : [];
          _diasCompletados = (body['dias_completados'] ?? 0) as int;
          _duracionDias    = (body['duracion_dias']    ?? 0) as int;
          _diasRestantes   = (body['dias_restantes']   ?? 0) as int;
          _pctCompletado   = ((body['porcentaje_completado'] ?? 0.0) as num).toDouble();
          _yaRegistroHoy   = body['ya_registro_hoy'] == true;
          _loading         = false;
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

  // ── Registrar cumplimiento ─────────────────────────────────────────────────
  Future<void> _mostrarDialogoRegistro() async {
    String? nivelSeleccionado;
    final calCtrl   = TextEditingController();
    final aguaCtrl  = TextEditingController();
    final notasCtrl = TextEditingController();

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _kGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: _kGreen, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('¿Cómo fue tu día?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nivel de cumplimiento',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: _kDark)),
                const SizedBox(height: 10),
                ...['excelente', 'bueno', 'regular', 'malo'].map((nivel) {
                  final config = _nivelConfig(nivel);
                  final seleccionado = nivelSeleccionado == nivel;
                  return GestureDetector(
                    onTap: () => setDialogState(() => nivelSeleccionado = nivel),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: seleccionado
                            ? config.color.withOpacity(0.15)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: seleccionado ? config.color : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Row(children: [
                        Text(config.emoji, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(config.label,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: seleccionado ? config.color : _kDark,
                              )),
                          Text(config.descripcion,
                              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                        ]),
                        if (seleccionado) ...[
                          const Spacer(),
                          Icon(Icons.check_circle_rounded, color: config.color, size: 18),
                        ],
                      ]),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                const Text('Datos opcionales',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: _kDark)),
                const SizedBox(height: 10),
                TextField(
                  controller: calCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _inputDeco(
                    'Calorías consumidas (kcal)',
                    Icons.local_fire_department_rounded,
                    const Color(0xFFFF6B6B),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: aguaCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                  ],
                  decoration: _inputDeco(
                    'Agua consumida (litros)',
                    Icons.water_drop_rounded,
                    const Color(0xFF4F6EF7),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notasCtrl,
                  maxLines: 2,
                  decoration: _inputDeco(
                    'Notas (opcional)',
                    Icons.edit_note_rounded,
                    Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancelar', style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: nivelSeleccionado == null
                  ? null
                  : () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGreen,
                disabledBackgroundColor: Colors.grey[300],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Registrar'),
            ),
          ],
        ),
      ),
    );

    if (confirmar != true || nivelSeleccionado == null) return;

    setState(() => _registrando = true);
    try {
      final h   = await _headers;
      final hoy = _fechaHoy();

      final body = <String, dynamic>{
        'fecha': hoy,
        'nivel_cumplimiento': nivelSeleccionado,
      };

      final cal  = int.tryParse(calCtrl.text.trim());
      final agua = double.tryParse(aguaCtrl.text.trim());
      final nota = notasCtrl.text.trim();

      if (cal  != null) body['calorias_consumidas'] = cal;
      if (agua != null) body['agua_consumida']      = agua;
      if (nota.isNotEmpty) body['notas']            = nota;

      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/progreso/alimentacion/'),
        headers: h,
        body: jsonEncode(body),
      );

      if (!mounted) return;

      if (res.statusCode == 201) {
        final data = jsonDecode(res.body);
        final mensaje = data['mensaje'] ?? '¡Cumplimiento registrado!';

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(mensaje)),
          ]),
          backgroundColor: _kGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
        await _loadPlan();
      } else {
        final data = jsonDecode(res.body);
        final error = data['error'] ?? 'Error al registrar (${res.statusCode})';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se pudo conectar con el servidor.'),
          backgroundColor: Colors.redAccent,
        ));
      }
    } finally {
      if (mounted) setState(() => _registrando = false);
    }
  }

  String _fechaHoy() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  InputDecoration _inputDeco(String hint, IconData icon, Color color) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
      prefixIcon: Icon(icon, color: color, size: 18),
      filled: true,
      fillColor: Colors.grey[100],
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[200]!)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color, width: 1.5)),
    );
  }

  _NivelConfig _nivelConfig(String nivel) {
    switch (nivel) {
      case 'excelente':
        return _NivelConfig('🌟', 'Excelente', 'Seguí todo al pie de la letra',
            const Color(0xFF2E7D32));
      case 'bueno':
        return _NivelConfig('✅', 'Bueno', 'Seguí la mayoría del plan', _kGreen);
      case 'regular':
        return _NivelConfig('😐', 'Regular', 'Cumplí parcialmente',
            const Color(0xFFFF9800));
      case 'malo':
      default:
        return _NivelConfig('😕', 'Malo', 'No pude seguir el plan hoy', _kRed);
    }
  }

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
        return _MomentoConfig('Merienda', Icons.local_cafe_rounded, _kGreen);
    }
  }

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

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),   // fondo blanco páginas funcionales
      body: Column(
        children: [
          _buildBanner(),
          _buildHomeStrip(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _kGreen))
                : _error != null
                    ? _buildError()
                    : RefreshIndicator(
                        color: _kGreen,
                        onRefresh: _loadPlan,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                          children: [
                            _buildGaugeCard(),
                            const SizedBox(height: 16),
                            _buildMacrosBars(),
                            const SizedBox(height: 16),
                            if (!_yaRegistroHoy) _buildBotonRegistrar(),
                            if (_yaRegistroHoy)  _buildYaRegistrado(),
                            const SizedBox(height: 20),
                            _buildSectionTitle(),
                            const SizedBox(height: 12),
                            ..._comidas.map((c) => _buildMealCard(c)),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // ── Banner superior (fijo, no scrollea) ──────────────────────────────────
  Widget _buildBanner() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF25050), Color(0xFFB83030)],
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
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Text(
                'MI ALIMENTACIÓN',
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

  // ── Tira del botón HOME (fija, fuera del scroll) ───────────────────────────
  Widget _buildHomeStrip() {
    return Container(
      color: const Color(0xFFF5F7FA),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.80,
          child: _buildHomeButton(),
        ),
      ),
    );
  }

  // ── Botón HOME (idéntico al de training_plan) ──────────────────────────────
  Widget _buildHomeButton() {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _kRed,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _kRed.withOpacity(0.4),
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Gauge de calorías (estilo manómetro) ───────────────────────────────────
  Widget _buildGaugeCard() {
    final calTotal      = (_plan?['calorias'] ?? 2350) as num;
    final calConsumidas = _totales['cal']!;
    final pct           = (calConsumidas / calTotal).clamp(0.0, 1.0);
    final objetivo      = _plan?['objetivo'] ?? 'Plan alimenticio';

    // Contenedor transparente — sin color ni borde para integración limpia
    return Container(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Fila: nombre del plan + badge registrado ─────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  objetivo.toString(),
                  style: const TextStyle(
                    color: _kDark,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_yaRegistroHoy)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kGreen.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _kGreen.withOpacity(0.4)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.check_circle_rounded, color: _kGreen, size: 12),
                    const SizedBox(width: 4),
                    const Text('Registrado',
                        style: TextStyle(color: _kGreen, fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Manómetro con LayoutBuilder para radio dinámico ──────────────
          LayoutBuilder(
            builder: (context, constraints) {
              const strokeW = 16.0;
              final availW  = constraints.maxWidth;
              // Radio = 33% del ancho disponible → gauge más compacto
              final radius  = availW * 0.33;
              // Alto del canvas = radio + la mitad del trazo (semicírculo exacto)
              final gaugeH  = radius + strokeW / 2 + 4;
              // Alto total = gauge + espacio para número + label
              const textH   = 60.0;

              return SizedBox(
                height: gaugeH + textH,
                child: Stack(
                  children: [
                    // Canvas del arco — ocupa solo la zona del semicírculo
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: gaugeH,
                      child: CustomPaint(
                        painter: _GaugePainter(pct, radius: radius, strokeWidth: strokeW),
                      ),
                    ),
                    // Texto anclado al centro geométrico del arco (base del semicírculo)
                    // cy del painter = gaugeH - strokeW/2 - 4 ≈ radius
                    // El texto va justo debajo de ese punto
                    Positioned(
                      top: gaugeH - 4,
                      left: 0,
                      right: 0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: calConsumidas.toInt().toString(),
                                  style: GoogleFonts.bebasNeue(
                                    color: _kDark,
                                    fontSize: 38,
                                    letterSpacing: 1,
                                  ),
                                ),
                                TextSpan(
                                  text: ' kcal/${calTotal.toInt()}',
                                  style: GoogleFonts.bebasNeue(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _calLabel(pct),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _kRed,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // ── Stats días ────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _dayStat('$_diasCompletados', 'Días completados', _kGreen),
              Container(width: 1, height: 32, color: Colors.black12),
              _dayStat('$_diasRestantes', 'Días restantes', Colors.black45),
              Container(width: 1, height: 32, color: Colors.black12),
              _dayStat('$_duracionDias', 'Total días', Colors.black26),
            ],
          ),
        ],
      ),
    );
  }

  String _calLabel(double pct) {
    if (pct < 0.3) return 'Bajo';
    if (pct < 0.75) return 'En progreso';
    if (pct < 1.0) return 'Casi completo';
    return 'Meta alcanzada';
  }

  Color _gaugeColor(double pct) {
    if (pct < 0.5) return _kRed;
    if (pct < 0.85) return _kGold;
    return _kGreen;
  }

  Widget _dayStat(String value, String label, Color color) {
    return Column(children: [
      Text(value,
          style: GoogleFonts.bebasNeue(
              color: color, fontSize: 22, letterSpacing: 1)),
      const SizedBox(height: 2),
      Text(label,
          style: const TextStyle(color: Colors.black45, fontSize: 10)),
    ]);
  }

  // ── Barras verticales de macros ────────────────────────────────────────────
  Widget _buildMacrosBars() {
    final t        = _totales;
    final calTotal = (_plan?['calorias'] ?? 2350) as num;

    final metaProt  = (calTotal * 0.30 / 4).clamp(50.0, 300.0);
    final metaCarbs = (calTotal * 0.45 / 4).clamp(50.0, 500.0);
    final metaGrasa = (calTotal * 0.25 / 9).clamp(20.0, 200.0);

    // Contenedor transparente — sin fondo para integrarse al fondo blanco
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _verticalMacroBar(
            label: 'Proteínas',
            value: t['prot']!,
            meta: metaProt,
            unit: 'g',
            color: const Color(0xFF4F6EF7),
            icon: Icons.egg_rounded,
          ),
          _verticalMacroBar(
            label: 'Carbohidratos',
            value: t['carbs']!,
            meta: metaCarbs,
            unit: 'g',
            color: const Color(0xFFFF9800),
            icon: Icons.grain_rounded,
          ),
          _verticalMacroBar(
            label: 'Grasas',
            value: t['grasas']!,
            meta: metaGrasa,
            unit: 'g',
            color: _kGreen,
            icon: Icons.opacity_rounded,
          ),
        ],
      ),
    );
  }

  Widget _verticalMacroBar({
    required String label,
    required double value,
    required double meta,
    required String unit,
    required Color color,
    required IconData icon,
  }) {
    final pct = (value / meta).clamp(0.0, 1.0);
    const barH = 100.0;

    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 8),
        // Barra vertical
        Container(
          width: 28,
          height: barH,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.hardEdge,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOut,
            width: 28,
            height: barH * pct,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${value.toStringAsFixed(0)}$unit',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '/${meta.toStringAsFixed(0)}$unit',
          style: const TextStyle(color: Colors.black38, fontSize: 10),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.black54, fontSize: 10),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ── Botón registrar cumplimiento ───────────────────────────────────────────
  Widget _buildBotonRegistrar() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _registrando ? null : _mostrarDialogoRegistro,
        icon: _registrando
            ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.add_task_rounded, color: Colors.white, size: 20),
        label: Text(
          _registrando ? 'Registrando...' : 'REGISTRAR CUMPLIMIENTO DE HOY',
          style: GoogleFonts.bebasNeue(
              fontSize: 16, color: Colors.white, letterSpacing: 1.2),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _kGreen,
          disabledBackgroundColor: _kGreen.withOpacity(0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 2,
          shadowColor: _kGreen.withOpacity(0.4),
        ),
      ),
    );
  }

  Widget _buildYaRegistrado() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _kGreen.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kGreen.withOpacity(0.3)),
      ),
      child: Row(children: const [
        Icon(Icons.check_circle_rounded, color: _kGreen, size: 22),
        SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('¡Cumplimiento registrado hoy!',
                style: TextStyle(fontWeight: FontWeight.bold,
                    fontSize: 14, color: _kGreen)),
            SizedBox(height: 2),
            Text('Vuelve mañana para registrar el siguiente día.',
                style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
          ]),
        ),
      ]),
    );
  }

  // ── Sección comidas ────────────────────────────────────────────────────────
  Widget _buildSectionTitle() {
    return Row(children: [
      const Icon(Icons.restaurant_menu_rounded, color: _kGreen, size: 20),
      const SizedBox(width: 8),
      const Text('Comidas del día',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _kDark)),
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

  void _mostrarDetalleComida(dynamic comida) {
    final cfg = _momentoConfig((comida['momento'] ?? 'merienda').toString());
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DetalleComidaSheet(comida: comida, cfg: cfg),
    );
  }

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

    return GestureDetector(
      onTap: () => _mostrarDetalleComida(comida),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: cfg.color.withOpacity(0.08),
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18), topRight: Radius.circular(18)),
              ),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                      color: cfg.color.withOpacity(0.15), shape: BoxShape.circle),
                  child: Icon(cfg.icon, color: cfg.color, size: 18),
                ),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(cfg.label.toUpperCase(),
                      style: TextStyle(fontSize: 10, color: cfg.color,
                          fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                  Text('Comida $orden',
                      style: const TextStyle(fontSize: 11, color: Colors.black38)),
                ]),
                const Spacer(),
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
                const SizedBox(width: 8),
                const Icon(Icons.keyboard_arrow_right_rounded,
                    color: Colors.black26, size: 18),
              ]),
            ),
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
                        style: const TextStyle(fontSize: 12, color: Colors.black45,
                            height: 1.4)),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FA),
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
                        _inlineMacro('G', '${grasas.toStringAsFixed(1)}g', _kGreen),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Icon(Icons.touch_app_rounded, size: 12, color: Colors.black26),
                    const SizedBox(width: 4),
                    const Text('Toca para ver la receta',
                        style: TextStyle(fontSize: 11, color: Colors.black26)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inlineMacro(String letter, String value, Color color) {
    return Column(children: [
      Text(letter,
          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
      const SizedBox(height: 2),
      Text(value,
          style: const TextStyle(fontSize: 12, color: _kDark,
              fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _vDivider() => Container(width: 1, height: 28, color: Colors.black12);

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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                elevation: 0,
              ),
            ),
        ]),
      ),
    );
  }
}

// ── CustomPainter: Manómetro / Gauge ──────────────────────────────────────────
class _GaugePainter extends CustomPainter {
  final double progress;      // 0.0 → 1.0
  final double radius;        // radio pasado desde LayoutBuilder
  final double strokeWidth;

  const _GaugePainter(this.progress, {required this.radius, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    // El centro del semicírculo queda en la mitad inferior del canvas
    final cx = size.width / 2;
    final cy = size.height - strokeWidth / 2 - 4;

    // ── Arco de fondo ──────────────────────────────────────────────────────
    final bgPaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      math.pi,      // empieza en izquierda
      math.pi,      // 180°
      false,
      bgPaint,
    );

    // ── Arco de progreso ───────────────────────────────────────────────────
    if (progress > 0.01) {
      const fgColor = Color(0xFFF25050);  // siempre rojo
      final fgPaint = Paint()
        ..color = fgColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        math.pi,
        math.pi * progress,
        false,
        fgPaint,
      );

      // Punto en el extremo del progreso
      final angle = math.pi + math.pi * progress;
      final dotX  = cx + radius * math.cos(angle);
      final dotY  = cy + radius * math.sin(angle);

      canvas.drawCircle(Offset(dotX, dotY), strokeWidth * 0.45,
          Paint()..color = const Color(0xFFF25050));
      canvas.drawCircle(Offset(dotX, dotY), strokeWidth * 0.22,
          Paint()..color = Colors.white);
    }

    // ── Marcas de escala ───────────────────────────────────────────────────
    final tickPaint = Paint()
      ..color = Colors.black12
      ..strokeWidth = 1.5;

    for (int i = 0; i <= 10; i++) {
      final angle    = math.pi + (math.pi / 10) * i;
      final isMajor  = i % 5 == 0;
      final innerR   = radius - (isMajor ? strokeWidth + 6 : strokeWidth + 2);
      final outerR   = radius - strokeWidth / 2 + 4;

      canvas.drawLine(
        Offset(cx + innerR * math.cos(angle), cy + innerR * math.sin(angle)),
        Offset(cx + outerR * math.cos(angle), cy + outerR * math.sin(angle)),
        tickPaint,
      );
    }
  }

  Color _gaugeColor(double p) {
    if (p < 0.5) return const Color(0xFFF25050);
    if (p < 0.85) return const Color(0xFFFFB800);
    return const Color(0xFF43C6AC);
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.progress != progress || old.radius != radius;
}


// ── Modelos helper ─────────────────────────────────────────────────────────────
class _MomentoConfig {
  final String label;
  final IconData icon;
  final Color color;
  const _MomentoConfig(this.label, this.icon, this.color);
}

class _NivelConfig {
  final String emoji;
  final String label;
  final String descripcion;
  final Color color;
  const _NivelConfig(this.emoji, this.label, this.descripcion, this.color);
}

// ══════════════════════════════════════════════════════════════════════════════
// Bottom sheet: detalle completo de la comida (sin cambios de funcionalidad)
// ══════════════════════════════════════════════════════════════════════════════
class _DetalleComidaSheet extends StatelessWidget {
  final dynamic comida;
  final _MomentoConfig cfg;

  const _DetalleComidaSheet({required this.comida, required this.cfg});

  static const _kDark    = Color(0xFF1A1A2E);
  static const _kBgLight = Color(0xFFF5F7FA);
  static const _kGreen   = Color(0xFF43C6AC);

  @override
  Widget build(BuildContext context) {
    final nombre       = (comida['nombre']          ?? '—').toString();
    final descripcion  = (comida['descripcion']     ?? '').toString().trim();
    final ingredientes = (comida['ingredientes']    ?? '').toString().trim();
    final preparacion  = (comida['preparacion']     ?? '').toString().trim();
    final tiempo       = comida['tiempo_preparacion'];
    final cal          = (comida['calorias']        as num? ?? 0).toInt();
    final prot         = (comida['proteinas']       as num? ?? 0).toDouble();
    final carbs        = (comida['carbohidratos']   as num? ?? 0).toDouble();
    final grasas       = (comida['grasas']          as num? ?? 0).toDouble();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                    color: cfg.color.withOpacity(0.12), shape: BoxShape.circle),
                child: Icon(cfg.icon, color: cfg.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(cfg.label.toUpperCase(),
                      style: TextStyle(fontSize: 11, color: cfg.color,
                          fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                  Text(nombre,
                      style: const TextStyle(fontSize: 17,
                          fontWeight: FontWeight.bold, color: _kDark)),
                ]),
              ),
              if (tiempo != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _kGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.timer_rounded, color: _kGreen, size: 13),
                    const SizedBox(width: 4),
                    Text('$tiempo min',
                        style: const TextStyle(color: _kGreen,
                            fontSize: 12, fontWeight: FontWeight.bold)),
                  ]),
                ),
            ]),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                  color: _kBgLight, borderRadius: BorderRadius.circular(14)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _macro(Icons.local_fire_department_rounded,
                      '$cal kcal', 'Calorías', const Color(0xFFFF6B6B)),
                  _vDiv(),
                  _macro(Icons.egg_rounded,
                      '${prot.toStringAsFixed(1)}g', 'Proteínas', const Color(0xFF4F6EF7)),
                  _vDiv(),
                  _macro(Icons.grain_rounded,
                      '${carbs.toStringAsFixed(1)}g', 'Carbos', const Color(0xFFFF9800)),
                  _vDiv(),
                  _macro(Icons.opacity_rounded,
                      '${grasas.toStringAsFixed(1)}g', 'Grasas', _kGreen),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (descripcion.isNotEmpty) ...[
              _seccionTitulo('Descripción', Icons.info_outline_rounded,
                  const Color(0xFF4F6EF7)),
              const SizedBox(height: 8),
              Text(descripcion,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.5)),
              const SizedBox(height: 20),
            ],
            if (ingredientes.isNotEmpty) ...[
              _seccionTitulo('Ingredientes', Icons.shopping_basket_rounded,
                  const Color(0xFFFF9800)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800).withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFF9800).withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: ingredientes
                      .split('\n')
                      .where((l) => l.trim().isNotEmpty)
                      .map((linea) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('•  ',
                                    style: TextStyle(
                                        color: Color(0xFFFF9800),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                                Expanded(
                                  child: Text(
                                      linea.replaceFirst(RegExp(r'^[-•]\s*'), ''),
                                      style: TextStyle(fontSize: 14,
                                          color: Colors.grey[800], height: 1.4)),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (preparacion.isNotEmpty) ...[
              _seccionTitulo('Preparación', Icons.restaurant_rounded, _kGreen),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kGreen.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kGreen.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: () {
                    final pasos = preparacion
                        .split('\n')
                        .where((l) => l.trim().isNotEmpty)
                        .toList();
                    return pasos.asMap().entries.map((e) {
                      final idx  = e.key + 1;
                      final paso = e.value.replaceFirst(RegExp(r'^\d+[.)]\s*'), '');
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 22, height: 22,
                              decoration: const BoxDecoration(
                                  color: _kGreen, shape: BoxShape.circle),
                              child: Center(
                                child: Text('$idx',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(paso,
                                  style: TextStyle(fontSize: 14,
                                      color: Colors.grey[800], height: 1.4)),
                            ),
                          ],
                        ),
                      );
                    }).toList();
                  }(),
                ),
              ),
              const SizedBox(height: 24),
            ],
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  backgroundColor: Colors.grey[100],
                ),
                child: const Text('Cerrar',
                    style: TextStyle(color: _kDark, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seccionTitulo(String titulo, IconData icon, Color color) {
    return Row(children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 8),
      Text(titulo,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
    ]);
  }

  Widget _macro(IconData icon, String valor, String label, Color color) {
    return Column(children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(height: 4),
      Text(valor,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
    ]);
  }

  Widget _vDiv() => Container(width: 1, height: 36, color: Colors.grey[200]);
}