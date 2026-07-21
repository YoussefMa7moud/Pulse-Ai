import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme.dart';
import '../../../widgets/animated_background.dart';
import '../../../widgets/glass_container.dart';
import '../../../widgets/staggered_animation.dart';
import '../../../widgets/pulse_loader.dart';
import '../../../utils/sync_helper.dart';
import '../../providers/data_providers.dart';
import '../../providers/providers.dart';
import '../../../use_cases/sync_use_case.dart';
import '../../../data/collections/workout_session.dart';

class ExerciseScreen extends ConsumerStatefulWidget {
  const ExerciseScreen({super.key});

  @override
  ConsumerState<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends ConsumerState<ExerciseScreen> {
  bool _isSyncing = false;
  bool _hasAutoSynced = false;

  @override
  void initState() {
    super.initState();
    // Auto-sync once after screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoSyncIfEmpty();
    });
  }

  /// Automatically triggers sync if there are no workouts in the DB.
  Future<void> _autoSyncIfEmpty() async {
    if (_hasAutoSynced || _isSyncing) return;
    _hasAutoSynced = true;
    try {
      final workouts = await ref.read(allWorkoutsProvider.future);
      if (workouts.isEmpty && mounted) {
        debugPrint('[ExerciseScreen] Auto-sync: no workouts in DB, triggering sync...');
        await _syncAndRefresh();
      }
    } catch (_) {
      // If provider fails, try sync anyway
      if (mounted) await _syncAndRefresh();
    }
  }

  Future<void> _syncAndRefresh({int daysBack = 30}) async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      final syncUseCase = ref.read(syncUseCaseProvider);
      final result = await syncUseCase.syncAll(daysBack: daysBack);
      ref.read(syncResultProvider.notifier).state = result;
    } catch (e) {
      ref.read(syncResultProvider.notifier).state = SyncResult(
        success: false,
        error: e.toString(),
        completedAt: DateTime.now(),
      );
    }
    if (!mounted) return;
    ref.invalidate(allWorkoutsProvider);
    setState(() => _isSyncing = false);
  }


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

  String _formatSportTitle(String? type) {
    if (type == null || type.isEmpty) return 'Exercise';
    return type.split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}').join(' ');
  }

  Map<String, List<WorkoutSession>> _groupWorkoutsByDate(List<WorkoutSession> workouts) {
    final groups = <String, List<WorkoutSession>>{};

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
        header = 'Today';
      } else if (wDayStr == yesterdayStr) {
        header = 'Yesterday';
      } else {
        header = DateFormat('EEEE, MMMM d').format(wTime);
      }

      groups.putIfAbsent(header, () => []).add(w);
    }

    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final workoutsAsync = ref.watch(allWorkoutsProvider);
    final textTheme = Theme.of(context).textTheme;
    final textColor = PulseTheme.isDark ? Colors.white : Colors.black87;
    final subColor = PulseTheme.isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Exercises',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: textColor,
          ),
        ),
        actions: [
          IconButton(
            icon: _isSyncing
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: PulseTheme.accent))
                : Icon(Icons.sync_rounded, color: PulseTheme.accent),
            onPressed: _isSyncing ? null : () async {
              await runWithSyncOverlay(context, _syncAndRefresh, message: 'Syncing workouts...');
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
            onRefresh: _syncAndRefresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [

                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  sliver: workoutsAsync.when(
                    data: (workouts) {
                      if (workouts.isEmpty && !_isSyncing) {
                        final syncResult = ref.watch(syncResultProvider);
                        String titleText = 'No Workouts Found';
                        IconData titleIcon = Icons.fitness_center_rounded;
                        Color statusColor = PulseTheme.accent;
                        String descriptionText = 'No exercise sessions were found in your Health Connect history for the last 30 days. Start a tracked session on your wearable app and sync again.';

                        if (syncResult != null) {
                          if (!syncResult.success) {
                            titleText = 'Sync Connection Error';
                            titleIcon = Icons.error_outline_rounded;
                            statusColor = PulseTheme.recoveryLow;
                            descriptionText = 'Connection failed: ${syncResult.error}. Please ensure Health Connect is installed, active, and permissions are granted for Exercise/Workouts.';
                          } else {
                            titleText = 'No Workouts in History';
                            titleIcon = Icons.info_outline_rounded;
                            descriptionText = 'Health Connect did not return any workouts for the last 30 days. Note: daily steps are fetched separately and do not register as individual workout sessions unless you explicitly track them in your companion app.';
                          }
                        }

                        return SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                              child: GlassContainer(
                                padding: const EdgeInsets.all(24),
                                borderColor: statusColor.withOpacity(0.15),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(titleIcon, size: 28, color: statusColor),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            titleText,
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
                                      descriptionText,
                                      style: TextStyle(color: subColor, fontSize: 13, height: 1.4),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      onPressed: _syncAndRefresh,
                                      icon: const Icon(Icons.sync_rounded),
                                      label: const Text('Sync Workouts'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: statusColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      if (workouts.isEmpty) {
                        return const SliverFillRemaining(
                          hasScrollBody: false,
                          child: PulseLoadingIndicator(message: 'Loading workouts...'),
                        );
                      }

                      final grouped = _groupWorkoutsByDate(workouts);
                      final flatList = <Object>[];
                      grouped.forEach((date, list) {
                        flatList.add(date);
                        flatList.addAll(list);
                      });

                      return SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = flatList[index];

                            if (item is String) {
                              return StaggeredFadeSlide(
                                index: index,
                                child: Padding(
                                  padding: EdgeInsets.only(top: index == 0 ? 8 : 24, bottom: 10, left: 4),
                                  child: Text(
                                    item,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              );
                            }

                            final w = item as WorkoutSession;
                            final icon = _getSportIcon(w.workoutType);
                            final sportTitle = _formatSportTitle(w.workoutType);
                            final formattedTime = w.startTime != null
                                ? DateFormat('h:mm a').format(w.startTime!)
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
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: PulseTheme.accent.withOpacity(0.15),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(icon, color: PulseTheme.accent, size: 26),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                sportTitle,
                                                style: TextStyle(
                                                  color: textColor,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                formattedTime,
                                                style: TextStyle(
                                                  color: PulseTheme.secondary,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Icon(Icons.timer_outlined, size: 15, color: PulseTheme.secondary),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    _formatDuration(w.durationSeconds),
                                                    style: TextStyle(
                                                      color: textColor,
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                  if (w.totalCaloriesKcal != null) ...[
                                                    const SizedBox(width: 16),
                                                    Icon(Icons.local_fire_department_outlined, size: 15, color: PulseTheme.secondary),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${w.totalCaloriesKcal!.toStringAsFixed(0)} kcal',
                                                      style: TextStyle(
                                                        color: textColor,
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
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
                      child: PulseLoadingIndicator(message: 'Loading workouts...'),
                    ),
                    error: (err, _) => SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Could not load exercises',
                                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$err',
                                style: const TextStyle(color: Colors.red, fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _syncAndRefresh,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
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
}
