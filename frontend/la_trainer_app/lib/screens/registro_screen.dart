import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
 
class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});
 
  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}
 
class _RegistroScreenState extends State<RegistroScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _emailCtrl    = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _pass1Ctrl    = TextEditingController();
  final _pass2Ctrl    = TextEditingController();
 
  bool _obscurePass1 = true;
  bool _obscurePass2 = true;
  bool _loading      = false;
 
  // Requisitos de contraseña
  bool get _hasMinLength => _pass1Ctrl.text.length >= 8;
  bool get _hasUppercase => _pass1Ctrl.text.contains(RegExp(r'[A-Z]'));
  bool get _hasNumber    => _pass1Ctrl.text.contains(RegExp(r'[0-9]'));
  bool get _hasSpecial   => _pass1Ctrl.text.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));
 
  @override
  void initState() {
    super.initState();
    _pass1Ctrl.addListener(() => setState(() {}));
  }
 
  @override
  void dispose() {
    _emailCtrl.dispose();
    _usernameCtrl.dispose();
    _pass1Ctrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }
 
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
 
    setState(() => _loading = true);
 
    final result = await AuthService.registro(
      email:     _emailCtrl.text.trim(),
      username:  _usernameCtrl.text.trim(),
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
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Error al registrarse'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
            child: Column(
              children: [
                // ── Encabezado ──────────────────────────────────────────
                const Icon(Icons.person_add_rounded,
                    size: 64, color: Color(0xFF4F6EF7)),
                const SizedBox(height: 12),
                Text(
                  'Crear cuenta',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1A2E),
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Completa tus datos para registrarte',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 28),
 
                // ── Formulario ──────────────────────────────────────────
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Email
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _inputDecoration(
                              label: 'Correo electrónico',
                              icon: Icons.email_outlined,
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Ingresa tu correo';
                              }
                              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                                  .hasMatch(v.trim())) {
                                return 'Correo no válido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
 
                          // Username
                          TextFormField(
                            controller: _usernameCtrl,
                            decoration: _inputDecoration(
                              label: 'Nombre de usuario',
                              icon: Icons.alternate_email_rounded,
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Ingresa un nombre de usuario';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
 
                          // Password1
                          TextFormField(
                            controller: _pass1Ctrl,
                            obscureText: _obscurePass1,
                            decoration: _inputDecoration(
                              label: 'Contraseña',
                              icon: Icons.lock_outline,
                            ).copyWith(
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePass1
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: Colors.grey,
                                ),
                                onPressed: () => setState(
                                    () => _obscurePass1 = !_obscurePass1),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Ingresa una contraseña';
                              }
                              if (v.length < 8) {
                                return 'Mínimo 8 caracteres';
                              }
                              return null;
                            },
                          ),
 
                          // ── Hint requisitos ─────────────────────────
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F3FF),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: const Color(0xFFD0D8FF), width: 1),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tu contraseña debe tener:',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                _reqRow(_hasMinLength, 'Mínimo 8 caracteres'),
                                _reqRow(_hasUppercase, 'Al menos una letra mayúscula y una letra minuscula'),
                                _reqRow(_hasNumber,    'Al menos 4 números'),
                                _reqRow(_hasSpecial,   'Al menos un carácter especial (!@#\$...)'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
 
                          // Password2
                          TextFormField(
                            controller: _pass2Ctrl,
                            obscureText: _obscurePass2,
                            decoration: _inputDecoration(
                              label: 'Confirmar contraseña',
                              icon: Icons.lock_outline,
                            ).copyWith(
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePass2
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: Colors.grey,
                                ),
                                onPressed: () => setState(
                                    () => _obscurePass2 = !_obscurePass2),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Confirma tu contraseña';
                              }
                              if (v != _pass1Ctrl.text) {
                                return 'Las contraseñas no coinciden';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 28),
 
                          // Botón registrarse
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4F6EF7),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Text(
                                      'Registrarse',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
 
                const SizedBox(height: 20),
 
                // ── Ir a login ──────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '¿Ya tienes cuenta? ',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        'Inicia sesión',
                        style: TextStyle(
                          color: Color(0xFF4F6EF7),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
 
  /// Fila de requisito con ícono dinámico
  Widget _reqRow(bool met, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            met
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 14,
            color: met ? const Color(0xFF4F6EF7) : Colors.grey[400],
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              color: met ? const Color(0xFF4F6EF7) : Colors.grey[500],
              fontWeight: met ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
 
  InputDecoration _inputDecoration(
      {required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF4F6EF7)),
      filled: true,
      fillColor: const Color(0xFFF5F7FA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF4F6EF7), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }
}