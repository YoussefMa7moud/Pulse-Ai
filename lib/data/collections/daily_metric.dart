class DailyMetric {
  late DateTime date;

  // SLEEP
  int? totalSleepMinutes;
  int? deepSleepMinutes;
  int? remSleepMinutes;
  int? lightSleepMinutes;
  int? awakeMinutes;
  int? sleepOnsetLatencyMinutes;
  double? sleepEfficiency;

  // HEART RATE
  double? restingHeartRate;
  double? averageHeartRate;
  double? maxHeartRate;
  double? minHeartRate;
  int? heartRateSampleCount;
  double? hrv;

  // ACTIVITY
  int? steps;
  int? totalCalories;
  double? activeCalories;
  double? caloriesBurned;
  double? distanceMeters;
  int? activeMinutes;
  int? exerciseDurationMinutes;
  int? floorsClimbed;

  // BODY COMPOSITION
  double? weightKg;
  double? bmi;
  double? bodyFatPercent;
  double? muscleMassKg;
  double? bodyWaterPercent;
  double? boneMassKg;

  // RESPIRATORY & OXYGEN
  double? bloodOxygenSpO2;
  double? respiratoryRate;

  // ADVANCED FITNESS METRICS
  double? vo2Max;
  int? recoveryTimeHours;
  int? avgCadence;
  double? avgPaceMinPerKm;
  double? avgSpeedMps;
  double? totalElevationGainMeters;

  // STRESS & WELLBEING
  double? stressScore;
  String? stressLevel;

  // BLOOD MARKERS
  double? systolicBP;
  double? diastolicBP;
  double? bloodGlucose;
  double? bodyTemperature;

  // WORKOUT SESSION REFERENCES
  int? workoutSessionCount;
  String? workoutSessionIdsJson;

  // SYNC METADATA
  DateTime? lastHuaweiSyncTime;
  String? huaweiDataSourceId;

  DailyMetric({
    required this.date,
    this.totalSleepMinutes,
    this.deepSleepMinutes,
    this.remSleepMinutes,
    this.lightSleepMinutes,
    this.awakeMinutes,
    this.sleepOnsetLatencyMinutes,
    this.sleepEfficiency,
    this.restingHeartRate,
    this.averageHeartRate,
    this.maxHeartRate,
    this.minHeartRate,
    this.heartRateSampleCount,
    this.hrv,
    this.steps,
    this.totalCalories,
    this.activeCalories,
    this.caloriesBurned,
    this.distanceMeters,
    this.activeMinutes,
    this.exerciseDurationMinutes,
    this.floorsClimbed,
    this.weightKg,
    this.bmi,
    this.bodyFatPercent,
    this.muscleMassKg,
    this.bodyWaterPercent,
    this.boneMassKg,
    this.bloodOxygenSpO2,
    this.respiratoryRate,
    this.vo2Max,
    this.recoveryTimeHours,
    this.avgCadence,
    this.avgPaceMinPerKm,
    this.avgSpeedMps,
    this.totalElevationGainMeters,
    this.stressScore,
    this.stressLevel,
    this.systolicBP,
    this.diastolicBP,
    this.bloodGlucose,
    this.bodyTemperature,
    this.workoutSessionCount,
    this.workoutSessionIdsJson,
    this.lastHuaweiSyncTime,
    this.huaweiDataSourceId,
  });

  factory DailyMetric.fromJson(Map<String, dynamic> json) {
    return DailyMetric(
      date: json['date'] != null ? DateTime.parse(json['date'] as String) : DateTime.now(),
      totalSleepMinutes: json['total_sleep_minutes'] != null ? (json['total_sleep_minutes'] as num).toInt() : null,
      deepSleepMinutes: json['deep_sleep_minutes'] != null ? (json['deep_sleep_minutes'] as num).toInt() : null,
      remSleepMinutes: json['rem_sleep_minutes'] != null ? (json['rem_sleep_minutes'] as num).toInt() : null,
      lightSleepMinutes: json['light_sleep_minutes'] != null ? (json['light_sleep_minutes'] as num).toInt() : null,
      awakeMinutes: json['awake_minutes'] != null ? (json['awake_minutes'] as num).toInt() : null,
      sleepOnsetLatencyMinutes: json['sleep_onset_latency_minutes'] != null ? (json['sleep_onset_latency_minutes'] as num).toInt() : null,
      sleepEfficiency: json['sleep_efficiency'] != null ? (json['sleep_efficiency'] as num).toDouble() : null,
      restingHeartRate: json['resting_heart_rate'] != null ? (json['resting_heart_rate'] as num).toDouble() : null,
      averageHeartRate: json['average_heart_rate'] != null ? (json['average_heart_rate'] as num).toDouble() : null,
      maxHeartRate: json['max_heart_rate'] != null ? (json['max_heart_rate'] as num).toDouble() : null,
      minHeartRate: json['min_heart_rate'] != null ? (json['min_heart_rate'] as num).toDouble() : null,
      heartRateSampleCount: json['heart_rate_sample_count'] != null ? (json['heart_rate_sample_count'] as num).toInt() : null,
      hrv: json['hrv'] != null ? (json['hrv'] as num).toDouble() : null,
      steps: json['steps'] != null ? (json['steps'] as num).toInt() : null,
      totalCalories: json['total_calories'] != null ? (json['total_calories'] as num).toInt() : null,
      activeCalories: json['active_calories'] != null ? (json['active_calories'] as num).toDouble() : null,
      caloriesBurned: json['calories_burned'] != null ? (json['calories_burned'] as num).toDouble() : null,
      distanceMeters: json['distance_meters'] != null ? (json['distance_meters'] as num).toDouble() : null,
      activeMinutes: json['active_minutes'] != null ? (json['active_minutes'] as num).toInt() : null,
      exerciseDurationMinutes: json['exercise_duration_minutes'] != null ? (json['exercise_duration_minutes'] as num).toInt() : null,
      floorsClimbed: json['floors_climbed'] != null ? (json['floors_climbed'] as num).toInt() : null,
      weightKg: json['weight_kg'] != null ? (json['weight_kg'] as num).toDouble() : null,
      bmi: json['bmi'] != null ? (json['bmi'] as num).toDouble() : null,
      bodyFatPercent: json['body_fat_percent'] != null ? (json['body_fat_percent'] as num).toDouble() : null,
      muscleMassKg: json['muscle_mass_kg'] != null ? (json['muscle_mass_kg'] as num).toDouble() : null,
      bodyWaterPercent: json['body_water_percent'] != null ? (json['body_water_percent'] as num).toDouble() : null,
      boneMassKg: json['bone_mass_kg'] != null ? (json['bone_mass_kg'] as num).toDouble() : null,
      bloodOxygenSpO2: json['blood_oxygen_spo2'] != null ? (json['blood_oxygen_spo2'] as num).toDouble() : null,
      respiratoryRate: json['respiratory_rate'] != null ? (json['respiratory_rate'] as num).toDouble() : null,
      vo2Max: json['vo2_max'] != null ? (json['vo2_max'] as num).toDouble() : null,
      recoveryTimeHours: json['recovery_time_hours'] != null ? (json['recovery_time_hours'] as num).toInt() : null,
      avgCadence: json['avg_cadence'] != null ? (json['avg_cadence'] as num).toInt() : null,
      avgPaceMinPerKm: json['avg_pace_min_per_km'] != null ? (json['avg_pace_min_per_km'] as num).toDouble() : null,
      avgSpeedMps: json['avg_speed_mps'] != null ? (json['avg_speed_mps'] as num).toDouble() : null,
      totalElevationGainMeters: json['total_elevation_gain_meters'] != null ? (json['total_elevation_gain_meters'] as num).toDouble() : null,
      stressScore: json['stress_score'] != null ? (json['stress_score'] as num).toDouble() : null,
      stressLevel: json['stress_level'] as String?,
      systolicBP: json['systolic_bp'] != null ? (json['systolic_bp'] as num).toDouble() : null,
      diastolicBP: json['diastolic_bp'] != null ? (json['diastolic_bp'] as num).toDouble() : null,
      bloodGlucose: json['blood_glucose'] != null ? (json['blood_glucose'] as num).toDouble() : null,
      bodyTemperature: json['body_temperature'] != null ? (json['body_temperature'] as num).toDouble() : null,
      workoutSessionCount: json['workout_session_count'] != null ? (json['workout_session_count'] as num).toInt() : null,
      workoutSessionIdsJson: json['workout_session_ids_json'] as String?,
      lastHuaweiSyncTime: json['last_sync_time'] != null ? DateTime.parse(json['last_sync_time'] as String) : null,
      huaweiDataSourceId: json['huawei_data_source_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    return {
      'date': dateStr,
      'total_sleep_minutes': totalSleepMinutes,
      'deep_sleep_minutes': deepSleepMinutes,
      'rem_sleep_minutes': remSleepMinutes,
      'light_sleep_minutes': lightSleepMinutes,
      'awake_minutes': awakeMinutes,
      'sleep_onset_latency_minutes': sleepOnsetLatencyMinutes,
      'sleep_efficiency': sleepEfficiency,
      'resting_heart_rate': restingHeartRate,
      'average_heart_rate': averageHeartRate,
      'max_heart_rate': maxHeartRate,
      'min_heart_rate': minHeartRate,
      'heart_rate_sample_count': heartRateSampleCount,
      'hrv': hrv,
      'steps': steps,
      'total_calories': totalCalories,
      'active_calories': activeCalories,
      'calories_burned': caloriesBurned,
      'distance_meters': distanceMeters,
      'active_minutes': activeMinutes,
      'exercise_duration_minutes': exerciseDurationMinutes,
      'floors_climbed': floorsClimbed,
      'weight_kg': weightKg,
      'bmi': bmi,
      'body_fat_percent': bodyFatPercent,
      'muscle_mass_kg': muscleMassKg,
      'body_water_percent': bodyWaterPercent,
      'bone_mass_kg': boneMassKg,
      'blood_oxygen_spo2': bloodOxygenSpO2,
      'respiratory_rate': respiratoryRate,
      'vo2_max': vo2Max,
      'recovery_time_hours': recoveryTimeHours,
      'avg_cadence': avgCadence,
      'avg_pace_min_per_km': avgPaceMinPerKm,
      'avg_speed_mps': avgSpeedMps,
      'total_elevation_gain_meters': totalElevationGainMeters,
      'stress_score': stressScore,
      'stress_level': stressLevel,
      'systolic_bp': systolicBP,
      'diastolic_bp': diastolicBP,
      'blood_glucose': bloodGlucose,
      'body_temperature': bodyTemperature,
      'workout_session_count': workoutSessionCount,
      'workout_session_ids_json': workoutSessionIdsJson,
      'last_sync_time': lastHuaweiSyncTime?.toIso8601String(),
      'huawei_data_source_id': huaweiDataSourceId,
    };
  }
}
