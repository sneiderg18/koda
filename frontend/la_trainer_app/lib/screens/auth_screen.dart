import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ExerciseScreen extends StatefulWidget {
  const ExerciseScreen({super.key});

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  List<dynamic> _ejercicios = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchEjercicios();
  }

  Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    return {
      'Content-Type': 'application/json',
      'ngrok-skip-browser-warning': 'true',
      'Authorization': 'Bearer $token',
    };
  }

  // ── GET ──────────────────────────────────────────────────────────────
  Future<void> _fetchEjercicios() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/ejercicios/'),
        headers: await _headers(),
      );
      if (res.statusCode == 200) {
        setState(() {
          _ejercicios = jsonDecode(res.body);
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Error ${res.statusCode}';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() { _error = 'Sin conexión: $e'; _loading = false; });
    }
  }

  // ── DELETE ───────────────────────────────────────────────────────────
  Future<void> _eliminar(int id) async {
    final confirm = await _showConfirmDialog();
    if (!confirm) return;
    try {
      final res = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/ejercicios/$id/'),
        headers: await _headers(),
      );
      if (res.statusCode == 200 || res.statusCode == 204) {
        _showSnack('Ejercicio eliminado', Colors.green);
        _fetchEjercicios();
      } else {
        _showSnack('Error al eliminar: ${res.statusCode}', Colors.redAccent);
      }
    } catch (_) {
      _showSnack('Sin conexión', Colors.redAccent);
    }
  }

  // ── PUT ──────────────────────────────────────────────────────────────
  Future<void> _actualizar(Map<String, dynamic> ejercicio) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EjercicioForm(
        ejercicio: ejercicio,
        headers: _headers,
        onSaved: () {
          _showSnack('Ejercicio actualizado', Colors.green);
          _fetchEjercicios();
        },
      ),
    );
  }

  // ── POST ─────────────────────────────────────────────────────────────
  Future<void> _crear() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EjercicioForm(
        headers: _headers,
        onSaved: () {
          _showSnack('Ejercicio creado', Colors.green);
          _fetchEjercicios();
        },
      ),
    );
  }

  Future<bool> _showConfirmDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Text('¿Eliminar ejercicio?'),
            content: const Text('Esta acción no se puede deshacer.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Eliminar',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Ejercicios',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF4F6EF7)),
            onPressed: _fetchEjercicios,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFEEEEEE), height: 1),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _crear,
        backgroundColor: const Color(0xFF4F6EF7),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4F6EF7)))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey)),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchEjercicios,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F6EF7),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Reintentar',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                )
              : _ejercicios.isEmpty
                  ? const Center(
                      child: Text('No hay ejercicios registrados',
                          style: TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 20),
                      itemCount: _ejercicios.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final e = _ejercicios[i];
                        return _EjercicioCard(
                          ejercicio: e,
                          onActualizar: () => _actualizar(e),
                          onEliminar: () => _eliminar(e['id']),
                        );
                      },
                    ),
    );
  }
}

// ── Card ──────────────────────────────────────────────────────────────────
class _EjercicioCard extends StatelessWidget {
  final Map<String, dynamic> ejercicio;
  final VoidCallback onActualizar;
  final VoidCallback onEliminar;

  const _EjercicioCard({
    required this.ejercicio,
    required this.onActualizar,
    required this.onEliminar,
  });

  // Color por grupo muscular
  Color _grupoColor(String? grupo) {
    switch (grupo?.toLowerCase()) {
      case 'piernas':   return const Color(0xFF4F6EF7);
      case 'pecho':     return const Color(0xFFFF6B6B);
      case 'espalda':   return const Color(0xFF43C59E);
      case 'hombros':   return const Color(0xFFFF9800);
      case 'brazos':    return const Color(0xFF9C27B0);
      case 'abdomen':   return const Color(0xFF00BCD4);
      default:          return const Color(0xFF607D8B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _grupoColor(ejercicio['grupo_muscular']);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Ícono con color por grupo muscular
            CircleAvatar(
              radius: 26,
              backgroundColor: color.withOpacity(0.12),
              child: Icon(Icons.fitness_center_rounded,
                  color: color, size: 24),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ejercicio['nombre'] ?? '—',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Chip grupo muscular
                  if (ejercicio['grupo_muscular'] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        ejercicio['grupo_muscular'],
                        style: TextStyle(
                            fontSize: 11,
                            color: color,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  if ((ejercicio['descripcion'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      ejercicio['descripcion'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ],
              ),
            ),

            // Botones
            Column(
              children: [
                IconButton(
                  onPressed: onActualizar,
                  style: IconButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF4F6EF7).withOpacity(0.08),
                    padding: const EdgeInsets.all(8),
                  ),
                  icon: const Icon(Icons.edit_rounded,
                      color: Color(0xFF4F6EF7), size: 18),
                ),
                const SizedBox(height: 6),
                IconButton(
                  onPressed: onEliminar,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.08),
                    padding: const EdgeInsets.all(8),
                  ),
                  icon: const Icon(Icons.delete_rounded,
                      color: Colors.redAccent, size: 18),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Formulario BottomSheet ────────────────────────────────────────────────
class _EjercicioForm extends StatefulWidget {
  final Map<String, dynamic>? ejercicio;
  final Future<Map<String, String>> Function() headers;
  final VoidCallback onSaved;

  const _EjercicioForm({
    this.ejercicio,
    required this.headers,
    required this.onSaved,
  });

  @override
  State<_EjercicioForm> createState() => _EjercicioFormState();
}

class _EjercicioFormState extends State<_EjercicioForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreCtrl;
  late TextEditingController _grupoCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _videoCtrl;
  bool _saving = false;

  bool get _isEditing => widget.ejercicio != null;

  final List<String> _grupos = [
    'Piernas', 'Pecho', 'Espalda', 'Hombros', 'Brazos', 'Abdomen', 'Otro'
  ];
  String? _grupoSeleccionado;

  @override
  void initState() {
    super.initState();
    final e = widget.ejercicio;
    _nombreCtrl = TextEditingController(text: e?['nombre']?.toString() ?? '');
    _grupoCtrl  = TextEditingController(text: e?['grupo_muscular']?.toString() ?? '');
    _descCtrl   = TextEditingController(text: e?['descripcion']?.toString() ?? '');
    _videoCtrl  = TextEditingController(text: e?['video_url']?.toString() ?? '');
    _grupoSeleccionado = e?['grupo_muscular']?.toString();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _grupoCtrl.dispose();
    _descCtrl.dispose();
    _videoCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final headers = await widget.headers();
    final body = jsonEncode({
      'nombre':          _nombreCtrl.text.trim(),
      'grupo_muscular':  _grupoSeleccionado ?? _grupoCtrl.text.trim(),
      'descripcion':     _descCtrl.text.trim(),
      'video_url':       _videoCtrl.text.trim(),
    });

    http.Response res;
    if (_isEditing) {
      res = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/ejercicios/${widget.ejercicio!['id']}/'),
        headers: headers,
        body: body,
      );
    } else {
      res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/ejercicios/'),
        headers: headers,
        body: body,
      );
    }

    if (mounted) setState(() => _saving = false);

    if (res.statusCode == 200 || res.statusCode == 201) {
      if (mounted) Navigator.pop(context);
      widget.onSaved();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error ${res.statusCode}: ${res.body}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4)),
              ),
            ),
            Text(
              _isEditing ? 'Actualizar ejercicio' : 'Nuevo ejercicio',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E)),
            ),
            const SizedBox(height: 20),

            // Nombre
            _field(_nombreCtrl, 'Nombre', Icons.fitness_center_rounded,
                validator: (v) => v!.isEmpty ? 'Ingresa el nombre' : null),
            const SizedBox(height: 12),

            // Grupo muscular dropdown
            DropdownButtonFormField<String>(
              value: _grupos.contains(_grupoSeleccionado)
                  ? _grupoSeleccionado
                  : null,
              decoration: _inputDeco('Grupo muscular', Icons.category_rounded),
              items: _grupos
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (v) => setState(() => _grupoSeleccionado = v),
              validator: (v) => v == null ? 'Selecciona un grupo' : null,
            ),
            const SizedBox(height: 12),

            // Descripción
            _field(_descCtrl, 'Descripción', Icons.notes_rounded),
            const SizedBox(height: 12),

            // Video URL
            _field(_videoCtrl, 'URL del video (opcional)',
                Icons.play_circle_outline_rounded),
            const SizedBox(height: 24),

            // Botón guardar
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F6EF7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(_isEditing ? 'Actualizar' : 'Crear',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      validator: validator,
      decoration: _inputDeco(label, icon),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF4F6EF7), size: 20),
      filled: true,
      fillColor: const Color(0xFFF5F7FA),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF4F6EF7), width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
    );
  }
}