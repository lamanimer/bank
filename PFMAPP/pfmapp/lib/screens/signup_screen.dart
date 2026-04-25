import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/floating_coins.dart'; // same as welcome screen
import 'otp_screen.dart';
import '../services/pffm_api.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with TickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _obscurePass = true;
  bool _obscureConfirm = true;

  late final AnimationController _shineCtrl;

  @override
  void initState() {
    super.initState();
    _shineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _passCtrl.addListener(() => setState(() {}));
    _confirmCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _shineCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  // ===== Password strength =====
  // returns 0..3 (0 poor, 1 ok, 2 good, 3 strong)
  int _passwordScore(String p) {
    if (p.isEmpty) return 0;
    int score = 0;

    if (p.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(p)) score++;
    if (RegExp(r'[0-9]').hasMatch(p)) score++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>_\-\\/\[\]]').hasMatch(p)) score++;

    // cap at 3 levels for UI
    if (score <= 1) return 0; // poor
    if (score == 2) return 1; // ok
    if (score == 3) return 2; // good
    return 3; // strong
  }

  String _passwordLabel(int s) {
    switch (s) {
      case 0:
        return "weak password";
      case 1:
        return "Okay password";
      case 2:
        return "Good password";
      default:
        return "Strong password";
    }
  }

  Color _passwordColor(int s) {
    if (s == 0) return const Color(0xFFFF3B30); // red
    if (s == 1) return const Color(0xFFFFC928); // yellow-ish
    if (s == 2) return const Color(0xFF34C759); // green
    return const Color(0xFF2ECC71); // strong green
  }

  bool get _passwordsMatch =>
      _passCtrl.text.isNotEmpty && _passCtrl.text == _confirmCtrl.text;

  @override
  Widget build(BuildContext context) {
    const bgBase = Color(0xFFFFC9DA); // same pink base vibe

    return Scaffold(
      backgroundColor: bgBase,
      body: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final h = c.maxHeight;

          final maxContentW = (w * 0.92).clamp(340.0, 760.0);
          final compact = h < 760;

          final cardPad = (w * 0.04).clamp(
            compact ? 14.0 : 16.0,
            compact ? 18.0 : 22.0,
          );
          final topBannerH = (w * 0.18).clamp(92.0, 120.0);
          final sectionGap = compact ? 10.0 : 14.0;

          final titleSize = compact ? 26.0 : 30.0;
          final subSize = compact ? 13.0 : 14.0;
          final fieldGap = compact ? 10.0 : 14.0;
          final buttonH = compact ? 52.0 : 56.0;

          final score = _passwordScore(_passCtrl.text);

          return Stack(
            children: [
              const Positioned.fill(child: _SignUpPinkGlow()),
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
                              shine: _shineCtrl,
                              title: "Create account ✨",
                              subtitle: "Join PFM and start saving smarter.",
                              titleSize: titleSize,
                              subtitleSize: subSize,
                            ),

                            SizedBox(height: sectionGap),

                            _LightPurpleCard(
                              padding: cardPad,
                              child: Column(
                                children: [
                                  Text(
                                    "Sign Up",
                                    style: GoogleFonts.baloo2(
                                      fontSize: compact ? 28 : 32,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      height: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "Fill your details to receive an OTP.",
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.baloo2(
                                      fontSize: subSize,
                                      fontWeight: FontWeight.w700,
                                      color: const Color.fromRGBO(
                                        255,
                                        255,
                                        255,
                                        0.92,
                                      ),
                                    ),
                                  ),

                                  SizedBox(height: fieldGap),

                                  _CuteField(
                                    label: "Full name",
                                    hint: "Your name",
                                    controller: _nameCtrl,
                                    focusNode: _nameFocus,
                                    prefix: Icons.person_rounded,
                                  ),

                                  SizedBox(height: fieldGap),

                                  _CuteField(
                                    label: "Email",
                                    hint: "name@example.com",
                                    controller: _emailCtrl,
                                    focusNode: _emailFocus,
                                    keyboardType: TextInputType.emailAddress,
                                    prefix: Icons.alternate_email,
                                  ),

                                  SizedBox(height: fieldGap),

                                  _CuteField(
                                    label: "Password",
                                    hint: "••••••••",
                                    controller: _passCtrl,
                                    focusNode: _passFocus,
                                    obscureText: _obscurePass,
                                    prefix: Icons.lock_rounded,
                                    suffix: IconButton(
                                      onPressed: () => setState(
                                        () => _obscurePass = !_obscurePass,
                                      ),
                                      icon: Icon(
                                        _obscurePass
                                            ? Icons.visibility_rounded
                                            : Icons.visibility_off_rounded,
                                        color: const Color.fromRGBO(
                                          255,
                                          255,
                                          255,
                                          0.9,
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 8),

                                  // ✅ password strength (red when poor)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      _passwordLabel(score),
                                      style: GoogleFonts.baloo2(
                                        fontSize: compact ? 12.5 : 13.5,
                                        fontWeight: FontWeight.w900,
                                        color: _passwordColor(score),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 8),

                                  // little strength bar
                                  _StrengthBar(
                                    value: score / 3.0,
                                    color: _passwordColor(score),
                                  ),

                                  SizedBox(height: fieldGap),

                                  _CuteField(
                                    label: "Confirm password",
                                    hint: "••••••••",
                                    controller: _confirmCtrl,
                                    focusNode: _confirmFocus,
                                    obscureText: _obscureConfirm,
                                    prefix: Icons.lock_outline_rounded,
                                    suffix: IconButton(
                                      onPressed: () => setState(
                                        () =>
                                            _obscureConfirm = !_obscureConfirm,
                                      ),
                                      icon: Icon(
                                        _obscureConfirm
                                            ? Icons.visibility_rounded
                                            : Icons.visibility_off_rounded,
                                        color: const Color.fromRGBO(
                                          255,
                                          255,
                                          255,
                                          0.9,
                                        ),
                                      ),
                                    ),
                                  ),

                                  if (_confirmCtrl.text.isNotEmpty &&
                                      !_passwordsMatch) ...[
                                    const SizedBox(height: 6),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        "Passwords do not match",
                                        style: GoogleFonts.baloo2(
                                          fontSize: compact ? 12.5 : 13.5,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFFFF3B30),
                                        ),
                                      ),
                                    ),
                                  ],

                                  SizedBox(height: fieldGap),

                                  // ✅ Send OTP / Register button -> next page
                                  SizedBox(
                                    width: double.infinity,
                                    height: buttonH,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(18),
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFFFE06B),
                                            Color(0xFFFFC928),
                                          ],
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            blurRadius: 18,
                                            offset: Offset(0, 10),
                                            color: Color.fromRGBO(
                                              0,
                                              0,
                                              0,
                                              0.18,
                                            ),
                                          ),
                                        ],
                                      ),
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                          ),
                                        ),
                                        onPressed:
                                            (score == 0 || !_passwordsMatch)
                                            ? null
                                            : () async {
                                                final email = _emailCtrl.text
                                                    .trim();
                                                final name = _nameCtrl.text
                                                    .trim();

                                                try {
                                                  await PffmApi.requestOtp(
                                                    email: email,
                                                  );

                                                  if (!mounted) return;

                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) => OtpScreen(
                                                        email: email,
                                                        name: name,
                                                      ),
                                                    ),
                                                  );
                                                } catch (e) {
                                                  if (!mounted) return;
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        "OTP request failed: $e",
                                                      ),
                                                    ),
                                                  );
                                                }
                                              },
                                        child: Text(
                                          "Send OTP",
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

                                  // Back to login
                                  GestureDetector(
                                    onTap: () => Navigator.pop(context),
                                    child: Text(
                                      "Already have an account? Login",
                                      style: GoogleFonts.baloo2(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFFFFF3B0),
                                        decoration: TextDecoration.underline,
                                        decorationColor: const Color(
                                          0xFFFFF3B0,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ================= UI pieces (same theme) =================

class _SignUpPinkGlow extends StatelessWidget {
  const _SignUpPinkGlow();

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
      Offset(size.width * 0.12, size.height * 0.22),
      Offset(size.width * 0.85, size.height * 0.20),
      Offset(size.width * 0.22, size.height * 0.60),
      Offset(size.width * 0.78, size.height * 0.66),
      Offset(size.width * 0.55, size.height * 0.42),
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

class _TopPill extends StatelessWidget {
  final double height;
  final Animation<double> shine;
  final String title;
  final String subtitle;
  final double titleSize;
  final double subtitleSize;

  const _TopPill({
    required this.height,
    required this.shine,
    required this.title,
    required this.subtitle,
    required this.titleSize,
    required this.subtitleSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFBFA7FF), Color(0xFF8F7BFF), Color(0xFFBFA7FF)],
        ),
        border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.30)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 30,
            offset: Offset(0, 16),
            color: Color.fromRGBO(124, 77, 255, 0.20),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(34),
              child: AnimatedBuilder(
                animation: shine,
                builder: (context, _) {
                  final x = (shine.value * 2) - 1;
                  return Transform.translate(
                    offset: Offset(x * 260, 0),
                    child: Opacity(
                      opacity: 0.18,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Color.fromRGBO(255, 255, 255, 0.85),
                              Colors.transparent,
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const Positioned(
            left: 12,
            top: 10,
            child: Icon(Icons.auto_awesome, color: Color(0xFFFFE6FF), size: 18),
          ),
          const Positioned(
            right: 12,
            top: 10,
            child: Icon(Icons.auto_awesome, color: Color(0xFFFFE6FF), size: 18),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.baloo2(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
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
        ],
      ),
    );
  }
}

class _LightPurpleCard extends StatelessWidget {
  final double padding;
  final Widget child;

  const _LightPurpleCard({required this.padding, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
      child: child,
    );
  }
}

class _StrengthBar extends StatelessWidget {
  final double value; // 0..1
  final Color color;

  const _StrengthBar({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 10,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: const Color.fromRGBO(255, 255, 255, 0.22),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

class _CuteField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final FocusNode focusNode;
  final TextInputType? keyboardType;
  final bool obscureText;
  final IconData prefix;
  final Widget? suffix;

  const _CuteField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.focusNode,
    this.keyboardType,
    this.obscureText = false,
    required this.prefix,
    this.suffix,
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

// ================= Next page (OTP) =================
