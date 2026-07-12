import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
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
      
      double bodyFat = 0.0;
      double weight = 0.0;
      double spo2 = 0.0;
      double temp = 0.0;
      int exerciseDurationMinutes = 0;

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

          final data = await _health.getHealthDataFromTypes(
            types: [type], 
            startTime: queryStart, 
            endTime: end
          );

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
              for (var p in data) {
                exerciseDurationMinutes += p.dateTo.difference(p.dateFrom).inMinutes;
              }
              break;
            default:
              break;
          }
        } catch (e) {
          debugPrint('[GoogleHealthService] Error fetching $type: $e');
        }
      }

      // Aggregate cumulative metrics with source level deduplication
      final double activeCalories = _aggregateCumulative(activeEnergyPoints);
      final double basalCalories = _aggregateCumulative(basalEnergyPoints);
      final int steps = _aggregateCumulative(stepPoints).toInt();
      final double distance = _aggregateCumulative(distancePoints);
      
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
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));

    try {
      final healthData = await _health.getHealthDataFromTypes(types: [HealthDataType.WORKOUT], startTime: start, endTime: end);
      
      return healthData.map((point) {
        final val = point.value as WorkoutHealthValue;
        final workout = WorkoutSession(
          date: day,
        )
          ..startTime = point.dateFrom
          ..endTime = point.dateTo
          ..workoutType = val.workoutActivityType.name
          ..durationSeconds = point.dateTo.difference(point.dateFrom).inSeconds
          ..totalCaloriesKcal = val.totalEnergyBurned?.toDouble()
          ..activityId = point.uuid
          ..distanceMeters = val.totalDistance?.toDouble();
        return workout;
      }).toList();
    } catch (e) {
      debugPrint('[GoogleHealthService] Error fetching workouts: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS FOR ACCURATE ACCUMULATION AND DEDUPLICATION
  // ─────────────────────────────────────────────────────────────────────────

  double _aggregateCumulative(List<HealthDataPoint> points) {
    if (points.isEmpty) return 0.0;

    final sourceSums = <String, double>{};
    for (var p in points) {
      final src = p.sourceId ?? p.sourceName ?? 'unknown';
      final val = p.value is NumericHealthValue 
          ? (p.value as NumericHealthValue).numericValue.toDouble() 
          : 0.0;
      sourceSums[src] = (sourceSums[src] ?? 0.0) + val;
    }

    if (sourceSums.isEmpty) return 0.0;

    // Prioritize Huawei Health
    String? bestSource;
    for (final src in sourceSums.keys) {
      final sLower = src.toLowerCase();
      if (sLower.contains('huawei') || sLower.contains('health')) {
        bestSource = src;
        break;
      }
    }
    
    // Check Samsung Health
    if (bestSource == null) {
      for (final src in sourceSums.keys) {
        final sLower = src.toLowerCase();
        if (sLower.contains('samsung') || sLower.contains('shealth')) {
          bestSource = src;
          break;
        }
      }
    }

    // Fallback to the source with the maximum sum
    bestSource ??= sourceSums.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    return sourceSums[bestSource] ?? 0.0;
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

    String? bestSource;
    for (final src in sourcePoints.keys) {
      final sLower = src.toLowerCase();
      if (sLower.contains('huawei') || sLower.contains('health')) {
        bestSource = src;
        break;
      }
    }
    if (bestSource == null) {
      for (final src in sourcePoints.keys) {
        final sLower = src.toLowerCase();
        if (sLower.contains('samsung') || sLower.contains('shealth')) {
          bestSource = src;
          break;
        }
      }
    }
    if (bestSource == null) {
      bestSource = sourcePoints.entries
          .reduce((a, b) => a.value.length > b.value.length ? a : b)
          .key;
    }

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

    String? bestSource;
    for (final src in sourcePoints.keys) {
      final sLower = src.toLowerCase();
      if (sLower.contains('huawei') || sLower.contains('health')) {
        bestSource = src;
        break;
      }
    }
    if (bestSource == null) {
      for (final src in sourcePoints.keys) {
        final sLower = src.toLowerCase();
        if (sLower.contains('samsung') || sLower.contains('shealth')) {
          bestSource = src;
          break;
        }
      }
    }
    if (bestSource == null) {
      bestSource = sourcePoints.entries
          .reduce((a, b) => a.value.length > b.value.length ? a : b)
          .key;
    }

    return sourcePoints[bestSource] ?? [];
  }
}
