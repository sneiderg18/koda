import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'progress_screen.dart';
import 'training_plan_screen.dart';
import 'food_plan_screen.dart';

const _kRed = Color(0xFFD72105);
const _kRed2 = Color(0xFFD90B1C);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _username = 'Usuario';

  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    final name = await AuthService.getUsername();
    if (mounted) setState(() => _username = name);
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _handleMenuSelection(BuildContext context, String value) {
    if (value == 'profile') {
      _navigateTo(context, const ProfileScreen());
    } else if (value == 'logout') {
      AuthService.logout();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  void _openCoachChat() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      transitionAnimationController: AnimationController(
        vsync: Navigator.of(context),
        duration: const Duration(milliseconds: 380),
      ),
      builder: (_) => const _CoachChatModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          // ── Contenido principal ─────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                children: [
                  const SizedBox(height: 5),
                  _buildWelcomeText(),
                  Expanded(child: _buildNavigationButtons(context)),
                ],
              ),
            ),
          ),
          // ── Barra inferior — abre el chat IA ────────────────────────────
          _CoachBottomBar(onTap: _openCoachChat),
        ],
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
            colors: [_kRed, _kRed2],
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          position: PopupMenuPosition.under,
          onSelected: (value) => _handleMenuSelection(context, value),
          itemBuilder: (_) => [
            _buildMenuItem(
                'profile', Icons.person_outline_rounded, 'Perfil', _kRed),
            const PopupMenuDivider(),
            _buildMenuItem('logout', Icons.logout_rounded, 'Cerrar sesión',
                Colors.redAccent),
          ],
        ),
      ],
    );
  }

  PopupMenuItem<String> _buildMenuItem(
      String value, IconData icon, String text, Color color) {
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
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'Bienvenido, $_username',
              style: const TextStyle(fontSize: 17, color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
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
          onTap: () => _navigateTo(context, const TrainingPlanScreen()),
        ),
        _NavAvatar(
          imagePath: 'assets/images/plan_alimentacion.png',
          label: 'Alimentación',
          onTap: () => _navigateTo(context, const FoodPlanScreen()),
        ),
      ],
    );
  }
}

// ── Barra inferior — encabezado del chat IA ───────────────────────────────────
class _CoachBottomBar extends StatelessWidget {
  final VoidCallback onTap;
  const _CoachBottomBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
        ),
        // ✅ ia_chat.png se ajusta adecuadamente manteniendo la proporción
        child: Image.asset(
          'assets/images/ia_chat.png',
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.08,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

// ── Modal de chat con Coach KODA ──────────────────────────────────────────────
class _CoachChatModal extends StatefulWidget {
  const _CoachChatModal();

  @override
  State<_CoachChatModal> createState() => _CoachChatModalState();
}

class _CoachChatModalState extends State<_CoachChatModal> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _messages.add(const _ChatMessage(
      text:
          '¡Hola! Soy tu coach personal 💪 ¿En qué te puedo ayudar hoy?',
      isUser: false,
    ));
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _isSending = true;
    });
    _msgCtrl.clear();
    _scrollToBottom();

    try {
      final token = await AuthService.getToken();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/ia/coach/'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'mensaje': text}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data['respuesta'] ??
            data['message'] ??
            data['response'] ??
            'Sin respuesta';

        setState(() {
          _messages.add(_ChatMessage(text: reply.toString(), isUser: false));
          _isSending = false;
        });
        _scrollToBottom();
      } else {
        setState(() {
          _messages.add(const _ChatMessage(
            text: 'Ocurrió un error. Intenta de nuevo.',
            isUser: false,
          ));
          _isSending = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _messages.add(const _ChatMessage(
            text: 'Sin conexión. Verifica tu internet.',
            isUser: false,
          ));
          _isSending = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 1,
      minChildSize: 1,
      maxChildSize: 1,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF5F7FA),
            borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Column(
            children: [
              // Handle bar
              _buildHandle(),
              // Header
              _buildHeader(context),
              // Messages
              Expanded(
                child: ListView.builder(
                  controller: _scrollCtrl,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) => _BubbleTile(msg: _messages[i]),
                ),
              ),
              // Typing indicator
              if (_isSending)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      // ✅ Typing indicator con ia_icon_chat.png
                      Image.asset(
                        'assets/images/ia_icon_chat.png',
                        width: 28,
                        height: 28,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 10),
                      const _TypingIndicator(),
                    ],
                  ),
                ),
              // Input
              _buildInput(bottomInset),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFFDDDDDD),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF5F7FA),
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Row(
        children: [
          // ✅ Header con ia_icon_chat.png
          Image.asset(
            'assets/images/ia_icon_chat.png',
            width: 40,
            height: 40,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Coach KODA',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF1A1A2E))),
              Text('Siempre disponible para ti',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded,
                color: Colors.grey, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(double bottomInset) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _msgCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Escribe tu mensaje...',
                hintStyle:
                    const TextStyle(color: Colors.grey, fontSize: 14),
                filled: true,
                fillColor: const Color(0xFFF5F7FA),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: _isSending
                    ? null
                    : const LinearGradient(
                        colors: [_kRed, _kRed2],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                color: _isSending ? Colors.grey[300] : null,
                shape: BoxShape.circle,
                boxShadow: _isSending
                    ? []
                    : [
                        BoxShadow(
                            color: _kRed.withOpacity(0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3))
                      ],
              ),
              child: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Burbuja de mensaje ────────────────────────────────────────────────────────
class _ChatMessage {
  final String text;
  final bool isUser;
  const _ChatMessage({required this.text, required this.isUser});
}

class _BubbleTile extends StatelessWidget {
  final _ChatMessage msg;
  const _BubbleTile({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!msg.isUser) ...[
            // ✅ Ícono IA en burbuja con ia_icon_chat.png
            Image.asset(
              'assets/images/ia_icon_chat.png',
              width: 28,
              height: 28,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: msg.isUser
                    ? const LinearGradient(
                        colors: [_kRed, _kRed2],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight)
                    : null,
                color: msg.isUser ? null : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(msg.isUser ? 18 : 4),
                  bottomRight: Radius.circular(msg.isUser ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: msg.isUser
                        ? _kRed.withOpacity(0.25)
                        : Colors.black.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              // ✅ Soporte markdown negritas **texto**
              child: _buildRichText(msg.text, msg.isUser),
            ),
          ),
          if (msg.isUser) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 14,
              backgroundColor: Color(0xFFEEEEEE),
              child: Icon(Icons.person_rounded,
                  color: Color(0xFF666666), size: 14),
            ),
          ],
        ],
      ),
    );
  }

  // ✅ Convierte **texto** y *texto* en negritas reales
  Widget _buildRichText(String text, bool isUser) {
    final baseColor = isUser ? Colors.white : const Color(0xFF1A1A2E);
    final spans = <InlineSpan>[];
    final regex = RegExp(r'\*{1,2}(.+?)\*{1,2}');
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: TextStyle(color: baseColor, fontSize: 15, height: 1.4),
        ));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: TextStyle(
          color: baseColor,
          fontSize: 15,
          height: 1.4,
          fontWeight: FontWeight.bold,
        ),
      ));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: TextStyle(color: baseColor, fontSize: 15, height: 1.4),
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }
}

// ── Indicador de escritura animado ────────────────────────────────────────────
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              final offset = ((_ctrl.value * 3) - i).clamp(0.0, 1.0);
              final bounce = offset < 0.5 ? offset * 2 : (1 - offset) * 2;
              return Transform.translate(
                offset: Offset(0, -4 * bounce),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: _kRed,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

// ── NavAvatar ─────────────────────────────────────────────────────────────────
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
          Text(label,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}