import 'package:flutter/material.dart';
import 'dart:math';

import '../core/theme.dart';

class AnimatedGradientBackground extends StatefulWidget {
  final Widget child;

  const AnimatedGradientBackground({super.key, required this.child});

  @override
  State<AnimatedGradientBackground> createState() => _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState extends State<AnimatedGradientBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: PulseTheme.background),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Positioned.fill(
              child: CustomPaint(
                painter: _GradientPainter(_controller.value),
              ),
            );
          },
        ),
        // Floating particle overlay
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Positioned.fill(
              child: CustomPaint(
                painter: _ParticlePainter(_controller.value),
              ),
            );
          },
        ),
        widget.child,
      ],
    );
  }
}

class _GradientPainter extends CustomPainter {
  final double progress;

  _GradientPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    // Primary orbiting gradient
    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [
          PulseTheme.accent.withOpacity(0.15),
          Colors.transparent,
        ],
        radius: 0.8,
      ).createShader(Rect.fromCircle(
        center: Offset(
          size.width * (0.5 + 0.3 * cos(progress * 2 * pi)),
          size.height * (0.3 + 0.2 * sin(progress * 2 * pi)),
        ),
        radius: size.width * 0.8,
      ));

    // Secondary orbiting gradient
    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          PulseTheme.sleepPrimary.withOpacity(0.1),
          Colors.transparent,
        ],
        radius: 0.8,
      ).createShader(Rect.fromCircle(
        center: Offset(
          size.width * (0.5 - 0.3 * sin(progress * 2 * pi)),
          size.height * (0.7 + 0.2 * cos(progress * 2 * pi)),
        ),
        radius: size.width * 0.8,
      ));

    // Third gradient with different phase for more dynamism
    final paint3 = Paint()
      ..shader = RadialGradient(
        colors: [
          PulseTheme.recoveryHigh.withOpacity(0.06),
          Colors.transparent,
        ],
        radius: 0.6,
      ).createShader(Rect.fromCircle(
        center: Offset(
          size.width * (0.3 + 0.4 * sin(progress * 2 * pi * 0.7 + 1.5)),
          size.height * (0.5 + 0.3 * cos(progress * 2 * pi * 0.7 + 1.5)),
        ),
        radius: size.width * 0.6,
      ));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint1);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint2);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint3);
  }

  @override
  bool shouldRepaint(covariant _GradientPainter oldDelegate) => oldDelegate.progress != progress;
}

/// Subtle floating particles that drift slowly upward
class _ParticlePainter extends CustomPainter {
  final double progress;
  static final Random _rng = Random(42); // Fixed seed for consistent positions
  static final List<_Particle> _particles = List.generate(18, (i) {
    return _Particle(
      x: _rng.nextDouble(),
      y: _rng.nextDouble(),
      radius: 1.0 + _rng.nextDouble() * 2.0,
      speed: 0.02 + _rng.nextDouble() * 0.04,
      phase: _rng.nextDouble() * 2 * pi,
      opacity: 0.05 + _rng.nextDouble() * 0.12,
    );
  });

  _ParticlePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _particles) {
      // Slow upward drift + horizontal sway
      final y = (p.y - progress * p.speed * 5) % 1.0;
      final x = p.x + 0.02 * sin(progress * 2 * pi * 2 + p.phase);
      
      final paint = Paint()
        ..color = PulseTheme.accent.withOpacity(p.opacity * (0.5 + 0.5 * sin(progress * 2 * pi * 3 + p.phase)))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      
      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        p.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => oldDelegate.progress != progress;
}

class _Particle {
  final double x;
  final double y;
  final double radius;
  final double speed;
  final double phase;
  final double opacity;

  _Particle({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.phase,
    required this.opacity,
  });
}
