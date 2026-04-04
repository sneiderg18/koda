import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/auth_service.dart';
import 'coach_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final _edadCtrl          = TextEditingController();
  final _pesoCtrl           = TextEditingController();
  final _alturaCtrl         = TextEditingController();
  final _objetivoTiempoCtrl = TextEditingController(); // String, ej: "bajar 5kg en 3 meses"
  final _motivacionCtrl     = TextEditingController();
  final _diasCtrl           = TextEditingController();
  final _tiempoSesionCtrl   = TextEditingController();

  String? _genero;
  String? _objetivo;
  String? _nivelActividad;
  String? _lugarEntrenamiento;
  String? _tieneEquipo;

  static const _kRed = Color(0xFFD72105);

  // ── Valores mostrados en UI → valores que espera la API ─────────────────────
  final _generos = {
    'Masculino': 'masculino',
    'Femenino': 'femenino',
    'Otro': 'otro',
  };

  final _objetivos = {
    'Bajar de peso': 'bajar_peso',
    'Ganar músculo': 'ganar_musculo',
    'Mejorar resistencia': 'mejorar_resistencia',
    'Mantener peso': 'mantener_peso',
    'Mejorar salud general': 'mejorar_salud',
  };

  final _nivelesActividad = {
    'Principiante': 'principiante',
    'Ligero': 'ligero',
    'Moderado': 'moderado',
    'Activo': 'activo',
    'Muy activo': 'muy_activo',
  };

  final _lugares = {
    'Casa': 'casa',
    'Gimnasio': 'gimnasio',
    'Al aire libre': 'aire_libre',
    'Mixto': 'mixto',
  };

  @override
  void dispose() {
    _edadCtrl.dispose();
    _pesoCtrl.dispose();
    _alturaCtrl.dispose();
    _objetivoTiempoCtrl.dispose();
    _motivacionCtrl.dispose();
    _diasCtrl.dispose();
    _tiempoSesionCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final token = await AuthService.getToken();

      // Construimos el body eliminando nulls para no enviar campos vacíos
      final Map<String, dynamic> body = {};

      final edad   = int.tryParse(_edadCtrl.text.trim());
      final peso   = double.tryParse(_pesoCtrl.text.trim());
      final altura = double.tryParse(_alturaCtrl.text.trim());
      final dias   = int.tryParse(_diasCtrl.text.trim());
      final tiempo = int.tryParse(_tiempoSesionCtrl.text.trim());

      if (edad   != null) body['edad']                = edad;
      if (peso   != null) body['peso']                = peso;
      if (altura != null) body['altura']              = altura;
      if (dias   != null) body['dias_entrenamiento']  = dias;
      if (tiempo != null) body['tiempo_sesion']       = tiempo;

      // objetivo_tiempo es un String descriptivo, ej: "bajar 5kg en 3 meses"
      final objTiempoStr = _objetivoTiempoCtrl.text.trim();
      if (objTiempoStr.isNotEmpty) body['objetivo_tiempo'] = objTiempoStr;

      // Usar los valores de la API (no los labels del UI)
      if (_genero            != null) body['genero']              = _generos[_genero!]!;
      if (_objetivo          != null) body['objetivo']            = _objetivos[_objetivo!]!;
      if (_nivelActividad    != null) body['nivel_actividad']     = _nivelesActividad[_nivelActividad!]!;
      if (_lugarEntrenamiento != null) body['lugar_entrenamiento'] = _lugares[_lugarEntrenamiento!]!;
      if (_tieneEquipo       != null) body['tiene_equipo']        = _tieneEquipo == 'Sí';

      final motivacion = _motivacionCtrl.text.trim();
      if (motivacion.isNotEmpty) body['motivacion'] = motivacion;

      // ── DEBUG: ver exactamente qué mandamos ───────────────────────────────
      print('>>> ONBOARDING BODY: ${jsonEncode(body)}');

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/onboarding/'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      print('>>> ONBOARDING STATUS: ${response.statusCode}');
      print('>>> ONBOARDING RESPONSE: ${response.body}');
      // ── FIN DEBUG ─────────────────────────────────────────────────────────

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CoachScreen()),
        );
      } else {
        // Mostrar el mensaje exacto que devuelve Django
        String errorMsg = 'Error ${response.statusCode}';
        try {
          final data = jsonDecode(response.body);
          if (data is Map) {
            errorMsg = data.entries
                .map((e) => '${e.key}: ${e.value}')
                .join('\n');
          }
        } catch (_) {
          errorMsg = response.body;
        }
        _mostrarError(errorMsg);
      }
    } catch (e) {
      _mostrarError('No se pudo conectar: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          'Cuéntanos sobre ti',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFEEEEEE), height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Datos personales'),
              const SizedBox(height: 16),
              _buildRow([
                _numField(_edadCtrl, 'Edad', Icons.cake_rounded,
                    hint: 'Ej. 25', isInt: true),
                _numField(_pesoCtrl, 'Peso (kg)', Icons.monitor_weight_rounded,
                    hint: 'Ej. 70.5'),
              ]),
              const SizedBox(height: 12),
              _buildRow([
                _numField(_alturaCtrl, 'Altura (cm)', Icons.height_rounded,
                    hint: 'Ej. 175', isInt: true),
                _dropdown('Género', _generos.keys.toList(), _genero, Icons.person_rounded,
                    (v) => setState(() => _genero = v)),
              ]),
              const SizedBox(height: 28),

              _sectionTitle('Objetivos'),
              const SizedBox(height: 16),
              _dropdown('Objetivo principal', _objetivos.keys.toList(), _objetivo,
                  Icons.flag_rounded, (v) => setState(() => _objetivo = v)),
              const SizedBox(height: 12),
              _textField(_objetivoTiempoCtrl, 'Describe tu meta', Icons.calendar_today_rounded,
                  hint: 'Ej. Bajar 5kg en 3 meses', required: false),
              const SizedBox(height: 12),
              _textField(_motivacionCtrl, 'Motivación', Icons.star_rounded,
                  hint: 'Ej. Quiero sentirme mejor', required: false),
              const SizedBox(height: 28),

              _sectionTitle('Entrenamiento'),
              const SizedBox(height: 16),
              _dropdown('Nivel de actividad', _nivelesActividad.keys.toList(), _nivelActividad,
                  Icons.fitness_center_rounded,
                  (v) => setState(() => _nivelActividad = v)),
              const SizedBox(height: 12),
              _buildRow([
                _numField(_diasCtrl, 'Días/semana', Icons.event_rounded,
                    hint: 'Ej. 4', isInt: true),
                _numField(_tiempoSesionCtrl, 'Min/sesión', Icons.timer_rounded,
                    hint: 'Ej. 60', isInt: true),
              ]),
              const SizedBox(height: 12),
              _dropdown('Lugar de entrenamiento', _lugares.keys.toList(), _lugarEntrenamiento,
                  Icons.place_rounded,
                  (v) => setState(() => _lugarEntrenamiento = v)),
              const SizedBox(height: 12),
              _dropdown('¿Tiene equipo/pesas?', ['Sí', 'No'], _tieneEquipo,
                  Icons.sports_gymnastics_rounded,
                  (v) => setState(() => _tieneEquipo = v)),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _enviar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kRed,
                    disabledBackgroundColor: _kRed.withOpacity(0.6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Text(
                          'Continuar',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E))),
      );

  Widget _buildRow(List<Widget> children) {
    final withGaps = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      withGaps.add(Expanded(child: children[i]));
      if (i < children.length - 1) withGaps.add(const SizedBox(width: 12));
    }
    return Row(children: withGaps);
  }

  Widget _numField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    String hint = '',
    bool isInt = false,
    bool required = true,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: isInt
          ? TextInputType.number
          : const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        isInt
            ? FilteringTextInputFormatter.digitsOnly
            : FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
      ],
      decoration: _deco(label, icon, hint),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null
          : null,
    );
  }

  Widget _textField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    String hint = '',
    bool required = true,
  }) {
    return TextFormField(
      controller: ctrl,
      decoration: _deco(label, icon, hint),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null
          : null,
    );
  }

  Widget _dropdown(
    String label,
    List<String> items,
    String? value,
    IconData icon,
    void Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: _deco(label, icon, ''),
      isExpanded: true,
      items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
      onChanged: onChanged,
      validator: (v) => v == null ? 'Selecciona una opción' : null,
    );
  }

  InputDecoration _deco(String label, IconData icon, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
      prefixIcon: Icon(icon, color: _kRed, size: 20),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEEEEEE))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEEEEEE))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kRed, width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
    );
  }
}