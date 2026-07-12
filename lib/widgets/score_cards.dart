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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Text(title.toUpperCase(), style: Theme.of(context).textTheme.titleLarge?.copyWith(letterSpacing: 2, color: PulseTheme.secondary, fontSize: 16)),
          const SizedBox(height: 24),
          SizedBox(
            height: 280,
            width: 280,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background Track
                CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 24,
                  backgroundColor: Colors.transparent,
                  color: PulseTheme.surfaceLight.withOpacity(0.5),
                ),
                // Shadow for premium feel
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.15),
                        blurRadius: 40,
                        spreadRadius: 10,
                      )
                    ],
                  ),
                ),
                // Actual Progress
                CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 24,
                  backgroundColor: Colors.transparent,
                  color: color,
                  strokeCap: StrokeCap.round,
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        score.toInt().toString(),
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          color: Colors.white,
                          fontSize: 96,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                        ),
                      ),
                      Text(
                        ' / 100',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: PulseTheme.secondary,
                          fontWeight: FontWeight.w600,
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
              padding: const EdgeInsets.only(top: 24),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  message!,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
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
