import 'package:flutter/material.dart';
import '../core/theme.dart';

class PulseLoadingIndicator extends StatefulWidget {
  final double size;
  final String? message;

  const PulseLoadingIndicator({
    super.key,
    this.size = 80.0,
    this.message,
  });

  @override
  State<PulseLoadingIndicator> createState() => _PulseLoadingIndicatorState();
}

class _PulseLoadingIndicatorState extends State<PulseLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: widget.size,
            height: widget.size,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  painter: _PulsePainter(
                    progress: _controller.value,
                    color: PulseTheme.accent,
                  ),
                  child: Center(
                    child: Container(
                      width: widget.size * 0.4,
                      height: widget.size * 0.4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: PulseTheme.accent,
                        boxShadow: [
                          BoxShadow(
                            color: PulseTheme.accent.withOpacity(0.5),
                            blurRadius: 15.0,
                            spreadRadius: 2.0,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.insights_rounded,
                        color: PulseTheme.background,
                        size: widget.size * 0.22,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (widget.message != null) ...[
            const SizedBox(height: 16),
            Text(
              widget.message!,
              style: TextStyle(
                color: PulseTheme.secondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  final double progress;
  final Color color;

  _PulsePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    final paint1 = Paint()
      ..color = color.withOpacity((1.0 - progress).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final radius1 = maxRadius * progress;
    canvas.drawCircle(center, radius1, paint1);

    // Second ripple offset by 0.5
    final progress2 = (progress + 0.5) % 1.0;
    final paint2 = Paint()
      ..color = color.withOpacity((1.0 - progress2).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final radius2 = maxRadius * progress2;
    canvas.drawCircle(center, radius2, paint2);
  }

  @override
  bool shouldRepaint(covariant _PulsePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
