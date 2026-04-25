import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/floating_coins.dart';
import 'signup_screen.dart';
import '../services/session.dart';
import '../services/pffm_api.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  final _emailFocus = FocusNode();
  final _passFocus = FocusNode();

  bool _obscure = true;
  bool _passFocused = false;
  bool _loading = false;

  Offset _cursor = Offset.zero;
  late final AnimationController _floatCtrl;

  @override
  void initState() {
    super.initState();

    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _passFocus.addListener(() {
      setState(() => _passFocused = _passFocus.hasFocus);
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    final pass = _passCtrl.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enter a valid email")));
      return;
    }

    if (pass.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enter your password")));
      return;
    }

    setState(() => _loading = true);

    try {
      // ✅ REAL CHECK: ask backend if this email exists in Firestore
      final user = await PffmApi.getUserByEmail(email);
      print("LOGIN USER RESPONSE: $user");

      // Save user locally
      await Session.saveUser(user);

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (_) => false);
    } catch (e) {
      if (!mounted) return;

      final msg = e.toString().toLowerCase();

      if (msg.contains('404') || msg.contains('email not found')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Email not found, please sign up")),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Login failed: $e")));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgBase = Color(0xFFFFC9DA);

    return Scaffold(
      backgroundColor: bgBase,
      body: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final h = c.maxHeight;

          final compact = h < 760;
          final maxContentW = (w * 0.92).clamp(340.0, 760.0);

          final topBannerH = (h * 0.15).clamp(compact ? 72.0 : 86.0, 110.0);
          final jarSize = (h * 0.30).clamp(compact ? 140.0 : 165.0, 230.0);

          final cardPad = compact ? 14.0 : 18.0;
          final fieldGap = compact ? 10.0 : 14.0;
          final sectionGap = compact ? 10.0 : 14.0;

          final titleSize = compact ? 26.0 : 30.0;
          final subSize = compact ? 13.5 : 15.0;

          final buttonH = compact ? 50.0 : 56.0;

          return MouseRegion(
            onHover: (e) => setState(() => _cursor = e.position),
            child: Stack(
              children: [
                const Positioned.fill(child: _LoginPinkGlow()),
                const Positioned.fill(child: FloatingCoins(count: 18)),
                const Positioned.fill(child: _SparkleBackground()),
                SafeArea(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxContentW),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _TopPill(
                                height: topBannerH,
                                titleSize: compact ? 26 : 30,
                                subtitleSize: compact ? 13 : 14,
                              ),
                              SizedBox(height: sectionGap),
                              _FloatingMascot(
                                size: jarSize,
                                floatCtrl: _floatCtrl,
                                passFocused: _passFocused,
                                cursorGlobal: _cursor,
                              ),
                              SizedBox(height: sectionGap),
                              _LoginCard(
                                padding: cardPad,
                                titleSize: titleSize,
                                subtitleSize: subSize,
                                fieldGap: fieldGap,
                                buttonH: buttonH,
                                emailCtrl: _emailCtrl,
                                passCtrl: _passCtrl,
                                emailFocus: _emailFocus,
                                passFocus: _passFocus,
                                obscure: _obscure,
                                loading: _loading,
                                onToggleObscure: () =>
                                    setState(() => _obscure = !_obscure),
                                onLogin: _handleLogin,
                                onSignUp: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const SignUpScreen(),
                                    ),
                                  );
                                },
                                showNotLooking: _passFocused,
                              ),
                              SizedBox(height: compact ? 8 : 12),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// ===== Pink background glow =====
class _LoginPinkGlow extends StatelessWidget {
  const _LoginPinkGlow();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.25),
          radius: 1.15,
          colors: [Color.fromRGBO(255, 255, 255, 0.92), Color(0xFFFFC9DA)],
        ),
      ),
    );
  }
}

/// ===== soft sparkles =====
class _SparkleBackground extends StatelessWidget {
  const _SparkleBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _SparklePainter());
  }
}

class _SparklePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color.fromRGBO(255, 255, 255, 0.35);
    final points = <Offset>[
      Offset(size.width * 0.10, size.height * 0.20),
      Offset(size.width * 0.86, size.height * 0.18),
      Offset(size.width * 0.20, size.height * 0.60),
      Offset(size.width * 0.82, size.height * 0.62),
      Offset(size.width * 0.52, size.height * 0.42),
    ];
    for (final c in points) {
      canvas.drawCircle(c, 2.0, p);
      canvas.drawLine(Offset(c.dx - 7, c.dy), Offset(c.dx + 7, c.dy), p);
      canvas.drawLine(Offset(c.dx, c.dy - 7), Offset(c.dx, c.dy + 7), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// ===== top pill =====
class _TopPill extends StatelessWidget {
  final double height;
  final double titleSize;
  final double subtitleSize;

  const _TopPill({
    required this.height,
    required this.titleSize,
    required this.subtitleSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 46, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFBFA7FF), Color(0xFF8F7BFF)],
        ),
        border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.30)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 30,
            offset: Offset(0, 16),
            color: Color.fromRGBO(124, 77, 255, 0.22),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Welcome back ✨",
              textAlign: TextAlign.center,
              style: GoogleFonts.baloo2(
                fontSize: titleSize,
                height: 1.0,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Log in and continue saving",
              textAlign: TextAlign.center,
              style: GoogleFonts.baloo2(
                fontSize: subtitleSize,
                fontWeight: FontWeight.w700,
                color: const Color.fromRGBO(255, 255, 255, 0.92),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ===== floating mascot =====
class _FloatingMascot extends StatelessWidget {
  final double size;
  final Animation<double> floatCtrl;
  final bool passFocused;
  final Offset cursorGlobal;

  const _FloatingMascot({
    required this.size,
    required this.floatCtrl,
    required this.passFocused,
    required this.cursorGlobal,
  });

  @override
  Widget build(BuildContext context) {
    final asset = passFocused
        ? 'assets/images/pfm_mascot_hide.png'
        : 'assets/images/pfm_mascot_base.png';

    return AnimatedBuilder(
      animation: floatCtrl,
      builder: (context, child) {
        final dy = (floatCtrl.value - 0.5) * 10;
        return Transform.translate(offset: Offset(0, dy), child: child);
      },
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: size * 0.88,
              height: size * 0.88,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color.fromRGBO(150, 110, 255, 0.30),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Image.asset(asset, fit: BoxFit.contain),
            if (!passFocused)
              Positioned.fill(
                child: IgnorePointer(
                  child: _PupilsOverlay(cursorGlobal: cursorGlobal),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PupilsOverlay extends StatelessWidget {
  final Offset cursorGlobal;
  const _PupilsOverlay({required this.cursorGlobal});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PupilPainter(cursorGlobal: cursorGlobal, context: context),
    );
  }
}

class _PupilPainter extends CustomPainter {
  final Offset cursorGlobal;
  final BuildContext context;

  _PupilPainter({required this.cursorGlobal, required this.context});

  @override
  void paint(Canvas canvas, Size size) {
    final box = context.findRenderObject();
    if (box is! RenderBox) return;

    final local = box.globalToLocal(cursorGlobal);

    // Put pupils exactly inside the eye whites
    final leftEyeCenter = Offset(size.width * 0.405, size.height * 0.335);
    final rightEyeCenter = Offset(size.width * 0.605, size.height * 0.335);

    // Bigger movement, but still stays inside the eyes
    Offset dir(Offset eye) {
      final v = local - eye;
      final len = v.distance;
      if (len < 0.001) return Offset.zero;
      final n = v / len;
      return n * (size.width * 0.016);
    }

    final left = leftEyeCenter + dir(leftEyeCenter);
    final right = rightEyeCenter + dir(rightEyeCenter);

    // Bigger pupils
    final pupilPaint = Paint()..color = const Color.fromRGBO(20, 20, 30, 0.95);

    final r = size.width * 0.032;

    canvas.drawCircle(left, r, pupilPaint);
    canvas.drawCircle(right, r, pupilPaint);

    // Small white shine
    final hiPaint = Paint()..color = const Color.fromRGBO(255, 255, 255, 0.85);

    canvas.drawCircle(left + Offset(-r * 0.30, -r * 0.30), r * 0.28, hiPaint);
    canvas.drawCircle(right + Offset(-r * 0.30, -r * 0.30), r * 0.28, hiPaint);
  }

  @override
  bool shouldRepaint(covariant _PupilPainter oldDelegate) {
    return oldDelegate.cursorGlobal != cursorGlobal;
  }
}

/// ===== login card =====
class _LoginCard extends StatelessWidget {
  final double padding;
  final double titleSize;
  final double subtitleSize;
  final double fieldGap;
  final double buttonH;

  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final FocusNode emailFocus;
  final FocusNode passFocus;

  final bool obscure;
  final bool loading;
  final VoidCallback onToggleObscure;
  final VoidCallback onLogin;
  final VoidCallback onSignUp;
  final bool showNotLooking;

  const _LoginCard({
    required this.padding,
    required this.titleSize,
    required this.subtitleSize,
    required this.fieldGap,
    required this.buttonH,
    required this.emailCtrl,
    required this.passCtrl,
    required this.emailFocus,
    required this.passFocus,
    required this.obscure,
    required this.loading,
    required this.onToggleObscure,
    required this.onLogin,
    required this.onSignUp,
    required this.showNotLooking,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFBFA7FF), Color(0xFF8F7BFF)],
        ),
        border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.35)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 35,
            offset: Offset(0, 18),
            color: Color.fromRGBO(120, 80, 255, 0.25),
          ),
        ],
      ),
      child: AutofillGroup(
        child: Column(
          children: [
            Text(
              "Login",
              style: GoogleFonts.baloo2(
                fontSize: titleSize,
                height: 1,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Login to continue saving smarter.",
              textAlign: TextAlign.center,
              style: GoogleFonts.baloo2(
                fontSize: subtitleSize,
                fontWeight: FontWeight.w700,
                color: const Color.fromRGBO(255, 255, 255, 0.92),
              ),
            ),
            SizedBox(height: fieldGap),
            _CuteField(
              label: "Email",
              hint: "name@example.com",
              controller: emailCtrl,
              focusNode: emailFocus,
              keyboardType: TextInputType.emailAddress,
              prefix: Icons.alternate_email,
              autofillHints: const [AutofillHints.username], // ✅ ADD
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => passFocus.requestFocus(),
            ),
            SizedBox(height: fieldGap),
            _CuteField(
              label: "Password",
              hint: "••••••••",
              controller: passCtrl,
              focusNode: passFocus,
              obscureText: obscure,
              prefix: Icons.lock_rounded,
              autofillHints: const [AutofillHints.password], // ✅ ADD
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onLogin(),
              suffix: IconButton(
                onPressed: onToggleObscure,
                icon: Icon(
                  obscure
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  color: const Color.fromRGBO(255, 255, 255, 0.9),
                ),
              ),
            ),
            SizedBox(height: fieldGap),
            SizedBox(
              width: double.infinity,
              height: buttonH,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFE06B), Color(0xFFFFC928)],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 18,
                      offset: Offset(0, 10),
                      color: Color.fromRGBO(0, 0, 0, 0.18),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: loading ? null : onLogin,
                  child: loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        )
                      : Text(
                          "Login",
                          style: GoogleFonts.baloo2(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF1E1E1E),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "New here? ",
                  style: GoogleFonts.baloo2(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color.fromRGBO(255, 255, 255, 0.92),
                  ),
                ),
                GestureDetector(
                  onTap: onSignUp,
                  child: Text(
                    "Create account",
                    style: GoogleFonts.baloo2(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFFFF3B0),
                      decoration: TextDecoration.underline,
                      decorationColor: const Color(0xFFFFF3B0),
                    ),
                  ),
                ),
              ],
            ),
            if (showNotLooking) ...[
              const SizedBox(height: 8),
              Text(
                "🙈 Don’t worry… I’m not looking!",
                style: GoogleFonts.baloo2(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: const Color.fromRGBO(255, 255, 255, 0.92),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// ===== Cute input field (UPDATED WITH AUTOFILL SUPPORT) =====
class _CuteField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final FocusNode focusNode;
  final TextInputType? keyboardType;
  final bool obscureText;
  final IconData prefix;
  final Widget? suffix;

  final List<String>? autofillHints; // ✅ NEW
  final TextInputAction? textInputAction; // ✅ NEW
  final ValueChanged<String>? onSubmitted; // ✅ NEW

  const _CuteField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.focusNode,
    this.keyboardType,
    this.obscureText = false,
    required this.prefix,
    this.suffix,
    this.autofillHints,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.baloo2(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: const Color.fromRGBO(255, 255, 255, 0.95),
          ),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          obscureText: obscureText,
          autofillHints: autofillHints, // ✅ NEW
          textInputAction: textInputAction, // ✅ NEW
          onSubmitted: onSubmitted, // ✅ NEW
          style: GoogleFonts.baloo2(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.baloo2(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: const Color.fromRGBO(255, 255, 255, 0.70),
            ),
            prefixIcon: Icon(
              prefix,
              color: const Color.fromRGBO(255, 255, 255, 0.92),
            ),
            suffixIcon: suffix,
            filled: true,
            fillColor: const Color.fromRGBO(255, 255, 255, 0.18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(
                color: Color.fromRGBO(255, 255, 255, 0.60),
                width: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
