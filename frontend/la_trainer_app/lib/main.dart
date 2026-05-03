import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/auth_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Oculta la barra de navegación inferior del sistema (botones de Android)
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mi App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F6EF7)),
        useMaterial3: true,
      ),
      home: const _SplashRouter(),
    );
  }
}

/// Pantalla de arranque: revisa si hay sesión activa y redirige
class _SplashRouter extends StatefulWidget {
  const _SplashRouter();

  @override
  State<_SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<_SplashRouter> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final token = await AuthService.getToken();

    if (!mounted) return;

    if (token == null || token.isEmpty) {
      _goTo(const LoginScreen());
      return;
    }

    // ── Registrar acceso diario (racha + calendario) ──────────────
    await AuthService.registrarAcceso();

    // Hay token → verificar si completó el onboarding
    final onboardingDone = await AuthService.isOnboardingDone();

    if (!mounted) return;

    if (onboardingDone) {
      _goTo(const HomeScreen());
    } else {
      _goTo(const OnboardingScreen());
    }
  }

  void _goTo(Widget screen) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Pantalla de carga mientras se verifica la sesión
    return const Scaffold(
      backgroundColor: Color(0xFF0d0d0d),
      body: Center(child: CircularProgressIndicator(color: Color(0xFFD72105))),
    );
  }
}
