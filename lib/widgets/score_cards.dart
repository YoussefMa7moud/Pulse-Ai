import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'glass_container.dart';

class HeroScoreCard extends StatelessWidget {
  final String title;
  final double score; // 0-100
  final Color color;
  final String? message;

  const HeroScoreCard({
    super.key,
    required this.title,
    required this.score,
    required this.color,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = PulseTheme.isDark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.08),
            color.withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: color.withOpacity(0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              letterSpacing: 2.5,
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 190,
            width: 190,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Soft radial glow in the center
                Center(
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          color.withOpacity(0.12),
                          color.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                // Background Track
                CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 16,
                  backgroundColor: Colors.transparent,
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                ),
                // Actual Progress
                CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 16,
                  backgroundColor: Colors.transparent,
                  color: color,
                  strokeCap: StrokeCap.round,
                ),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        score.toInt().toString(),
                        style: TextStyle(
                          color: textColor,
                          fontSize: 54,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                      Text(
                        '%',
                        style: TextStyle(
                          color: color,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withOpacity(0.2), width: 1),
                ),
                child: Text(
                  message!.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SmallScoreCard extends StatelessWidget {
  final String title;
  final double score;
  final Color color;
  final String? description;

  const SmallScoreCard({
    super.key,
    required this.title,
    required this.score,
    required this.color,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          SizedBox(
            height: 80,
            width: 80,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 8,
                  backgroundColor: Colors.transparent,
                  color: PulseTheme.surfaceLight,
                ),
                CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 8,
                  backgroundColor: Colors.transparent,
                  color: color,
                  strokeCap: StrokeCap.round,
                ),
                Center(
                  child: Text(
                    score.toInt().toString(),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title.toUpperCase(), 
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 12, 
              letterSpacing: 1.2, 
              fontWeight: FontWeight.w600,
            ), 
            textAlign: TextAlign.center,
          ),
          if (description != null) ...[
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Text(
                  description!,
                  style: TextStyle(fontSize: 11, color: PulseTheme.secondary, height: 1.3),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class CompactScoreCard extends StatelessWidget {
  final String title;
  final double score;
  final Color color;

  const CompactScoreCard({
    super.key,
    required this.title,
    required this.score,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 52,
            width: 52,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 5,
                  backgroundColor: Colors.transparent,
                  color: PulseTheme.surfaceLight.withOpacity(0.3),
                ),
                CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 5,
                  backgroundColor: Colors.transparent,
                  color: color,
                  strokeCap: StrokeCap.round,
                ),
                Center(
                  child: Text(
                    score.toInt().toString(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
