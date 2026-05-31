import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/auth_service.dart';

// ── Paleta ─────────────────────────────────────────────────────────────────────
const _kRed         = Color(0xFFF25050);
const _kBg          = Color(0xFFF5F7FA);
const _kDark        = Color(0xFF1A1A2E);
const _cVerdeFuerte = Color(0xFF2E7D32);
const _cVerdeClaro  = Color(0xFF81C784);
const _cAzul        = Color(0xFF1976D2);

// ── Mapeo grupos musculares backend → IDs del mapa ────────────────────────────
const Map<String, List<String>> _grupoToIds = {
  // Frente
  'Pecho':           ['pectorales'],
  'Pectorales':      ['pectorales'],
  'Bíceps':          ['biceps'],
  'Biceps':          ['biceps'],
  'Hombros':         ['hombros'],
  'Abdomen':         ['abdomen'],
  'Oblicuos':        ['oblicuos'],
  'Antebrazo':       ['antebrazo'],
  'Antebrazos':      ['antebrazo'],
  'Cuádriceps':      ['cuadriceps'],
  'Cuadriceps':      ['cuadriceps'],
  'Piernas':         ['cuadriceps', 'femorales'],
  'Serratos':        ['serratos'],
  'Trapecio':        ['trapecio_front', 'trapecio_back'],
  'Aductores':       ['aductores'],
  'Tibial':          ['tibial_ant'],
  'Sóleo':           ['soleo'],
  // Espalda
  'Espalda':         ['dorsales'],
  'Dorsales':        ['dorsales'],
  'Tríceps':         ['triceps'],
  'Triceps':         ['triceps'],
  'Glúteos':         ['gluteos'],
  'Gluteos':         ['gluteos'],
  'Isquiotibiales':  ['femorales'],
  'Femorales':       ['femorales'],
  'Gemelos':         ['gemelos'],
  'Pantorrillas':    ['gemelos'],
};

// IDs que son de la vista posterior
const _backIds = {
  'dorsales', 'femorales', 'gemelos', 'gluteos',
  'trapecio_back', 'triceps',
};

// ── Músculos disponibles ───────────────────────────────────────────────────────
class _MuscleGroup {
  final String id;
  final String assetPath;
  final bool isFront;
  const _MuscleGroup(this.id, this.assetPath, {required this.isFront});
}

const _kFrontMuscles = [
  _MuscleGroup('abdomen',       'assets/images/partes_cuerpo/musculos/front_muscles/abdomen.svg',      isFront: true),
  _MuscleGroup('aductores',     'assets/images/partes_cuerpo/musculos/front_muscles/aductores.svg',    isFront: true),
  _MuscleGroup('antebrazo',     'assets/images/partes_cuerpo/musculos/front_muscles/antebrazo.svg',    isFront: true),
  _MuscleGroup('biceps',        'assets/images/partes_cuerpo/musculos/front_muscles/biceps.svg',       isFront: true),
  _MuscleGroup('cuadriceps',    'assets/images/partes_cuerpo/musculos/front_muscles/cuadriceps.svg',   isFront: true),
  _MuscleGroup('hombros',       'assets/images/partes_cuerpo/musculos/front_muscles/hombros.svg',      isFront: true),
  _MuscleGroup('oblicuos',      'assets/images/partes_cuerpo/musculos/front_muscles/oblicuos.svg',     isFront: true),
  _MuscleGroup('pectorales',    'assets/images/partes_cuerpo/musculos/front_muscles/pectorales.svg',   isFront: true),
  _MuscleGroup('serratos',      'assets/images/partes_cuerpo/musculos/front_muscles/serratos.svg',     isFront: true),
  _MuscleGroup('soleo',         'assets/images/partes_cuerpo/musculos/front_muscles/soleo.svg',        isFront: true),
  _MuscleGroup('tibial_ant',    'assets/images/partes_cuerpo/musculos/front_muscles/tibial_ant.svg',   isFront: true),
  _MuscleGroup('trapecio_front','assets/images/partes_cuerpo/musculos/front_muscles/trapecio.svg',     isFront: true),
];

const _kBackMuscles = [
  _MuscleGroup('dorsales',     'assets/images/partes_cuerpo/musculos/back_mucles/dorsales.svg',  isFront: false),
  _MuscleGroup('femorales',    'assets/images/partes_cuerpo/musculos/back_mucles/femorales.svg', isFront: false),
  _MuscleGroup('gemelos',      'assets/images/partes_cuerpo/musculos/back_mucles/gemelos.svg',   isFront: false),
  _MuscleGroup('gluteos',      'assets/images/partes_cuerpo/musculos/back_mucles/gluteos.svg',   isFront: false),
  _MuscleGroup('trapecio_back','assets/images/partes_cuerpo/musculos/back_mucles/trapecio.svg',  isFront: false),
  _MuscleGroup('triceps',      'assets/images/partes_cuerpo/musculos/back_mucles/triceps.svg',   isFront: false),
];

// ── Offsets SVG ────────────────────────────────────────────────────────────────
class _MuscleOffset {
  final double top;
  final double left;
  const _MuscleOffset({this.top = 0.0, this.left = 0.0});
}

const Map<String, _MuscleOffset> _frontOffsets = {
  'abdomen':        _MuscleOffset(top: -0.42,  left: -0.34),
  'aductores':      _MuscleOffset(top:  0.01,  left:  0.02),
  'antebrazo':      _MuscleOffset(top: -0.30,  left: -0.078),
  'biceps':         _MuscleOffset(top: -0.24,  left: -0.154),
  'cuadriceps':     _MuscleOffset(top:  0.03,  left:  0.02),
  'hombros':        _MuscleOffset(top: -0.184, left: -0.205),
  'oblicuos':       _MuscleOffset(top: -0.36,  left: -0.31),
  'pectorales':     _MuscleOffset(top: -0.19,  left: -0.27),
  'serratos':       _MuscleOffset(top: -0.274, left: -0.274),
  'soleo':          _MuscleOffset(top:  0.0,   left:  0.015),
  'tibial_ant':     _MuscleOffset(top: -0.01,  left:  0.02),
  'trapecio_front': _MuscleOffset(top: -0.12,  left: -0.284),
};

const Map<String, _MuscleOffset> _backOffsets = {
  'dorsales':     _MuscleOffset(top: -0.196, left: -0.248),
  'femorales':    _MuscleOffset(top:  0.03,  left:  0.087),
  'gemelos':      _MuscleOffset(top:  0.03,  left:  0.088),
  'gluteos':      _MuscleOffset(top: -0.39,  left: -0.26),
  'trapecio_back':_MuscleOffset(top: -0.075, left: -0.25),
  'triceps':      _MuscleOffset(top: -0.24,  left: -0.14),
};

// ── Convierte grupos del backend a IDs del mapa ───────────────────────────────
Set<String> _frontIdsFromGrupos(List<String> grupos) {
  final ids = <String>{};
  for (final g in grupos) {
    final mapped = _grupoToIds[g] ?? [];
    for (final id in mapped) {
      if (!_backIds.contains(id)) ids.add(id);
    }
  }
  return ids;
}

Set<String> _backIdsFromGrupos(List<String> grupos) {
  final ids = <String>{};
  for (final g in grupos) {
    final mapped = _grupoToIds[g] ?? [];
    for (final id in mapped) {
      if (_backIds.contains(id)) ids.add(id);
    }
  }
  return ids;
}

// ══════════════════════════════════════════════════════════════════════════════
// Widget del mapa muscular (solo visualización, sin botones)
// ══════════════════════════════════════════════════════════════════════════════
class MuscleMapWidget extends StatelessWidget {
  final Set<String> activeFrontMuscles;
  final Set<String> activeBackMuscles;

  const MuscleMapWidget({
    super.key,
    required this.activeFrontMuscles,
    required this.activeBackMuscles,
  });

  static const double _frontRatio = 1280 / 920;
  static const double _backRatio  = 1248 / 902;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double totalW = constraints.maxWidth;
        final double viewW  = (totalW - 1) / 2;
        final double frontH = viewW * _frontRatio;
        final double backH  = viewW * _backRatio;
        final double rowH   = frontH > backH ? frontH : backH;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              SizedBox(
                width: viewW,
                child: const Text('Vista frontal',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              const SizedBox(width: 1),
              SizedBox(
                width: viewW,
                child: const Text('Vista posterior',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ]),
            const SizedBox(height: 8),
            SizedBox(
              height: rowH,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── FRONTAL ───────────────────────────────────────────────
                  SizedBox(
                    width: viewW,
                    height: frontH * 1.15,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          top: -10, left: 0,
                          width: viewW, height: frontH,
                          child: SvgPicture.asset(
                            'assets/images/partes_cuerpo/cuerpo_base/front_desac.svg',
                            fit: BoxFit.contain,
                            alignment: Alignment.topCenter,
                          ),
                        ),
                        for (final muscle in _kFrontMuscles)
                          if (activeFrontMuscles.contains(muscle.id))
                            Builder(builder: (context) {
                              final offset = _frontOffsets[muscle.id] ?? const _MuscleOffset();
                              return Positioned(
                                top:  -10 + (offset.top * frontH),
                                left: offset.left * viewW,
                                width: viewW, height: frontH,
                                child: SvgPicture.asset(
                                  muscle.assetPath,
                                  fit: BoxFit.contain,
                                  alignment: Alignment.topCenter,
                                ),
                              );
                            }),
                      ],
                    ),
                  ),
                  // Separador
                  Container(width: 1, height: rowH, color: Colors.grey.withValues(alpha: 0.3)),
                  // ── POSTERIOR ─────────────────────────────────────────────
                  SizedBox(
                    width: viewW,
                    height: backH,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: SvgPicture.asset(
                            'assets/images/partes_cuerpo/cuerpo_base/back_desac.svg',
                            fit: BoxFit.contain,
                            alignment: Alignment.topCenter,
                          ),
                        ),
                        for (final muscle in _kBackMuscles)
                          if (activeBackMuscles.contains(muscle.id))
                            Builder(builder: (context) {
                              final offset = _backOffsets[muscle.id] ?? const _MuscleOffset();
                              return Positioned(
                                top:  offset.top * backH,
                                left: offset.left * viewW,
                                width: viewW, height: backH,
                                child: SvgPicture.asset(
                                  muscle.assetPath,
                                  fit: BoxFit.contain,
                                  alignment: Alignment.topCenter,
                                ),
                              );
                            }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ProgressScreen
// ══════════════════════════════════════════════════════════════════════════════
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  bool _loading = true;
  String? _error;
  DateTime _mesActual = DateTime.now();

  final Map<String, Map<String, dynamic>> _detalleEntrenamiento = {};
  final Map<String, Map<String, dynamic>> _detalleAlimentacion  = {};

  int _rachaActual = 0;
  int _rachaMaxima = 0;

  // Grupos musculares trabajados hoy
  List<String> _gruposHoy = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<Map<String, String>> get _headers async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> _cargarDatos() async {
    setState(() { _loading = true; _error = null; });
    try {
      final h = await _headers;
      final results = await Future.wait([
        http.get(Uri.parse('${ApiConfig.baseUrl}/api/actividad/'),             headers: h),
        http.get(Uri.parse('${ApiConfig.baseUrl}/api/progreso/alimentacion/'), headers: h),
        http.get(Uri.parse('${ApiConfig.baseUrl}/api/progreso/resumen/'),      headers: h),
      ]);

      if (!mounted) return;

      _detalleEntrenamiento.clear();
      _detalleAlimentacion.clear();

      if (results[0].statusCode == 200) {
        final data = jsonDecode(results[0].body);
        final list = data is List ? data : (data['results'] ?? []) as List;
        for (final r in list) {
          final fecha = (r['fecha'] ?? '').toString();
          if (fecha.isNotEmpty) _detalleEntrenamiento[fecha] = Map<String, dynamic>.from(r);
        }
      }

      if (results[1].statusCode == 200) {
        final data = jsonDecode(results[1].body);
        final list = data is List ? data : (data['results'] ?? []) as List;
        for (final r in list) {
          final fecha = (r['fecha'] ?? '').toString();
          if (fecha.isNotEmpty) _detalleAlimentacion[fecha] = Map<String, dynamic>.from(r);
        }
      }

      // Grupos musculares de hoy desde el resumen
      if (results[2].statusCode == 200) {
        final resumen = jsonDecode(results[2].body);
        final sesiones = resumen['sesiones_recientes'] as List? ?? [];
        final hoy = _fechaStr(DateTime.now());
        for (final s in sesiones) {
          if ((s['fecha'] ?? '').toString().startsWith(hoy)) {
            final grupos = s['grupos_musculares'];
            if (grupos is List) {
              _gruposHoy = grupos.map((g) => g.toString()).toList();
            }
            break;
          }
        }
      }

      _calcularRachas();
      setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() { _error = 'No se pudo cargar el progreso.'; _loading = false; });
    }
  }

  void _calcularRachas() {
    if (_detalleEntrenamiento.isEmpty) { _rachaActual = 0; _rachaMaxima = 0; return; }
    final fechas = _detalleEntrenamiento.keys.toList()..sort();
    int maxima = 1, segmento = 1;
    for (int i = 1; i < fechas.length; i++) {
      final prev = DateTime.parse(fechas[i - 1]);
      final curr = DateTime.parse(fechas[i]);
      if (curr.difference(prev).inDays == 1) {
        segmento++;
        if (segmento > maxima) maxima = segmento;
      } else {
        segmento = 1;
      }
    }
    _rachaMaxima = maxima;
    int actual = 0;
    DateTime dia = DateTime.now();
    while (_detalleEntrenamiento.containsKey(_fechaStr(dia))) {
      actual++;
      dia = dia.subtract(const Duration(days: 1));
    }
    _rachaActual = actual;
  }

  String _fechaStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Color? _colorDia(String fecha) {
    final entreno = _detalleEntrenamiento.containsKey(fecha);
    final alim    = _detalleAlimentacion.containsKey(fecha);
    if (entreno && alim) return _cVerdeFuerte;
    if (entreno)         return _cVerdeClaro;
    if (alim)            return _cAzul;
    return null;
  }

  void _mostrarDetalleDia(String fecha, int diaNum) {
    final entreno = _detalleEntrenamiento[fecha];
    final alim    = _detalleAlimentacion[fecha];
    if (entreno == null && alim == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DetalleDiaSheet(fecha: fecha, entreno: entreno, alim: alim),
    );
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          _buildBanner(),
          _buildHomeStrip(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _kRed))
                : _error != null
                    ? _buildError()
                    : RefreshIndicator(
                        color: _kRed,
                        onRefresh: _cargarDatos,
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                          children: [
                            _buildRachaCard(),
                            const SizedBox(height: 20),
                            _buildMapaMuscular(),
                            const SizedBox(height: 20),
                            _buildCalendario(),
                            const SizedBox(height: 20),
                            _buildResumen(),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // ── Mapa muscular de hoy ───────────────────────────────────────────────────
  Widget _buildMapaMuscular() {
    final frontIds = _frontIdsFromGrupos(_gruposHoy);
    final backIds  = _backIdsFromGrupos(_gruposHoy);
    final hayDatos = frontIds.isNotEmpty || backIds.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.accessibility_new_rounded, color: _kRed, size: 22),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Músculos trabajados hoy',
                  style: TextStyle(color: _kDark, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            if (hayDatos)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _kRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${frontIds.length + backIds.length} grupos',
                  style: const TextStyle(fontSize: 11, color: _kRed, fontWeight: FontWeight.w600),
                ),
              ),
          ]),
          const Divider(height: 20),
          if (!hayDatos)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Icon(Icons.directions_run_rounded, size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text(
                      'Completa una sesión de entrenamiento\npara ver tus músculos trabajados',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            MuscleMapWidget(
              activeFrontMuscles: frontIds,
              activeBackMuscles:  backIds,
            ),
            const SizedBox(height: 16),
            // Etiquetas de grupos trabajados
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _gruposHoy.map((g) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _kRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kRed.withValues(alpha: 0.2)),
                ),
                child: Text(g,
                    style: const TextStyle(
                        fontSize: 12, color: _kRed, fontWeight: FontWeight.w600)),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ── Banner rojo fijo ───────────────────────────────────────────────────────
  Widget _buildBanner() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF25050), Color(0xFFB83030)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        bottom: 20, left: 20, right: 20,
      ),
      child: Row(children: [
        const Expanded(
          child: Text('MI PROGRESO',
              style: TextStyle(
                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold,
                  letterSpacing: 1.2)),
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: _cargarDatos,
        ),
      ]),
    );
  }

  Widget _buildHomeStrip() {
    return Container(
      color: const Color(0xFFB83030),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.chevron_left_rounded, size: 18),
          label: const Text('HOME'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kRed,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
    );
  }

  Widget _buildRachaCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF25050), Color(0xFFB83030)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _kRed.withValues(alpha: 0.3),
            blurRadius: 12, offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(children: [
        const Text('🔥', style: TextStyle(fontSize: 40)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              '$_rachaActual ${_rachaActual == 1 ? 'día' : 'días'} de racha',
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Racha máxima: $_rachaMaxima días',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildCalendario() {
    final primerDia   = DateTime(_mesActual.year, _mesActual.month, 1);
    final ultimoDia   = DateTime(_mesActual.year, _mesActual.month + 1, 0);
    final offset      = (primerDia.weekday - 1) % 7;
    final totalCeldas = offset + ultimoDia.day;
    final filas       = (totalCeldas / 7).ceil();
    const encabezados = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    final hoy         = _fechaStr(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded, color: _kDark),
              onPressed: () => setState(() =>
                  _mesActual = DateTime(_mesActual.year, _mesActual.month - 1)),
            ),
            Text(
              '${_nombreMes(_mesActual.month)} ${_mesActual.year}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _kDark),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded, color: _kDark),
              onPressed: () => setState(() =>
                  _mesActual = DateTime(_mesActual.year, _mesActual.month + 1)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: encabezados.map((d) => Expanded(
            child: Center(
              child: Text(d,
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: (d == 'S' || d == 'D') ? Colors.grey[400] : Colors.grey[600],
                  )),
            ),
          )).toList(),
        ),
        const SizedBox(height: 8),
        ...List.generate(filas, (fila) {
          return Row(
            children: List.generate(7, (col) {
              final idx    = fila * 7 + col;
              final diaNum = idx - offset + 1;
              if (diaNum < 1 || diaNum > ultimoDia.day) {
                return const Expanded(child: SizedBox(height: 38));
              }
              final fecha = _fechaStr(DateTime(_mesActual.year, _mesActual.month, diaNum));
              final color = _colorDia(fecha);
              final esHoy = fecha == hoy;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _mostrarDetalleDia(fecha, diaNum),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    height: 34,
                    decoration: BoxDecoration(
                      color: color ?? (esHoy ? _kDark.withValues(alpha: 0.05) : Colors.transparent),
                      shape: BoxShape.circle,
                      border: esHoy ? Border.all(color: _kRed, width: 2) : null,
                    ),
                    child: Center(
                      child: Text(
                        '$diaNum',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: esHoy ? FontWeight.bold : FontWeight.normal,
                          color: color != null ? Colors.white : (esHoy ? _kRed : _kDark),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          );
        }),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12, runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            _leyenda(_cVerdeFuerte, 'Entreno + Alim'),
            _leyenda(_cVerdeClaro,  'Solo entreno'),
            _leyenda(_cAzul,        'Solo alim'),
          ],
        ),
      ]),
    );
  }

  Widget _leyenda(Color color, String texto) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 11, height: 11, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(texto, style: const TextStyle(fontSize: 11, color: Colors.grey)),
    ]);
  }

  Widget _buildResumen() {
    final prefijo = '${_mesActual.year}-${_mesActual.month.toString().padLeft(2, '0')}';
    final sesionesDelMes = _detalleEntrenamiento.keys.where((f) => f.startsWith(prefijo)).length;
    final alimentDelMes  = _detalleAlimentacion.keys.where((f) => f.startsWith(prefijo)).length;
    final diasEnElMes    = DateTime(_mesActual.year, _mesActual.month + 1, 0).day;
    final pctConstancia  = diasEnElMes > 0
        ? (sesionesDelMes / diasEnElMes * 100).clamp(0.0, 100.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.bar_chart_rounded, color: _kRed, size: 22),
          SizedBox(width: 10),
          Text('Resumen del mes',
              style: TextStyle(color: _kDark, fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
        const Divider(height: 20),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 2.4,
          children: [
            _statTile(Icons.fitness_center_rounded, 'Sesiones', '$sesionesDelMes', _cVerdeFuerte),
            _statTile(Icons.restaurant_rounded, 'Alim. cumplida', '$alimentDelMes', _cAzul),
            _statTile(Icons.local_fire_department_rounded, 'Racha actual', '$_rachaActual días', _kRed),
            _statTile(Icons.percent_rounded, 'Constancia', '${pctConstancia.toStringAsFixed(1)}%', Colors.orange),
          ],
        ),
      ]),
    );
  }

  Widget _statTile(IconData icon, String label, String valor, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(valor, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off_rounded, size: 56, color: Colors.grey),
        const SizedBox(height: 12),
        Text(_error!, style: const TextStyle(color: Colors.grey, fontSize: 15)),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _cargarDatos,
          style: ElevatedButton.styleFrom(
            backgroundColor: _kRed,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Reintentar', style: TextStyle(color: Colors.white)),
        ),
      ]),
    );
  }

  String _nombreMes(int m) {
    const meses = ['Enero','Febrero','Marzo','Abril','Mayo','Junio',
        'Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];
    return meses[m - 1];
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Bottom sheet: detalle del día
// ══════════════════════════════════════════════════════════════════════════════
class _DetalleDiaSheet extends StatelessWidget {
  final String fecha;
  final Map<String, dynamic>? entreno;
  final Map<String, dynamic>? alim;

  const _DetalleDiaSheet({required this.fecha, required this.entreno, required this.alim});

  static const sheetDark        = Color(0xFF1A1A2E);
  static const sheetVerdeFuerte = Color(0xFF2E7D32);
  static const sheetVerdeClaro  = Color(0xFF81C784);
  static const sheetAzul        = Color(0xFF1976D2);
  static const sheetRed         = Color(0xFFF25050);

  String get fechaFormateada {
    final parts = fecha.split('-');
    if (parts.length != 3) return fecha;
    const meses = ['','enero','febrero','marzo','abril','mayo','junio',
        'julio','agosto','septiembre','octubre','noviembre','diciembre'];
    final mes = int.tryParse(parts[1]) ?? 0;
    return '${parts[2]} de ${meses[mes]} ${parts[0]}';
  }

  _NivelConfig nivelConfig(String nivel) {
    switch (nivel) {
      case 'excelente': return _NivelConfig('🌟', 'Excelente', sheetVerdeFuerte);
      case 'bueno':     return _NivelConfig('✅', 'Bueno', const Color(0xFF43C6AC));
      case 'regular':   return _NivelConfig('😐', 'Regular', const Color(0xFFFF9800));
      default:          return _NivelConfig('😕', 'Malo', sheetRed);
    }
  }

  String get resumenDia {
    if (entreno != null && alim != null) return 'Entrenaste y registraste tu alimentación 💪';
    if (entreno != null) return 'Solo entrenaste este día';
    if (alim    != null) return 'Solo registraste tu alimentación';
    return 'Sin actividad registrada';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Text(fechaFormateada,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: sheetDark)),
          const SizedBox(height: 4),
          Text(resumenDia, style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          const SizedBox(height: 20),
          buildSeccionEntrenamiento(),
          const SizedBox(height: 12),
          buildSeccionAlimentacion(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                backgroundColor: Colors.grey[100],
              ),
              child: const Text('Cerrar',
                  style: TextStyle(color: sheetDark, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSeccionEntrenamiento() {
    if (entreno == null) {
      return buildSinActividad(Icons.fitness_center_rounded, 'Entrenamiento', 'No entrenaste este día');
    }
    final sesion = entreno!['sesion_numero'] ?? '—';
    final notas  = (entreno!['notas'] ?? '').toString().trim();
    return buildTarjeta(
      color: sheetVerdeClaro,
      icon: Icons.fitness_center_rounded,
      titulo: 'Entrenamiento',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        buildFila(Icons.tag_rounded, 'Sesión completada', 'Sesión #$sesion', sheetVerdeFuerte),
        if (notas.isNotEmpty) ...[
          const SizedBox(height: 8),
          buildFila(Icons.edit_note_rounded, 'Notas', notas, Colors.grey),
        ],
      ]),
    );
  }

  Widget buildSeccionAlimentacion() {
    if (alim == null) {
      return buildSinActividad(Icons.restaurant_rounded, 'Alimentación', 'No registraste tu alimentación');
    }
    final nivelStr = (alim!['nivel_cumplimiento'] ?? '').toString();
    final cal      = alim!['calorias_consumidas'];
    final agua     = alim!['agua_consumida'];
    final notas    = (alim!['notas'] ?? '').toString().trim();
    final cfg      = nivelConfig(nivelStr);

    return buildTarjeta(
      color: sheetAzul,
      icon: Icons.restaurant_rounded,
      titulo: 'Alimentación',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: cfg.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cfg.color.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            Text(cfg.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Text(cfg.label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: cfg.color)),
          ]),
        ),
        if (cal != null) ...[
          const SizedBox(height: 8),
          buildFila(Icons.local_fire_department_rounded, 'Calorías consumidas', '$cal kcal', const Color(0xFFFF6B6B)),
        ],
        if (agua != null) ...[
          const SizedBox(height: 8),
          buildFila(Icons.water_drop_rounded, 'Agua consumida', '$agua litros', sheetAzul),
        ],
        if (notas.isNotEmpty) ...[
          const SizedBox(height: 8),
          buildFila(Icons.edit_note_rounded, 'Notas', notas, Colors.grey),
        ],
      ]),
    );
  }

  Widget buildTarjeta({required Color color, required IconData icon, required String titulo, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Text(titulo, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
        ]),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }

  Widget buildSinActividad(IconData icon, String titulo, String mensaje) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle),
          child: Icon(icon, color: Colors.grey[400], size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey[500])),
            const SizedBox(height: 2),
            Text(mensaje, style: TextStyle(fontSize: 12, color: Colors.grey[400])),
          ]),
        ),
      ]),
    );
  }

  Widget buildFila(IconData icon, String label, String valor, Color color) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 15),
      const SizedBox(width: 8),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          Text(valor, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: sheetDark)),
        ]),
      ),
    ]);
  }
}

class _NivelConfig {
  final String emoji;
  final String label;
  final Color  color;
  const _NivelConfig(this.emoji, this.label, this.color);
}