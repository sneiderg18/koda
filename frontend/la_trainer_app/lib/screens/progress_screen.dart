import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/auth_service.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  static const _kRed         = Color(0xFFD72105);
  static const _kBg          = Color(0xFFF5F7FA);
  static const _kDark        = Color(0xFF1A1A2E);
  static const _cVerdeFuerte = Color(0xFF2E7D32);
  static const _cVerdeClaro  = Color(0xFF81C784);
  static const _cAzul        = Color(0xFF1976D2);

  bool _loading = true;
  String? _error;
  DateTime _mesActual = DateTime.now();

  // Detalle completo por fecha
  final Map<String, Map<String, dynamic>> _detalleEntrenamiento = {};
  final Map<String, Map<String, dynamic>> _detalleAlimentacion  = {};

  int _rachaActual = 0;
  int _rachaMaxima = 0;

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

    int actual   = 0;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _kDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Progreso',
            style: TextStyle(
                color: _kDark, fontWeight: FontWeight.bold, fontSize: 20)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _kRed),
            onPressed: _cargarDatos,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFEEEEEE), height: 1),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kRed))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  color: _kRed,
                  onRefresh: _cargarDatos,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 24),
                    children: [
                      _buildRachaCard(),
                      const SizedBox(height: 20),
                      _buildCalendario(),
                      const SizedBox(height: 20),
                      _buildResumen(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }

  Widget _buildRachaCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD72105), Color(0xFFD90B1C)],
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
        // Navegación mes
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

        // Encabezado días
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

        // Hint interactividad
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

        // Cuadrícula
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
                                  ? (color == _cVerdeClaro
                                      ? _kDark
                                      : Colors.white)
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

        // Leyenda
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

  Widget _buildResumen() {
    final prefijo =
        '${_mesActual.year}-${_mesActual.month.toString().padLeft(2, '0')}';
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
// Bottom sheet de detalle del día
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
  static const _kRed         = Color(0xFFD72105);

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
          // Handle
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

          // Fecha y resumen
          Text(_fechaFormateada,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: _kDark)),
          const SizedBox(height: 4),
          Text(_resumenDia,
              style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          const SizedBox(height: 20),

          // Entrenamiento
          _buildSeccionEntrenamiento(),
          const SizedBox(height: 12),

          // Alimentación
          _buildSeccionAlimentacion(),
          const SizedBox(height: 24),

          // Botón cerrar
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
                  style: TextStyle(
                      color: _kDark, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeccionEntrenamiento() {
    if (entreno == null) {
      return _buildSinActividad(
        Icons.fitness_center_rounded,
        'Entrenamiento',
        'No entrenaste este día',
      );
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
        Icons.restaurant_rounded,
        'Alimentación',
        'No registraste tu alimentación',
      );
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
        // Badge nivel
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
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: cfg.color)),
          ]),
        ),
        if (cal != null) ...[
          const SizedBox(height: 8),
          _buildFila(Icons.local_fire_department_rounded,
              'Calorías consumidas', '$cal kcal', const Color(0xFFFF6B6B)),
        ],
        if (agua != null) ...[
          const SizedBox(height: 8),
          _buildFila(Icons.water_drop_rounded,
              'Agua consumida', '$agua litros', _cAzul),
        ],
        if (notas.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildFila(Icons.edit_note_rounded, 'Notas', notas, Colors.grey),
        ],
      ]),
    );
  }

  Widget _buildTarjeta({
    required Color color,
    required IconData icon,
    required String titulo,
    required Widget child,
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
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14, color: color)),
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
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.grey[500])),
          const SizedBox(height: 2),
          Text(mensaje,
              style: TextStyle(fontSize: 12, color: Colors.grey[400])),
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
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          Text(valor,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _kDark)),
        ]),
      ),
    ]);
  }
}

// ── Modelo helper ──────────────────────────────────────────────────────────
class _NivelConfig {
  final String emoji;
  final String label;
  final Color color;
  const _NivelConfig(this.emoji, this.label, this.color);
}