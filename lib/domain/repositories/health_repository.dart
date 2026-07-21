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

  /// Fetches ALL [WorkoutSession] records between [start] and [end] in a
  /// single Health Connect call. This avoids the day-by-day loop which can
  /// hit rate limits and miss edge-case workouts.
  Future<List<WorkoutSession>> fetchWorkoutsInRange(DateTime start, DateTime end);

  /// Fetches ALL [DailyMetric] records between [start] and [end] in bulk.
  /// This eliminates the day-by-day Health Connect query loop that causes
  /// API call quota exceeded errors on Android Health Connect.
  Future<List<DailyMetric>> fetchMetricsInRange(DateTime start, DateTime end);
}

