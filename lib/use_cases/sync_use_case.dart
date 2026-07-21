import 'package:flutter/foundation.dart';
import '../../data/database_service.dart';
import '../../data/collections/daily_metric.dart';
import '../../data/collections/daily_score.dart';
import '../../data/collections/workout_session.dart';
import '../../data/collections/user_profile.dart';
import '../../scores/score_engine.dart';
import '../../domain/repositories/health_repository.dart';

class SyncResult {
  final bool success;
  final int daysImported;
  final int workoutsImported;
  final String? error;
  final DateTime completedAt;

  SyncResult({
    required this.success,
    this.daysImported = 0,
    this.workoutsImported = 0,
    this.error,
    required this.completedAt,
  });
}

class SyncUseCase {
  final HealthRepository _healthRepo;
  final DatabaseService _db;

  SyncUseCase(this._healthRepo, this._db);

  Future<SyncResult> syncAll({int daysBack = 30}) async {
    debugPrint('┌─────────────────────────────────────────────────────────────');
    debugPrint('│ [PIPELINE][SYNC] syncAll START — daysBack=$daysBack');
    debugPrint('└─────────────────────────────────────────────────────────────');

    try {
      final profile = await _db.getUserProfile();
      final end = DateTime.now();
      final start = end.subtract(Duration(days: daysBack));

      debugPrint('[PIPELINE][SYNC] Date range: $start → $end');

      // ── 1. Bulk-fetch ALL workouts in a single Health Connect call ──
      debugPrint('[PIPELINE][SYNC] Step 1: Fetching ALL workouts via fetchWorkoutsInRange...');
      final List<WorkoutSession> allWorkouts = await _healthRepo.fetchWorkoutsInRange(start, end);
      debugPrint('[PIPELINE][SYNC] Step 1 complete: ${allWorkouts.length} workouts fetched');

      // ── 2. Bulk-fetch daily metrics via range query (limit to max 30 days to prevent Health Connect IPC block)
      final metricStart = daysBack > 30 ? end.subtract(const Duration(days: 30)) : start;
      debugPrint('[PIPELINE][SYNC] Step 2: Bulk-fetching daily metrics from $metricStart to $end...');
      final List<DailyMetric> rawMetrics = await _healthRepo.fetchMetricsInRange(metricStart, end);


      final List<DailyMetric> allMetrics = [];
      for (final metric in rawMetrics) {
        final dayStr = "${metric.date.year}-${metric.date.month.toString().padLeft(2, '0')}-${metric.date.day.toString().padLeft(2, '0')}";
        final dayWorkouts = allWorkouts.where((w) {
          final wStr = "${w.date.year}-${w.date.month.toString().padLeft(2, '0')}-${w.date.day.toString().padLeft(2, '0')}";
          return wStr == dayStr;
        }).toList();

        if (dayWorkouts.isNotEmpty) {
          metric.workoutSessionCount = dayWorkouts.length;
        }

        _applyProfileToMetric(metric, profile);
        allMetrics.add(metric);
      }


      // Log summary of what was fetched
      final daysWithSteps = allMetrics.where((m) => m.steps != null && m.steps! > 0).length;
      final daysWithSleep = allMetrics.where((m) => m.totalSleepMinutes != null && m.totalSleepMinutes! > 0).length;
      final daysWithHR = allMetrics.where((m) => m.averageHeartRate != null).length;
      debugPrint('[PIPELINE][SYNC] Step 2 complete: ${allMetrics.length} days — '
          '$daysWithSteps with steps, $daysWithSleep with sleep, $daysWithHR with HR');

      // ── 3. Persist to Supabase ──
      debugPrint('[PIPELINE][SYNC] Step 3: Persisting ${allMetrics.length} metrics and ${allWorkouts.length} workouts to Supabase...');
      await _db.upsertMetrics(allMetrics);
      await _db.upsertWorkoutSessions(allWorkouts);

      // Verify workouts were actually written
      if (allWorkouts.isNotEmpty) {
        final verifyWorkouts = await _db.getAllWorkouts();
        debugPrint('[PIPELINE][SYNC] Step 3 VERIFY: ${verifyWorkouts.length} workouts now in DB (attempted to write ${allWorkouts.length})');
        if (verifyWorkouts.isEmpty) {
          debugPrint('[PIPELINE][SYNC] ⚠⚠⚠ CRITICAL: Workouts were fetched from Health Connect but NONE exist in DB after upsert!');
          debugPrint('[PIPELINE][SYNC] This likely means the Supabase workout_sessions table has issues.');
        }
      }
      debugPrint('[PIPELINE][SYNC] Step 3 complete: data persisted');

      // ── 4. Recalculate scores ──
      debugPrint('[PIPELINE][SYNC] Step 4: Recalculating scores...');
      await _recalculateScores(allMetrics);

      profile.lastSyncDate = DateTime.now();
      await _db.saveUserProfile(profile);

      debugPrint('┌─────────────────────────────────────────────────────────────');
      debugPrint('│ [PIPELINE][SYNC] syncAll COMPLETE');
      debugPrint('│ days=${allMetrics.length}, workouts=${allWorkouts.length}');
      debugPrint('└─────────────────────────────────────────────────────────────');

      return SyncResult(
        success: true,
        daysImported: allMetrics.length,
        workoutsImported: allWorkouts.length,
        completedAt: DateTime.now(),
      );
    } catch (e, stack) {
      debugPrint('[PIPELINE][SYNC] ❌ syncAll error: $e\n$stack');
      final errStr = e.toString();
      final isOfflineErr = errStr.contains('SocketException') ||
          errStr.contains('ClientException') ||
          errStr.contains('Failed host lookup') ||
          errStr.contains('NetworkImage') ||
          errStr.contains('Network');
      return SyncResult(
        success: false,
        error: isOfflineErr ? 'Offline mode active. Displaying cached data.' : e.toString(),
        completedAt: DateTime.now(),
      );
    }

  }


  void _applyProfileToMetric(DailyMetric metric, UserProfile profile) {
    if (metric.weightKg == null || metric.weightKg == 0.0) {
      metric.weightKg = profile.weightKg;
    }
    
    // BMR estimation using Harris-Benedict equation if missing or using old 75kg default (75 * 24 = 1800)
    if (metric.caloriesBurned == null || metric.caloriesBurned == 0.0 || metric.caloriesBurned == 1800.0) {
      final w = profile.weightKg ?? 75.0;
      final h = profile.heightCm ?? 175.0;
      final age = profile.age ?? 25;
      final gender = profile.gender ?? 'Male';
      
      double estimatedBmr;
      if (gender.toLowerCase() == 'female') {
        estimatedBmr = 447.593 + (9.247 * w) + (3.098 * h) - (4.330 * age);
      } else {
        estimatedBmr = 88.362 + (13.397 * w) + (4.799 * h) - (5.677 * age);
      }
      
      metric.caloriesBurned = estimatedBmr;
      metric.totalCalories = ((metric.activeCalories ?? 0.0) + estimatedBmr).toInt();
      debugPrint('[SyncUseCase] Applied Harris-Benedict BMR to metric for ${metric.date}: ${estimatedBmr.toStringAsFixed(1)} kcal (weight=$w, height=$h, age=$age, gender=$gender)');
    }
  }

  Future<void> _recalculateScores(List<DailyMetric> metrics) async {
    if (metrics.isEmpty) return;

    final sorted = [...metrics]..sort((a, b) => a.date.compareTo(b.date));
    final history = await _db.getRecentMetrics(days: 60);

    final List<DailyScore> scores = [];
    for (final metric in sorted) {
      final priorHistory = history.where((m) => m.date.isBefore(metric.date)).toList();
      final score = ScoreEngine.calculateScores(metric, priorHistory);
      scores.add(score);
    }

    await _db.upsertScores(scores);
  }

  Future<void> syncToday() async {
    try {
      final today = DateTime.now();
      final metric = await _healthRepo.fetchMetricsForDay(today);
      final workouts = await _healthRepo.fetchWorkoutsForDay(today);
      
      if (workouts.isNotEmpty) metric.workoutSessionCount = workouts.length;

      final profile = await _db.getUserProfile();
      _applyProfileToMetric(metric, profile);

      await _db.upsertMetric(metric);
      await _db.upsertWorkoutSessions(workouts);

      final history = await _db.getRecentMetrics(days: 30);
      final priorHistory = history.where((m) => m.date.isBefore(metric.date)).toList();
      final score = ScoreEngine.calculateScores(metric, priorHistory);
      
      await _db.upsertScore(score);
    } catch (e) {
      debugPrint('[SyncUseCase] syncToday error: $e');
    }
  }
}
