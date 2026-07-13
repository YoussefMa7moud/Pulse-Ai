import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme.dart';

class StyledCard extends StatefulWidget {
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final BorderColorOpacity? borderStyle;

  const StyledCard({
    super.key,
    required this.child,
    required this.color,
    this.padding,
    this.borderRadius = 20,
    this.borderStyle,
  });

  @override
  State<StyledCard> createState() => _StyledCardState();
}

class _StyledCardState extends State<StyledCard> with TickerProviderStateMixin {
  late AnimationController _glowController;
  late AnimationController _aurasController;
  late Animation<double> _glowAnimation;
  late Animation<double> _auraAnimation;

  @override
  void initState() {
    super.initState();
    // Cyberpunk pulsing glow animation
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Animated Aura rotating gradient background animation
    _aurasController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _auraAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(_aurasController);
  }

  @override
  void dispose() {
    _glowController.dispose();
    _aurasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeTheme = PulseTheme.activeWidgetCardTheme;
    final isDark = PulseTheme.isDark;
    final baseBgColor = isDark ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.3);

    switch (activeTheme) {
      case WidgetCardTheme.cyberpunk:
        return AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return Container(
              padding: widget.padding ?? const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F0B18) : Colors.white,
                borderRadius: BorderRadius.circular(widget.borderRadius),
                border: Border.all(
                  color: widget.color.withOpacity(0.8),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.25 * _glowAnimation.value),
                    blurRadius: 12 * _glowAnimation.value,
                    spreadRadius: 1 * _glowAnimation.value,
                  ),
                ],
              ),
              child: widget.child,
            );
          },
        );

      case WidgetCardTheme.animatedAura:
        return ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: AnimatedBuilder(
            animation: _auraAnimation,
            builder: (context, child) {
              return Container(
                padding: widget.padding ?? const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  border: Border.all(
                    color: widget.color.withOpacity(0.25),
                    width: 1,
                  ),
                  gradient: LinearGradient(
                    colors: [
                      widget.color.withOpacity(0.12),
                      widget.color.withOpacity(0.01),
                      baseBgColor,
                    ],
                    begin: Alignment(
                      math.sin(_auraAnimation.value),
                      math.cos(_auraAnimation.value),
                    ),
                    end: Alignment(
                      -math.sin(_auraAnimation.value),
                      -math.cos(_auraAnimation.value),
                    ),
                  ),
                ),
                child: widget.child,
              );
            },
          ),
        );

      case WidgetCardTheme.minimalStark:
        final borderColor = isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.12);
        return Container(
          padding: widget.padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: borderColor,
              width: 1,
            ),
          ),
          child: widget.child,
        );

      case WidgetCardTheme.glassmorphism:
      default:
        // Frosted Glass
        return Container(
          padding: widget.padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
              width: 1,
            ),
          ),
          child: widget.child,
        );
    }
  }
}

class BorderColorOpacity {
  final Color color;
  final double opacity;
  const BorderColorOpacity(this.color, this.opacity);
}
