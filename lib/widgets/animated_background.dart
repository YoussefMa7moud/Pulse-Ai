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

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint1);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint2);
  }

  @override
  bool shouldRepaint(covariant _GradientPainter oldDelegate) => oldDelegate.progress != progress;
}
