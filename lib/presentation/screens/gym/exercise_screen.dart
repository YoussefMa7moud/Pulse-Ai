import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme.dart';
import '../../../widgets/animated_background.dart';
import '../../../widgets/glass_container.dart';
import '../../../widgets/staggered_animation.dart';
import '../../providers/data_providers.dart';
import '../../providers/providers.dart';
import '../../../data/collections/workout_session.dart';

class ExerciseScreen extends ConsumerWidget {
  const ExerciseScreen({super.key});

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

  void _showWorkoutDetails(BuildContext context, WorkoutSession workout) {
    final textTheme = Theme.of(context).textTheme;
    final textColor = PulseTheme.isDark ? Colors.white : Colors.black87;
    final subColor = PulseTheme.isDark ? Colors.white70 : Colors.black54;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: GlassContainer(
            padding: const EdgeInsets.all(24),
            borderColor: PulseTheme.accent.withOpacity(0.2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Modal Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: PulseTheme.accent.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getSportIcon(workout.workoutType),
                        color: PulseTheme.accent,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            workout.workoutType?.toUpperCase() ?? 'TRACKED EXERCISE',
                            style: textTheme.titleLarge?.copyWith(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            workout.startTime != null
                                ? DateFormat('EEEE, MMMM d • hh:mm a').format(workout.startTime!)
                                : '--',
                            style: TextStyle(color: subColor, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: subColor),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 32, color: Colors.white10),

                // Grid of Stats
                GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 2.2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  children: [
                    _buildDetailTile(
                      'Duration',
                      _formatDuration(workout.durationSeconds),
                      Icons.timer_rounded,
                      PulseTheme.strainPrimary,
                    ),
                    _buildDetailTile(
                      'Calories Burned',
                      workout.totalCaloriesKcal != null
                          ? '${workout.totalCaloriesKcal!.toStringAsFixed(0)} kcal'
                          : '--',
                      Icons.local_fire_department_rounded,
                      PulseTheme.recoveryLow,
                    ),
                    _buildDetailTile(
                      'Average HR',
                      workout.avgHeartRate != null
                          ? '${workout.avgHeartRate!.toStringAsFixed(0)} bpm'
                          : '--',
                      Icons.favorite_rounded,
                      PulseTheme.recoveryHigh,
                    ),
                    _buildDetailTile(
                      'Peak HR',
                      workout.maxHeartRate != null
                          ? '${workout.maxHeartRate!.toStringAsFixed(0)} bpm'
                          : '--',
                      Icons.trending_up_rounded,
                      PulseTheme.recoveryLow,
                    ),
                    if (workout.distanceMeters != null && workout.distanceMeters! > 0) ...[
                      _buildDetailTile(
                        'Distance',
                        '${(workout.distanceMeters! / 1000).toStringAsFixed(2)} km',
                        Icons.map_rounded,
                        PulseTheme.accent,
                      ),
                      _buildDetailTile(
                        'Average Pace',
                        _formatPace(workout.avgPaceMinPerKm),
                        Icons.speed_rounded,
                        Colors.greenAccent,
                      ),
                    ],
                    if (workout.avgSpeedMps != null && workout.avgSpeedMps! > 0) ...[
                      _buildDetailTile(
                        'Avg Speed',
                        '${(workout.avgSpeedMps! * 3.6).toStringAsFixed(1)} km/h',
                        Icons.trending_up_rounded,
                        PulseTheme.accent,
                      ),
                    ],
                    if (workout.totalElevationGainMeters != null && workout.totalElevationGainMeters! > 0) ...[
                      _buildDetailTile(
                        'Elevation Gain',
                        '+${workout.totalElevationGainMeters!.toStringAsFixed(0)} m',
                        Icons.landscape_rounded,
                        Colors.tealAccent,
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailTile(String label, String value, IconData icon, Color color) {
    final titleColor = PulseTheme.isDark ? Colors.white : Colors.black87;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(color: PulseTheme.secondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(color: titleColor, fontSize: 15, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, List<WorkoutSession>> _groupWorkoutsByDate(List<WorkoutSession> workouts) {
    final groups = <String, List<WorkoutSession>>{};
    
    // Sort workouts by start time descending
    final sorted = List<WorkoutSession>.from(workouts)
      ..sort((a, b) {
        final aTime = a.startTime ?? a.date;
        final bTime = b.startTime ?? b.date;
        return bTime.compareTo(aTime);
      });

    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final yesterdayStr = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));

    for (var w in sorted) {
      final wTime = w.startTime ?? w.date;
      final wDayStr = DateFormat('yyyy-MM-dd').format(wTime);
      
      String header;
      if (wDayStr == todayStr) {
        header = 'TODAY';
      } else if (wDayStr == yesterdayStr) {
        header = 'YESTERDAY';
      } else {
        header = DateFormat('EEEE, MMMM d, yyyy').format(wTime).toUpperCase();
      }
      
      groups.putIfAbsent(header, () => []).add(w);
    }
    
    return groups;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutsAsync = ref.watch(recentWorkoutsProvider);
    final textTheme = Theme.of(context).textTheme;
    final textColor = PulseTheme.isDark ? Colors.white : Colors.black87;
    final subColor = PulseTheme.isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'EXERCISES',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: textColor,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.sync_rounded, color: PulseTheme.accent),
            onPressed: () async {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );
              try {
                final syncUseCase = ref.read(syncUseCaseProvider);
                await syncUseCase.syncAll(daysBack: 30);
              } catch (_) {}
              if (context.mounted) Navigator.pop(context);

              ref.invalidate(recentWorkoutsProvider);
              ref.invalidate(todayMetricsProvider);
              ref.invalidate(todayScoresProvider);
            },
          ),
          IconButton(
            icon: Icon(Icons.person_outline, color: PulseTheme.primary),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: AnimatedGradientBackground(
        child: SafeArea(
          child: RefreshIndicator(
            color: PulseTheme.primary,
            backgroundColor: PulseTheme.surfaceLight,
            onRefresh: () async {
              ref.invalidate(recentWorkoutsProvider);
            },
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  sliver: workoutsAsync.when(
                    data: (workouts) {
                      if (workouts.isEmpty) {
                        return SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                              child: GlassContainer(
                                padding: const EdgeInsets.all(24),
                                borderColor: PulseTheme.accent.withOpacity(0.15),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.link_rounded, size: 28, color: PulseTheme.accent),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'Connect Your Wearable Band',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: textColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 24, color: Colors.white10),
                                    Text(
                                      'To view workouts from your band (Huawei, Zepp, Garmin, Samsung), ensure they sync to Health Connect:',
                                      style: TextStyle(color: subColor, fontSize: 13, height: 1.4),
                                    ),
                                    const SizedBox(height: 16),
                                    _buildStepRow(
                                      '1',
                                      'Open your band\'s companion app (e.g. Huawei Health).',
                                      textColor,
                                    ),
                                    _buildStepRow(
                                      '2',
                                      'Go to Settings -> Privacy/Data Sharing -> Health Connect, and allow it to WRITE all metrics and workouts.',
                                      textColor,
                                    ),
                                    _buildStepRow(
                                      '3',
                                      'In Pulse AI, tap "Link Connect (Permissions)" on the Home screen, and grant READ permissions.',
                                      textColor,
                                    ),
                                    _buildStepRow(
                                      '4',
                                      'Tap "Sync Now" to retrieve your 14-day exercise history.',
                                      textColor,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      final grouped = _groupWorkoutsByDate(workouts);
                      final flatList = [];
                      grouped.forEach((date, list) {
                        flatList.add(date);
                        flatList.addAll(list);
                      });

                      return SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = flatList[index];

                            if (item is String) {
                              // Render Section Header
                              return StaggeredFadeSlide(
                                index: index,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 20, bottom: 8, left: 4),
                                  child: Text(
                                    item,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: PulseTheme.secondary,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ),
                              );
                            }

                            final w = item as WorkoutSession;
                            final icon = _getSportIcon(w.workoutType);
                            final formattedTime = w.startTime != null
                                ? DateFormat('hh:mm a').format(w.startTime!)
                                : '--';

                            return StaggeredFadeSlide(
                              index: index,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: GestureDetector(
                                  onTap: () => context.push('/workout_detail', extra: w),
                                  child: GlassContainer(
                                    padding: const EdgeInsets.all(16),
                                    borderColor: PulseTheme.accent.withOpacity(0.15),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: PulseTheme.accent.withOpacity(0.15),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(icon, color: PulseTheme.accent, size: 24),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                w.workoutType?.toUpperCase() ?? 'EXERCISE',
                                                style: TextStyle(
                                                  color: textColor,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                formattedTime,
                                                style: TextStyle(
                                                  color: PulseTheme.secondary,
                                                  fontSize: 11,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Icon(Icons.timer_outlined, size: 14, color: PulseTheme.secondary),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    _formatDuration(w.durationSeconds),
                                                    style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w600),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  Icon(Icons.local_fire_department_outlined, size: 14, color: PulseTheme.secondary),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    w.totalCaloriesKcal != null
                                                        ? '${w.totalCaloriesKcal!.toStringAsFixed(0)} kcal'
                                                        : '--',
                                                    style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w600),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(Icons.chevron_right_rounded, color: PulseTheme.secondary),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                          childCount: flatList.length,
                        ),
                      );
                    },
                    loading: () => const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (err, _) => SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          'Error loading exercises: $err',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepRow(String stepNumber, String text, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: PulseTheme.accent.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Text(
              stepNumber,
              style: TextStyle(
                color: PulseTheme.accent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: textColor.withOpacity(0.85),
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
