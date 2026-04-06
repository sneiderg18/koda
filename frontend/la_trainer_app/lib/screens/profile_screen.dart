import 'dart:async';
import 'dart:html' as html;
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';

const _kRed1  = Color(0xFFD72105);
const _kBgTop = Color(0xFF0d0d0d);
const _kBgBot = Color(0xFF0F0F1E);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _perfil;
  bool _loading = true;
  Uint8List? _avatarBytes; // ✅ web-compatible

  @override
  void initState() {
    super.initState();
    _loadPerfil();
  }

  Future<void> _loadPerfil() async {
    final result = await AuthService.getPerfil();
    if (mounted) {
      setState(() {
        _perfil = result['success'] == true ? result['data'] : {};
        _loading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final completer = Completer<Uint8List?>();

    // ✅ Input HTML nativo — funciona en Flutter Web sin plugins
    final input = html.FileUploadInputElement()
      ..accept = 'image/*'
      ..click();

    input.onChange.listen((event) {
      final file = input.files?.first;
      if (file == null) {
        completer.complete(null);
        return;
      }
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      reader.onLoad.listen((_) {
        completer.complete(reader.result as Uint8List);
      });
      reader.onError.listen((_) => completer.complete(null));
    });

    final bytes = await completer.future;
    if (bytes != null && mounted) {
      setState(() => _avatarBytes = bytes);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
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
          // ── Fondo ────────────────────────────────────────────────────
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
          // ── Contenido ────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(context),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(color: _kRed1))
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
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.45),
            ),
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
          CircleAvatar(
            radius: 50,
            backgroundColor: _kRed1.withOpacity(0.2),
            // ✅ MemoryImage funciona en web, móvil y desktop
            backgroundImage: _avatarBytes != null
                ? MemoryImage(_avatarBytes!)
                : null,
            child: _avatarBytes == null
                ? Text(
                    username.isNotEmpty ? username[0].toUpperCase() : '?',
                    style: GoogleFonts.bebasNeue(
                      fontSize: 40,
                      color: Colors.white,
                    ),
                  )
                : null,
          ),
          Positioned(
            bottom: 2,
            right: 2,
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _kRed1,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: const Color(0xFF0d0d0d), width: 2),
                ),
                child: const Icon(Icons.add_rounded,
                    color: Colors.white, size: 16),
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
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.5),
              ),
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

// ── Fondo deportivo ────────────────────────────────────────────────────────
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
    ]) { canvas.drawCircle(c, r, _stroke); }

    canvas.drawLine(Offset(-20, s.height * 0.15), Offset(s.width * 0.40, -20), _thick);
    canvas.drawLine(Offset(-20, s.height * 0.28), Offset(s.width * 0.55, -20), _thick);
    canvas.drawLine(Offset(s.width + 20, s.height * 0.72), Offset(s.width * 0.55, s.height + 20), _thick);
    canvas.drawLine(Offset(s.width + 20, s.height * 0.58), Offset(s.width * 0.38, s.height + 20), _thick);

    canvas.drawArc(
      Rect.fromCenter(
          center: Offset(s.width * 0.05, s.height * 0.5),
          width: 140, height: 140),
      -math.pi / 2, math.pi, false, _stroke,
    );
    canvas.drawArc(
      Rect.fromCenter(
          center: Offset(s.width * 0.95, s.height * 0.5),
          width: 120, height: 120),
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