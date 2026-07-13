import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'providers.dart';
import '../../core/theme.dart';
import '../../utils/widget_theme_sync.dart';
import '../../data/database_service.dart';
import '../../data/collections/daily_metric.dart';
import '../../data/collections/daily_score.dart';
import '../../data/collections/workout_session.dart';
import '../../data/collections/gym_models.dart';
import '../../use_cases/sync_use_case.dart';
import '../../scores/score_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DATE NAVIGATION
// ─────────────────────────────────────────────────────────────────────────────

/// Currently selected date — drives the health data shown on Home and Health screens.
final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

// ─────────────────────────────────────────────────────────────────────────────
// TODAY'S METRICS  (reads from Supabase — populated by SyncService)
// ─────────────────────────────────────────────────────────────────────────────

/// Returns the DailyMetric for the selected date.
/// The metric is read from Supabase.
/// Falls back to an empty metric if no data is available yet.
final todayMetricsProvider = FutureProvider<DailyMetric>((ref) async {
  final db = ref.watch(databaseProvider);
  final selectedDate = ref.watch(selectedDateProvider);
  return await db.getMetricForDay(selectedDate) ??
      DailyMetric(
        date: DateTime.utc(selectedDate.year, selectedDate.month, selectedDate.day),
      );
});

// ─────────────────────────────────────────────────────────────────────────────
// HISTORY METRICS  (last 30 days for baseline + trends)
// ─────────────────────────────────────────────────────────────────────────────

/// Returns the last 30 days of DailyMetric records from Supabase.
/// Used by ScoreEngine for baseline calculations and by the AI for trend context.
final historyMetricsProvider = FutureProvider<List<DailyMetric>>((ref) async {
  final db = ref.watch(databaseProvider);
  return await db.getRecentMetrics(days: 30);
});

final historyScoresProvider = FutureProvider<List<DailyScore>>((ref) async {
  final db = ref.watch(databaseProvider);
  return await db.getRecentScores(days: 30);
});

// ─────────────────────────────────────────────────────────────────────────────
// WORKOUT SESSIONS
// ─────────────────────────────────────────────────────────────────────────────

/// Returns all workout sessions for the selected date.
final todayWorkoutsProvider = FutureProvider<List<WorkoutSession>>((ref) async {
  final db = ref.watch(databaseProvider);
  final selectedDate = ref.watch(selectedDateProvider);
  return await db.getWorkoutsForDay(selectedDate);
});

/// Returns recent workout sessions (last 14 days) — used by AI for training load context.
final recentWorkoutsProvider = FutureProvider<List<WorkoutSession>>((ref) async {
  final db = ref.watch(databaseProvider);
  return await db.getRecentWorkouts(days: 30);
});

/// Returns "Strength Training" sessions that haven't been linked to a GymRoutine yet.
final unlinkedStrengthWorkoutsProvider = FutureProvider<List<WorkoutSession>>((ref) async {
  final db = ref.watch(databaseProvider);
  
  // Get all strength training sessions from last 14 days
  final sessions = await db.getRecentWorkouts(days: 14);
  final strengthSessions = sessions
      .where((s) => s.workoutType != null && s.workoutType!.toLowerCase().contains('strength'))
      .toList();

  // Get all linked activity IDs from existing gym routines
  final routines = await db.getRecentRoutines();
  final linkedIds = routines.map((r) => r.linkedActivityId).whereType<String>().toSet();

  // Filter out the ones that are already linked
  return strengthSessions.where((session) => session.activityId != null && !linkedIds.contains(session.activityId)).toList();
});

// ─────────────────────────────────────────────────────────────────────────────
// TODAY'S SCORES
// ─────────────────────────────────────────────────────────────────────────────

/// Calculates, stores, and returns DailyScore for the selected date.
/// Uses ScoreEngine which now consumes all health data fields.
final todayScoresProvider = FutureProvider<DailyScore>((ref) async {
  final todayMetric = await ref.watch(todayMetricsProvider.future);
  final history = await ref.watch(historyMetricsProvider.future);

  final score = ScoreEngine.calculateScores(todayMetric, history);

  // Persist score to Supabase
  final db = ref.read(databaseProvider);
  await db.upsertScore(score);
  await db.upsertMetric(todayMetric);

  // Update Android Home Widgets (8 Premium widgets)
  try {
    final themeSettings = ref.read(themeSettingsProvider);
    await syncWidgetThemeToAndroid(themeSettings);

    // Scores
    await HomeWidget.saveWidgetData<String>('recovery_score', score.recoveryScore?.toInt().toString() ?? '--');
    await HomeWidget.saveWidgetData<String>('strain_score', score.strainScore?.toInt().toString() ?? '--');
    await HomeWidget.saveWidgetData<String>('sleep_score', score.sleepScore?.toInt().toString() ?? '--');
    await HomeWidget.saveWidgetData<String>('readiness_score', score.readinessScore?.toInt().toString() ?? '--');
    await HomeWidget.saveWidgetData<String>('energy_score', score.energyScore?.toInt().toString() ?? '--');
    await HomeWidget.saveWidgetData<String>('stress_score', score.stressBalanceScore?.toInt().toString() ?? '--');

    // Metrics from today's data
    await HomeWidget.saveWidgetData<String>('steps', todayMetric.steps?.toString() ?? '0');
    await HomeWidget.saveWidgetData<String>('calories', todayMetric.activeCalories?.toInt().toString() ?? '0');
    await HomeWidget.saveWidgetData<String>('rhr', todayMetric.restingHeartRate?.toInt().toString() ?? '--');
    await HomeWidget.saveWidgetData<String>('sleep_hours', ((todayMetric.totalSleepMinutes ?? 0) / 60.0).toStringAsFixed(1));
    await HomeWidget.saveWidgetData<String>('active_min', todayMetric.activeMinutes?.toString() ?? '0');
    await HomeWidget.saveWidgetData<String>('hrv', todayMetric.hrv?.toInt().toString() ?? '--');
    await HomeWidget.saveWidgetData<String>('spo2', todayMetric.bloodOxygenSpO2?.toInt().toString() ?? '--');
    await HomeWidget.saveWidgetData<String>('distance_km', ((todayMetric.distanceMeters ?? 0.0) / 1000.0).toStringAsFixed(1));

    // Notify each widget provider to update
    await HomeWidget.updateWidget(name: 'PulseRecoveryWidgetProvider');
    await HomeWidget.updateWidget(name: 'PulseSleepWidgetProvider');
    await HomeWidget.updateWidget(name: 'PulseStrainWidgetProvider');
    await HomeWidget.updateWidget(name: 'PulseReadinessWidgetProvider');
    await HomeWidget.updateWidget(name: 'PulseStressWidgetProvider');
    await HomeWidget.updateWidget(name: 'PulseStepsWidgetProvider');
    await HomeWidget.updateWidget(name: 'PulseHeartWidgetProvider');
    await HomeWidget.updateWidget(name: 'PulseOverviewWidgetProvider');
  } catch (e) {
    // Widget update failure is non-fatal
  }

  return score;
});

// ─────────────────────────────────────────────────────────────────────────────
// SYNC STATUS
// ─────────────────────────────────────────────────────────────────────────────

/// Holds the result of the most recent sync operation.
final syncResultProvider = StateProvider<SyncResult?>((ref) => null);

/// Trigger a full sync on demand — typically called from ProfileScreen.
final forceSyncProvider = FutureProvider<SyncResult>((ref) async {
  final syncUseCase = ref.read(syncUseCaseProvider);
  final result = await syncUseCase.syncAll(daysBack: 30);

  if (result.success) {
    // Invalidate all data providers so screens refresh
    ref.invalidate(todayMetricsProvider);
    ref.invalidate(historyMetricsProvider);
    ref.invalidate(todayScoresProvider);
    ref.invalidate(todayWorkoutsProvider);
    ref.invalidate(recentWorkoutsProvider);
    ref.invalidate(unlinkedStrengthWorkoutsProvider);
  }

  return result;
});

/// Invalidates all health data providers so screens refresh after sync.
void invalidateAllDataProviders(WidgetRef ref) {
  ref.invalidate(todayMetricsProvider);
  ref.invalidate(historyMetricsProvider);
  ref.invalidate(todayScoresProvider);
  ref.invalidate(historyScoresProvider);
  ref.invalidate(todayWorkoutsProvider);
  ref.invalidate(recentWorkoutsProvider);
  ref.invalidate(unlinkedStrengthWorkoutsProvider);
  ref.invalidate(healthAuthStateProvider);
}
