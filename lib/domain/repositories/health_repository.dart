import '../../data/collections/daily_metric.dart';
import '../../data/collections/workout_session.dart';

/// Abstract repository for fetching health data.
abstract class HealthRepository {
  /// Requests necessary permissions from the underlying health platform (e.g. Health Connect)
  Future<bool> requestPermissions();

  /// Returns true if the app already has the required health permissions.
  Future<bool> hasPermissions();

  /// Fetches an aggregated [DailyMetric] for a specific calendar day.
  Future<DailyMetric> fetchMetricsForDay(DateTime day);

  /// Fetches all discrete [WorkoutSession] records for a specific calendar day.
  Future<List<WorkoutSession>> fetchWorkoutsForDay(DateTime day);
}
