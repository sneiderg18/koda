import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'progress_screen.dart';
import 'exercise_screen.dart';
import 'food_screen.dart';

const _kRed = Color(0xFFD72105);

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _handleMenuSelection(BuildContext context, String value) {
    if (value == 'profile') {
      _navigateTo(context, const ProfileScreen());
    } else if (value == 'logout') {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: _buildAppBar(context),
      body: SizedBox.expand(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            children: [
              const SizedBox(height: 5),
              _buildWelcomeText(),
              Expanded(child: _buildNavigationButtons(context)),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      centerTitle: true,
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_kRed, Color(0xFFD90B1C)],
          ),
        ),
      ),
      title: Text(
        'KODA',
        style: GoogleFonts.bebasNeue(
          fontSize: 28,
          color: Colors.white,
          letterSpacing: 3,
        ),
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.account_circle_rounded, color: Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          position: PopupMenuPosition.under,
          onSelected: (value) => _handleMenuSelection(context, value),
          itemBuilder: (_) => [
            _buildMenuItem(
              'profile',
              Icons.person_outline_rounded,
              'Perfil',
              _kRed,
            ),
            const PopupMenuDivider(),
            _buildMenuItem(
              'logout',
              Icons.logout_rounded,
              'Cerrar sesión',
              Colors.redAccent,
            ),
          ],
        ),
      ],
    );
  }

  PopupMenuItem<String> _buildMenuItem(
    String value,
    IconData icon,
    String text,
    Color color,
  ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Text(text, style: TextStyle(color: color)),
        ],
      ),
    );
  }

  Widget _buildWelcomeText() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF260101),
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: _kRed.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('👋', style: TextStyle(fontSize: 18)),
          SizedBox(width: 10),
          Text(
            'Bienvenido',
            style: TextStyle(fontSize: 18, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _NavAvatar(
          imagePath: 'assets/images/progreso.png',
          label: 'Progreso',
          onTap: () => _navigateTo(context, const ProgressScreen()),
        ),
        _NavAvatar(
          imagePath: 'assets/images/plan_ejercicio.png',
          label: 'Ejercicio',
          onTap: () => _navigateTo(context, const ExerciseScreen()),
        ),
        _NavAvatar(
          imagePath: 'assets/images/plan_alimentacion.png',
          label: 'Alimentación',
          onTap: () => _navigateTo(context, const FoodScreen()),
        ),
      ],
    );
  }
}

class _NavAvatar extends StatelessWidget {
  final String imagePath;
  final String label;
  final VoidCallback onTap;

  const _NavAvatar({
    required this.imagePath,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipOval(
            child: Container(
              width: 64,
              height: 64,
              color: Colors.white,
              child: Image.asset(
                imagePath,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.error_outline, size: 24),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
