import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'training_plan_screen.dart';
import 'nutrition_plan_screen.dart';
import 'progress_screen.dart';
import 'exercise_screen.dart';
import 'food_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Home',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle_rounded,
                color: Color(0xFF4F6EF7)),
            tooltip: 'Opciones',
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) {
              if (value == 'profile') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              } else if (value == 'logout') {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline_rounded,
                        color: Color(0xFF4F6EF7), size: 20),
                    SizedBox(width: 10),
                    Text('Perfil'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded,
                        color: Colors.redAccent, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Cerrar sesión',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView( // 👈 SOLUCIÓN AQUÍ
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Bienvenido 👋',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 48),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _NavAvatar(
                      icon: Icons.fitness_center_rounded,
                      label: 'Plan de Entrenamiento',
                      color: const Color(0xFF4F6EF7),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const TrainingPlanScreen()),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _NavAvatar(
                      icon: Icons.restaurant_menu_rounded,
                      label: 'Plan de Alimentación',
                      color: const Color(0xFF43C6AC),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const NutritionPlanScreen()),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _NavAvatar(
                      icon: Icons.show_chart_rounded,
                      label: 'Progreso',
                      color: const Color(0xFFFF6B6B),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ProgressScreen()),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _NavAvatar(
                      icon: Icons.directions_run_rounded,
                      label: 'Ejercicio',
                      color: const Color(0xFFFF9800),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ExerciseScreen()),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _NavAvatar(
                      icon: Icons.lunch_dining_rounded,
                      label: 'Alimentación',
                      color: const Color(0xFF9C27B0),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FoodScreen()),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavAvatar extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _NavAvatar({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: color.withOpacity(0.15),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(width: 16),
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}