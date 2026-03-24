import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../config/api_config.dart';

class FoodScreen extends StatefulWidget {
  const FoodScreen({super.key});

  @override
  State<FoodScreen> createState() => _FoodScreenState();
}

class _FoodScreenState extends State<FoodScreen> {
  List<dynamic> _comidas = [];
  List<dynamic> _filtered = [];
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();

  static const _kRed = Color(0xFFD72105);
  static const _kPurple = Color(0xFF9C27B0);

  // Imágenes de alimentos desde web (Unsplash)
  static const _foodImages = {
    'pollo': 'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?w=150',
    'arroz': 'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=150',
    'ensalada': 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=150',
    'pescado': 'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?w=150',
    'huevos': 'https://images.unsplash.com/photo-1482049016688-2d3e1b311543?w=150',
    'avena': 'https://images.unsplash.com/photo-1517673132405-a56a62b18caf?w=150',
    'default': 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=150',
  };

  @override
  void initState() {
    super.initState();
    _fetchComidas();
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
          ? List.from(_comidas)
          : _comidas.where((c) {
              final nombre = (c['nombre'] ?? '').toString().toLowerCase();
              return nombre.contains(q);
            }).toList();
    });
  }

  String _getImageForFood(String? nombre) {
    if (nombre == null || nombre.isEmpty) return _foodImages['default']!;
    
    final lower = nombre.toLowerCase();
    if (lower.contains('pollo')) return _foodImages['pollo']!;
    if (lower.contains('arroz')) return _foodImages['arroz']!;
    if (lower.contains('ensalada')) return _foodImages['ensalada']!;
    if (lower.contains('pescado') || lower.contains('atún') || lower.contains('salmon')) return _foodImages['pescado']!;
    if (lower.contains('huevo')) return _foodImages['huevos']!;
    if (lower.contains('avena')) return _foodImages['avena']!;
    return _foodImages['default']!;
  }

  Future<void> _fetchComidas() async {
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
        Uri.parse('${ApiConfig.baseUrl}/api/comidas/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data is List
            ? data
            : (data['results'] ?? data['data'] ?? []) as List;
        setState(() {
          _comidas = list;
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
          _error = 'Error ${response.statusCode}: No se pudo cargar las comidas.';
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

  Future<void> _eliminarComida(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar comida',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('¿Estás seguro de que deseas eliminar esta comida?'),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
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
        Uri.parse('${ApiConfig.baseUrl}/api/comidas/$id/'),
        headers: {
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 204 || response.statusCode == 200) {
        setState(() {
          _comidas.removeWhere((c) => c['id'] == id);
          _filtered.removeWhere((c) => c['id'] == id);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Comida eliminada correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar: ${response.statusCode}'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error de conexión al eliminar'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _editarComida(Map<String, dynamic> comida) async {
    final nombreCtrl =
        TextEditingController(text: comida['nombre']?.toString() ?? '');
    final caloriasCtrl =
        TextEditingController(text: comida['calorias']?.toString() ?? '');
    final proteinasCtrl =
        TextEditingController(text: comida['proteinas']?.toString() ?? '');
    final carbosCtrl =
        TextEditingController(text: comida['carbohidratos']?.toString() ?? '');
    final grasasCtrl =
        TextEditingController(text: comida['grasas']?.toString() ?? '');

    final formKey = GlobalKey<FormState>();

    final guardado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Actualizar comida',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DialogField(
                    ctrl: nombreCtrl,
                    label: 'Nombre',
                    icon: Icons.lunch_dining_rounded),
                const SizedBox(height: 12),
                _DialogField(
                    ctrl: caloriasCtrl,
                    label: 'Calorías',
                    icon: Icons.local_fire_department_rounded,
                    isNumber: true),
                const SizedBox(height: 12),
                _DialogField(
                    ctrl: proteinasCtrl,
                    label: 'Proteínas (g)',
                    icon: Icons.fitness_center_rounded,
                    isNumber: true),
                const SizedBox(height: 12),
                _DialogField(
                    ctrl: carbosCtrl,
                    label: 'Carbohidratos (g)',
                    icon: Icons.grain_rounded,
                    isNumber: true),
                const SizedBox(height: 12),
                _DialogField(
                    ctrl: grasasCtrl,
                    label: 'Grasas (g)',
                    icon: Icons.opacity_rounded,
                    isNumber: true),
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
              backgroundColor: _kPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (guardado != true) return;

    try {
      final token = await AuthService.getToken();
      final id = comida['id'];

      final body = jsonEncode({
        'nombre': nombreCtrl.text.trim(),
        'calorias': int.tryParse(caloriasCtrl.text) ?? comida['calorias'],
        'proteinas':
            double.tryParse(proteinasCtrl.text) ?? comida['proteinas'],
        'carbohidratos':
            double.tryParse(carbosCtrl.text) ?? comida['carbohidratos'],
        'grasas': double.tryParse(grasasCtrl.text) ?? comida['grasas'],
      });

      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/comidas/$id/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final updated = jsonDecode(response.body);
        setState(() {
          final i = _comidas.indexWhere((c) => c['id'] == id);
          if (i != -1) _comidas[i] = updated;
          final j = _filtered.indexWhere((c) => c['id'] == id);
          if (j != -1) _filtered[j] = updated;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Comida actualizada correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al actualizar: ${response.statusCode}'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error de conexión al actualizar'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _agregarComida() async {
    final nombreCtrl = TextEditingController();
    final caloriasCtrl = TextEditingController();
    final proteinasCtrl = TextEditingController();
    final carbosCtrl = TextEditingController();
    final grasasCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final guardado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Nueva comida',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DialogField(
                    ctrl: nombreCtrl,
                    label: 'Nombre',
                    icon: Icons.lunch_dining_rounded),
                const SizedBox(height: 12),
                _DialogField(
                    ctrl: caloriasCtrl,
                    label: 'Calorías',
                    icon: Icons.local_fire_department_rounded,
                    isNumber: true),
                const SizedBox(height: 12),
                _DialogField(
                    ctrl: proteinasCtrl,
                    label: 'Proteínas (g)',
                    icon: Icons.fitness_center_rounded,
                    isNumber: true),
                const SizedBox(height: 12),
                _DialogField(
                    ctrl: carbosCtrl,
                    label: 'Carbohidratos (g)',
                    icon: Icons.grain_rounded,
                    isNumber: true),
                const SizedBox(height: 12),
                _DialogField(
                    ctrl: grasasCtrl,
                    label: 'Grasas (g)',
                    icon: Icons.opacity_rounded,
                    isNumber: true),
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
              backgroundColor: _kPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );

    if (guardado != true) return;

    try {
      final token = await AuthService.getToken();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/comidas/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'nombre': nombreCtrl.text.trim(),
          'calorias': int.tryParse(caloriasCtrl.text) ?? 0,
          'proteinas': double.tryParse(proteinasCtrl.text) ?? 0.0,
          'carbohidratos': double.tryParse(carbosCtrl.text) ?? 0.0,
          'grasas': double.tryParse(grasasCtrl.text) ?? 0.0,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final nueva = jsonDecode(response.body);
        setState(() {
          _comidas.add(nueva);
          _filtered.add(nueva);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Comida agregada correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al agregar: ${response.statusCode}'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error de conexión al agregar'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // ── Información del plan nutricional ───────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plan de Alimentación',
                  style: GoogleFonts.bebasNeue(
                    fontSize: 28,
                    color: const Color(0xFF1A1A2E),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.local_fire_department_rounded, color: _kRed, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Control calórico diario',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
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
              decoration: InputDecoration(
                hintText: 'Buscar comida...',
                hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, color: _kPurple),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: Colors.grey, size: 18),
                        onPressed: () => _searchCtrl.clear(),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
                  borderSide: const BorderSide(color: _kPurple, width: 1.5),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Lista de comidas ───────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _kPurple))
                : _error != null
                    ? _ErrorState(message: _error!, onRetry: _fetchComidas)
                    : _filtered.isEmpty
                        ? _EmptyState(isSearch: _searchCtrl.text.isNotEmpty)
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                            itemCount: _filtered.length,
                            itemBuilder: (context, index) {
                              final comida = _filtered[index];
                              final nombre = comida['nombre'] ?? '';
                              return _ComidaCard(
                                comida: comida,
                                index: index,
                                imageUrl: _getImageForFood(nombre),
                                onEditar: () => _editarComida(comida),
                                onEliminar: () {
                                  final id = comida['id'];
                                  if (id != null) {
                                    _eliminarComida(id);
                                  }
                                },
                              );
                            },
                          ),
          ),
        ],
      ),
      // ── Botón AGREGAR COMIDA ──────────────────────────────────────────────
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              const Color(0xFFF5F7FA).withOpacity(0.8),
            ],
          ),
        ),
        child: GestureDetector(
          onTap: _agregarComida,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_kPurple, _kPurple.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
              boxShadow: [
                BoxShadow(
                  color: _kPurple.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_circle_rounded, color: Colors.white, size: 24),
                const SizedBox(width: 10),
                Text(
                  'AGREGAR COMIDA',
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
      backgroundColor: _kPurple,
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
            'NUTRITION',
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

// ── Tarjeta de comida ──────────────────────────────────────────────────────────
class _ComidaCard extends StatelessWidget {
  final Map<String, dynamic> comida;
  final int index;
  final String imageUrl;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  const _ComidaCard({
    required this.comida,
    required this.index,
    required this.imageUrl,
    required this.onEditar,
    required this.onEliminar,
  });

  static const _kPurple = Color(0xFF9C27B0);

  @override
  Widget build(BuildContext context) {
    final nombre = (comida['nombre'] ?? 'Comida ${index + 1}').toString();
    final calorias = (comida['calorias'] ?? 0).toString();
    final proteinas = (comida['proteinas'] ?? 0).toDouble();
    final carbohidratos = (comida['carbohidratos'] ?? 0).toDouble();
    final grasas = (comida['grasas'] ?? 0).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // ── Imagen de la comida ────────────────────────────────────────
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
                    color: Colors.grey[200],
                    child: const Icon(Icons.lunch_dining, color: Colors.grey, size: 30),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: 70,
                    height: 70,
                    color: Colors.grey[200],
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _kPurple,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 14),
            // ── Información ────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // ── Macros ──────────────────────────────────────────────
                  Row(
                    children: [
                      _MacroChip(
                        label: 'P',
                        value: proteinas,
                        unit: 'g',
                        color: const Color(0xFF2196F3),
                      ),
                      const SizedBox(width: 8),
                      _MacroChip(
                        label: 'C',
                        value: carbohidratos,
                        unit: 'g',
                        color: const Color(0xFF43C6AC),
                      ),
                      const SizedBox(width: 8),
                      _MacroChip(
                        label: 'G',
                        value: grasas,
                        unit: 'g',
                        color: const Color(0xFFFF6B6B),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // ── Botones de acción ───────────────────────────────────
                  Row(
                    children: [
                      IconButton(
                        onPressed: onEditar,
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        color: Colors.grey[600],
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
                      const Spacer(),
                      // ── Calorías badge ─────────────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _kPurple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$calorias kcal',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _kPurple,
                          ),
                        ),
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
}

// ── Chip de macro ──────────────────────────────────────────────────────────────
class _MacroChip extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  final Color color;

  const _MacroChip({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '${value % 1 == 0 ? value.toInt() : value}$unit',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ── Campo del diálogo ──────────────────────────────────────────────────────────
class _DialogField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final bool isNumber;

  const _DialogField({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.isNumber = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _ComidaCard._kPurple, size: 20),
        filled: true,
        fillColor: const Color(0xFFF5F7FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _ComidaCard._kPurple, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      ),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
    );
  }
}

// ── Estado error ───────────────────────────────────────────────────────────────
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
            Icon(Icons.wifi_off_rounded, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text(
              'Algo salió mal',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E)),
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
                backgroundColor: _ComidaCard._kPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Estado vacío ───────────────────────────────────────────────────────────────
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
            isSearch
                ? Icons.search_off_rounded
                : Icons.lunch_dining_rounded,
            size: 56,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            isSearch ? 'Sin resultados' : 'No hay comidas',
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E)),
          ),
          const SizedBox(height: 6),
          Text(
            isSearch
                ? 'Intenta con otro término de búsqueda'
                : 'No se encontraron comidas disponibles',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}