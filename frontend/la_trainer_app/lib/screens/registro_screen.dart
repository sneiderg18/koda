import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';  // ← NUEVO

// ── Constantes ─────────────────────────────────────────────────────────────────
const _kRed1       = Color(0xFFD72105);
const _kRed2       = Color(0xFFD90B1C);
const _kBgTop      = Color(0xFF0d0d0d);
const _kBgBot      = Color(0xFF0F0F1E);
const double _kImageHeight  = 160;
const double _kImageOverlap = 50;

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});
  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _emailCtrl   = TextEditingController();
  final _userCtrl    = TextEditingController();
  final _pass1Ctrl   = TextEditingController();
  final _pass2Ctrl   = TextEditingController();

  bool _obscurePass1        = true;
  bool _obscurePass2        = true;
  bool _loading             = false;
  bool _showPassReqs        = false;

  // ── Validaciones de contraseña ────────────────────────────────────────────────
  bool get _hasMinLength => _pass1Ctrl.text.length >= 8;
  bool get _hasUppercase => _pass1Ctrl.text.contains(RegExp(r'[A-Z]'));
  bool get _hasLowercase => _pass1Ctrl.text.contains(RegExp(r'[a-z]'));
  bool get _hasNumber    => _pass1Ctrl.text.contains(RegExp(r'[0-9]'));
  bool get _hasSpecial   => _pass1Ctrl.text.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));

  @override
  void initState() {
    super.initState();
    _pass1Ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_emailCtrl, _userCtrl, _pass1Ctrl, _pass2Ctrl]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── LÓGICA DE REGISTRO CON REDIRECCIÓN A ONBOARDING ──────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final result = await AuthService.registro(
      email:     _emailCtrl.text.trim(),
      username:  _userCtrl.text.trim(),
      password1: _pass1Ctrl.text,
      password2: _pass2Ctrl.text,
    );

    setState(() => _loading = false);
    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Registro exitoso!'),
          backgroundColor: Colors.green,
        ),
      );

      // ── VERIFICAR si peso == null → ir a onboarding ─────────────────────────
      final data = result['data'];
      final peso = data?['peso'] ?? data?['user']?['peso'];

      final Widget nextScreen =
          (peso == null) ? const OnboardingScreen() : const HomeScreen();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => nextScreen),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['message'] ?? 'Error al registrarse'),
        backgroundColor: Colors.redAccent,
      ));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
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
          const Positioned.fill(child: CustomPaint(painter: _SportsBgPainter())),
          // Contenido
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                child: SizedBox(
                  width: 400,
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

  // ── Formulario ────────────────────────────────────────────────────────────────
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
        padding: const EdgeInsets.fromLTRB(25, 66, 28, 24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildField(
                controller: _emailCtrl,
                label: 'Correo electrónico',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Ingresa tu correo';
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) return 'Correo no válido';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              _buildField(
                controller: _userCtrl,
                label: 'Nombre de usuario',
                icon: Icons.alternate_email_rounded,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Ingresa un nombre de usuario' : null,
              ),
              const SizedBox(height: 10),
              _buildField(
                controller: _pass1Ctrl,
                label: 'Contraseña',
                icon: Icons.lock_outline,
                obscure: _obscurePass1,
                onToggleObscure: () => setState(() => _obscurePass1 = !_obscurePass1),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Ingresa una contraseña';
                  if (v.length < 8) return 'Mínimo 8 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              _buildPasswordRequirements(),
              const SizedBox(height: 10),
              _buildField(
                controller: _pass2Ctrl,
                label: 'Confirmar contraseña',
                icon: Icons.lock_outline,
                obscure: _obscurePass2,
                onToggleObscure: () => setState(() => _obscurePass2 = !_obscurePass2),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Confirma tu contraseña';
                  if (v != _pass1Ctrl.text) return 'Las contraseñas no coinciden';
                  return null;
                },
              ),
              const SizedBox(height: 18),
              _buildSubmitButton(),
              const SizedBox(height: 10),
              _buildLoginLink(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Campo reutilizable ────────────────────────────────────────────────────────
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
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        keyboardType: keyboardType,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w500),
          prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.8)),
          suffixIcon: onToggleObscure != null
              ? IconButton(
                  icon: Icon(
                    obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: Colors.white.withOpacity(0.7),
                  ),
                  onPressed: onToggleObscure,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        validator: validator,
      ),
    );
  }

  // ── Botón enviar ──────────────────────────────────────────────────────────────
  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _loading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: _kRed1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: _loading
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(color: _kRed1, strokeWidth: 2.5),
              )
            : const Text('Registrarse', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ── Link a login ──────────────────────────────────────────────────────────────
  Widget _buildLoginLink() {
    return Column(
      children: [
        const Text(
          '¿Ya tienes cuenta?',
          style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          height: 42,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.white.withOpacity(0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              'INICIAR SESIÓN',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
          ),
        ),
      ],
    );
  }

  // ── Requisitos de contraseña ──────────────────────────────────────────────────
  Widget _buildPasswordRequirements() {
    final reqs = [
      (_hasMinLength,                  'Mínimo 8 caracteres'),
      (_hasUppercase && _hasLowercase, 'Mayúscula y minúscula'),
      (_hasNumber,                     'Al menos un número'),
      (_hasSpecial,                    'Carácter especial (!@#\$...)'),
    ];

    return ClipRect(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: GestureDetector(
          onTap: () => setState(() => _showPassReqs = !_showPassReqs),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Requisitos de contraseña',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    Icon(
                      _showPassReqs ? Icons.expand_less : Icons.expand_more,
                      color: Colors.white.withOpacity(0.8),
                      size: 20,
                    ),
                  ],
                ),
                if (_showPassReqs) ...[
                  const SizedBox(height: 8),
                  for (final (met, text) in reqs) _reqRow(met, text),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _reqRow(bool met, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 14,
            color: met ? Colors.white : Colors.white60,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.white,
              fontWeight: met ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero ──────────────────────────────────────────────────────────────────────
  Widget _buildHero() {
    return SizedBox(
      height: _kImageHeight,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Image.asset('assets/images/register.png', height: _kImageHeight, fit: BoxFit.contain),
          Positioned(
            bottom: 0,
            child: SizedBox(
              width: 350,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '¡CREA TU USUARIO!',
                  style: GoogleFonts.bebasNeue(
                    fontSize: 36,
                    color: Colors.white,
                    letterSpacing: 2,
                    shadows: [
                      Shadow(color: Colors.red[900]!, blurRadius: 10),
                      const Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 2)),
                    ],
                  ),
                ),
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
    ..color = const Color(0x0AFFFFFF);

  static final _thick = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 18
    ..color = const Color(0x07FFFFFF);

  @override
  void paint(Canvas canvas, Size s) {
    for (final (center, r) in [
      (Offset(s.width * 0.88, s.height * 0.08), 55.0),
      (Offset(s.width * 0.88, s.height * 0.08), 38.0),
      (Offset(s.width * 0.1,  s.height * 0.92), 65.0),
      (Offset(s.width * 0.1,  s.height * 0.92), 45.0),
    ]) {
      canvas.drawCircle(center, r, _stroke);
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