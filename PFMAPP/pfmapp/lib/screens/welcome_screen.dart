import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import '../widgets/floating_coins.dart';
import 'login_screen.dart';
import 'package:pfmapp/services/session.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _shakeCtrl;
  late final AnimationController _shineCtrl;
  late VideoPlayerController _videoController;
  late final AnimationController _jarMoveCtrl;
  @override
  void initState() {
    super.initState();

    _shineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _videoController =
        VideoPlayerController.asset('assets/videos/pfmm1_intro.mp4')
          ..setLooping(true)
          ..setVolume(0)
          ..initialize().then((_) {
            if (!mounted) return;
            setState(() {});
            _videoController.play();
          });
  }

  @override
  void dispose() {
    _shineCtrl.dispose();
    _videoController.dispose();

    super.dispose();
  }

  void _shakeJar() => _shakeCtrl.forward(from: 0);

  @override
  Widget build(BuildContext context) {
    // MORE PINK (stronger)
    const bg = Color(0xFFF5C7D9);

    return Scaffold(
      backgroundColor: bg,
      extendBodyBehindAppBar: true,

      // ✅ AppBar ONLY for logout icon (no title)
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const SizedBox.shrink(), // no "Welcome"
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: "Logout",
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Session.clear();
              if (!context.mounted) return;

              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            },
          ),
        ],
      ),

      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;

            // responsive sizing (web + mobile)
            final maxContentW = (w * 0.92).clamp(340.0, 760.0);
            final topPillH = (w * 0.18).clamp(96.0, 132.0);
            final jarSize = (w * 0.42).clamp(220.0, 360.0);
            final bottomCardH = (w * 0.36).clamp(120.0, 190.0);
            final overlap = (jarSize * 0.42).clamp(90.0, 150.0);

            return Stack(
              children: [
                if (_videoController.value.isInitialized)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: _videoController.value.size.width,
                          height: _videoController.value.size.height,
                          child: VideoPlayer(_videoController),
                        ),
                      ),
                    ),
                  )
                else
                  const Positioned.fill(
                    child: ColoredBox(color: Color(0xFFF5C7D9)),
                  ),

                const Positioned.fill(child: FloatingCoins(count: 20)),

                Align(
                  alignment: Alignment.topCenter,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 0,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxContentW),
                      child: Stack(
                        alignment: Alignment.topCenter,
                        clipBehavior: Clip.none,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // TOP BOX (light purple + SHINE restored)
                              _TopBannerShiny(
                                height: topPillH,
                                shine: _shineCtrl,
                                title: "Start saving money now!",
                                subtitle:
                                    "Track the progress of your savings and build better habits.",
                              ),

                              const SizedBox(height: 340),

                              // BOTTOM BOX (light purple + SHINE restored)
                              _BottomCardFancy(
                                height: bottomCardH,
                                shine: _shineCtrl,
                                onGetStarted: () {
                                  _videoController.pause();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const LoginScreen(),
                                    ),
                                  );
                                },
                              ),

                              const SizedBox(height: 16),
                              Text(
                                "Smart saving • Better habits • Real progress ✨",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.baloo2(
                                  fontSize: 14,
                                  color: const Color.fromRGBO(30, 10, 40, 0.62),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// ===================== TOP BANNER (LIGHT PURPLE + SHINE) =====================

class _TopBannerShiny extends StatelessWidget {
  final double height;
  final Animation<double> shine;
  final String title;
  final String subtitle;

  const _TopBannerShiny({
    required this.height,
    required this.shine,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 46, vertical: 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          // LIGHT PURPLE
          colors: [Color(0xFFCFA8FF), Color(0xFF9C7CFF), Color(0xFFBDA2FF)],
        ),
        border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.35)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 42,
            offset: Offset(0, 22),
            color: Color.fromRGBO(72, 34, 170, 0.28),
          ),
        ],
      ),
      child: Stack(
        children: [
          // glossy shine sweep (RESTORED)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(34),
              child: AnimatedBuilder(
                animation: shine,
                builder: (context, _) {
                  final x = (shine.value * 2) - 1; // -1..1
                  return Transform.translate(
                    offset: Offset(x * 320, -6),
                    child: Opacity(
                      opacity: 0.30,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Color.fromRGBO(255, 255, 255, 0.95),
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

          // small glossy top highlight (like glass)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(34),
              child: Opacity(
                opacity: 0.42,
                child: Container(
                  height: 32,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.fromRGBO(255, 255, 255, 0.90),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          const Positioned(
            left: 14,
            top: 12,
            child: Icon(Icons.auto_awesome, color: Color(0xFFFFF1FF), size: 18),
          ),
          const Positioned(
            right: 14,
            top: 12,
            child: Icon(Icons.auto_awesome, color: Color(0xFFFFF1FF), size: 18),
          ),

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ShimmerText(
                  text: "$title ✨",
                  controller: shine,
                  style: GoogleFonts.baloo2(
                    fontSize: 26,
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.baloo2(
                    fontSize: 14.2,
                    color: const Color.fromRGBO(255, 255, 255, 0.94),
                    fontWeight: FontWeight.w700,
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

/// ===================== BOTTOM CARD (LIGHT PURPLE + SHINE) =====================

class _BottomCardFancy extends StatelessWidget {
  final double height;
  final VoidCallback onGetStarted;
  final Animation<double> shine;

  const _BottomCardFancy({
    required this.height,
    required this.onGetStarted,
    required this.shine,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          // LIGHT PURPLE
          colors: [Color(0xFFCBB2FF), Color(0xFF9277FF), Color(0xFFBFA8FF)],
        ),
        boxShadow: const [
          BoxShadow(
            blurRadius: 44,
            offset: Offset(0, 22),
            color: Color.fromRGBO(70, 30, 160, 0.28),
          ),
        ],
        border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.25)),
      ),
      child: Stack(
        children: [
          // glossy shine sweep (RESTORED)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: AnimatedBuilder(
                animation: shine,
                builder: (context, _) {
                  final x = (shine.value * 2) - 1;
                  return Transform.translate(
                    offset: Offset(x * 340, 0),
                    child: Opacity(
                      opacity: 0.26,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Color.fromRGBO(255, 255, 255, 0.95),
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

          // top glossy highlight strip
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Opacity(
                opacity: 0.20,
                child: Container(
                  height: 34,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.fromRGBO(255, 255, 255, 0.88),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          const Positioned(
            left: 14,
            top: 10,
            child: Icon(Icons.auto_awesome, color: Color(0xFFFFF1FF), size: 18),
          ),
          const Positioned(
            right: 14,
            top: 10,
            child: Icon(Icons.auto_awesome, color: Color(0xFFFFF1FF), size: 18),
          ),
          Column(
            children: [
              Text(
                "PFM",
                style: GoogleFonts.baloo2(
                  fontSize: 34,
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Track the progress of your savings and start a habit with us",
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  fontSize: 15.5,
                  color: const Color.fromRGBO(255, 255, 255, 0.94),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),

              // big yellow button
              SizedBox(
                width: double.infinity,
                height: 58,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFE06B), Color(0xFFFFC928)],
                    ),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 22,
                        offset: Offset(0, 12),
                        color: Color.fromRGBO(0, 0, 0, 0.20),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                    ),
                    onPressed: onGetStarted,
                    child: Text(
                      "Let’s get started",
                      style: GoogleFonts.baloo2(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF1E1E1E),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ===================== BACKGROUND (MORE PINK) =====================

class _HotPinkGlow extends StatelessWidget {
  const _HotPinkGlow();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // base pink gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF3C2D5), Color(0xFFF5C7D9), Color(0xFFF1BDD2)],
            ),
          ),
        ),

        // extra pink blobs (glow)
        Positioned.fill(child: CustomPaint(painter: _PinkBlobPainter())),
      ],
    );
  }
}

class _PinkBlobPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Paint()
      ..color = const Color.fromRGBO(255, 120, 190, 0.20)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);

    final p2 = Paint()
      ..color = const Color.fromRGBO(255, 170, 220, 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 90);

    canvas.drawCircle(Offset(size.width * 0.20, size.height * 0.22), 220, p1);
    canvas.drawCircle(Offset(size.width * 0.82, size.height * 0.30), 260, p2);
    canvas.drawCircle(Offset(size.width * 0.55, size.height * 0.78), 280, p1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// ===================== SPARKLES =====================

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
    final p = Paint()..color = const Color.fromRGBO(255, 255, 255, 0.40);

    final points = <Offset>[
      Offset(size.width * 0.10, size.height * 0.18),
      Offset(size.width * 0.86, size.height * 0.14),
      Offset(size.width * 0.18, size.height * 0.58),
      Offset(size.width * 0.82, size.height * 0.60),
      Offset(size.width * 0.52, size.height * 0.40),
      Offset(size.width * 0.35, size.height * 0.82),
      Offset(size.width * 0.74, size.height * 0.82),
    ];

    for (final c in points) {
      canvas.drawCircle(c, 2.0, p);
      canvas.drawLine(Offset(c.dx - 8, c.dy), Offset(c.dx + 8, c.dy), p);
      canvas.drawLine(Offset(c.dx, c.dy - 8), Offset(c.dx, c.dy + 8), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// ===================== JAR GLOW (STRONGER SHADOW) =====================

class _JarGlowStronger extends StatelessWidget {
  const _JarGlowStronger();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // deeper purple shadow under jar
        Positioned.fill(
          child: Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    blurRadius: 52,
                    offset: Offset(0, 26),
                    spreadRadius: 6,
                    color: Color.fromRGBO(70, 30, 160, 0.30),
                  ),
                ],
              ),
            ),
          ),
        ),

        // purple glow bloom
        Positioned.fill(
          child: Center(
            child: Container(
              width: 300,
              height: 300,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color.fromRGBO(170, 120, 255, 0.55),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // inner white glow blur
        Positioned.fill(
          child: Center(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                width: 220,
                height: 220,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color.fromRGBO(255, 255, 255, 0.22),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _JarSparklePainter extends CustomPainter {
  final double progress;
  _JarSparklePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color.fromRGBO(255, 255, 255, 0.9);

    final centers = [
      Offset(size.width * 0.20, size.height * 0.27),
      Offset(size.width * 0.30, size.height * 0.16),
      Offset(size.width * 0.70, size.height * 0.18),
      Offset(size.width * 0.84, size.height * 0.40),
      Offset(size.width * 0.26, size.height * 0.75),
      Offset(size.width * 0.78, size.height * 0.74),
    ];

    for (int i = 0; i < centers.length; i++) {
      final wave = math.sin((progress * math.pi * 2) + i) * 0.5 + 0.5;
      final r = 2.0 + wave * 2.8;
      canvas.drawCircle(centers[i], r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _JarSparklePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// ===================== SHIMMER TEXT =====================

class _ShimmerText extends StatelessWidget {
  final String text;
  final Animation<double> controller;
  final TextStyle style;

  const _ShimmerText({
    required this.text,
    required this.controller,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        final start = (t * 2) - 1;

        return ShaderMask(
          shaderCallback: (rect) {
            return LinearGradient(
              begin: Alignment(start - 1, 0),
              end: Alignment(start + 1, 0),
              colors: const [
                Color.fromRGBO(255, 255, 255, 0.92),
                Color(0xFFFFF3B0),
                Color.fromRGBO(255, 255, 255, 0.92),
              ],
            ).createShader(rect);
          },
          blendMode: BlendMode.srcATop,
          child: Text(text, textAlign: TextAlign.center, style: style),
        );
      },
    );
  }
}
