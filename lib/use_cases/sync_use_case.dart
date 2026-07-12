import 'package:flutter/foundation.dart';
import '../../data/database_service.dart';
import '../../data/collections/daily_metric.dart';
import '../../data/collections/daily_score.dart';
import '../../data/collections/workout_session.dart';
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
    debugPrint('[SyncUseCase] Starting full sync ($daysBack days)...');

    try {
      final end = DateTime.now();
      final start = end.subtract(Duration(days: daysBack));

      final List<DailyMetric> allMetrics = [];
      final List<WorkoutSession> allWorkouts = [];

      DateTime current = start;
      while (!current.isAfter(end)) {
        try {
          final metric = await _healthRepo.fetchMetricsForDay(current);
          final workouts = await _healthRepo.fetchWorkoutsForDay(current);
          
          if (workouts.isNotEmpty) {
            metric.workoutSessionCount = workouts.length;
          }
          
          allMetrics.add(metric);
          allWorkouts.addAll(workouts);
        } catch (e) {
          debugPrint('[SyncUseCase] Error fetching ${current.toIso8601String()}: $e');
        }
        current = current.add(const Duration(days: 1));
      }

      // Log summary of what was fetched
      final daysWithSteps = allMetrics.where((m) => m.steps != null && m.steps! > 0).length;
      final daysWithSleep = allMetrics.where((m) => m.totalSleepMinutes != null && m.totalSleepMinutes! > 0).length;
      final daysWithHR = allMetrics.where((m) => m.averageHeartRate != null).length;
      debugPrint('[SyncUseCase] Fetched ${allMetrics.length} days: $daysWithSteps with steps, $daysWithSleep with sleep, $daysWithHR with HR, ${allWorkouts.length} workouts');

      await _db.upsertMetrics(allMetrics);
      await _db.upsertWorkoutSessions(allWorkouts);

      await _recalculateScores(allMetrics);

      final profile = await _db.getUserProfile();
      profile.lastSyncDate = DateTime.now();
      await _db.saveUserProfile(profile);

      return SyncResult(
        success: true,
        daysImported: allMetrics.length,
        workoutsImported: allWorkouts.length,
        completedAt: DateTime.now(),
      );
    } catch (e, stack) {
      debugPrint('[SyncUseCase] syncAll error: $e\n$stack');
      return SyncResult(
        success: false,
        error: e.toString(),
        completedAt: DateTime.now(),
      );
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

    for (final score in scores) {
      await _db.upsertScore(score);
    }
  }

  Future<void> syncToday() async {
    try {
      final today = DateTime.now();
      final metric = await _healthRepo.fetchMetricsForDay(today);
      final workouts = await _healthRepo.fetchWorkoutsForDay(today);
      
      if (workouts.isNotEmpty) metric.workoutSessionCount = workouts.length;

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
