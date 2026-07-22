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
    HealthDataType.SLEEP_AWAKE,
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
    final list = await fetchMetricsInRange(day, day);
    if (list.isNotEmpty) return list.first;
    return DailyMetric(date: DateTime.utc(day.year, day.month, day.day));
  }

  @override
  Future<List<DailyMetric>> fetchMetricsInRange(DateTime start, DateTime end) async {
    final rangeStart = DateTime(start.year, start.month, start.day);
    final rangeEnd = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);

    debugPrint('┌─────────────────────────────────────────────────────────────');
    debugPrint('│ [PIPELINE] fetchMetricsInRange START (range=$rangeStart → $rangeEnd)');
    debugPrint('└─────────────────────────────────────────────────────────────');

    final Map<HealthDataType, List<HealthDataPoint>> typeDataMap = {};
    for (final type in _dataTypes) {
      typeDataMap[type] = [];
    }

    // Chunk date range into safe 14-day windows to prevent Health Connect IPC parcel overflow / hanging
    const int chunkDays = 14;
    DateTime chunkStart = rangeStart.subtract(const Duration(hours: 12));

    while (!chunkStart.isAfter(rangeEnd)) {
      DateTime chunkEnd = chunkStart.add(const Duration(days: chunkDays));
      if (chunkEnd.isAfter(rangeEnd)) {
        chunkEnd = rangeEnd;
      }

      for (final type in _dataTypes) {
        try {
          final rawData = await _health.getHealthDataFromTypes(
            types: [type],
            startTime: chunkStart,
            endTime: chunkEnd,
          );
          final seen = <String>{};
          final data = rawData.where((p) {
            final key = '${p.uuid}_${p.dateFrom.millisecondsSinceEpoch}_${p.dateTo.millisecondsSinceEpoch}';
            return seen.add(key);
          }).toList();

          typeDataMap[type]!.addAll(data);
        } catch (e) {
          debugPrint('[PIPELINE] Error chunk fetching $type ($chunkStart → $chunkEnd): $e');
        }
      }

      chunkStart = chunkEnd.add(const Duration(milliseconds: 1));
    }

    // Deduplicate accumulated points per type
    for (final type in _dataTypes) {
      final seen = <String>{};
      typeDataMap[type] = typeDataMap[type]!.where((p) {
        final key = '${p.uuid}_${p.dateFrom.millisecondsSinceEpoch}_${p.dateTo.millisecondsSinceEpoch}';
        return seen.add(key);
      }).toList();
      debugPrint('[PIPELINE] Bulk $type total points across range: ${typeDataMap[type]!.length}');
    }

    final List<DailyMetric> results = [];
    DateTime current = rangeStart;
    final endDate = DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day);


    while (!current.isAfter(endDate)) {
      final localStart = DateTime(current.year, current.month, current.day);
      final localEnd = localStart.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
      final utcDate = DateTime.utc(current.year, current.month, current.day);

      final metric = DailyMetric(date: utcDate);

      final dayStr = DateFormat('yyyy-MM-dd').format(localStart);

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

      for (final entry in typeDataMap.entries) {
        final type = entry.key;
        final points = entry.value;

        for (final p in points) {
          if (type == HealthDataType.SLEEP_SESSION ||
              type == HealthDataType.SLEEP_ASLEEP ||
              type == HealthDataType.SLEEP_LIGHT ||
              type == HealthDataType.SLEEP_DEEP ||
              type == HealthDataType.SLEEP_REM ||
              type == HealthDataType.SLEEP_AWAKE) {
            // Sleep sessions ending on day D belong to day D
            final pEndLocalStr = DateFormat('yyyy-MM-dd').format(p.dateTo.toLocal());
            if (pEndLocalStr == dayStr && p.dateTo.isAfter(localStart)) {
              sleepPoints.add(p);
            }
          } else {
            // Daily vitals and cumulative metrics matching this day
            final pLocalStr = DateFormat('yyyy-MM-dd').format(p.dateFrom.toLocal());
            if (pLocalStr == dayStr) {
              switch (type) {
                case HealthDataType.STEPS:
                  stepPoints.add(p);
                  break;
                case HealthDataType.ACTIVE_ENERGY_BURNED:
                  activeEnergyPoints.add(p);
                  break;
                case HealthDataType.BASAL_ENERGY_BURNED:
                  basalEnergyPoints.add(p);
                  break;
                case HealthDataType.DISTANCE_DELTA:
                  distancePoints.add(p);
                  break;
                case HealthDataType.HEART_RATE:
                  heartRates.add(p);
                  break;
                case HealthDataType.RESTING_HEART_RATE:
                  restingHeartRates.add(p);
                  break;
                case HealthDataType.HEART_RATE_VARIABILITY_RMSSD:
                  hrvs.add(p);
                  break;
                case HealthDataType.BODY_FAT_PERCENTAGE:
                  if (p.value is NumericHealthValue) {
                    bodyFat = (p.value as NumericHealthValue).numericValue.toDouble();
                  }
                  break;
                case HealthDataType.WEIGHT:
                  if (p.value is NumericHealthValue) {
                    weight = (p.value as NumericHealthValue).numericValue.toDouble();
                  }
                  break;
                case HealthDataType.BLOOD_OXYGEN:
                  if (p.value is NumericHealthValue) {
                    spo2 = (p.value as NumericHealthValue).numericValue.toDouble();
                  }
                  break;
                case HealthDataType.BODY_TEMPERATURE:
                  if (p.value is NumericHealthValue) {
                    temp = (p.value as NumericHealthValue).numericValue.toDouble();
                  }
                  break;
                case HealthDataType.WORKOUT:
                  workoutPoints.add(p);
                  break;
                default:
                  break;
              }
            }
          }
        }
      }

      // Filter cumulative metrics by best source to prevent double-counting phone + wearable
      final filteredActiveEnergy = _filterByBestSource(activeEnergyPoints);
      final filteredBasalEnergy = _filterByBestSource(basalEnergyPoints);
      final filteredSteps = _filterByBestSource(stepPoints);
      final filteredDistance = _filterByBestSource(distancePoints);

      // Aggregate cumulative metrics with time-interval deduplication within the best source
      final double activeCalories = _aggregateCumulative(filteredActiveEnergy);
      final double basalCalories = _aggregateCumulative(filteredBasalEnergy);
      final int steps = _aggregateCumulative(filteredSteps).toInt();
      final double distance = _aggregateCumulative(filteredDistance);
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
      }

      // Estimate Active Calories from steps if 0
      double finalActive = activeCalories;
      if (finalActive == 0.0 && steps > 0) {
        finalActive = steps * 0.04;
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
      if (sleepMap['nap']! > 0) metric.floorsClimbed = sleepMap['nap'];
      if (sleepMap['start']! >= 0) metric.systolicBP = sleepMap['start']!.toDouble();
      if (sleepMap['end']! >= 0) metric.diastolicBP = sleepMap['end']!.toDouble();

      results.add(metric);
      current = current.add(const Duration(days: 1));
    }

    debugPrint('┌─────────────────────────────────────────────────────────────');
    debugPrint('│ [PIPELINE] fetchMetricsInRange COMPLETE');
    debugPrint('│ Total DailyMetric records generated: ${results.length}');
    debugPrint('└─────────────────────────────────────────────────────────────');

    return results;
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
        final dynamicUuid = (p.uuid as dynamic);
        final uuidStr = (dynamicUuid == null || dynamicUuid.toString().isEmpty) 
            ? 'gen_${p.dateFrom.millisecondsSinceEpoch}_${p.dateTo.millisecondsSinceEpoch}' 
            : dynamicUuid.toString();
        final key = '${uuidStr}_${p.dateFrom.millisecondsSinceEpoch}_${p.dateTo.millisecondsSinceEpoch}';
        final isNew = seen.add(key);
        return isNew;
      }).toList();
      
      final dayStrLocal = DateFormat('yyyy-MM-dd').format(day.toLocal());
      final dayStrUtc = DateFormat('yyyy-MM-dd').format(day.toUtc());

      final filteredData = healthData.where((point) {
        final pointLocalStr = DateFormat('yyyy-MM-dd').format(point.dateFrom.toLocal());
        final pointUtcStr = DateFormat('yyyy-MM-dd').format(point.dateFrom.toUtc());
        
        final matches = (pointLocalStr == dayStrLocal) || (pointUtcStr == dayStrUtc);
        return matches;
      }).toList();

      debugPrint('[GoogleHealthService] Filtered workouts count: ${filteredData.length}');

      return filteredData.map((point) {
        String workoutTypeName = 'Workout';
        double? calories;
        double? distance;

        try {
          if (point.value is WorkoutHealthValue) {
            final val = point.value as WorkoutHealthValue;
            workoutTypeName = _formatWorkoutType(val.workoutActivityType.name);
            calories = val.totalEnergyBurned?.toDouble();
            distance = val.totalDistance?.toDouble();
          } else if (point.value is NumericHealthValue) {
            calories = (point.value as NumericHealthValue).numericValue.toDouble();
          }
        } catch (e) {
          debugPrint('[GoogleHealthService] Error parsing workout value: $e');
        }

        final pointLocal = point.dateFrom.toLocal();
        final workoutDate = DateTime(pointLocal.year, pointLocal.month, pointLocal.day);

        final dynamicUuid = (point.uuid as dynamic);
        final safeUuid = (dynamicUuid == null || dynamicUuid.toString().isEmpty) 
            ? 'gen_${point.dateFrom.millisecondsSinceEpoch}_${point.dateTo.millisecondsSinceEpoch}' 
            : dynamicUuid.toString();

        final workout = WorkoutSession(
          date: workoutDate,
        )
          ..startTime = point.dateFrom
          ..endTime = point.dateTo
          ..workoutType = workoutTypeName
          ..durationSeconds = point.dateTo.difference(point.dateFrom).inSeconds
          ..totalCaloriesKcal = calories
          ..activityId = safeUuid
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
      'nap': 0,
      'start': -1,
      'end': -1,
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
    
    // Find the main sleep session (the longest sleep session)
    final sleepSessions = points.where((p) => p.type == HealthDataType.SLEEP_SESSION).toList();
    HealthDataPoint? mainSessionPoint;
    int napMinutes = 0;
    if (sleepSessions.isNotEmpty) {
      sleepSessions.sort((a, b) {
        final aDur = a.dateTo.difference(a.dateFrom).inMinutes;
        final bDur = b.dateTo.difference(b.dateFrom).inMinutes;
        return bDur.compareTo(aDur);
      });
      mainSessionPoint = sleepSessions.first;
      
      // Any other sessions are naps
      for (int i = 1; i < sleepSessions.length; i++) {
        napMinutes += sleepSessions[i].dateTo.difference(sleepSessions[i].dateFrom).inMinutes;
      }
    }

    int deep = 0;
    int rem = 0;
    int light = 0;
    int asleep = 0;
    int awake = 0;

    for (var point in points) {
      final duration = point.dateTo.difference(point.dateFrom).inMinutes;
      if (point.type == HealthDataType.SLEEP_SESSION) {
        continue;
      }
      
      // Filter sleep stages to main session only
      if (mainSessionPoint != null) {
        final startMs = point.dateFrom.millisecondsSinceEpoch;
        final endMs = point.dateTo.millisecondsSinceEpoch;
        final mainStartMs = mainSessionPoint.dateFrom.millisecondsSinceEpoch;
        final mainEndMs = mainSessionPoint.dateTo.millisecondsSinceEpoch;
        
        final overlap = (startMs < mainEndMs) && (endMs > mainStartMs);
        if (!overlap) {
          continue; // belongs to nap or other times
        }
      }

      switch (point.type) {
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
        case HealthDataType.SLEEP_AWAKE:
          awake += duration;
          break;
        default:
          break;
      }
    }

    result['deep'] = deep;
    result['rem'] = rem;
    result['light'] = light;
    result['asleep'] = asleep;
    result['nap'] = napMinutes;
    
    if (mainSessionPoint != null) {
      result['total'] = mainSessionPoint.dateTo.difference(mainSessionPoint.dateFrom).inMinutes;
    } else {
      final sumStages = deep + rem + light + asleep;
      result['total'] = sumStages;
    }

    // Only infer awake time if stages cover most of the sleep session (e.g. >= 80%),
    // otherwise the unrecorded stages are likely just unclassified sleep segments, not awake time!
    final stagesSum = deep + rem + light;
    if (stagesSum > 0 && result['total']! > stagesSum && (stagesSum / result['total']!) >= 0.8) {
      result['awake'] = result['total']! - stagesSum;
    } else {
      result['awake'] = awake;
    }

    if (mainSessionPoint != null) {
      final startLocal = mainSessionPoint.dateFrom.toLocal();
      result['start'] = startLocal.hour * 60 + startLocal.minute;
      final endLocal = mainSessionPoint.dateTo.toLocal();
      result['end'] = endLocal.hour * 60 + endLocal.minute;
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

  // ─────────────────────────────────────────────────────────────────────────
  // BULK WORKOUT FETCH — single Health Connect call for entire range
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Future<List<WorkoutSession>> fetchWorkoutsInRange(DateTime start, DateTime end) async {
    final queryStart = DateTime(start.year, start.month, start.day);
    final queryEnd = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);

    debugPrint('┌─────────────────────────────────────────────────────────────');
    debugPrint('│ [PIPELINE] fetchWorkoutsInRange START');
    debugPrint('│ queryStart = $queryStart');
    debugPrint('│ queryEnd   = $queryEnd');
    debugPrint('│ span       = ${queryEnd.difference(queryStart).inDays} days');
    debugPrint('└─────────────────────────────────────────────────────────────');

    // 1. Log permission status
    try {
      final hasPerms = await hasPermissions();
      debugPrint('[PIPELINE] Permission status: $hasPerms');
    } catch (e) {
      debugPrint('[PIPELINE] Permission check error: $e');
    }

    try {
      final List<HealthDataPoint> rawData = [];

      // Chunk workout queries into safe 30-day windows to prevent Health Connect IPC parcel overflow
      const int chunkDays = 30;
      DateTime chunkStart = queryStart;

      while (!chunkStart.isAfter(queryEnd)) {
        DateTime chunkEnd = chunkStart.add(const Duration(days: chunkDays));
        if (chunkEnd.isAfter(queryEnd)) {
          chunkEnd = queryEnd;
        }

        try {
          final chunkData = await _health.getHealthDataFromTypes(
            types: [HealthDataType.WORKOUT],
            startTime: chunkStart,
            endTime: chunkEnd,
          );
          rawData.addAll(chunkData);
        } catch (e) {
          debugPrint('[PIPELINE] Error chunk fetching workouts ($chunkStart → $chunkEnd): $e');
        }

        chunkStart = chunkEnd.add(const Duration(milliseconds: 1));
      }

      debugPrint('[PIPELINE] Raw WORKOUT data points returned: ${rawData.length}');


      if (rawData.isEmpty) {
        debugPrint('[PIPELINE] ⚠ Health Connect returned ZERO workout records for the entire range.');
        debugPrint('[PIPELINE] Possible causes:');
        debugPrint('[PIPELINE]   - No WORKOUT permission granted');
        debugPrint('[PIPELINE]   - No READ_HEALTH_DATA_HISTORY permission');
        debugPrint('[PIPELINE]   - Health Connect has no workout data');
        debugPrint('[PIPELINE]   - The health plugin version does not support historical reads');
        return [];
      }

      // Mapped and deduplicated next


      // 4. Deduplicate by uuid + time range
      final seen = <String>{};
      final healthData = rawData.where((p) {
        final dynamicUuid = (p.uuid as dynamic);
        final uuidStr = (dynamicUuid == null || dynamicUuid.toString().isEmpty)
            ? 'gen_${p.dateFrom.millisecondsSinceEpoch}_${p.dateTo.millisecondsSinceEpoch}'
            : dynamicUuid.toString();
        final key = '${uuidStr}_${p.dateFrom.millisecondsSinceEpoch}_${p.dateTo.millisecondsSinceEpoch}';
        return seen.add(key);
      }).toList();

      debugPrint('[PIPELINE] After dedup: ${healthData.length} unique workout points (removed ${rawData.length - healthData.length} dupes)');

      // 5. Map to WorkoutSession objects
      final List<WorkoutSession> sessions = [];
      for (int i = 0; i < healthData.length; i++) {
        final point = healthData[i];
        String workoutTypeName = 'Workout';
        double? calories;
        double? distance;

        try {
          if (point.value is WorkoutHealthValue) {
            final val = point.value as WorkoutHealthValue;
            workoutTypeName = _formatWorkoutType(val.workoutActivityType.name);
            calories = val.totalEnergyBurned?.toDouble();
            distance = val.totalDistance?.toDouble();
          } else if (point.value is NumericHealthValue) {
            calories = (point.value as NumericHealthValue).numericValue.toDouble();
          }
        } catch (e) {
          debugPrint('[PIPELINE] Error parsing workout[$i] value: $e');
        }

        final pointLocal = point.dateFrom.toLocal();
        final workoutDate = DateTime(pointLocal.year, pointLocal.month, pointLocal.day);

        final dynamicUuid = (point.uuid as dynamic);
        final safeUuid = (dynamicUuid == null || dynamicUuid.toString().isEmpty)
            ? 'gen_${point.dateFrom.millisecondsSinceEpoch}_${point.dateTo.millisecondsSinceEpoch}'
            : dynamicUuid.toString();

        final durationSecs = point.dateTo.difference(point.dateFrom).inSeconds;

        final workout = WorkoutSession(
          date: workoutDate,
        )
          ..startTime = point.dateFrom
          ..endTime = point.dateTo
          ..workoutType = workoutTypeName
          ..durationSeconds = durationSecs
          ..totalCaloriesKcal = calories
          ..activityId = safeUuid
          ..distanceMeters = distance;

        debugPrint('[PIPELINE] Mapped[$i]: activityId=$safeUuid, date=$workoutDate, '
            'type=$workoutTypeName, duration=${durationSecs}s, '
            'calories=$calories, start=${point.dateFrom}, end=${point.dateTo}');

        sessions.add(workout);
      }

      // Deduplicate mapped sessions by activityId
      final seenActivityIds = <String>{};
      final uniqueSessions = sessions.where((s) => seenActivityIds.add(s.activityId ?? '')).toList();

      debugPrint('┌─────────────────────────────────────────────────────────────');
      debugPrint('│ [PIPELINE] fetchWorkoutsInRange COMPLETE');
      debugPrint('│ Total sessions mapped: ${sessions.length} (unique: ${uniqueSessions.length})');
      debugPrint('└─────────────────────────────────────────────────────────────');

      return uniqueSessions;
    } catch (e, stack) {
      debugPrint('[PIPELINE] ❌ fetchWorkoutsInRange ERROR: $e\n$stack');
      return [];
    }
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
