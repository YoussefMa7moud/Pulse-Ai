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

  bool _isSyncing = false;

  SyncUseCase(this._healthRepo, this._db);

  /// Performs a full historical sync (defaults to 14 days).
  /// Past data is stored permanently in Supabase.
  Future<SyncResult> syncAll({int daysBack = 14}) async {
    if (_isSyncing) {
      debugPrint('[PIPELINE][SYNC] syncAll skipped: another sync is already in progress');
      return SyncResult(
        success: true,
        daysImported: 0,
        workoutsImported: 0,
        completedAt: DateTime.now(),
      );
    }

    _isSyncing = true;
    debugPrint('┌─────────────────────────────────────────────────────────────');
    debugPrint('│ [PIPELINE][SYNC] syncAll START — daysBack=$daysBack');
    debugPrint('└─────────────────────────────────────────────────────────────');

    try {
      final profile = await _db.getUserProfile();
      final end = DateTime.now();
      final start = end.subtract(Duration(days: daysBack));

      debugPrint('[PIPELINE][SYNC] Date range: $start → $end');

      // 1. Bulk-fetch ALL workouts in range
      final List<WorkoutSession> allWorkouts = await _healthRepo.fetchWorkoutsInRange(start, end);
      debugPrint('[PIPELINE][SYNC] Step 1: ${allWorkouts.length} workouts fetched');

      // 2. Bulk-fetch daily metrics via range query
      final List<DailyMetric> rawMetrics = await _healthRepo.fetchMetricsInRange(start, end);

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

      // 3. Persist to Supabase
      debugPrint('[PIPELINE][SYNC] Step 3: Persisting ${allMetrics.length} metrics and ${allWorkouts.length} workouts to Supabase...');
      await _db.upsertMetrics(allMetrics);
      await _db.upsertWorkoutSessions(allWorkouts);

      // 4. Recalculate scores
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
    } finally {
      _isSyncing = false;
    }
  }

  /// Fast incremental sync for recent days (defaults to today + yesterday).
  /// Used for routine app launch, app resume, and daily updates.
  Future<SyncResult> syncRecent({int daysBack = 2}) async {
    return await syncAll(daysBack: daysBack);
  }

  Future<void> syncToday() async {
    await syncRecent(daysBack: 2);
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
      await Future.delayed(Duration.zero);
    }

    await _db.upsertScores(scores);
  }
}
