import 'dart:convert';
import 'package:flutter/material.dart';
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

  // ── ELIMINAR ───────────────────────────────────────────────────────────────
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

  // ── ACTUALIZAR ─────────────────────────────────────────────────────────────
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
              backgroundColor: const Color(0xFF9C27B0),
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

  // ── AGREGAR ────────────────────────────────────────────────────────────────
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
              backgroundColor: const Color(0xFF9C27B0),
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Alimentación',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF4F6EF7)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF9C27B0)),
            tooltip: 'Recargar lista',
            onPressed: _fetchComidas,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregarComida,
        backgroundColor: const Color(0xFF9C27B0),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Agregar comida',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          // ── Barra de búsqueda ──────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar comida...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                prefixIcon:
                    const Icon(Icons.search_rounded, color: Color(0xFF9C27B0)),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded,
                            color: Colors.grey, size: 18),
                        onPressed: () => _searchCtrl.clear(),
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF5F7FA),
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
                  borderSide:
                      const BorderSide(color: Color(0xFF9C27B0), width: 1.5),
                ),
              ),
            ),
          ),

          // ── Contador ───────────────────────────────────────────────────
          if (!_loading && _error == null)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  Text(
                    '${_filtered.length} comida${_filtered.length != 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          // ── Lista / estados ────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF9C27B0),
                      strokeWidth: 2.5,
                    ),
                  )
                : _error != null
                    ? _ErrorState(
                        message: _error!,
                        onRetry: _fetchComidas,
                      )
                    : _filtered.isEmpty
                        ? _EmptyState(isSearch: _searchCtrl.text.isNotEmpty)
                        : ListView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: _filtered.length,
                            itemBuilder: (context, index) => _ComidaCard(
                              comida: _filtered[index],
                              index: index,
                              onEditar: () =>
                                  _editarComida(_filtered[index]),
                              onEliminar: () =>
                                  _eliminarComida(_filtered[index]['id']),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

// ── Tarjeta de comida ──────────────────────────────────────────────────────────

class _ComidaCard extends StatelessWidget {
  final Map<String, dynamic> comida;
  final int index;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  const _ComidaCard({
    required this.comida,
    required this.index,
    required this.onEditar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final nombre = comida['nombre'] ?? 'Comida ${index + 1}';
    final calorias = comida['calorias'] ?? 0;
    final proteinas = (comida['proteinas'] ?? 0).toDouble();
    final carbohidratos = (comida['carbohidratos'] ?? 0).toDouble();
    final grasas = (comida['grasas'] ?? 0).toDouble();
    final id = comida['id'] ?? comida['pk'] ?? (index + 1);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Encabezado ───────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF9C27B0).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.lunch_dining_rounded,
                      color: Color(0xFF9C27B0), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#${id.toString().padLeft(3, '0')}',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[400],
                            letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        nombre.toString(),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                    ],
                  ),
                ),
                // Calorías badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9C27B0).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$calorias',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF9C27B0),
                        ),
                      ),
                      const Text('kcal',
                          style: TextStyle(
                              fontSize: 10, color: Color(0xFF9C27B0))),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // ── Macros ───────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _MacroChip(
                    label: 'Proteínas',
                    value: proteinas,
                    unit: 'g',
                    color: const Color(0xFF2196F3)),
                _MacroChip(
                    label: 'Carbos',
                    value: carbohidratos,
                    unit: 'g',
                    color: const Color(0xFF43C6AC)),
                _MacroChip(
                    label: 'Grasas',
                    value: grasas,
                    unit: 'g',
                    color: const Color(0xFFFF6B6B)),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // ── Botones Actualizar / Eliminar ─────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEditar,
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    label: const Text('Actualizar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF9C27B0),
                      side: const BorderSide(color: Color(0xFF9C27B0)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEliminar,
                    icon: const Icon(Icons.delete_rounded, size: 16),
                    label: const Text('Eliminar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ],
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
        prefixIcon: Icon(icon, color: const Color(0xFF9C27B0), size: 20),
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
          borderSide:
              const BorderSide(color: Color(0xFF9C27B0), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      ),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
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
    return Column(
      children: [
        Text(
          '${value % 1 == 0 ? value.toInt() : value}$unit',
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
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
            Text('Algo salió mal',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700])),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[500])),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9C27B0),
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
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700]),
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