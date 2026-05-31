import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

// ── Constantes ─────────────────────────────────────────────────────────────────
const _kRed1       = Color(0xFFD72105);
const _kRed2       = Color(0xFFD90B1C);
const _kBgTop      = Color(0xFF0d0d0d);
const _kBgBot      = Color(0xFF0F0F1E);
const double _kImageHeight  = 160;
const double _kImageOverlap = 50;

// ── Contenido de los términos ──────────────────────────────────────────────────
const _terminosSecciones = [
  _TerminoSeccion(
    icon: Icons.person_outline_rounded,
    titulo: '1. Datos que recopilamos',
    texto:
        'Recopilamos tu nombre, correo, edad, peso, altura y datos de actividad física para personalizar tu experiencia en KODA.',
  ),
  _TerminoSeccion(
    icon: Icons.fitness_center_rounded,
    titulo: '2. Uso de tu información',
    texto:
        'Tus datos se usan exclusivamente para generar planes de entrenamiento y alimentación personalizados con IA. No los vendemos ni compartimos con terceros.',
  ),
  _TerminoSeccion(
    icon: Icons.health_and_safety_outlined,
    titulo: '3. Responsabilidad médica',
    texto:
        'KODA no reemplaza la asesoría médica profesional. Consulta a un especialista antes de iniciar cualquier rutina de ejercicio o cambio de dieta.',
  ),
  _TerminoSeccion(
    icon: Icons.lock_outline_rounded,
    titulo: '4. Seguridad',
    texto:
        'Tu información está protegida con cifrado JWT y almacenamiento seguro. Solo tú tienes acceso a tu perfil y datos personales.',
  ),
  _TerminoSeccion(
    icon: Icons.delete_outline_rounded,
    titulo: '5. Eliminación de cuenta',
    texto:
        'Puedes solicitar la eliminación de tu cuenta y todos tus datos en cualquier momento desde la sección de perfil.',
  ),
  _TerminoSeccion(
    icon: Icons.update_rounded,
    titulo: '6. Cambios en los términos',
    texto:
        'Podemos actualizar estos términos ocasionalmente. Te notificaremos dentro de la app si hay cambios importantes.',
  ),
];

class _TerminoSeccion {
  final IconData icon;
  final String titulo;
  final String texto;
  const _TerminoSeccion({required this.icon, required this.titulo, required this.texto});
}

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});
  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _userCtrl  = TextEditingController();
  final _pass1Ctrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();

  bool _obscurePass1   = true;
  bool _obscurePass2   = true;
  bool _loading        = false;
  bool _showPassReqs   = false;
  bool _aceptoTerminos = false; // ← NUEVO

  // ── Validaciones de contraseña ────────────────────────────────────────────────
  bool get _hasMinLength => _pass1Ctrl.text.length >= 8;
  bool get _hasUppercase => _pass1Ctrl.text.contains(RegExp(r'[A-Z]'));
  bool get _hasLowercase => _pass1Ctrl.text.contains(RegExp(r'[a-z]'));
  bool get _hasNumber => RegExp(r'[0-9]').allMatches(_pass1Ctrl.text).length >= 4;
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

  // ── Modal de términos estilo chat ─────────────────────────────────────────────
  void _mostrarTerminos() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _TerminosModal(),
    );
  }

  // ── Submit ────────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_aceptoTerminos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes aceptar los términos y condiciones para continuar.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

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
              const SizedBox(height: 14),

              // ── NUEVO: Checkbox de términos ────────────────────────────────
              _buildTerminosCheckbox(),

              const SizedBox(height: 14),
              _buildSubmitButton(),
              const SizedBox(height: 10),
              _buildLoginLink(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Checkbox términos ─────────────────────────────────────────────────────────
  Widget _buildTerminosCheckbox() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _aceptoTerminos
              ? Colors.white.withOpacity(0.5)
              : Colors.white.withOpacity(0.2),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          // Checkbox personalizado
          GestureDetector(
            onTap: () => setState(() => _aceptoTerminos = !_aceptoTerminos),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: _aceptoTerminos ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: _aceptoTerminos
                  ? const Icon(Icons.check_rounded, color: _kRed1, size: 14)
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _aceptoTerminos = !_aceptoTerminos),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                  ),
                  children: [
                    const TextSpan(text: 'Acepto los '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: GestureDetector(
                        onTap: _mostrarTerminos, // abre el modal
                        child: const Text(
                          'Términos y Condiciones',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const TextSpan(text: ' de KODA'),
                  ],
                ),
              ),
            ),
          ),
        ],
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
      (_hasNumber,                     'Mínimo 4 números'),
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

// ══════════════════════════════════════════════════════════════════════════════
//  Modal de Términos estilo chat
// ══════════════════════════════════════════════════════════════════════════════
class _TerminosModal extends StatefulWidget {
  const _TerminosModal();

  @override
  State<_TerminosModal> createState() => _TerminosModalState();
}

class _TerminosModalState extends State<_TerminosModal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _slideAnim;

  // Cuántas secciones ya se muestran (simula que van "llegando" como mensajes)
  int _visibles = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();

    // Mostrar secciones una por una con delay
    _mostrarSeccionesProgresivamente();
  }

  Future<void> _mostrarSeccionesProgresivamente() async {
    for (int i = 0; i < _terminosSecciones.length; i++) {
      await Future.delayed(Duration(milliseconds: 200 + i * 300));
      if (!mounted) return;
      setState(() => _visibles = i + 1);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(_slideAnim),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.82,
        decoration: const BoxDecoration(
          color: Color(0xFF0D0D0D),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // ── Handle + título ───────────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1C1C1C),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _kRed1.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.gavel_rounded,
                            color: _kRed1, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'KODA',
                            style: GoogleFonts.bebasNeue(
                              color: Colors.white,
                              fontSize: 18,
                              letterSpacing: 2,
                            ),
                          ),
                          const Text(
                            'Términos y Condiciones',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white38, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Lista de secciones estilo burbuja de chat ─────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  // Mensaje inicial de KODA
                  _buildBurbujaKoda(
                    '¡Hola! Antes de crear tu cuenta, te explicamos brevemente cómo funciona KODA y cómo cuidamos tu información. 💪',
                    delay: 0,
                  ),
                  const SizedBox(height: 8),

                  // Secciones que aparecen progresivamente
                  for (int i = 0; i < _terminosSecciones.length; i++)
                    if (i < _visibles)
                      _buildSeccionBurbuja(_terminosSecciones[i], i),

                  // Mensaje final cuando ya están todas
                  if (_visibles >= _terminosSecciones.length) ...[
                    const SizedBox(height: 8),
                    _buildBurbujaKoda(
                      'Al registrarte, confirmas que leíste y aceptas estos términos. ¡Bienvenido a KODA! 🔥',
                      delay: 0,
                    ),
                    const SizedBox(height: 16),
                    // Botón cerrar
                    Center(
                      child: SizedBox(
                        width: 200,
                        height: 44,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kRed1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'ENTENDIDO',
                            style: GoogleFonts.bebasNeue(
                              color: Colors.white,
                              fontSize: 17,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBurbujaKoda(String texto, {required int delay}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _kRed1,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              'K',
              style: GoogleFonts.bebasNeue(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1C),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Text(
              texto,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSeccionBurbuja(_TerminoSeccion seccion, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _kRed1,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                'K',
                style: GoogleFonts.bebasNeue(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1C),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(seccion.icon, color: _kRed1, size: 15),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          seccion.titulo,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    seccion.texto,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      height: 1.5,
                    ),
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