import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

const _kRed  = Color(0xFFD72105);
const _kBg   = Color(0xFF0D0D0D);
const _kCard = Color(0xFF1C1C1C);

class PantallaDetalles extends StatefulWidget {
  final int? sesionId;
  const PantallaDetalles({super.key, this.sesionId});

  @override
  State<PantallaDetalles> createState() => _PantallaDetallesState();
}

class _PantallaDetallesState extends State<PantallaDetalles> {
  bool _loading     = true;
  bool _completando = false;
  String? _error;

  int? _sesionId;
  Map<String, dynamic>? _estadoPlan;
  List<Map<String, dynamic>> _ejercicios = [];

  int _indexActual = 0;

  Map<String, dynamic>? _resultadoFinal;

  @override
  void initState() {
    super.initState();
    _cargarSesionActiva();
  }

  Future<Map<String, String>> get _headers async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
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

  Future<void> _cargarSesionActiva() async {
    setState(() { _loading = true; _error = null; });

    try {
      final headers = await _headers;
      if (!headers.containsKey('Authorization')) { await _goToLogin(); return; }

      final url = Uri.parse('${ApiConfig.baseUrl}/api/sesion/activa/');
      final res = await http.get(url, headers: headers);

      if (!mounted) return;
      if (res.statusCode == 401) { await _goToLogin(); return; }

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;

        if (body['tiene_sesion_activa'] != true) {
          if (widget.sesionId != null) {
            await Future.delayed(const Duration(milliseconds: 800));
            if (!mounted) return;
            final res2 = await http.get(url, headers: headers);
            if (!mounted) return;
            if (res2.statusCode == 200) {
              final body2 = jsonDecode(res2.body) as Map<String, dynamic>;
              if (body2['tiene_sesion_activa'] == true) {
                _procesarSesion(body2);
                return;
              }
            }
          }
          setState(() {
            _error   = 'No hay una sesión activa en este momento.\nInicia una sesión desde el plan de entrenamiento.';
            _loading = false;
          });
          return;
        }
        _procesarSesion(body);
      } else {
        setState(() {
          _error   = 'Error al cargar la sesión (${res.statusCode})';
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

  void _procesarSesion(Map<String, dynamic> body) {
    final sesion     = Map<String, dynamic>.from(body['sesion'] as Map);
    final estadoPlan = body['estado_plan'] != null
        ? Map<String, dynamic>.from(body['estado_plan'] as Map)
        : null;

    final rawList    = sesion['ejercicios_completados'] as List? ?? [];
    final ejercicios = rawList
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final pendienteIdx = ejercicios.indexWhere((e) => e['completado'] != true);
    final indexInicial = pendienteIdx >= 0 ? pendienteIdx : ejercicios.length - 1;

    setState(() {
      _sesionId    = sesion['id'] as int?;
      _estadoPlan  = estadoPlan;
      _ejercicios  = ejercicios;
      _indexActual = indexInicial;
      _loading     = false;
    });
  }

  Future<void> _completarEjercicioActual() async {
    if (_sesionId == null || _completando) return;

    final ejercicio         = _ejercicios[_indexActual];
    final ejercicioSesionId = ejercicio['id'] as int?;
    if (ejercicioSesionId == null) return;

    setState(() => _completando = true);

    try {
      final headers = await _headers;
      final url = '${ApiConfig.baseUrl}/api/sesion/$_sesionId/ejercicio/$ejercicioSesionId/completar/';

      final res = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode({'notas': ''}),
      );

      if (!mounted) return;
      if (res.statusCode == 401) { await _goToLogin(); return; }

      if (res.statusCode == 200 || res.statusCode == 201) {
        final body             = jsonDecode(res.body) as Map<String, dynamic>;
        final sesionCompletada = body['sesion_completada'] == true;

        if (sesionCompletada) {
          setState(() {
            _resultadoFinal = body;
            _completando    = false;
          });
        } else {
          setState(() {
            _ejercicios[_indexActual] = {
              ..._ejercicios[_indexActual],
              'completado': true,
            };
            _indexActual++;
            _completando = false;
          });
        }
      } else {
        setState(() {
          _ejercicios[_indexActual] = {
            ..._ejercicios[_indexActual],
            'completado': true,
          };
          if (_indexActual < _ejercicios.length - 1) _indexActual++;
          _completando = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Advertencia: no se pudo sincronizar (${res.statusCode})'),
            backgroundColor: Colors.orange[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _ejercicios[_indexActual] = {
            ..._ejercicios[_indexActual],
            'completado': true,
          };
          if (_indexActual < _ejercicios.length - 1) _indexActual++;
          _completando = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sin conexión: progreso guardado localmente'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _kRed))
                : _error != null
                    ? _buildError()
                    : _resultadoFinal != null
                        ? _buildPantallaFinal()
                        : _buildDetalleEjercicio(),
          ),
        ],
      ),
    );
  }

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
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
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

  Widget _buildDetalleEjercicio() {
    if (_ejercicios.isEmpty) {
      return const Center(
        child: Text('No hay ejercicios en esta sesión.',
            style: TextStyle(color: Colors.white54)),
      );
    }

    final ejercicio  = _ejercicios[_indexActual];
    final nombre     = ejercicio['nombre']        ?? 'Ejercicio';
    final grupo      = ejercicio['grupo_muscular'] ?? '';
    final series     = ejercicio['series']         ?? 0;
    final reps       = ejercicio['repeticiones']   ?? 0;
    final descanso   = ejercicio['descanso']       ?? '—';
    final imagenUrl  = ejercicio['imagen_url']?.toString() ?? '';
    final completado = ejercicio['completado'] == true;
    final esUltimo   = _indexActual == _ejercicios.length - 1;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Imagen del ejercicio ──────────────────────────────────
              Container(
                width: double.infinity,
                height: 220,
                color: Colors.grey[900],
                child: imagenUrl.isNotEmpty && !kIsWeb
                    ? Image.network(
                        imagenUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              color: _kRed,
                              value: progress.expectedTotalBytes != null
                                  ? progress.cumulativeBytesLoaded /
                                      progress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.fitness_center_rounded,
                              color: Colors.white12, size: 80),
                        ),
                      )
                    : const Center(
                        child: Icon(Icons.fitness_center_rounded,
                            color: Colors.white12, size: 80),
                      ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),

                    if (grupo.toString().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: _kRed.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          grupo.toString(),
                          style: const TextStyle(
                              color: _kRed,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ),

                    const SizedBox(height: 20),

                    Row(
                      children: [
                        _statBox(Icons.repeat_rounded, '$series', 'Series'),
                        const SizedBox(width: 12),
                        _statBox(Icons.fitness_center_rounded, '$reps', 'Reps'),
                        const SizedBox(width: 12),
                        _statBox(Icons.timer_outlined, descanso.toString(), 'Descanso'),
                      ],
                    ),

                    const SizedBox(height: 24),

                    const Text(
                      'Descripción',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildDescripcion(ejercicio),

                    if (completado) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.green.withOpacity(0.4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded,
                                color: Colors.green, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Ejercicio completado',
                              style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    _buildProgreso(),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Botón SIGUIENTE / FINALIZAR
        Positioned(
          bottom: 24,
          left: 24,
          right: 24,
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _completando ? null : _completarEjercicioActual,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kRed,
                disabledBackgroundColor: _kRed.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 6,
                shadowColor: _kRed.withOpacity(0.5),
              ),
              child: _completando
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : Text(
                      esUltimo ? 'FINALIZAR' : 'SIGUIENTE',
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
    );
  }

  Widget _buildDescripcion(Map<String, dynamic> ejercicio) {
    final nombre  = ejercicio['nombre']        ?? 'este ejercicio';
    final grupo   = ejercicio['grupo_muscular'] ?? '';
    final series  = ejercicio['series']         ?? 0;
    final reps    = ejercicio['repeticiones']   ?? 0;
    final notas   = ejercicio['notas'];
    final descIa  = ejercicio['descripcion_ia'];

    final texto = (descIa != null && descIa.toString().isNotEmpty)
        ? descIa.toString()
        : (notas != null && notas.toString().isNotEmpty)
            ? notas.toString()
            : 'Realiza $nombre trabajando $grupo. '
              'Completa $series series de $reps repeticiones con buena técnica. '
              'Mantén el control del movimiento en cada repetición para maximizar el resultado y evitar lesiones.';

    return Text(
      texto,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 14,
        height: 1.6,
      ),
    );
  }

  Widget _statBox(IconData icon, String valor, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: _kRed, size: 20),
            const SizedBox(height: 6),
            Text(
              valor,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgreso() {
    final total    = _ejercicios.length;
    final hechos   = _ejercicios.where((e) => e['completado'] == true).length;
    final progreso = total > 0 ? hechos / total : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Progreso de la sesión',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            Text(
              '$hechos / $total',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progreso,
            backgroundColor: _kCard,
            color: _kRed,
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildPantallaFinal() {
    final mensaje     = _resultadoFinal!['mensaje']              ?? '¡Sesión completada!';
    final completadas = _resultadoFinal!['sesiones_completadas'] ?? _estadoPlan?['sesiones_completadas'] ?? 0;
    final totales     = _resultadoFinal!['sesiones_totales']     ?? _estadoPlan?['sesiones_totales']     ?? 0;
    final planDone    = _resultadoFinal!['plan_completado']      == true;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _kRed.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                planDone
                    ? Icons.emoji_events_rounded
                    : Icons.check_circle_outline_rounded,
                color: _kRed,
                size: 40,
              ),
            ),
            const SizedBox(height: 28),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kRed.withOpacity(0.3)),
              ),
              child: Text(
                mensaje.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.6,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 20),

            if (totales > 0)
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Progreso del plan',
                          style: TextStyle(color: Colors.white54, fontSize: 12)),
                      Text('$completadas / $totales sesiones',
                          style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: totales > 0 ? completadas / totales : 0,
                      backgroundColor: _kCard,
                      color: _kRed,
                      minHeight: 8,
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kRed,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  planDone ? 'VER MIS LOGROS' : 'VOLVER AL INICIO',
                  style: GoogleFonts.bebasNeue(
                    fontSize: 20,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 56, color: Colors.white24),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white54, fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _cargarSesionActiva,
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