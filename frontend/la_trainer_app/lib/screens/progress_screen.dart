import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

// ── Mapeo de keywords de ejercicio → grupos musculares ─────────────────────────
const Map<String, List<String>> _musculoPorKeyword = {
  // Pecho
  'press': ['pecho'],
  'pecho': ['pecho'],
  'chest': ['pecho'],
  'fondos': ['pecho', 'triceps'],
  'push': ['pecho', 'triceps'],
  // Espalda
  'remo': ['espalda'],
  'jalón': ['espalda', 'biceps'],
  'pull': ['espalda', 'biceps'],
  'dominadas': ['espalda', 'biceps'],
  'espalda': ['espalda'],
  'back': ['espalda'],
  'lumbar': ['lumbares'],
  'lumbares': ['lumbares'],
  'deadlift': ['lumbares', 'isquiotibiales', 'gluteos'],
  'peso muerto': ['lumbares', 'isquiotibiales', 'gluteos'],
  // Hombros
  'hombro': ['hombros'],
  'shoulder': ['hombros'],
  'militar': ['hombros'],
  'elevacion': ['hombros'],
  // Brazos
  'bicep': ['biceps'],
  'curl': ['biceps'],
  'tricep': ['triceps'],
  'extension': ['triceps'],
  // Piernas
  'squat': ['cuadriceps', 'gluteos'],
  'sentadilla': ['cuadriceps', 'gluteos'],
  'cuadriceps': ['cuadriceps'],
  'femoral': ['isquiotibiales'],
  'isquio': ['isquiotibiales'],
  'leg': ['cuadriceps', 'isquiotibiales'],
  'prensa': ['cuadriceps', 'gluteos'],
  'gluteo': ['gluteos'],
  'glúteo': ['gluteos'],
  'hip': ['gluteos'],
  'lunges': ['cuadriceps', 'gluteos'],
  'zancada': ['cuadriceps', 'gluteos'],
  'pantorrilla': ['pantorrillas'],
  'calf': ['pantorrillas'],
  'gemelo': ['pantorrillas'],
  // Core
  'abdominal': ['abdomen'],
  'abs': ['abdomen'],
  'core': ['abdomen'],
  'plancha': ['abdomen'],
  'crunch': ['abdomen'],
};

/// Dado el historial de entrenamientos, devuelve qué grupos musculares
/// se trabajaron y con qué intensidad (0.0–1.0).
Map<String, double> _calcularMusculosActivos(
    Map<String, Map<String, dynamic>> historial) {
  final conteo = <String, int>{};

  for (final reg in historial.values) {
    // Buscamos en notas, nombre del ejercicio o cualquier campo de texto
    final texto = [
      reg['notas'],
      reg['ejercicio'],
      reg['nombre'],
      reg['descripcion'],
      reg['rutina'],
    ].where((v) => v != null).map((v) => v.toString().toLowerCase()).join(' ');

    for (final entry in _musculoPorKeyword.entries) {
      if (texto.contains(entry.key)) {
        for (final m in entry.value) {
          conteo[m] = (conteo[m] ?? 0) + 1;
        }
      }
    }
  }

  if (conteo.isEmpty) return {};
  final maxVal = conteo.values.reduce((a, b) => a > b ? a : b);
  return conteo.map((k, v) => MapEntry(k, v / maxVal));
}

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

  // Filtro del mapa corporal: 7, 30 días o total
  int _filtroDias = 7;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<Map<String, String>> get _headers async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      'ngrok-skip-browser-warning': 'true',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> _cargarDatos() async {
    setState(() { _loading = true; _error = null; });
    try {
      final h = await _headers;
      final results = await Future.wait([
        http.get(Uri.parse('${ApiConfig.baseUrl}/api/actividad/'), headers: h),
        http.get(Uri.parse('${ApiConfig.baseUrl}/api/progreso/alimentacion/'), headers: h),
      ]);

      if (!mounted) return;

      _detalleEntrenamiento.clear();
      _detalleAlimentacion.clear();

      if (results[0].statusCode == 200) {
        final data = jsonDecode(results[0].body);
        final list = data is List ? data : (data['results'] ?? []) as List;
        for (final r in list) {
          final fecha = (r['fecha'] ?? '').toString();
          if (fecha.isNotEmpty) {
            _detalleEntrenamiento[fecha] = Map<String, dynamic>.from(r);
          }
        }
      }

      if (results[1].statusCode == 200) {
        final data = jsonDecode(results[1].body);
        final list = data is List ? data : (data['results'] ?? []) as List;
        for (final r in list) {
          final fecha = (r['fecha'] ?? '').toString();
          if (fecha.isNotEmpty) {
            _detalleAlimentacion[fecha] = Map<String, dynamic>.from(r);
          }
        }
      }

      _calcularRachas();
      setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() {
        _error   = 'No se pudo cargar el progreso.';
        _loading = false;
      });
    }
  }

  void _calcularRachas() {
    if (_detalleEntrenamiento.isEmpty) {
      _rachaActual = 0;
      _rachaMaxima = 0;
      return;
    }
    final fechas = _detalleEntrenamiento.keys.toList()..sort();
    int maxima   = 1;
    int segmento = 1;
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
      builder: (_) => _DetalleDiaSheet(
        fecha: fecha,
        entreno: entreno,
        alim: alim,
      ),
    );
  }

  /// Filtra el historial según el rango de días seleccionado
  Map<String, Map<String, dynamic>> get _historialFiltrado {
    if (_filtroDias == 0) return _detalleEntrenamiento; // total
    final desde = DateTime.now().subtract(Duration(days: _filtroDias));
    return Map.fromEntries(
      _detalleEntrenamiento.entries.where((e) {
        try {
          return DateTime.parse(e.key).isAfter(desde);
        } catch (_) {
          return false;
        }
      }),
    );
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          // ── Banner rojo fijo ─────────────────────────────────────────────
          _buildBanner(),
          // ── Botón HOME fijo (no scrollea) ────────────────────────────────
          _buildHomeStrip(),
          // ── Contenido scrollable ─────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _kRed))
                : _error != null
                    ? _buildError()
                    : RefreshIndicator(
                        color: _kRed,
                        onRefresh: _cargarDatos,
                        child: ListView(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 20),
                          children: [
                            _buildRachaCard(),
                            const SizedBox(height: 20),
                            _buildBodyMap(),
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

  // ── Banner rojo ────────────────────────────────────────────────────────────
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
                onPressed: _cargarDatos,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Text(
                'MI PROGRESO',
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

  // ── Tira HOME fija ─────────────────────────────────────────────────────────
  Widget _buildHomeStrip() {
    return Container(
      color: _kBg,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.80,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
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
          ),
        ),
      ),
    );
  }

  // ── Racha card ─────────────────────────────────────────────────────────────
  Widget _buildRachaCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF25050), Color(0xFFB83030)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
            color: _kRed.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        const Text('🔥', style: TextStyle(fontSize: 40)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              '$_rachaActual ${_rachaActual == 1 ? 'día' : 'días'} de racha',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('Racha máxima: $_rachaMaxima días',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.8), fontSize: 13)),
          ]),
        ),
      ]),
    );
  }

  // ── Mapa corporal ──────────────────────────────────────────────────────────
  Widget _buildBodyMap() {
    final musculos = _calcularMusculosActivos(_historialFiltrado);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título
          const Row(children: [
            Icon(Icons.accessibility_new_rounded, color: _kRed, size: 22),
            SizedBox(width: 10),
            Text('Mapa muscular',
                style: TextStyle(
                    color: _kDark, fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
          const SizedBox(height: 4),
          Text('Zonas trabajadas según tu historial',
              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          const SizedBox(height: 16),

          // Selector de rango
          Row(
            children: [
              _filtroChip('7 días', 7),
              const SizedBox(width: 8),
              _filtroChip('30 días', 30),
              const SizedBox(width: 8),
              _filtroChip('Total', 0),
            ],
          ),
          const SizedBox(height: 20),

          // SVG del cuerpo (frontal + trasero)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(children: [
                  Text('Frontal',
                      style: TextStyle(fontSize: 11,
                          color: Colors.grey[400], fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  _BodyFront(musculos: musculos),
                ]),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(children: [
                  Text('Posterior',
                      style: TextStyle(fontSize: 11,
                          color: Colors.grey[400], fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  _BodyBack(musculos: musculos),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Leyenda de músculos trabajados
          if (musculos.isNotEmpty) _buildMusculosLegend(musculos),
        ],
      ),
    );
  }

  Widget _filtroChip(String label, int dias) {
    final selected = _filtroDias == dias;
    return GestureDetector(
      onTap: () => setState(() => _filtroDias = dias),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _kRed : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : Colors.grey[600],
            )),
      ),
    );
  }

  Widget _buildMusculosLegend(Map<String, double> musculos) {
    final ordenados = musculos.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1),
        const SizedBox(height: 12),
        Text('Grupos trabajados',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600])),
        const SizedBox(height: 10),
        ...ordenados.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Text(
              _nombreMusculo(e.key),
              style: const TextStyle(fontSize: 13, color: _kDark),
            ),
            const Spacer(),
            SizedBox(
              width: 120,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: e.value,
                  minHeight: 6,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation(_musculoColor(e.value)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('${(e.value * 100).toInt()}%',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _musculoColor(e.value))),
          ]),
        )),
      ],
    );
  }

  String _nombreMusculo(String key) {
    const nombres = {
      'pecho': 'Pecho',
      'espalda': 'Espalda',
      'hombros': 'Hombros',
      'biceps': 'Bíceps',
      'triceps': 'Tríceps',
      'cuadriceps': 'Cuádriceps',
      'isquiotibiales': 'Isquiotibiales',
      'gluteos': 'Glúteos',
      'lumbares': 'Lumbares',
      'abdomen': 'Abdomen',
      'pantorrillas': 'Pantorrillas',
    };
    return nombres[key] ?? key;
  }

  Color _musculoColor(double intensidad) {
    if (intensidad > 0.7) return const Color(0xFFF25050);
    if (intensidad > 0.4) return const Color(0xFFFF9800);
    return const Color(0xFF43C6AC);
  }

  // ── Calendario ─────────────────────────────────────────────────────────────
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
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3))],
      ),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded, color: _kDark),
              onPressed: () => setState(() => _mesActual =
                  DateTime(_mesActual.year, _mesActual.month - 1)),
            ),
            Text(
              '${_nombreMes(_mesActual.month)} ${_mesActual.year}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16, color: _kDark),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded, color: _kDark),
              onPressed: () => setState(() => _mesActual =
                  DateTime(_mesActual.year, _mesActual.month + 1)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: encabezados.map((d) => Expanded(
            child: Center(
              child: Text(d, style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: (d == 'S' || d == 'D')
                    ? Colors.grey[400]
                    : Colors.grey[600],
              )),
            ),
          )).toList(),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _kDark.withOpacity(0.04),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.touch_app_rounded, size: 13, color: Colors.grey),
            SizedBox(width: 4),
            Text('Toca un día para ver el detalle',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
          ]),
        ),
        const SizedBox(height: 10),
        ...List.generate(filas, (fila) {
          return Row(
            children: List.generate(7, (col) {
              final idx    = fila * 7 + col;
              final diaNum = idx - offset + 1;
              if (diaNum < 1 || diaNum > ultimoDia.day) {
                return const Expanded(child: SizedBox(height: 44));
              }
              final fecha = '${_mesActual.year}-'
                  '${_mesActual.month.toString().padLeft(2, '0')}-'
                  '${diaNum.toString().padLeft(2, '0')}';
              final esHoy          = fecha == hoy;
              final color          = _colorDia(fecha);
              final tieneActividad = color != null;

              return Expanded(
                child: GestureDetector(
                  onTap: () => _mostrarDetalleDia(fecha, diaNum),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: tieneActividad
                              ? color.withOpacity(0.85)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                          border: esHoy
                              ? Border.all(color: _kRed, width: 2)
                              : tieneActividad
                                  ? Border.all(
                                      color: color.withOpacity(0.4), width: 1)
                                  : null,
                        ),
                        child: Center(
                          child: Text(
                            '$diaNum',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: (esHoy || tieneActividad)
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: tieneActividad
                                  ? (color == _cVerdeClaro ? _kDark : Colors.white)
                                  : esHoy
                                      ? _kRed
                                      : _kDark,
                            ),
                          ),
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
          spacing: 12,
          runSpacing: 8,
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
      Container(
          width: 11, height: 11,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(texto, style: const TextStyle(fontSize: 11, color: Colors.grey)),
    ]);
  }

  // ── Resumen del mes ────────────────────────────────────────────────────────
  Widget _buildResumen() {
    final prefijo = '${_mesActual.year}-${_mesActual.month.toString().padLeft(2, '0')}';
    final sesionesDelMes =
        _detalleEntrenamiento.keys.where((f) => f.startsWith(prefijo)).length;
    final alimentDelMes =
        _detalleAlimentacion.keys.where((f) => f.startsWith(prefijo)).length;
    final diasEnElMes =
        DateTime(_mesActual.year, _mesActual.month + 1, 0).day;
    final pctConstancia = diasEnElMes > 0
        ? (sesionesDelMes / diasEnElMes * 100).clamp(0.0, 100.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.bar_chart_rounded, color: _kRed, size: 22),
          SizedBox(width: 10),
          Text('Resumen del mes',
              style: TextStyle(
                  color: _kDark, fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
        const Divider(height: 20),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.4,
          children: [
            _statTile(Icons.fitness_center_rounded, 'Sesiones',
                '$sesionesDelMes', _cVerdeFuerte),
            _statTile(Icons.restaurant_rounded, 'Alim. cumplida',
                '$alimentDelMes', _cAzul),
            _statTile(Icons.local_fire_department_rounded, 'Racha actual',
                '$_rachaActual días', _kRed),
            _statTile(Icons.percent_rounded, 'Constancia',
                '${pctConstancia.toStringAsFixed(1)}%', Colors.orange),
          ],
        ),
      ]),
    );
  }

  Widget _statTile(IconData icon, String label, String valor, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
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
              Text(valor,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15, color: color)),
              Text(label,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  overflow: TextOverflow.ellipsis),
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
    const meses = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return meses[m - 1];
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Widget: Cuerpo frontal (SVG paths simplificados por zona muscular)
// ══════════════════════════════════════════════════════════════════════════════
class _BodyFront extends StatelessWidget {
  final Map<String, double> musculos;
  const _BodyFront({required this.musculos});

  Color _color(String grupo) {
    final v = musculos[grupo];
    if (v == null) return const Color(0xFFD0E8F5); // sin actividad
    if (v > 0.7)  return const Color(0xFFF25050);
    if (v > 0.4)  return const Color(0xFFFF9800);
    return const Color(0xFF43C6AC);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth > 0 ? constraints.maxWidth : 120.0;
        return SizedBox(
          width: w,
          height: w / 0.52,
          child: CustomPaint(
            painter: _BodyFrontPainter(
          pecho:       _color('pecho'),
          hombros:     _color('hombros'),
          biceps:      _color('biceps'),
          abdomen:     _color('abdomen'),
          cuadriceps:  _color('cuadriceps'),
          pantorrillas:_color('pantorrillas'),
          base:        const Color(0xFFD0E8F5),
          ),
          ),
        );
      },
    );
  }
}

class _BodyFrontPainter extends CustomPainter {
  final Color pecho, hombros, biceps, abdomen, cuadriceps, pantorrillas, base;
  const _BodyFrontPainter({
    required this.pecho, required this.hombros, required this.biceps,
    required this.abdomen, required this.cuadriceps, required this.pantorrillas,
    required this.base,
  });

  @override
  void paint(Canvas canvas, Size s) {
    if (s.width == 0 || s.height == 0) return;
    final w = s.width;
    final h = s.height;

    void fill(Color c, Path p) =>
        canvas.drawPath(p, Paint()..color = c..style = PaintingStyle.fill);
    void stroke(Path p) => canvas.drawPath(
        p, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.0);

    // ── Cabeza ──────────────────────────────────────────────────────────────
    final head = Path()..addOval(Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.055), width: w * 0.26, height: h * 0.085));
    fill(base, head); stroke(head);

    // ── Cuello ──────────────────────────────────────────────────────────────
    final neck = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.44, h * 0.09, w * 0.12, h * 0.04),
          const Radius.circular(4)));
    fill(base, neck);

    // ── Hombros ─────────────────────────────────────────────────────────────
    final shoulderL = Path()
      ..addOval(Rect.fromCenter(
          center: Offset(w * 0.21, h * 0.155), width: w * 0.16, height: h * 0.065));
    final shoulderR = Path()
      ..addOval(Rect.fromCenter(
          center: Offset(w * 0.79, h * 0.155), width: w * 0.16, height: h * 0.065));
    fill(hombros, shoulderL); stroke(shoulderL);
    fill(hombros, shoulderR); stroke(shoulderR);

    // ── Pecho ────────────────────────────────────────────────────────────────
    final chestL = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.28, h * 0.135, w * 0.19, h * 0.075),
          const Radius.circular(8)));
    final chestR = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.53, h * 0.135, w * 0.19, h * 0.075),
          const Radius.circular(8)));
    fill(pecho, chestL); stroke(chestL);
    fill(pecho, chestR); stroke(chestR);

    // ── Abdomen (6 bloques) ───────────────────────────────────────────────────
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 2; col++) {
        final block = Path()
          ..addRRect(RRect.fromRectAndRadius(
              Rect.fromLTWH(
                  w * (col == 0 ? 0.305 : 0.505),
                  h * (0.218 + row * 0.055),
                  w * 0.19, h * 0.048),
              const Radius.circular(5)));
        fill(abdomen, block); stroke(block);
      }
    }

    // ── Brazos (bíceps) ────────────────────────────────────────────────────
    final armL = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.10, h * 0.19, w * 0.13, h * 0.14),
          const Radius.circular(8)));
    final armR = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.77, h * 0.19, w * 0.13, h * 0.14),
          const Radius.circular(8)));
    fill(biceps, armL); stroke(armL);
    fill(biceps, armR); stroke(armR);

    // ── Antebrazos ────────────────────────────────────────────────────────
    final foreL = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.07, h * 0.34, w * 0.11, h * 0.12),
          const Radius.circular(6)));
    final foreR = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.82, h * 0.34, w * 0.11, h * 0.12),
          const Radius.circular(6)));
    fill(base, foreL); stroke(foreL);
    fill(base, foreR); stroke(foreR);

    // ── Caderas / oblicuos ─────────────────────────────────────────────────
    final hip = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.28, h * 0.385, w * 0.44, h * 0.06),
          const Radius.circular(8)));
    fill(base, hip); stroke(hip);

    // ── Cuádriceps ────────────────────────────────────────────────────────
    final quadL = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.29, h * 0.455, w * 0.18, h * 0.175),
          const Radius.circular(10)));
    final quadR = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.53, h * 0.455, w * 0.18, h * 0.175),
          const Radius.circular(10)));
    fill(cuadriceps, quadL); stroke(quadL);
    fill(cuadriceps, quadR); stroke(quadR);

    // ── Rodillas ──────────────────────────────────────────────────────────
    final kneeL = Path()..addOval(Rect.fromCenter(
        center: Offset(w * 0.38, h * 0.645), width: w * 0.14, height: h * 0.045));
    final kneeR = Path()..addOval(Rect.fromCenter(
        center: Offset(w * 0.62, h * 0.645), width: w * 0.14, height: h * 0.045));
    fill(base, kneeL); fill(base, kneeR);

    // ── Pantorrillas ──────────────────────────────────────────────────────
    final calfL = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.30, h * 0.675, w * 0.16, h * 0.16),
          const Radius.circular(10)));
    final calfR = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.54, h * 0.675, w * 0.16, h * 0.16),
          const Radius.circular(10)));
    fill(pantorrillas, calfL); stroke(calfL);
    fill(pantorrillas, calfR); stroke(calfR);

    // ── Pies ──────────────────────────────────────────────────────────────
    final footL = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.28, h * 0.845, w * 0.20, h * 0.04),
          const Radius.circular(4)));
    final footR = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.52, h * 0.845, w * 0.20, h * 0.04),
          const Radius.circular(4)));
    fill(base, footL); fill(base, footR);
  }

  @override
  bool shouldRepaint(_BodyFrontPainter old) =>
      old.pecho != pecho || old.abdomen != abdomen ||
      old.cuadriceps != cuadriceps || old.hombros != hombros;
}

// ══════════════════════════════════════════════════════════════════════════════
// Widget: Cuerpo posterior (espalda, glúteos, isquiotibiales, lumbares)
// ══════════════════════════════════════════════════════════════════════════════
class _BodyBack extends StatelessWidget {
  final Map<String, double> musculos;
  const _BodyBack({required this.musculos});

  Color _color(String grupo) {
    final v = musculos[grupo];
    if (v == null) return const Color(0xFFD0E8F5);
    if (v > 0.7)  return const Color(0xFFF25050);
    if (v > 0.4)  return const Color(0xFFFF9800);
    return const Color(0xFF43C6AC);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth > 0 ? constraints.maxWidth : 120.0;
        return SizedBox(
          width: w,
          height: w / 0.52,
          child: CustomPaint(
            painter: _BodyBackPainter(
          espalda:        _color('espalda'),
          lumbares:       _color('lumbares'),
          gluteos:        _color('gluteos'),
          isquiotibiales: _color('isquiotibiales'),
          hombros:        _color('hombros'),
          triceps:        _color('triceps'),
          pantorrillas:   _color('pantorrillas'),
          base:           const Color(0xFFD0E8F5),
          ),
          ),
        );
      },
    );
  }
}

class _BodyBackPainter extends CustomPainter {
  final Color espalda, lumbares, gluteos, isquiotibiales,
              hombros, triceps, pantorrillas, base;
  const _BodyBackPainter({
    required this.espalda, required this.lumbares, required this.gluteos,
    required this.isquiotibiales, required this.hombros, required this.triceps,
    required this.pantorrillas, required this.base,
  });

  @override
  void paint(Canvas canvas, Size s) {
    if (s.width == 0 || s.height == 0) return;
    final w = s.width;
    final h = s.height;

    void fill(Color c, Path p) =>
        canvas.drawPath(p, Paint()..color = c..style = PaintingStyle.fill);
    void stroke(Path p) => canvas.drawPath(
        p, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.0);

    // ── Cabeza ──────────────────────────────────────────────────────────────
    final head = Path()..addOval(Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.055), width: w * 0.26, height: h * 0.085));
    fill(base, head); stroke(head);

    // ── Cuello ──────────────────────────────────────────────────────────────
    final neck = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.44, h * 0.09, w * 0.12, h * 0.04),
          const Radius.circular(4)));
    fill(base, neck);

    // ── Hombros (trapecios) ──────────────────────────────────────────────
    final trapL = Path()
      ..addOval(Rect.fromCenter(
          center: Offset(w * 0.21, h * 0.155), width: w * 0.16, height: h * 0.065));
    final trapR = Path()
      ..addOval(Rect.fromCenter(
          center: Offset(w * 0.79, h * 0.155), width: w * 0.16, height: h * 0.065));
    fill(hombros, trapL); stroke(trapL);
    fill(hombros, trapR); stroke(trapR);

    // ── Espalda alta (dorsales) ────────────────────────────────────────────
    final upperBack = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.27, h * 0.135, w * 0.46, h * 0.10),
          const Radius.circular(10)));
    fill(espalda, upperBack); stroke(upperBack);

    // ── Espalda media ────────────────────────────────────────────────────
    final midBack = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.29, h * 0.24, w * 0.42, h * 0.08),
          const Radius.circular(8)));
    fill(espalda, midBack); stroke(midBack);

    // ── Lumbares ──────────────────────────────────────────────────────────
    final lumbar = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.33, h * 0.325, w * 0.34, h * 0.055),
          const Radius.circular(6)));
    fill(lumbares, lumbar); stroke(lumbar);

    // ── Tríceps ─────────────────────────────────────────────────────────
    final triL = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.10, h * 0.19, w * 0.13, h * 0.14),
          const Radius.circular(8)));
    final triR = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.77, h * 0.19, w * 0.13, h * 0.14),
          const Radius.circular(8)));
    fill(triceps, triL); stroke(triL);
    fill(triceps, triR); stroke(triR);

    // ── Antebrazos ───────────────────────────────────────────────────────
    final foreL = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.07, h * 0.34, w * 0.11, h * 0.12),
          const Radius.circular(6)));
    final foreR = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.82, h * 0.34, w * 0.11, h * 0.12),
          const Radius.circular(6)));
    fill(base, foreL); stroke(foreL);
    fill(base, foreR); stroke(foreR);

    // ── Glúteos ────────────────────────────────────────────────────────────
    final glutL = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.29, h * 0.385, w * 0.20, h * 0.085),
          const Radius.circular(10)));
    final glutR = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.51, h * 0.385, w * 0.20, h * 0.085),
          const Radius.circular(10)));
    fill(gluteos, glutL); stroke(glutL);
    fill(gluteos, glutR); stroke(glutR);

    // ── Isquiotibiales ────────────────────────────────────────────────────
    final hamL = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.29, h * 0.478, w * 0.18, h * 0.16),
          const Radius.circular(10)));
    final hamR = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.53, h * 0.478, w * 0.18, h * 0.16),
          const Radius.circular(10)));
    fill(isquiotibiales, hamL); stroke(hamL);
    fill(isquiotibiales, hamR); stroke(hamR);

    // ── Rodillas ────────────────────────────────────────────────────────
    final kneeL = Path()..addOval(Rect.fromCenter(
        center: Offset(w * 0.38, h * 0.648), width: w * 0.14, height: h * 0.045));
    final kneeR = Path()..addOval(Rect.fromCenter(
        center: Offset(w * 0.62, h * 0.648), width: w * 0.14, height: h * 0.045));
    fill(base, kneeL); fill(base, kneeR);

    // ── Pantorrillas ─────────────────────────────────────────────────────
    final calfL = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.30, h * 0.675, w * 0.16, h * 0.16),
          const Radius.circular(10)));
    final calfR = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.54, h * 0.675, w * 0.16, h * 0.16),
          const Radius.circular(10)));
    fill(pantorrillas, calfL); stroke(calfL);
    fill(pantorrillas, calfR); stroke(calfR);

    // ── Pies ─────────────────────────────────────────────────────────────
    final footL = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.28, h * 0.845, w * 0.20, h * 0.04),
          const Radius.circular(4)));
    final footR = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.52, h * 0.845, w * 0.20, h * 0.04),
          const Radius.circular(4)));
    fill(base, footL); fill(base, footR);
  }

  @override
  bool shouldRepaint(_BodyBackPainter old) =>
      old.espalda != espalda || old.gluteos != gluteos ||
      old.isquiotibiales != isquiotibiales;
}

// ══════════════════════════════════════════════════════════════════════════════
// Bottom sheet de detalle del día (sin cambios de funcionalidad)
// ══════════════════════════════════════════════════════════════════════════════
class _DetalleDiaSheet extends StatelessWidget {
  final String fecha;
  final Map<String, dynamic>? entreno;
  final Map<String, dynamic>? alim;

  const _DetalleDiaSheet({
    required this.fecha,
    required this.entreno,
    required this.alim,
  });

  static const _kDark        = Color(0xFF1A1A2E);
  static const _cVerdeFuerte = Color(0xFF2E7D32);
  static const _cVerdeClaro  = Color(0xFF81C784);
  static const _cAzul        = Color(0xFF1976D2);
  static const _kRed         = Color(0xFFF25050);

  String get _fechaFormateada {
    final parts = fecha.split('-');
    if (parts.length != 3) return fecha;
    const meses = [
      '', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    final mes = int.tryParse(parts[1]) ?? 0;
    return '${parts[2]} de ${meses[mes]} ${parts[0]}';
  }

  _NivelConfig _nivelConfig(String nivel) {
    switch (nivel) {
      case 'excelente': return _NivelConfig('🌟', 'Excelente', _cVerdeFuerte);
      case 'bueno':     return _NivelConfig('✅', 'Bueno',     const Color(0xFF43C6AC));
      case 'regular':   return _NivelConfig('😐', 'Regular',   const Color(0xFFFF9800));
      case 'malo':
      default:          return _NivelConfig('😕', 'Malo',      _kRed);
    }
  }

  String get _resumenDia {
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
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(_fechaFormateada,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: _kDark)),
          const SizedBox(height: 4),
          Text(_resumenDia,
              style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          const SizedBox(height: 20),
          _buildSeccionEntrenamiento(),
          const SizedBox(height: 12),
          _buildSeccionAlimentacion(),
          const SizedBox(height: 24),
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
    );
  }

  Widget _buildSeccionEntrenamiento() {
    if (entreno == null) {
      return _buildSinActividad(
        Icons.fitness_center_rounded, 'Entrenamiento', 'No entrenaste este día');
    }
    final sesion = entreno!['sesion_numero'] ?? '—';
    final notas  = (entreno!['notas'] ?? '').toString().trim();
    return _buildTarjeta(
      color: _cVerdeClaro,
      icon: Icons.fitness_center_rounded,
      titulo: 'Entrenamiento',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildFila(Icons.tag_rounded, 'Sesión completada',
            'Sesión #$sesion', _cVerdeFuerte),
        if (notas.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildFila(Icons.edit_note_rounded, 'Notas', notas, Colors.grey),
        ],
      ]),
    );
  }

  Widget _buildSeccionAlimentacion() {
    if (alim == null) {
      return _buildSinActividad(
        Icons.restaurant_rounded, 'Alimentación', 'No registraste tu alimentación');
    }
    final nivelStr = (alim!['nivel_cumplimiento'] ?? '').toString();
    final cal      = alim!['calorias_consumidas'];
    final agua     = alim!['agua_consumida'];
    final notas    = (alim!['notas'] ?? '').toString().trim();
    final cfg      = _nivelConfig(nivelStr);
    return _buildTarjeta(
      color: _cAzul,
      icon: Icons.restaurant_rounded,
      titulo: 'Alimentación',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: cfg.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cfg.color.withOpacity(0.3)),
          ),
          child: Row(children: [
            Text(cfg.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Text(cfg.label,
                style: TextStyle(fontWeight: FontWeight.bold,
                    fontSize: 15, color: cfg.color)),
          ]),
        ),
        if (cal != null) ...[
          const SizedBox(height: 8),
          _buildFila(Icons.local_fire_department_rounded,
              'Calorías consumidas', '$cal kcal', const Color(0xFFFF6B6B)),
        ],
        if (agua != null) ...[
          const SizedBox(height: 8),
          _buildFila(Icons.water_drop_rounded, 'Agua consumida', '$agua litros', _cAzul),
        ],
        if (notas.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildFila(Icons.edit_note_rounded, 'Notas', notas, Colors.grey),
        ],
      ]),
    );
  }

  Widget _buildTarjeta({
    required Color color, required IconData icon,
    required String titulo, required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
                color: color.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Text(titulo,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
        ]),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }

  Widget _buildSinActividad(IconData icon, String titulo, String mensaje) {
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
          decoration:
              BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle),
          child: Icon(icon, color: Colors.grey[400], size: 16),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo,
              style: TextStyle(fontWeight: FontWeight.bold,
                  fontSize: 13, color: Colors.grey[500])),
          const SizedBox(height: 2),
          Text(mensaje, style: TextStyle(fontSize: 12, color: Colors.grey[400])),
        ]),
      ]),
    );
  }

  Widget _buildFila(IconData icon, String label, String valor, Color color) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 15),
      const SizedBox(width: 8),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          Text(valor,
              style: const TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w600, color: _kDark)),
        ]),
      ),
    ]);
  }
}

// ── Modelos helper ─────────────────────────────────────────────────────────────
class _NivelConfig {
  final String emoji;
  final String label;
  final Color color;
  const _NivelConfig(this.emoji, this.label, this.color);
}