import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/auth_service.dart';

const _kRed1  = Color(0xFFD72105);
const _kBgTop = Color(0xFF0d0d0d);
const _kBgBot = Color(0xFF0F0F1E);

// ── Mapa local de emojis por id ───────────────────────────────────────────────
const _emojiMap = {
  'avatar_1': '🏃',
  'avatar_2': '🏋️',
  'avatar_3': '🧘',
  'avatar_4': '🚴',
  'avatar_5': '🏊',
  'avatar_6': '🥊',
  'avatar_7': '🧗',
  'avatar_8': '💃',
};

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _perfil;
  bool _loading = true;

  String _avatarActual = 'avatar_1';
  String _avatarEmoji  = '🏃';

  @override
  void initState() {
    super.initState();
    _loadPerfil();
  }

  Future<void> _loadPerfil() async {
    final result = await AuthService.getPerfil();
    if (mounted) {
      final data = result['success'] == true ? result['data'] as Map<String, dynamic> : <String, dynamic>{};
      final avatarId = data['avatar']?.toString() ?? 'avatar_1';
      setState(() {
        _perfil       = data;
        _avatarActual = avatarId;
        _avatarEmoji  = _emojiMap[avatarId] ?? '🏃'; // ← resuelve emoji al cargar
        _loading      = false;
      });
    }
  }

  Future<void> _abrirSelectorAvatar() async {
    final seleccionado = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AvatarSelectorModal(avatarActual: _avatarActual),
    );

    if (seleccionado == null || !mounted) return;

    final token = await AuthService.getToken();
    if (token == null) return;

    try {
      final res = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/perfil/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          ..._perfil ?? {},
          'avatar': seleccionado['id'],
        }),
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final nuevaId    = seleccionado['id'] as String;
        final nuevoEmoji = seleccionado['emoji'] as String? ?? _emojiMap[nuevaId] ?? '🏃';
        setState(() {
          _avatarActual       = nuevaId;
          _avatarEmoji        = nuevoEmoji;
          _perfil?['avatar']  = nuevaId;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Avatar actualizado: ${seleccionado['nombre']}'),
            backgroundColor: _kRed1,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo guardar el avatar (${res.statusCode})'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error de conexión al guardar avatar'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _label(String key) {
    const map = {
      'username':        'Usuario',
      'email':           'Correo',
      'edad':            'Edad',
      'peso':            'Peso',
      'altura':          'Altura',
      'genero':          'Género',
      'objetivo':        'Objetivo',
      'nivel_actividad': 'Nivel de actividad',
    };
    return map[key] ?? key;
  }

  String _value(String key, dynamic val) {
    if (val == null || val.toString().isEmpty) return '—';
    if (key == 'peso')   return '$val kg';
    if (key == 'altura') return '$val m';
    if (key == 'edad')   return '$val años';
    return val.toString().replaceAll('_', ' ');
  }

  IconData _icon(String key) {
    const map = {
      'username':        Icons.person_outline_rounded,
      'email':           Icons.email_outlined,
      'edad':            Icons.cake_outlined,
      'peso':            Icons.monitor_weight_outlined,
      'altura':          Icons.height_rounded,
      'genero':          Icons.wc_rounded,
      'objetivo':        Icons.flag_outlined,
      'nivel_actividad': Icons.fitness_center_rounded,
    };
    return map[key] ?? Icons.info_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_kBgTop, _kBgBot],
              ),
            ),
          ),
          const Positioned.fill(
            child: CustomPaint(painter: _SportsBgPainter()),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(context),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator(color: _kRed1))
                      : _buildContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white70, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            'PERFIL',
            style: GoogleFonts.bebasNeue(
              fontSize: 24,
              color: Colors.white,
              letterSpacing: 3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final username = _perfil?['username'] ?? 'Usuario';
    final keys = [
      'username', 'email', 'edad', 'peso',
      'altura', 'genero', 'objetivo', 'nivel_actividad',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          _buildAvatar(username),
          const SizedBox(height: 12),
          Text(
            username,
            style: GoogleFonts.bebasNeue(
              fontSize: 28,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _perfil?['email'] ?? '',
            style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.45)),
          ),
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              children: [
                for (int i = 0; i < keys.length; i++) ...[
                  _buildRow(keys[i], _perfil?[keys[i]]),
                  if (i < keys.length - 1)
                    Divider(
                      height: 1,
                      color: Colors.white.withOpacity(0.07),
                      indent: 56,
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAvatar(String username) {
    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: _kRed1.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: _kRed1.withOpacity(0.4), width: 2),
            ),
            child: Center(
              child: Text(_avatarEmoji, style: const TextStyle(fontSize: 44)),
            ),
          ),
          Positioned(
            bottom: 2,
            right: 2,
            child: GestureDetector(
              onTap: _abrirSelectorAvatar,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _kRed1,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0d0d0d), width: 2),
                ),
                child: const Icon(Icons.edit_rounded, color: Colors.white, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String key, dynamic val) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Icon(_icon(key), color: _kRed1, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              _label(key),
              style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.5)),
            ),
          ),
          Text(
            _value(key, val),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Modal selector de avatares
// ══════════════════════════════════════════════════════════════════════════════
class _AvatarSelectorModal extends StatefulWidget {
  final String avatarActual;
  const _AvatarSelectorModal({required this.avatarActual});

  @override
  State<_AvatarSelectorModal> createState() => _AvatarSelectorModalState();
}

class _AvatarSelectorModalState extends State<_AvatarSelectorModal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _slideAnim;

  bool _loading = true;
  List<Map<String, dynamic>> _avatares = [];
  String _seleccionado = '';

  @override
  void initState() {
    super.initState();
    _seleccionado = widget.avatarActual;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _slideAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
    _cargarAvatares();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _cargarAvatares() async {
    try {
      final token = await AuthService.getToken();
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/avatares/'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (res.statusCode == 200) {
        final body  = jsonDecode(res.body) as Map<String, dynamic>;
        final lista = body['avatares'] as List? ?? [];
        setState(() {
          _avatares = lista.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _loading  = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(_slideAnim),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.72,
        decoration: const BoxDecoration(
          color: Color(0xFF0D0D0D),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1C1C1C),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _kRed1.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person_rounded, color: _kRed1, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Elige tu avatar',
                            style: GoogleFonts.bebasNeue(
                              color: Colors.white,
                              fontSize: 20,
                              letterSpacing: 2,
                            ),
                          ),
                          const Text(
                            'Selecciona el que mejor te representa',
                            style: TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _kRed1))
                  : _avatares.isEmpty
                      ? const Center(
                          child: Text('No se pudieron cargar los avatares',
                              style: TextStyle(color: Colors.white38)))
                      : GridView.builder(
                          padding: const EdgeInsets.all(20),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: 1.1,
                          ),
                          itemCount: _avatares.length,
                          itemBuilder: (_, i) => _buildAvatarCard(_avatares[i]),
                        ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _avatares.isEmpty
                      ? null
                      : () {
                          final avatar = _avatares.firstWhere(
                            (a) => a['id'] == _seleccionado,
                            orElse: () => _avatares.first,
                          );
                          Navigator.pop(context, avatar);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kRed1,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26)),
                    elevation: 0,
                  ),
                  child: Text(
                    'CONFIRMAR AVATAR',
                    style: GoogleFonts.bebasNeue(
                      color: Colors.white,
                      fontSize: 18,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarCard(Map<String, dynamic> avatar) {
    final id           = avatar['id'] as String;
    final nombre       = avatar['nombre'] as String? ?? '';
    final descripcion  = avatar['descripcion'] as String? ?? '';
    final emoji        = avatar['emoji'] as String? ?? _emojiMap[id] ?? '🏃';
    final seleccionado = id == _seleccionado;

    return GestureDetector(
      onTap: () => setState(() => _seleccionado = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: seleccionado ? _kRed1.withOpacity(0.15) : const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: seleccionado ? _kRed1 : Colors.white.withOpacity(0.06),
            width: seleccionado ? 2 : 1,
          ),
          boxShadow: seleccionado
              ? [BoxShadow(color: _kRed1.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 4))]
              : [],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 36)),
            const SizedBox(height: 8),
            Text(
              nombre,
              style: TextStyle(
                color: seleccionado ? Colors.white : Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              descripcion,
              style: const TextStyle(color: Colors.white38, fontSize: 10),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (seleccionado) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _kRed1,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Seleccionado',
                  style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Fondo deportivo ────────────────────────────────────────────────────────────
class _SportsBgPainter extends CustomPainter {
  const _SportsBgPainter();

  static final _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2
    ..color = const Color(0x0AFFFFFF);

  static final _thick = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 18
    ..color = const Color(0x07FFFFFF);

  @override
  void paint(Canvas canvas, Size s) {
    for (final (c, r) in [
      (Offset(s.width * 0.88, s.height * 0.08), 55.0),
      (Offset(s.width * 0.88, s.height * 0.08), 38.0),
      (Offset(s.width * 0.1,  s.height * 0.92), 65.0),
      (Offset(s.width * 0.1,  s.height * 0.92), 45.0),
    ]) {
      canvas.drawCircle(c, r, _stroke);
    }
    canvas.drawLine(Offset(-20, s.height * 0.15), Offset(s.width * 0.40, -20), _thick);
    canvas.drawLine(Offset(-20, s.height * 0.28), Offset(s.width * 0.55, -20), _thick);
    canvas.drawLine(Offset(s.width + 20, s.height * 0.72), Offset(s.width * 0.55, s.height + 20), _thick);
    canvas.drawLine(Offset(s.width + 20, s.height * 0.58), Offset(s.width * 0.38, s.height + 20), _thick);
    canvas.drawArc(
      Rect.fromCenter(center: Offset(s.width * 0.05, s.height * 0.5), width: 140, height: 140),
      -math.pi / 2, math.pi, false, _stroke,
    );
    canvas.drawArc(
      Rect.fromCenter(center: Offset(s.width * 0.95, s.height * 0.5), width: 120, height: 120),
      math.pi / 2, math.pi, false, _stroke,
    );
    for (final pt in [
      Offset(s.width * 0.15, s.height * 0.22),
      Offset(s.width * 0.82, s.height * 0.45),
      Offset(s.width * 0.25, s.height * 0.75),
      Offset(s.width * 0.72, s.height * 0.82),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(pt.dx, pt.dy - 22)
          ..lineTo(pt.dx + 13, pt.dy)
          ..lineTo(pt.dx, pt.dy + 22)
          ..lineTo(pt.dx - 13, pt.dy)
          ..close(),
        _stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}