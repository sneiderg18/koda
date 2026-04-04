import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/auth_service.dart';
import 'coach_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _kRed = Color(0xFFD72105);

  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _perfil;
  List<dynamic> _planes = [];
  Map<String, dynamic>? _progreso;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<Map<String, String>> get _headers async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      'ngrok-skip-browser-warning': 'true',
      'Authorization': 'Bearer $token',
    };
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final headers = await _headers;
      final results = await Future.wait([
        http.get(Uri.parse('${ApiConfig.baseUrl}/api/perfil/'),
            headers: headers),
        http.get(Uri.parse('${ApiConfig.baseUrl}/api/planes/entrenamiento/'),
            headers: headers),
        http.get(Uri.parse('${ApiConfig.baseUrl}/api/ia/progreso/'),
            headers: headers),
      ]);

      if (!mounted) return;

      final perfilRes = results[0];
      final planesRes = results[1];
      final progresoRes = results[2];

      setState(() {
        if (perfilRes.statusCode == 200) {
          _perfil = jsonDecode(perfilRes.body);
        }
        if (planesRes.statusCode == 200) {
          final body = jsonDecode(planesRes.body);
          _planes = body is List ? body : (body['results'] ?? []);
        }
        if (progresoRes.statusCode == 200) {
          _progreso = jsonDecode(progresoRes.body);
        }
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'No se pudo cargar la información.';
          _loading = false;
        });
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
        automaticallyImplyLeading: false,
        title: const Text(
          'Mi Dashboard',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _kRed),
            onPressed: _loadAll,
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded, color: _kRed),
            tooltip: 'Hablar con el coach',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CoachScreen()),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFEEEEEE), height: 1),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _kRed))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  color: _kRed,
                  onRefresh: _loadAll,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 24),
                    children: [
                      if (_perfil != null) _buildPerfilCard(),
                      const SizedBox(height: 20),
                      if (_progreso != null) _buildProgresoCard(),
                      const SizedBox(height: 20),
                      _buildPlanesSection(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 56, color: Colors.grey),
          const SizedBox(height: 12),
          Text(_error!,
              style: const TextStyle(color: Colors.grey, fontSize: 15)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadAll,
            style: ElevatedButton.styleFrom(
                backgroundColor: _kRed,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: const Text('Reintentar',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildPerfilCard() {
    final nombre = _perfil!['username'] ?? _perfil!['email'] ?? 'Usuario';
    final peso = _perfil!['peso'];
    final objetivo = _perfil!['objetivo'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD72105), Color(0xFFD90B1C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _kRed.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white24,
            child:
                Icon(Icons.person_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¡Hola, $nombre!',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18),
                ),
                if (objetivo != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Objetivo: $objetivo',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 13),
                    ),
                  ),
                if (peso != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Peso actual: ${peso}kg',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgresoCard() {
    final analisis = _progreso!['analisis'] ??
        _progreso!['analysis'] ??
        _progreso!['mensaje'] ??
        'Sin análisis disponible';

    return _SectionCard(
      title: 'Análisis de progreso',
      icon: Icons.insights_rounded,
      color: const Color(0xFF4F6EF7),
      child: Text(
        analisis.toString(),
        style: const TextStyle(
            color: Color(0xFF444444), fontSize: 14, height: 1.5),
      ),
    );
  }

  Widget _buildPlanesSection() {
    return _SectionCard(
      title: 'Planes de entrenamiento',
      icon: Icons.fitness_center_rounded,
      color: _kRed,
      child: _planes.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Aún no tienes planes generados. Habla con el coach para obtener uno.',
                style:
                    TextStyle(color: Colors.grey, fontSize: 14, height: 1.4),
              ),
            )
          : Column(
              children: _planes
                  .take(3)
                  .map((plan) => _PlanTile(plan: plan))
                  .toList(),
            ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF1A1A2E),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          child,
        ],
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  final Map<String, dynamic> plan;
  const _PlanTile({required this.plan});

  @override
  Widget build(BuildContext context) {
    final nombre = plan['nombre'] ?? plan['name'] ?? 'Plan';
    final desc =
        plan['descripcion'] ?? plan['description'] ?? '';
    final dias = plan['dias'] ?? plan['days'] ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFD72105).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.event_note_rounded,
                color: Color(0xFFD72105), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre.toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                if (desc.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      desc.toString(),
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (dias.toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Días: $dias',
                      style: const TextStyle(
                          color: Color(0xFFD72105), fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}