import 'dart:math';
import 'package:flutter/material.dart';

class FloatingCoins extends StatefulWidget {
  final int count;
  const FloatingCoins({super.key, this.count = 16});

  @override
  State<FloatingCoins> createState() => _FloatingCoinsState();
}

class _FloatingCoinsState extends State<FloatingCoins>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final _rnd = Random(7);
  late final List<_CoinSpec> _coins;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _coins = List.generate(widget.count, (i) {
      final size = 14.0 + _rnd.nextInt(26); // 14..39
      final dx = _rnd.nextDouble();
      final dy = _rnd.nextDouble();
      final drift = 18 + _rnd.nextInt(30);
      final speed = 0.5 + _rnd.nextDouble() * 1.2;
      final phase = _rnd.nextDouble() * 2 * pi;
      final opacity = 0.10 + _rnd.nextDouble() * 0.18;
      final spin = _rnd.nextDouble() * 2 * pi;
      return _CoinSpec(
        size: size,
        dx: dx,
        dy: dy,
        drift: drift.toDouble(),
        speed: speed,
        phase: phase,
        opacity: opacity,
        spin: spin,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final h = c.maxHeight;

          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;

              return Stack(
                children: _coins.map((coin) {
                  final floatY =
                      sin((t * 2 * pi * coin.speed) + coin.phase) * 26;
                  final floatX =
                      cos((t * 2 * pi * coin.speed) + coin.phase) * coin.drift;

                  final left = (coin.dx * w) + floatX;
                  final top = (coin.dy * h) + floatY;

                  // subtle rotation
                  final angle = coin.spin + (t * 2 * pi * 0.15);

                  return Positioned(
                    left: left.clamp(0, w - coin.size),
                    top: top.clamp(0, h - coin.size),
                    child: Opacity(
                      opacity: coin.opacity,
                      child: Transform.rotate(
                        angle: angle,
                        child: _RealCoin(size: coin.size),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          );
        },
      ),
    );
  }
}

class _RealCoin extends StatelessWidget {
  final double size;
  const _RealCoin({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: Offset(0, 7),
            color: Color(0x24000000),
          ),
        ],
      ),
      child: CustomPaint(painter: _CoinPainter()),
    );
  }
}

class _CoinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final r = s.width / 2;
    final c = Offset(r, r);

    // Outer rim
    final rimPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFE08A), Color(0xFFFFB300), Color(0xFFFFD54F)],
      ).createShader(Rect.fromCircle(center: c, radius: r));

    canvas.drawCircle(c, r, rimPaint);

    // Inner face
    final facePaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.3, -0.35),
        radius: 1.0,
        colors: [Color(0xFFFFF3C1), Color(0xFFFFC107), Color(0xFFFFB300)],
      ).createShader(Rect.fromCircle(center: c, radius: r * 0.82));

    canvas.drawCircle(c, r * 0.82, facePaint);

    // Rim line
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.08
      ..color = const Color(0x66A46A00);

    canvas.drawCircle(c, r * 0.9, stroke);

    // Shine highlight
    final shine = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0x90FFFFFF), Color(0x00FFFFFF)],
      ).createShader(Rect.fromLTWH(0, 0, s.width, s.height));

    canvas.drawCircle(Offset(r * 0.65, r * 0.45), r * 0.55, shine);

    // Small “$” symbol (optional cute detail)
    final tp = TextPainter(
      text: const TextSpan(
        text: "\$",
        style: TextStyle(color: Color(0xAA7A4B00), fontWeight: FontWeight.w900),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(r - tp.width / 2, r - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CoinSpec {
  final double size, dx, dy, drift, speed, phase, opacity, spin;

  const _CoinSpec({
    required this.size,
    required this.dx,
    required this.dy,
    required this.drift,
    required this.speed,
    required this.phase,
    required this.opacity,
    required this.spin,
  });
}
