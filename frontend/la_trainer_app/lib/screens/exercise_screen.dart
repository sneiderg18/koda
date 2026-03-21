import 'dart:convert';
import 'package:flutter/material.dart';
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

  static const _color = Color(0xFFFF9800);

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
              final desc =
                  (e['descripcion'] ?? '').toString().toLowerCase();
              final grupo =
                  (e['grupo_muscular'] ?? '').toString().toLowerCase();
              return nombre.contains(q) ||
                  desc.contains(q) ||
                  grupo.contains(q);
            }).toList();
    });
  }

  // ── FETCH ──────────────────────────────────────────────────────────────────
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
        final list = data is List
            ? data
            : (data['results'] ?? data['data'] ?? []) as List;
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
          _error =
              'Error ${response.statusCode}: No se pudo cargar los ejercicios.';
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

  // ── AGREGAR ────────────────────────────────────────────────────────────────
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

  // ── EDITAR ─────────────────────────────────────────────────────────────────
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

  // ── ELIMINAR ───────────────────────────────────────────────────────────────
  Future<void> _eliminarEjercicio(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar ejercicio',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
            '¿Estás seguro de que deseas eliminar este ejercicio?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                Text('Cancelar', style: TextStyle(color: Colors.grey[600])),
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

  // ── FORMULARIO (crear / editar) ────────────────────────────────────────────
  Future<Map<String, dynamic>?> _mostrarFormulario(
      {Map<String, dynamic>? ejercicio}) async {
    final nombreCtrl =
        TextEditingController(text: ejercicio?['nombre'] ?? '');
    final grupoCtrl =
        TextEditingController(text: ejercicio?['grupo_muscular'] ?? '');
    final descCtrl =
        TextEditingController(text: ejercicio?['descripcion'] ?? '');
    final formKey = GlobalKey<FormState>();
    final esEdicion = ejercicio != null;

    final guardado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                _DialogField(
                  ctrl: nombreCtrl,
                  label: 'Nombre',
                  icon: Icons.directions_run_rounded,
                  color: _color,
                ),
                const SizedBox(height: 12),
                _DialogField(
                  ctrl: grupoCtrl,
                  label: 'Grupo muscular',
                  icon: Icons.fitness_center_rounded,
                  color: _color,
                ),
                const SizedBox(height: 12),
                _DialogField(
                  ctrl: descCtrl,
                  label: 'Descripción',
                  icon: Icons.description_rounded,
                  color: _color,
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                Text('Cancelar', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
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
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Ejercicios',
          style: TextStyle(
              color: Color(0xFF1A1A2E), fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF4F6EF7)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _color),
            tooltip: 'Recargar',
            onPressed: _fetchEjercicios,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregarEjercicio,
        backgroundColor: _color,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Agregar ejercicio',
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
                hintText: 'Buscar ejercicio...',
                hintStyle:
                    TextStyle(color: Colors.grey[400], fontSize: 14),
                prefixIcon:
                    const Icon(Icons.search_rounded, color: _color),
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
                      const BorderSide(color: _color, width: 1.5),
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
                    '${_filtered.length} ejercicio${_filtered.length != 1 ? 's' : ''}',
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
                        color: _color, strokeWidth: 2.5))
                : _error != null
                    ? _ErrorState(
                        message: _error!, onRetry: _fetchEjercicios)
                    : _filtered.isEmpty
                        ? _EmptyState(
                            isSearch: _searchCtrl.text.isNotEmpty)
                        : ListView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(16, 4, 16, 100),
                            itemCount: _filtered.length,
                            itemBuilder: (context, index) =>
                                _EjercicioCard(
                              ejercicio: _filtered[index],
                              index: index,
                              onEditar: () =>
                                  _editarEjercicio(_filtered[index]),
                              onEliminar: () => _eliminarEjercicio(
                                  _filtered[index]['id']),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

// ── Tarjeta ────────────────────────────────────────────────────────────────────

class _EjercicioCard extends StatelessWidget {
  final Map<String, dynamic> ejercicio;
  final int index;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  const _EjercicioCard({
    required this.ejercicio,
    required this.index,
    required this.onEditar,
    required this.onEliminar,
  });

  static const _color = Color(0xFFFF9800);

  @override
  Widget build(BuildContext context) {
    final nombre = ejercicio['nombre'] ?? 'Ejercicio ${index + 1}';
    final descripcion = ejercicio['descripcion'] ?? '';
    final grupo = ejercicio['grupo_muscular'] ?? '';
    final id = ejercicio['id'] ?? ejercicio['pk'] ?? (index + 1);

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.directions_run_rounded,
                      color: _color, size: 24),
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
                      if (grupo.toString().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _color.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: _color.withOpacity(0.25)),
                          ),
                          child: Text(
                            grupo.toString(),
                            style: const TextStyle(
                              fontSize: 11,
                              color: _color,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            if (descripcion.toString().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                descripcion.toString(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13, color: Colors.grey[600], height: 1.5),
              ),
            ],

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // ── Botones ──────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEditar,
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    label: const Text('Actualizar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _color,
                      side: const BorderSide(color: _color),
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
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: color, size: 20),
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
          borderSide: BorderSide(color: color, width: 1.5),
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
                backgroundColor: const Color(0xFFFF9800),
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
                : Icons.fitness_center_rounded,
            size: 56,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            isSearch ? 'Sin resultados' : 'No hay ejercicios',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700]),
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