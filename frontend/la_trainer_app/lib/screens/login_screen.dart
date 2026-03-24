import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'registro_screen.dart';

// ── Constantes globales ────────────────────────────────────────────────────────
const _kRed1 = Color(0xFFD72105);
const _kRed2 = Color(0xFFD90B1C);
const _kBgTop = Color(0xFF0d0d0d);
const _kBgBot = Color(0xFF0F0F1E);
const double _kImageHeight = 160;
const double _kImageOverlap = 30;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final result = await AuthService.login(
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text,
    );

    setState(() => _loading = false);
    if (!mounted) return;

    if (result['success'] == true) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Error al iniciar sesión'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fondo
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_kBgTop, _kBgBot],
              ),
            ),
          ),
          // Decoración deportiva
          const Positioned.fill(
            child: CustomPaint(painter: _SportsBgPainter()),
          ),
          // Contenido
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 60,
                ),
                child: SizedBox(
                  width: 280,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [_buildForm(), _buildHero()],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Formulario ───────────────────────────────────────────────────────────────
  Widget _buildForm() {
    return Padding(
      padding: const EdgeInsets.only(top: _kImageHeight - _kImageOverlap),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_kRed1, _kRed2],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.fromLTRB(24, 56, 24, 32),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text(
                'Inicia sesión para comenzar',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              _buildField(
                controller: _emailCtrl,
                label: 'Gmail de usuario',
                icon: Icons.person_outline,
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Ingresa tu usuario'
                    : null,
              ),
              const SizedBox(height: 16),
              _buildField(
                controller: _passCtrl,
                label: 'Contraseña',
                icon: Icons.lock_outline,
                obscure: _obscurePass,
                onToggleObscure: () =>
                    setState(() => _obscurePass = !_obscurePass),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Ingresa tu contraseña' : null,
              ),
              const SizedBox(height: 28),
              _buildLoginButton(),
              const SizedBox(height: 20),
              _buildRegisterSection(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Campo de texto reutilizable ───────────────────────────────────────────────
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    VoidCallback? onToggleObscure,
    required String? Function(String?) validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        keyboardType: keyboardType,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.7)),
          suffixIcon: onToggleObscure != null
              ? IconButton(
                  icon: Icon(
                    obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.white.withOpacity(0.7),
                  ),
                  onPressed: onToggleObscure,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        validator: validator,
      ),
    );
  }

  // ── Botón login ───────────────────────────────────────────────────────────────
  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _loading ? null : _submit,
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.red[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Color(0xFF260101),
                  strokeWidth: 2.5,
                ),
              )
            : const Text(
                'Login',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  // ── Sección registro ──────────────────────────────────────────────────────────
  Widget _buildRegisterSection() {
    return Column(
      children: [
        const Text(
          '¿Nuevo en Koda?',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RegistroScreen()),
            ),
            style: TextButton.styleFrom(
              side: const BorderSide(color: Colors.transparent),
            ),
            child: const Text(
              'CREAR UNA CUENTA!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Hero: imagen + texto ──────────────────────────────────────────────────────
  Widget _buildHero() {
    return SizedBox(
      height: _kImageHeight,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Image.asset(
            'images/mask_group.png',
            height: _kImageHeight,
            fit: BoxFit.contain,
          ),
          Positioned(
            bottom: 0,
            child: Text(
              'VAMOS A ENTRENAR!',
              style: GoogleFonts.bebasNeue(
                fontSize: 38,
                color: Colors.white,
                letterSpacing: 2,
                shadows: [
                  Shadow(color: Colors.red[900]!, blurRadius: 10),
                  const Shadow(
                    color: Colors.black87,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Fondo decorativo deportivo ─────────────────────────────────────────────────
class _SportsBgPainter extends CustomPainter {
  const _SportsBgPainter();

  static final _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2
    ..color = const Color(0x0AFFFFFF); // blanco ~4% opacidad

  static final _thick = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 18
    ..color = const Color(0x07FFFFFF); // blanco ~3% opacidad

  @override
  void paint(Canvas canvas, Size s) {
    // Círculos esquinas
    canvas.drawCircle(Offset(s.width * 0.88, s.height * 0.08), 55, _stroke);
    canvas.drawCircle(Offset(s.width * 0.88, s.height * 0.08), 38, _stroke);
    canvas.drawCircle(Offset(s.width * 0.1, s.height * 0.92), 65, _stroke);
    canvas.drawCircle(Offset(s.width * 0.1, s.height * 0.92), 45, _stroke);

    // Diagonales
    canvas.drawLine(
      Offset(-20, s.height * 0.15),
      Offset(s.width * 0.4, -20),
      _thick,
    );
    canvas.drawLine(
      Offset(-20, s.height * 0.28),
      Offset(s.width * 0.55, -20),
      _thick,
    );
    canvas.drawLine(
      Offset(s.width + 20, s.height * 0.72),
      Offset(s.width * 0.55, s.height + 20),
      _thick,
    );
    canvas.drawLine(
      Offset(s.width + 20, s.height * 0.58),
      Offset(s.width * 0.38, s.height + 20),
      _thick,
    );

    // Arcos laterales
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(s.width * 0.05, s.height * 0.5),
        width: 140,
        height: 140,
      ),
      -math.pi / 2,
      math.pi,
      false,
      _stroke,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(s.width * 0.95, s.height * 0.5),
        width: 120,
        height: 120,
      ),
      math.pi / 2,
      math.pi,
      false,
      _stroke,
    );

    // Rombos
    for (final pt in [
      Offset(s.width * 0.15, s.height * 0.22),
      Offset(s.width * 0.82, s.height * 0.45),
      Offset(s.width * 0.25, s.height * 0.75),
      Offset(s.width * 0.72, s.height * 0.82),
    ]) {
      _drawDiamond(canvas, pt, 22);
    }
  }

  void _drawDiamond(Canvas canvas, Offset c, double r) {
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy - r)
        ..lineTo(c.dx + r * 0.6, c.dy)
        ..lineTo(c.dx, c.dy + r)
        ..lineTo(c.dx - r * 0.6, c.dy)
        ..close(),
      _stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
