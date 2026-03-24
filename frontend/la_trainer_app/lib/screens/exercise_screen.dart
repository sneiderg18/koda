import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../config/api_config.dart';

class ExerciseScreen extends StatefulWidget {
  const ExerciseScreen({super.key});

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  List<dynamic> _ejercicios = [];
  List<dynamic> _filtered = [];
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();

  static const _kRed = Color(0xFFD72105);

  // Imágenes de calistenia para cada ejercicio
  static const _exerciseImages = {
    'dominada': 'https://images.unsplash.com/photo-1598289431512-b97b0917affc?w=150',
    'flexion': 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=150',
    'fondo': 'https://images.unsplash.com/photo-1581009146145-b5ef050c2e1e?w=150',
    'plancha': 'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=150',
    'sentadilla': 'https://images.unsplash.com/photo-1434608519344-49d77a699ded?w=150',
    'default': 'https://images.unsplash.com/photo-1599058945522-28d584b6f0ff?w=150',
  };

  @override
  void initState() {
    super.initState();
    _fetchEjercicios();
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _filtered = q.isEmpty
          ? List.from(_ejercicios)
          : _ejercicios.where((e) {
              final nombre = (e['nombre'] ?? '').toString().toLowerCase();
              final desc = (e['descripcion'] ?? '').toString().toLowerCase();
              final grupo = (e['grupo_muscular'] ?? '').toString().toLowerCase();
              return nombre.contains(q) || desc.contains(q) || grupo.contains(q);
            }).toList();
    });
  }

  String _getImageForExercise(String nombre) {
    final lower = nombre.toLowerCase();
    if (lower.contains('dominada')) return _exerciseImages['dominada']!;
    if (lower.contains('flexion')) return _exerciseImages['flexion']!;
    if (lower.contains('fondo')) return _exerciseImages['fondo']!;
    if (lower.contains('plancha')) return _exerciseImages['plancha']!;
    if (lower.contains('sentadilla')) return _exerciseImages['sentadilla']!;
    return _exerciseImages['default']!;
  }

  Future<void> _fetchEjercicios() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        setState(() {
          _error = 'No se encontró el token. Por favor inicia sesión de nuevo.';
          _loading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/ejercicios/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data is List ? data : (data['results'] ?? data['data'] ?? []) as List;
        setState(() {
          _ejercicios = list;
          _filtered = List.from(list);
          _loading = false;
        });
      } else if (response.statusCode == 401) {
        setState(() {
          _error = 'Sesión expirada. Por favor inicia sesión de nuevo.';
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Error ${response.statusCode}: No se pudo cargar los ejercicios.';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error de conexión. Verifica tu internet.';
        _loading = false;
      });
    }
  }

  Future<void> _agregarEjercicio() async {
    final result = await _mostrarFormulario();
    if (result == null) return;

    try {
      final token = await AuthService.getToken();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/ejercicios/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode(result),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final nuevo = jsonDecode(response.body);
        setState(() {
          _ejercicios.add(nuevo);
          _filtered.add(nuevo);
        });
        _showSnack('Ejercicio agregado correctamente', Colors.green);
      } else {
        _showSnack('Error al agregar: ${response.statusCode}', Colors.redAccent);
      }
    } catch (e) {
      _showSnack('Error de conexión al agregar', Colors.redAccent);
    }
  }

  Future<void> _editarEjercicio(Map<String, dynamic> ejercicio) async {
    final result = await _mostrarFormulario(ejercicio: ejercicio);
    if (result == null) return;

    try {
      final token = await AuthService.getToken();
      final id = ejercicio['id'];
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/ejercicios/$id/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode(result),
      );

      if (response.statusCode == 200) {
        final updated = jsonDecode(response.body);
        setState(() {
          final i = _ejercicios.indexWhere((e) => e['id'] == id);
          if (i != -1) _ejercicios[i] = updated;
          final j = _filtered.indexWhere((e) => e['id'] == id);
          if (j != -1) _filtered[j] = updated;
        });
        _showSnack('Ejercicio actualizado correctamente', Colors.green);
      } else {
        _showSnack('Error al actualizar: ${response.statusCode}', Colors.redAccent);
      }
    } catch (e) {
      _showSnack('Error de conexión al actualizar', Colors.redAccent);
    }
  }

  Future<void> _eliminarEjercicio(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar ejercicio', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('¿Estás seguro de que deseas eliminar este ejercicio?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final token = await AuthService.getToken();
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/ejercicios/$id/'),
        headers: {
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 204 || response.statusCode == 200) {
        setState(() {
          _ejercicios.removeWhere((e) => e['id'] == id);
          _filtered.removeWhere((e) => e['id'] == id);
        });
        _showSnack('Ejercicio eliminado correctamente', Colors.green);
      } else {
        _showSnack('Error al eliminar: ${response.statusCode}', Colors.redAccent);
      }
    } catch (e) {
      _showSnack('Error de conexión al eliminar', Colors.redAccent);
    }
  }

  Future<Map<String, dynamic>?> _mostrarFormulario({Map<String, dynamic>? ejercicio}) async {
    final nombreCtrl = TextEditingController(text: ejercicio?['nombre'] ?? '');
    final grupoCtrl = TextEditingController(text: ejercicio?['grupo_muscular'] ?? '');
    final descCtrl = TextEditingController(text: ejercicio?['descripcion'] ?? '');
    final formKey = GlobalKey<FormState>();
    final esEdicion = ejercicio != null;

    final guardado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          esEdicion ? 'Actualizar ejercicio' : 'Nuevo ejercicio',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DialogField(ctrl: nombreCtrl, label: 'Nombre', icon: Icons.directions_run_rounded, color: _kRed),
                const SizedBox(height: 12),
                _DialogField(ctrl: grupoCtrl, label: 'Grupo muscular', icon: Icons.fitness_center_rounded, color: _kRed),
                const SizedBox(height: 12),
                _DialogField(ctrl: descCtrl, label: 'Descripción', icon: Icons.description_rounded, color: _kRed, maxLines: 3),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: Text(esEdicion ? 'Guardar' : 'Agregar'),
          ),
        ],
      ),
    );

    if (guardado != true) return null;

    return {
      'nombre': nombreCtrl.text.trim(),
      'grupo_muscular': grupoCtrl.text.trim(),
      'descripcion': descCtrl.text.trim(),
    };
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // ── Información del entrenamiento ──────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Día 4 Tren Superior Fuerza',
                  style: GoogleFonts.bebasNeue(
                    fontSize: 28,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded, color: _kRed, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      '33 mins',
                      style: TextStyle(color: Colors.grey[400], fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Barra de búsqueda ──────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Buscar ejercicio...',
                hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, color: _kRed),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: Colors.grey, size: 18),
                        onPressed: () => _searchCtrl.clear(),
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey[900],
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[800]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kRed, width: 1.5),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Lista de ejercicios ────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _kRed))
                : _error != null
                    ? _ErrorState(message: _error!, onRetry: _fetchEjercicios)
                    : _filtered.isEmpty
                        ? _EmptyState(isSearch: _searchCtrl.text.isNotEmpty)
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                            itemCount: _filtered.length,
                            itemBuilder: (context, index) => _EjercicioCard(
                              ejercicio: _filtered[index],
                              index: index,
                              imageUrl: _getImageForExercise(_filtered[index]['nombre'] ?? ''),
                              onEditar: () => _editarEjercicio(_filtered[index]),
                              onEliminar: () => _eliminarEjercicio(_filtered[index]['id']),
                            ),
                          ),
          ),
        ],
      ),
      // ── Botón EMPEZAR SESIÓN ───────────────────────────────────────────────
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.8),
            ],
          ),
        ),
        child: GestureDetector(
          onTap: _agregarEjercicio,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_kRed, _kRed.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
              boxShadow: [
                BoxShadow(
                  color: _kRed.withOpacity(0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                const SizedBox(width: 10),
                Text(
                  'Crear ejercicio',
                  style: GoogleFonts.bebasNeue(
                    fontSize: 20,
                    color: Colors.white,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _kRed,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  'DETALLES',
                  style: GoogleFonts.bebasNeue(
                    fontSize: 16,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Text(
            'IA TRAINER',
            style: GoogleFonts.bebasNeue(
              fontSize: 18,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Tarjeta de ejercicio ──────────────────────────────────────────────────────
class _EjercicioCard extends StatelessWidget {
  final Map<String, dynamic> ejercicio;
  final int index;
  final String imageUrl;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  const _EjercicioCard({
    required this.ejercicio,
    required this.index,
    required this.imageUrl,
    required this.onEditar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final nombre = ejercicio['nombre'] ?? 'Ejercicio ${index + 1}';
    final descripcion = ejercicio['descripcion'] ?? '';
    final grupo = ejercicio['grupo_muscular'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // ── Imagen del ejercicio ────────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                imageUrl,
                width: 70,
                height: 70,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 70,
                    height: 70,
                    color: Colors.grey[800],
                    child: const Icon(Icons.fitness_center, color: Colors.grey, size: 30),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: 70,
                    height: 70,
                    color: Colors.grey[800],
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                        strokeWidth: 2,
                        color: _EjercicioCard._kRed,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 14),
            // ── Información ─────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre.toString(),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (grupo.toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      grupo.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                  if (descripcion.toString().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      descripcion.toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  // ── Botones de acción ────────────────────────────────────
                  Row(
                    children: [
                      IconButton(
                        onPressed: onEditar,
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        color: Colors.grey[500],
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      IconButton(
                        onPressed: onEliminar,
                        icon: const Icon(Icons.delete_rounded, size: 18),
                        color: Colors.redAccent,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _kRed = Color(0xFFD72105);
}

// ── Campo del diálogo ────────────────────────────────────────────────────────
class _DialogField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final Color color;
  final int maxLines;

  const _DialogField({
    required this.ctrl,
    required this.label,
    required this.icon,
    required this.color,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[500]),
        prefixIcon: Icon(icon, color: color, size: 20),
        filled: true,
        fillColor: Colors.grey[900],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[800]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      ),
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
    );
  }
}

// ── Estado error ─────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 56, color: Colors.grey[700]),
            const SizedBox(height: 16),
            const Text(
              'Algo salió mal',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _ErrorState._kRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _kRed = Color(0xFFD72105);
}

// ── Estado vacío ─────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool isSearch;

  const _EmptyState({required this.isSearch});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSearch ? Icons.search_off_rounded : Icons.fitness_center_rounded,
            size: 56,
            color: Colors.grey[700],
          ),
          const SizedBox(height: 16),
          Text(
            isSearch ? 'Sin resultados' : 'No hay ejercicios',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            isSearch
                ? 'Intenta con otro término de búsqueda'
                : 'No se encontraron ejercicios disponibles',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}