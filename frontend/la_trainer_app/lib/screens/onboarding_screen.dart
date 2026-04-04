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

  final _edadCtrl               = TextEditingController();
  final _pesoCtrl               = TextEditingController();
  final _alturaCtrl             = TextEditingController();
  final _objetivoTiempoCtrl     = TextEditingController();
  final _condicionesMedicasCtrl = TextEditingController();
  final _alergiasCtrl           = TextEditingController();
  final _lesionesCtrl           = TextEditingController();
  final _diasCtrl               = TextEditingController();
  final _tiempoSesionCtrl       = TextEditingController();
  final _comidasPorDiaCtrl      = TextEditingController();
  final _aguaPorDiaCtrl         = TextEditingController();

  String? _genero;
  String? _objetivo;
  String? _motivacion;
  String? _nivelActividad;
  String? _lugarEntrenamiento;
  String? _tieneEquipo;
  String? _restriccionesAlimentarias;
  String? _calidadSueno;
  String? _nivelEstres;

  static const _kRed = Color(0xFFD72105);

  final _generos = const {
    'Masculino':         'masculino',
    'Femenino':          'femenino',
    'Otro':              'otro',
    'Prefiero no decir': 'prefiero_no_decir',
  };

  final _objetivos = const {
    'Bajar de peso':       'bajar_peso',
    'Aumentar masa':       'aumentar_masa',
    'Mantenerse':          'mantenerse',
    'Mejorar resistencia': 'mejorar_resistencia',
    'Rehabilitación':      'rehabilitacion',
  };

  final _motivaciones = const {
    'Salud':       'salud',
    'Estética':    'estetica',
    'Rendimiento': 'rendimiento',
  };

  final _nivelesActividad = const {
    'Sedentario':   'sedentario',
    'Principiante': 'principiante',
    'Intermedio':   'intermedio',
    'Avanzado':     'avanzado',
  };

  final _lugares = const {
    'Casa':     'casa',
    'Gimnasio': 'gimnasio',
    'Ambos':    'ambos',
  };

  final _restricciones = const {
    'Ninguna':     'ninguna',
    'Vegetariano': 'vegetariano',
    'Vegano':      'vegano',
    'Sin gluten':  'sin_gluten',
    'Sin lactosa': 'sin_lactosa',
    'Otro':        'otro',
  };

  final _calidadesSueno = const {
    'Bueno':   'bueno',
    'Regular': 'regular',
    'Malo':    'malo',
  };

  final _nivelesEstres = const {
    'Bajo':  'bajo',
    'Medio': 'medio',
    'Alto':  'alto',
  };

  @override
  void dispose() {
    _edadCtrl.dispose();
    _pesoCtrl.dispose();
    _alturaCtrl.dispose();
    _objetivoTiempoCtrl.dispose();
    _condicionesMedicasCtrl.dispose();
    _alergiasCtrl.dispose();
    _lesionesCtrl.dispose();
    _diasCtrl.dispose();
    _tiempoSesionCtrl.dispose();
    _comidasPorDiaCtrl.dispose();
    _aguaPorDiaCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final token = await AuthService.getToken();
      final Map<String, dynamic> body = {};

      final edad    = int.tryParse(_edadCtrl.text.trim());
      final dias    = int.tryParse(_diasCtrl.text.trim());
      final tiempo  = int.tryParse(_tiempoSesionCtrl.text.trim());
      final comidas = int.tryParse(_comidasPorDiaCtrl.text.trim());
      final peso    = double.tryParse(_pesoCtrl.text.trim());
      final altura  = double.tryParse(_alturaCtrl.text.trim());
      final agua    = double.tryParse(_aguaPorDiaCtrl.text.trim());

      if (edad    != null) body['edad']               = edad;
      if (peso    != null) body['peso']               = peso;
      if (altura  != null) body['altura']             = altura;
      if (dias    != null) body['dias_entrenamiento'] = dias;
      if (tiempo  != null) body['tiempo_sesion']      = tiempo;
      if (comidas != null) body['comidas_por_dia']    = comidas;
      if (agua    != null) body['agua_por_dia']       = agua;

      final objTiempo   = _objetivoTiempoCtrl.text.trim();
      final condiciones = _condicionesMedicasCtrl.text.trim();
      final alergias    = _alergiasCtrl.text.trim();
      final lesiones    = _lesionesCtrl.text.trim();

      if (objTiempo.isNotEmpty)   body['objetivo_tiempo']     = objTiempo;
      if (condiciones.isNotEmpty) body['condiciones_medicas'] = condiciones;
      if (alergias.isNotEmpty)    body['alergias']            = alergias;
      if (lesiones.isNotEmpty)    body['lesiones']            = lesiones;

      if (_genero                    != null) body['genero']                    = _generos[_genero!]!;
      if (_objetivo                  != null) body['objetivo']                  = _objetivos[_objetivo!]!;
      if (_motivacion                != null) body['motivacion']                = _motivaciones[_motivacion!]!;
      if (_nivelActividad            != null) body['nivel_actividad']           = _nivelesActividad[_nivelActividad!]!;
      if (_lugarEntrenamiento        != null) body['lugar_entrenamiento']       = _lugares[_lugarEntrenamiento!]!;
      if (_restriccionesAlimentarias != null) body['restricciones_alimentarias']= _restricciones[_restriccionesAlimentarias!]!;
      if (_calidadSueno              != null) body['calidad_sueno']             = _calidadesSueno[_calidadSueno!]!;
      if (_nivelEstres               != null) body['nivel_estres']              = _nivelesEstres[_nivelEstres!]!;
      if (_tieneEquipo               != null) body['tiene_equipo']              = _tieneEquipo == 'Sí';

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

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        await AuthService.setOnboardingDone();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CoachScreen()),
        );
      } else {
        String errorMsg = 'Error ${response.statusCode}';
        try {
          final data = jsonDecode(response.body);
          if (data is Map) {
            errorMsg = data.entries.map((e) => '${e.key}: ${e.value}').join('\n');
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
          style: TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.bold, fontSize: 20),
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

              // ── Datos personales ────────────────────────────────────────
              _sectionTitle('Datos personales'),
              const SizedBox(height: 16),
              _buildRow([
                _numField(_edadCtrl, 'Edad', Icons.cake_rounded, hint: 'Ej. 25', isInt: true),
                _numField(_pesoCtrl, 'Peso (kg)', Icons.monitor_weight_rounded, hint: 'Ej. 75.5'),
              ]),
              const SizedBox(height: 12),
              _buildRow([
                _numField(_alturaCtrl, 'Altura (cm)', Icons.height_rounded, hint: 'Ej. 175.0'),
                _dropdown('Género', _generos.keys.toList(), _genero,
                    Icons.person_rounded, (v) => setState(() => _genero = v)),
              ]),
              const SizedBox(height: 28),

              // ── Objetivos ───────────────────────────────────────────────
              _sectionTitle('Objetivos'),
              const SizedBox(height: 16),
              _dropdown('Objetivo principal', _objetivos.keys.toList(), _objetivo,
                  Icons.flag_rounded, (v) => setState(() => _objetivo = v)),
              const SizedBox(height: 12),
              _dropdown('Motivación', _motivaciones.keys.toList(), _motivacion,
                  Icons.star_rounded, (v) => setState(() => _motivacion = v)),
              const SizedBox(height: 12),
              _textField(_objetivoTiempoCtrl, 'Describe tu meta',
                  Icons.calendar_today_rounded,
                  hint: 'Ej. Bajar 5kg en 3 meses', required: false),
              const SizedBox(height: 28),

              // ── Entrenamiento ───────────────────────────────────────────
              _sectionTitle('Entrenamiento'),
              const SizedBox(height: 16),
              _dropdown('Nivel de actividad', _nivelesActividad.keys.toList(),
                  _nivelActividad, Icons.fitness_center_rounded,
                  (v) => setState(() => _nivelActividad = v)),
              const SizedBox(height: 12),
              _buildRow([
                _numField(_diasCtrl, 'Días/semana', Icons.event_rounded, hint: 'Ej. 3', isInt: true),
                _numField(_tiempoSesionCtrl, 'Min/sesión', Icons.timer_rounded, hint: 'Ej. 45', isInt: true),
              ]),
              const SizedBox(height: 12),
              _dropdown('Lugar de entrenamiento', _lugares.keys.toList(),
                  _lugarEntrenamiento, Icons.place_rounded,
                  (v) => setState(() => _lugarEntrenamiento = v)),
              const SizedBox(height: 12),
              _dropdown('¿Tiene equipo/pesas?', ['Sí', 'No'], _tieneEquipo,
                  Icons.sports_gymnastics_rounded,
                  (v) => setState(() => _tieneEquipo = v)),
              const SizedBox(height: 28),

              // ── Salud ───────────────────────────────────────────────────
              _sectionTitle('Salud'),
              const SizedBox(height: 16),
              _textField(_condicionesMedicasCtrl, 'Condiciones médicas',
                  Icons.medical_information_rounded,
                  hint: 'Ej. Diabetes tipo 2', required: false),
              const SizedBox(height: 12),
              _textField(_alergiasCtrl, 'Alergias',
                  Icons.warning_amber_rounded,
                  hint: 'Ej. Maní, mariscos', required: false),
              const SizedBox(height: 12),
              _textField(_lesionesCtrl, 'Lesiones',
                  Icons.healing_rounded,
                  hint: 'Ej. Dolor de rodilla derecha', required: false),
              const SizedBox(height: 28),

              // ── Alimentación ────────────────────────────────────────────
              _sectionTitle('Alimentación'),
              const SizedBox(height: 16),
              _dropdown('Restricciones alimentarias', _restricciones.keys.toList(),
                  _restriccionesAlimentarias, Icons.no_meals_rounded,
                  (v) => setState(() => _restriccionesAlimentarias = v)),
              const SizedBox(height: 12),
              _buildRow([
                _numField(_comidasPorDiaCtrl, 'Comidas/día', Icons.restaurant_rounded,
                    hint: 'Ej. 5', isInt: true),
                _numField(_aguaPorDiaCtrl, 'Agua/día (L)', Icons.water_drop_rounded,
                    hint: 'Ej. 2.5'),
              ]),
              const SizedBox(height: 28),

              // ── Hábitos ─────────────────────────────────────────────────
              _sectionTitle('Hábitos'),
              const SizedBox(height: 16),
              _dropdown('Calidad del sueño', _calidadesSueno.keys.toList(),
                  _calidadSueno, Icons.bedtime_rounded,
                  (v) => setState(() => _calidadSueno = v)),
              const SizedBox(height: 12),
              _dropdown('Nivel de estrés', _nivelesEstres.keys.toList(),
                  _nivelEstres, Icons.psychology_rounded,
                  (v) => setState(() => _nivelEstres = v)),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _enviar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kRed,
                    disabledBackgroundColor: _kRed.withOpacity(0.6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text('Continuar',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
      );

  Widget _buildRow(List<Widget> children) {
    final withGaps = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      withGaps.add(Expanded(child: children[i]));
      if (i < children.length - 1) withGaps.add(const SizedBox(width: 12));
    }
    return Row(children: withGaps);
  }

  Widget _numField(TextEditingController ctrl, String label, IconData icon,
      {String hint = '', bool isInt = false, bool required = true}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: isInt ? TextInputType.number : const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        isInt
            ? FilteringTextInputFormatter.digitsOnly
            : FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
      ],
      decoration: _deco(label, icon, hint),
      validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null : null,
    );
  }

  Widget _textField(TextEditingController ctrl, String label, IconData icon,
      {String hint = '', bool required = true}) {
    return TextFormField(
      controller: ctrl,
      decoration: _deco(label, icon, hint),
      validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null : null,
    );
  }

  Widget _dropdown(String label, List<String> items, String? value, IconData icon,
      void Function(String?) onChanged, {bool required = true}) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: _deco(label, icon, ''),
      isExpanded: true,
      items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
      onChanged: onChanged,
      validator: required ? (v) => v == null ? 'Selecciona una opción' : null : null,
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
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEEEEEE))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEEEEEE))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kRed, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
    );
  }
}