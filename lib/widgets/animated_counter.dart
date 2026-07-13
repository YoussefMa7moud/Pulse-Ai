import 'package:flutter/material.dart';

/// Animated counter that smoothly counts from 0 (or a start value) to the target value.
/// Used for metric displays like steps, calories, heart rate, etc.
class AnimatedCounter extends StatefulWidget {
  final double value;
  final double startValue;
  final Duration duration;
  final TextStyle? style;
  final String? suffix;
  final String? prefix;
  final int decimals;
  final Curve curve;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.startValue = 0,
    this.duration = const Duration(milliseconds: 1200),
    this.style,
    this.suffix,
    this.prefix,
    this.decimals = 0,
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _previousValue = 0;

  @override
  void initState() {
    super.initState();
    _previousValue = widget.startValue;
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = Tween<double>(
      begin: _previousValue,
      end: widget.value,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previousValue = oldWidget.value;
      _animation = Tween<double>(
        begin: _previousValue,
        end: widget.value,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: widget.curve,
      ));
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        String text = widget.decimals > 0
            ? _animation.value.toStringAsFixed(widget.decimals)
            : _animation.value.toInt().toString();
        if (widget.prefix != null) text = '${widget.prefix}$text';
        if (widget.suffix != null) text = '$text${widget.suffix}';
        return Text(text, style: widget.style);
      },
    );
  }
}

/// Animated progress ring that fills from 0 to the target value with a smooth animation.
class AnimatedProgressRing extends StatefulWidget {
  final double value; // 0.0 to 1.0
  final double size;
  final double strokeWidth;
  final Color color;
  final Color backgroundColor;
  final Duration duration;
  final Widget? child;

  const AnimatedProgressRing({
    super.key,
    required this.value,
    this.size = 48,
    this.strokeWidth = 3.5,
    required this.color,
    this.backgroundColor = const Color(0x15FFFFFF),
    this.duration = const Duration(milliseconds: 1500),
    this.child,
  });

  @override
  State<AnimatedProgressRing> createState() => _AnimatedProgressRingState();
}

class _AnimatedProgressRingState extends State<AnimatedProgressRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: widget.value.clamp(0.0, 1.0),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.value.clamp(0.0, 1.0),
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ));
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: CircularProgressIndicator(
                value: _animation.value,
                strokeWidth: widget.strokeWidth,
                backgroundColor: widget.backgroundColor,
                valueColor: AlwaysStoppedAnimation<Color>(widget.color),
                strokeCap: StrokeCap.round,
              ),
            ),
            if (widget.child != null) widget.child!,
          ],
        );
      },
    );
  }
}
