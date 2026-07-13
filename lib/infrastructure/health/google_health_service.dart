import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import '../../domain/repositories/health_repository.dart';
import '../../data/collections/daily_metric.dart';
import '../../data/collections/workout_session.dart';

class GoogleHealthService implements HealthRepository {
  final Health _health = Health();

  static const List<HealthDataType> _dataTypes = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.BASAL_ENERGY_BURNED,
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
    HealthDataType.SLEEP_SESSION,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
    HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
    HealthDataType.BODY_TEMPERATURE,
    HealthDataType.BODY_FAT_PERCENTAGE,
    HealthDataType.WEIGHT,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.WORKOUT,
  ];

  GoogleHealthService() {
    _health.configure();
  }

  @override
  Future<bool> hasPermissions() async {
    final permissions = _dataTypes.map((_) => HealthDataAccess.READ).toList();
    bool? hasPermissions = await _health.hasPermissions(_dataTypes, permissions: permissions);
    // Return true by default to let fetch attempt happen, as hasPermissions is flaky on Health Connect
    return hasPermissions ?? true;
  }

  @override
  Future<bool> requestPermissions() async {
    try {
      final permissions = _dataTypes.map((_) => HealthDataAccess.READ).toList();
      await Permission.activityRecognition.request();
      bool requested = await _health.requestAuthorization(_dataTypes, permissions: permissions);
      if (requested) {
        try {
          await _health.requestHealthDataHistoryAuthorization();
        } catch (_) {}
      }
      return requested;
    } catch (e) {
      debugPrint('[GoogleHealthService] Error requesting permissions: $e');
      return false;
    }
  }

  @override
  Future<DailyMetric> fetchMetricsForDay(DateTime day) async {
    final localStart = DateTime(day.year, day.month, day.day);
    final localEnd = localStart.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));

    final utcDate = DateTime.utc(day.year, day.month, day.day);
    final metric = DailyMetric(date: utcDate);

    final start = localStart;
    final end = localEnd;

    try {
      debugPrint('[GoogleHealth] Fetching day=${day.toIso8601String()}, local=$start→$end, utcKey=$utcDate');
      
      final List<HealthDataPoint> heartRates = [];
      final List<HealthDataPoint> restingHeartRates = [];
      final List<HealthDataPoint> hrvs = [];
      
      final List<HealthDataPoint> stepPoints = [];
      final List<HealthDataPoint> activeEnergyPoints = [];
      final List<HealthDataPoint> basalEnergyPoints = [];
      final List<HealthDataPoint> distancePoints = [];
      final List<HealthDataPoint> sleepPoints = [];
      final List<HealthDataPoint> workoutPoints = [];
      
      double bodyFat = 0.0;
      double weight = 0.0;
      double spo2 = 0.0;
      double temp = 0.0;

      for (final type in _dataTypes) {
        try {
          DateTime queryStart = start;
          if (type == HealthDataType.SLEEP_SESSION || 
              type == HealthDataType.SLEEP_ASLEEP || 
              type == HealthDataType.SLEEP_LIGHT ||
              type == HealthDataType.SLEEP_DEEP ||
              type == HealthDataType.SLEEP_REM) {
            queryStart = start.subtract(const Duration(hours: 12));
          }

          final rawData = await _health.getHealthDataFromTypes(
            types: [type], 
            startTime: queryStart, 
            endTime: end
          );
          final seen = <String>{};
          final List<HealthDataPoint> data = rawData.where((p) {
            final key = '${p.uuid}_${p.dateFrom.millisecondsSinceEpoch}_${p.dateTo.millisecondsSinceEpoch}';
            return seen.add(key);
          }).toList();

          debugPrint('[GoogleHealth] $type: ${data.length} points from $queryStart→$end');

          switch (type) {
            case HealthDataType.STEPS:
              stepPoints.addAll(data);
              break;
            case HealthDataType.ACTIVE_ENERGY_BURNED:
              activeEnergyPoints.addAll(data);
              break;
            case HealthDataType.BASAL_ENERGY_BURNED:
              basalEnergyPoints.addAll(data);
              break;
            case HealthDataType.DISTANCE_DELTA:
              distancePoints.addAll(data);
              break;
            case HealthDataType.HEART_RATE:
              heartRates.addAll(data);
              break;
            case HealthDataType.RESTING_HEART_RATE:
              restingHeartRates.addAll(data);
              break;
            case HealthDataType.HEART_RATE_VARIABILITY_RMSSD:
              hrvs.addAll(data);
              break;
            case HealthDataType.SLEEP_SESSION:
            case HealthDataType.SLEEP_ASLEEP:
            case HealthDataType.SLEEP_LIGHT:
            case HealthDataType.SLEEP_DEEP:
            case HealthDataType.SLEEP_REM:
              for (var p in data) {
                if (p.dateTo.isAfter(start)) {
                  sleepPoints.add(p);
                }
              }
              break;
            case HealthDataType.BODY_FAT_PERCENTAGE:
              if (data.isNotEmpty) {
                bodyFat = (data.last.value as NumericHealthValue).numericValue.toDouble();
              }
              break;
            case HealthDataType.WEIGHT:
              if (data.isNotEmpty) {
                weight = (data.last.value as NumericHealthValue).numericValue.toDouble();
              }
              break;
            case HealthDataType.BLOOD_OXYGEN:
              if (data.isNotEmpty) {
                spo2 = (data.last.value as NumericHealthValue).numericValue.toDouble();
              }
              break;
            case HealthDataType.BODY_TEMPERATURE:
              if (data.isNotEmpty) {
                temp = (data.last.value as NumericHealthValue).numericValue.toDouble();
              }
              break;
            case HealthDataType.WORKOUT:
              workoutPoints.addAll(data);
              break;
            default:
              break;
          }
        } catch (e) {
          debugPrint('[GoogleHealthService] Error fetching $type: $e');
        }
      }

      // Aggregate cumulative metrics with time-interval deduplication across ALL sources
      final double activeCalories = _aggregateCumulative(activeEnergyPoints);
      final double basalCalories = _aggregateCumulative(basalEnergyPoints);
      final int steps = _aggregateCumulative(stepPoints).toInt();
      final double distance = _aggregateCumulative(distancePoints);
      final int exerciseDurationMinutes = _aggregateExerciseDuration(workoutPoints);
      
      final sleepMap = _aggregateSleep(sleepPoints);

      metric.steps = steps;
      metric.distanceMeters = distance;
      metric.exerciseDurationMinutes = exerciseDurationMinutes;
      metric.activeMinutes = exerciseDurationMinutes + (steps ~/ 150);

      // Estimate Basal Metabolic Rate (BMR) if 0
      double finalBasal = basalCalories;
      if (finalBasal == 0.0) {
        final w = weight > 0 ? weight : (metric.weightKg ?? 75.0);
        finalBasal = w * 24.0;
        debugPrint('[GoogleHealth] Estimated basal calories: $finalBasal');
      }
      
      // Estimate Active Calories from steps if 0
      double finalActive = activeCalories;
      if (finalActive == 0.0 && steps > 0) {
        finalActive = steps * 0.04;
        debugPrint('[GoogleHealth] Estimated active calories from steps: $finalActive');
      }

      metric.activeCalories = finalActive;
      metric.caloriesBurned = finalBasal;
      metric.totalCalories = (finalActive + finalBasal).toInt();

      if (bodyFat > 0) metric.bodyFatPercent = bodyFat;
      if (weight > 0) metric.weightKg = weight;
      if (spo2 > 0) metric.bloodOxygenSpO2 = spo2;
      if (temp > 0) metric.bodyTemperature = temp;

      // Filter vitals by best source
      final filteredHeartRates = _filterByBestSource(heartRates);
      final filteredRestingHeartRates = _filterByBestSource(restingHeartRates);
      final filteredHrvs = _filterByBestSource(hrvs);

      debugPrint('[GoogleHealth] Filtered HR samples: ${filteredHeartRates.length}, restingHR: ${filteredRestingHeartRates.length}, HRV: ${filteredHrvs.length}');

      if (filteredHeartRates.isNotEmpty) {
        double sum = 0;
        double min = double.maxFinite;
        double max = 0;
        for (var point in filteredHeartRates) {
          final val = (point.value as NumericHealthValue).numericValue.toDouble();
          sum += val;
          if (val < min) min = val;
          if (val > max) max = val;
        }
        metric.averageHeartRate = sum / filteredHeartRates.length;
        metric.minHeartRate = min;
        metric.maxHeartRate = max;
        metric.heartRateSampleCount = filteredHeartRates.length;
      }

      if (filteredRestingHeartRates.isNotEmpty) {
        double sum = 0;
        for (var point in filteredRestingHeartRates) {
          sum += (point.value as NumericHealthValue).numericValue.toDouble();
        }
        metric.restingHeartRate = sum / filteredRestingHeartRates.length;
      } else if (filteredHeartRates.isNotEmpty) {
        final sortedHR = filteredHeartRates
            .map((p) => (p.value as NumericHealthValue).numericValue.toDouble())
            .toList()
          ..sort();
        final count = (sortedHR.length * 0.1).ceil().clamp(1, sortedHR.length);
        final lowestTenPercent = sortedHR.sublist(0, count);
        metric.restingHeartRate = lowestTenPercent.reduce((a, b) => a + b) / count;
        debugPrint('[GoogleHealth] Estimated resting heart rate: ${metric.restingHeartRate}');
      }

      if (filteredHrvs.isNotEmpty) {
        double sum = 0;
        for (var point in filteredHrvs) {
          sum += (point.value as NumericHealthValue).numericValue.toDouble();
        }
        metric.hrv = sum / filteredHrvs.length;
      }

      if (sleepMap['deep']! > 0) metric.deepSleepMinutes = sleepMap['deep'];
      if (sleepMap['rem']! > 0) metric.remSleepMinutes = sleepMap['rem'];
      if (sleepMap['light']! > 0) metric.lightSleepMinutes = sleepMap['light'];
      if (sleepMap['total']! > 0) metric.totalSleepMinutes = sleepMap['total'];
      if (sleepMap['awake']! > 0) metric.awakeMinutes = sleepMap['awake'];

    } catch (e) {
      debugPrint('[GoogleHealthService] Error fetching metrics: $e');
    }

    return metric;
  }

  @override
  Future<List<WorkoutSession>> fetchWorkoutsForDay(DateTime day) async {
    // Standardize the query window using the local day
    final localStart = DateTime(day.year, day.month, day.day);
    final queryStart = localStart.subtract(const Duration(days: 1));
    final queryEnd = localStart.add(const Duration(days: 2)).subtract(const Duration(milliseconds: 1));

    debugPrint('[GoogleHealthService] fetchWorkoutsForDay triggered for day: ${DateFormat('yyyy-MM-dd').format(day)}');
    debugPrint('[GoogleHealthService] Query Range: $queryStart to $queryEnd');

    try {
      final rawData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.WORKOUT],
        startTime: queryStart,
        endTime: queryEnd,
      );
      
      debugPrint('[GoogleHealthService] rawData count returned: ${rawData.length}');
      
      final seen = <String>{};
      final healthData = rawData.where((p) {
        // Fallback to a compound key if UUID is empty/null, avoiding complete suppression
        final uuid = p.uuid.isEmpty ? 'gen_${p.dateFrom.millisecondsSinceEpoch}_${p.dateTo.millisecondsSinceEpoch}' : p.uuid;
        final key = '${uuid}_${p.dateFrom.millisecondsSinceEpoch}_${p.dateTo.millisecondsSinceEpoch}';
        final isNew = seen.add(key);
        debugPrint('[GoogleHealthService] Workout point: uuid=${p.uuid}, dateFrom=${p.dateFrom}, dateTo=${p.dateTo}, isDuplicate=${!isNew}');
        return isNew;
      }).toList();
      
      // Determine target date in YYYY-MM-DD formats for BOTH local and UTC to avoid boundary filter loss
      final dayStrLocal = DateFormat('yyyy-MM-dd').format(day.toLocal());
      final dayStrUtc = DateFormat('yyyy-MM-dd').format(day.toUtc());

      final filteredData = healthData.where((point) {
        final pointLocalStr = DateFormat('yyyy-MM-dd').format(point.dateFrom.toLocal());
        final pointUtcStr = DateFormat('yyyy-MM-dd').format(point.dateFrom.toUtc());
        
        final matches = (pointLocalStr == dayStrLocal) || (pointUtcStr == dayStrUtc);
        debugPrint('[GoogleHealthService] Filtering workout: pointLocalStr=$pointLocalStr, pointUtcStr=$pointUtcStr, targetDayLocal=$dayStrLocal, targetDayUtc=$dayStrUtc, matches=$matches');
        return matches;
      }).toList();

      debugPrint('[GoogleHealthService] Filtered workouts count: ${filteredData.length}');

      return filteredData.map((point) {
        String workoutTypeName = 'Workout';
        double? calories;
        double? distance;

        if (point.value is WorkoutHealthValue) {
          final val = point.value as WorkoutHealthValue;
          workoutTypeName = _formatWorkoutType(val.workoutActivityType.name);
          calories = val.totalEnergyBurned?.toDouble();
          distance = val.totalDistance?.toDouble();
          debugPrint('[GoogleHealthService] Workout details: type=$workoutTypeName, calories=$calories kcal, distance=$distance m');
        } else if (point.value is NumericHealthValue) {
          calories = (point.value as NumericHealthValue).numericValue.toDouble();
          debugPrint('[GoogleHealthService] Numeric workout details: calories=$calories kcal');
        }

        final pointLocal = point.dateFrom.toLocal();
        final workoutDate = DateTime(pointLocal.year, pointLocal.month, pointLocal.day);

        final workout = WorkoutSession(
          date: workoutDate,
        )
          ..startTime = point.dateFrom
          ..endTime = point.dateTo
          ..workoutType = workoutTypeName
          ..durationSeconds = point.dateTo.difference(point.dateFrom).inSeconds
          ..totalCaloriesKcal = calories
          ..activityId = point.uuid
          ..distanceMeters = distance;
        return workout;
      }).toList();
    } catch (e, stack) {
      debugPrint('[GoogleHealthService] Error fetching workouts: $e\n$stack');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS FOR ACCURATE ACCUMULATION AND DEDUPLICATION
  // ─────────────────────────────────────────────────────────────────────────

  /// Aggregates cumulative metrics (steps, calories, distance) across ALL
  /// sources using time-interval deduplication. This eliminates double-counting
  /// when multiple sources (phone pedometer + watch) report overlapping data.
  ///
  /// Algorithm:
  /// 1. Build intervals (dateFrom, dateTo, value) from every data point.
  /// 2. Sort by start time, then longest interval first (so summary records
  ///    take priority over granular sub-records).
  /// 3. Track already-covered time ranges.
  /// 4. For each interval, only count the portion NOT already covered.
  double _aggregateCumulative(List<HealthDataPoint> points) {
    if (points.isEmpty) return 0.0;

    // Build typed intervals
    final intervals = <_TimeInterval>[];
    for (var p in points) {
      final val = p.value is NumericHealthValue
          ? (p.value as NumericHealthValue).numericValue.toDouble()
          : 0.0;
      if (val <= 0) continue;
      // Skip zero-length intervals
      if (!p.dateTo.isAfter(p.dateFrom)) continue;
      intervals.add(_TimeInterval(p.dateFrom, p.dateTo, val));
    }
    if (intervals.isEmpty) return 0.0;

    // Sort: earliest start first, then longest interval first (so summaries
    // are processed before their sub-records, reducing fragmentation).
    intervals.sort((a, b) {
      final cmp = a.start.compareTo(b.start);
      if (cmp != 0) return cmp;
      // Longer intervals first when same start time
      return b.durationMs.compareTo(a.durationMs);
    });

    // Covered ranges – maintained sorted and non-overlapping
    final covered = <_TimeInterval>[];

    double total = 0.0;

    for (final iv in intervals) {
      final uncoveredFraction = _uncoveredFraction(iv, covered);
      if (uncoveredFraction > 0) {
        total += iv.value * uncoveredFraction;
        _addCoveredRange(covered, iv);
      }
    }

    debugPrint('[GoogleHealth] _aggregateCumulative: ${points.length} points → '
        '${intervals.length} intervals → total=$total');
    return total;
  }

  /// Calculates what fraction of [iv] is NOT already covered by [covered].
  /// Returns a value between 0.0 and 1.0.
  double _uncoveredFraction(_TimeInterval iv, List<_TimeInterval> covered) {
    if (covered.isEmpty) return 1.0;

    final ivStartMs = iv.start.millisecondsSinceEpoch;
    final ivEndMs = iv.end.millisecondsSinceEpoch;
    final ivDuration = ivEndMs - ivStartMs;
    if (ivDuration <= 0) return 0.0;

    int coveredMs = 0;
    for (final c in covered) {
      final cStartMs = c.start.millisecondsSinceEpoch;
      final cEndMs = c.end.millisecondsSinceEpoch;
      // No overlap
      if (cEndMs <= ivStartMs || cStartMs >= ivEndMs) continue;
      // Overlap region
      final overlapStart = cStartMs > ivStartMs ? cStartMs : ivStartMs;
      final overlapEnd = cEndMs < ivEndMs ? cEndMs : ivEndMs;
      coveredMs += overlapEnd - overlapStart;
    }

    if (coveredMs >= ivDuration) return 0.0;
    return (ivDuration - coveredMs) / ivDuration;
  }

  /// Adds a new interval to [covered] and merges any overlapping/adjacent ranges.
  void _addCoveredRange(List<_TimeInterval> covered, _TimeInterval iv) {
    covered.add(_TimeInterval(iv.start, iv.end, 0));
    // Sort by start
    covered.sort((a, b) => a.start.compareTo(b.start));
    // Merge overlapping / adjacent
    int i = 0;
    while (i < covered.length - 1) {
      if (!covered[i + 1].start.isAfter(covered[i].end)) {
        // Merge: extend end if needed
        final mergedEnd =
            covered[i].end.isAfter(covered[i + 1].end) ? covered[i].end : covered[i + 1].end;
        covered[i] = _TimeInterval(covered[i].start, mergedEnd, 0);
        covered.removeAt(i + 1);
      } else {
        i++;
      }
    }
  }

  /// Deduplicates exercise/workout duration using the same time-interval
  /// approach so overlapping workout records aren't double-counted.
  int _aggregateExerciseDuration(List<HealthDataPoint> workoutPoints) {
    if (workoutPoints.isEmpty) return 0;

    final intervals = <_TimeInterval>[];
    for (var p in workoutPoints) {
      if (!p.dateTo.isAfter(p.dateFrom)) continue;
      intervals.add(_TimeInterval(p.dateFrom, p.dateTo, 1.0));
    }
    if (intervals.isEmpty) return 0;

    // Sort by start, then longest first
    intervals.sort((a, b) {
      final cmp = a.start.compareTo(b.start);
      if (cmp != 0) return cmp;
      return b.durationMs.compareTo(a.durationMs);
    });

    // Merge all into non-overlapping ranges, then sum their durations
    final merged = <_TimeInterval>[intervals.first];
    for (int i = 1; i < intervals.length; i++) {
      final last = merged.last;
      if (!intervals[i].start.isAfter(last.end)) {
        // Overlaps – extend
        final mergedEnd =
            last.end.isAfter(intervals[i].end) ? last.end : intervals[i].end;
        merged[merged.length - 1] = _TimeInterval(last.start, mergedEnd, 1.0);
      } else {
        merged.add(intervals[i]);
      }
    }

    int totalMinutes = 0;
    for (final m in merged) {
      totalMinutes += m.end.difference(m.start).inMinutes;
    }
    return totalMinutes;
  }

  Map<String, int> _aggregateSleep(List<HealthDataPoint> sleepPoints) {
    final result = {
      'total': 0,
      'deep': 0,
      'rem': 0,
      'light': 0,
      'asleep': 0,
      'awake': 0,
    };
    if (sleepPoints.isEmpty) return result;

    final sourcePoints = <String, List<HealthDataPoint>>{};
    for (var p in sleepPoints) {
      final src = p.sourceId ?? p.sourceName ?? 'unknown';
      sourcePoints.putIfAbsent(src, () => []).add(p);
    }

    final bestSource = _findBestSource(sourcePoints.keys) ??
        sourcePoints.entries.reduce((a, b) => a.value.length > b.value.length ? a : b).key;

    final points = sourcePoints[bestSource] ?? [];
    
    int totalSession = 0;
    int deep = 0;
    int rem = 0;
    int light = 0;
    int asleep = 0;
    int awake = 0;

    for (var point in points) {
      final duration = point.dateTo.difference(point.dateFrom).inMinutes;
      switch (point.type) {
        case HealthDataType.SLEEP_SESSION:
          totalSession += duration;
          break;
        case HealthDataType.SLEEP_ASLEEP:
          asleep += duration;
          break;
        case HealthDataType.SLEEP_LIGHT:
          light += duration;
          break;
        case HealthDataType.SLEEP_DEEP:
          deep += duration;
          break;
        case HealthDataType.SLEEP_REM:
          rem += duration;
          break;
        default:
          break;
      }
    }

    result['deep'] = deep;
    result['rem'] = rem;
    result['light'] = light;
    result['asleep'] = asleep;
    
    if (totalSession > 0) {
      result['total'] = totalSession;
    } else {
      final sumStages = deep + rem + light + asleep;
      result['total'] = sumStages;
    }

    final stagesSum = deep + rem + light;
    if (stagesSum > 0 && result['total']! > stagesSum) {
      result['awake'] = result['total']! - stagesSum;
    } else {
      result['awake'] = awake;
    }

    return result;
  }

  List<HealthDataPoint> _filterByBestSource(List<HealthDataPoint> points) {
    if (points.isEmpty) return [];

    final sourcePoints = <String, List<HealthDataPoint>>{};
    for (var p in points) {
      final src = p.sourceId ?? p.sourceName ?? 'unknown';
      sourcePoints.putIfAbsent(src, () => []).add(p);
    }

    final bestSource = _findBestSource(sourcePoints.keys) ??
        sourcePoints.entries.reduce((a, b) => a.value.length > b.value.length ? a : b).key;

    return sourcePoints[bestSource] ?? [];
  }

  String? _findBestSource(Iterable<String> sources) {
    if (sources.isEmpty) return null;

    // 1. Strictly prioritize Huawei Health and Honor app (contains 'huawei' or 'honor')
    for (final src in sources) {
      final sLower = src.toLowerCase();
      if (sLower.contains('huawei') || sLower.contains('honor')) {
        return src;
      }
    }

    // 2. Next, check for specific wearable companion apps
    for (final src in sources) {
      final sLower = src.toLowerCase();
      if (sLower.contains('samsung') ||
          sLower.contains('shealth') ||
          sLower.contains('zepp') ||
          sLower.contains('fitbit') ||
          sLower.contains('mi') ||
          sLower.contains('xiaomi') ||
          sLower.contains('garmin') ||
          sLower.contains('polar') ||
          sLower.contains('suunto') ||
          sLower.contains('wearable') ||
          sLower.contains('watch') ||
          sLower.contains('band') ||
          sLower.contains('wear')) {
        return src;
      }
    }

    // 3. Next, check for Google Fit or generic health/fitness apps (excluding system healthdata)
    for (final src in sources) {
      final sLower = src.toLowerCase();
      if (sLower.contains('fitness') ||
          sLower.contains('fit') ||
          (sLower.contains('health') && !sLower.contains('healthdata'))) {
        return src;
      }
    }

    return null;
  }

  /// Converts Health Connect workout type enum names (e.g. EXERCISE_TYPE_WALKING,
  /// RUNNING, OTHER) into human-readable labels (e.g. "Walking", "Running",
  /// "Other Exercise").
  String _formatWorkoutType(String rawType) {
    // Strip common prefixes
    String cleaned = rawType;
    const prefixes = ['EXERCISE_TYPE_', 'WORKOUT_TYPE_', 'ACTIVITY_TYPE_'];
    for (final prefix in prefixes) {
      if (cleaned.startsWith(prefix)) {
        cleaned = cleaned.substring(prefix.length);
        break;
      }
    }

    // Handle special one-word cases
    if (cleaned == 'OTHER' || cleaned == 'UNKNOWN') {
      return 'Other Exercise';
    }

    // Convert SCREAMING_SNAKE_CASE → Title Case
    // e.g. INDOOR_CYCLING → Indoor Cycling
    final words = cleaned.split('_').where((w) => w.isNotEmpty).map((word) {
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    });

    return words.join(' ');
  }
}

/// Lightweight helper class for time-interval deduplication.
class _TimeInterval {
  final DateTime start;
  final DateTime end;
  final double value;

  const _TimeInterval(this.start, this.end, this.value);

  int get durationMs => end.millisecondsSinceEpoch - start.millisecondsSinceEpoch;
}
