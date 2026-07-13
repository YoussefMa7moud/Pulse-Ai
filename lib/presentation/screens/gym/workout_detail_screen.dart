import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme.dart';
import '../../../widgets/animated_background.dart';
import '../../../widgets/glass_container.dart';
import '../../../data/collections/workout_session.dart';

class WorkoutDetailScreen extends StatelessWidget {
  final WorkoutSession workout;

  const WorkoutDetailScreen({super.key, required this.workout});

  IconData _getSportIcon(String? type) {
    if (type == null) return Icons.sports_rounded;
    final t = type.toLowerCase();
    if (t.contains('run')) return Icons.directions_run_rounded;
    if (t.contains('walk')) return Icons.directions_walk_rounded;
    if (t.contains('cycl') || t.contains('bik')) return Icons.directions_bike_rounded;
    if (t.contains('swim')) return Icons.pool_rounded;
    if (t.contains('soccer') || t.contains('football')) return Icons.sports_soccer_rounded;
    if (t.contains('basket')) return Icons.sports_basketball_rounded;
    if (t.contains('tennis')) return Icons.sports_tennis_rounded;
    if (t.contains('strength') || t.contains('gym') || t.contains('lift') || t.contains('weight')) {
      return Icons.fitness_center_rounded;
    }
    return Icons.sports_rounded;
  }

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return '--';
    final hrs = seconds ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    if (hrs > 0) {
      return '${hrs}h ${mins}m';
    }
    return '${mins}m';
  }

  String _formatPace(double? minPerKm) {
    if (minPerKm == null || minPerKm <= 0) return '--';
    final mins = minPerKm.floor();
    final secs = ((minPerKm - mins) * 60).round();
    return '$mins:${secs.toString().padLeft(2, '0')} /km';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final textColor = PulseTheme.isDark ? Colors.white : Colors.black87;
    final subColor = PulseTheme.isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'WORKOUT SUMMARY',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: textColor,
          ),
        ),
      ),
      body: AnimatedGradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                // Header card
                GlassContainer(
                  padding: const EdgeInsets.all(24),
                  borderColor: PulseTheme.accent.withOpacity(0.2),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: PulseTheme.accent.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getSportIcon(workout.workoutType),
                          color: PulseTheme.accent,
                          size: 40,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              workout.workoutType?.toUpperCase() ?? 'TRACKED WORKOUT',
                              style: textTheme.headlineSmall?.copyWith(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              workout.startTime != null
                                  ? DateFormat('EEEE, MMMM d, yyyy').format(workout.startTime!)
                                  : '--',
                              style: TextStyle(color: subColor, fontSize: 14),
                            ),
                            Text(
                              workout.startTime != null
                                  ? DateFormat('hh:mm a').format(workout.startTime!)
                                  : '--',
                              style: TextStyle(color: subColor.withOpacity(0.8), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Stats Section Header
                Text(
                  'WORKOUT METRICS',
                  style: TextStyle(
                    letterSpacing: 2,
                    color: PulseTheme.secondary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Stats Grid
                GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.4,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  children: [
                    _buildStatTile(
                      'Duration',
                      _formatDuration(workout.durationSeconds),
                      Icons.timer_rounded,
                      PulseTheme.strainPrimary,
                      context,
                    ),
                    _buildStatTile(
                      'Calories',
                      workout.totalCaloriesKcal != null
                          ? '${workout.totalCaloriesKcal!.toStringAsFixed(0)} kcal'
                          : '--',
                      Icons.local_fire_department_rounded,
                      PulseTheme.recoveryLow,
                      context,
                    ),
                    _buildStatTile(
                      'Average HR',
                      workout.avgHeartRate != null
                          ? '${workout.avgHeartRate!.toStringAsFixed(0)} bpm'
                          : '--',
                      Icons.favorite_rounded,
                      PulseTheme.recoveryLow,
                      context,
                    ),
                    _buildStatTile(
                      'Max HR',
                      workout.maxHeartRate != null
                          ? '${workout.maxHeartRate!.toStringAsFixed(0)} bpm'
                          : '--',
                      Icons.trending_up_rounded,
                      PulseTheme.recoveryLow,
                      context,
                    ),
                    _buildStatTile(
                      'Distance',
                      workout.distanceMeters != null
                          ? '${(workout.distanceMeters! / 1000).toStringAsFixed(2)} km'
                          : '--',
                      Icons.map_rounded,
                      PulseTheme.accent,
                      context,
                    ),
                    _buildStatTile(
                      'Average Pace',
                      _formatPace(workout.avgPaceMinPerKm),
                      Icons.speed_rounded,
                      PulseTheme.strainPrimary,
                      context,
                    ),
                  ],
                ),
                if (workout.avgHeartRate != null) ...[
                  const SizedBox(height: 24),
                  Text(
                    'HEART RATE TIMELINE',
                    style: TextStyle(
                      letterSpacing: 2,
                      color: PulseTheme.secondary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GlassContainer(
                    padding: const EdgeInsets.only(right: 24, left: 12, top: 20, bottom: 12),
                    borderColor: PulseTheme.accent.withOpacity(0.1),
                    child: SizedBox(
                      height: 180,
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(show: false),
                          titlesData: FlTitlesData(
                            show: true,
                            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 32,
                                getTitlesWidget: (val, meta) {
                                  return Text(
                                    '${val.toInt()}',
                                    style: TextStyle(color: PulseTheme.secondary, fontSize: 10),
                                  );
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: [
                                FlSpot(0, (workout.minHeartRate ?? (workout.avgHeartRate! * 0.8)).clamp(50.0, 220.0)),
                                FlSpot(1, (workout.avgHeartRate! * 0.9).clamp(50.0, 220.0)),
                                FlSpot(2, (workout.avgHeartRate! * 1.05).clamp(50.0, 220.0)),
                                FlSpot(3, (workout.maxHeartRate ?? (workout.avgHeartRate! * 1.2)).clamp(50.0, 220.0)),
                                FlSpot(4, (workout.avgHeartRate! * 0.85).clamp(50.0, 220.0)),
                              ],
                              isCurved: true,
                              color: PulseTheme.recoveryLow,
                              barWidth: 3.5,
                              isStrokeCapRound: true,
                              dotData: FlDotData(show: true),
                              belowBarData: BarAreaData(
                                show: true,
                                color: PulseTheme.recoveryLow.withOpacity(0.08),
                              ),
                            ),
                          ],
                          minX: 0,
                          maxX: 4,
                          minY: (workout.minHeartRate ?? (workout.avgHeartRate! * 0.7)).clamp(40.0, 220.0) - 10,
                          maxY: (workout.maxHeartRate ?? (workout.avgHeartRate! * 1.3)).clamp(40.0, 220.0) + 10,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatTile(String label, String value, IconData icon, Color color, BuildContext context) {
    final textColor = PulseTheme.isDark ? Colors.white : Colors.black87;
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderColor: PulseTheme.accent.withOpacity(0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(color: PulseTheme.secondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
              Icon(icon, color: color, size: 18),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
