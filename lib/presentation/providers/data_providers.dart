import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'providers.dart';
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

  // Update Android Home Widget
  try {
    await HomeWidget.saveWidgetData<String>(
        'recovery_score', score.recoveryScore?.toInt().toString() ?? '--');
    await HomeWidget.saveWidgetData<String>(
        'strain_score', score.strainScore?.toInt().toString() ?? '--');
    await HomeWidget.saveWidgetData<String>(
        'sleep_score', score.sleepScore?.toInt().toString() ?? '--');
    await HomeWidget.updateWidget(name: 'PulseWidgetProvider');
    await HomeWidget.updateWidget(name: 'PulseLargeWidgetProvider');
    await HomeWidget.updateWidget(name: 'PulseSmallWidgetProvider');
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
