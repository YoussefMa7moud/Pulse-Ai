class WorkoutSession {
  String? id;
  String? activityId;
  late DateTime date;

  DateTime? startTime;
  DateTime? endTime;
  int? durationSeconds;

  String? workoutType;
  int? sportTypeCode;

  double? distanceMeters;
  double? totalCaloriesKcal;
  double? avgHeartRate;
  double? maxHeartRate;
  double? minHeartRate;
  double? avgPaceMinPerKm;
  double? avgSpeedMps;
  double? maxSpeedMps;
  int? avgCadence;
  int? maxCadence;

  double? totalElevationGainMeters;
  double? totalElevationLossMeters;
  double? maxAltitudeMeters;
  double? minAltitudeMeters;

  String? heartRateZonesJson;

  double? vo2MaxEstimate;
  double? aerobicTrainingEffect;
  double? anaerobicTrainingEffect;
  double? avgPowerWatts;
  double? maxPowerWatts;
  int? strokeCount;
  int? steps;

  String? gpsRouteJson;

  WorkoutSession({
    this.id,
    this.activityId,
    required this.date,
    this.startTime,
    this.endTime,
    this.durationSeconds,
    this.workoutType,
    this.sportTypeCode,
    this.distanceMeters,
    this.totalCaloriesKcal,
    this.avgHeartRate,
    this.maxHeartRate,
    this.minHeartRate,
    this.avgPaceMinPerKm,
    this.avgSpeedMps,
    this.maxSpeedMps,
    this.avgCadence,
    this.maxCadence,
    this.totalElevationGainMeters,
    this.totalElevationLossMeters,
    this.maxAltitudeMeters,
    this.minAltitudeMeters,
    this.heartRateZonesJson,
    this.vo2MaxEstimate,
    this.aerobicTrainingEffect,
    this.anaerobicTrainingEffect,
    this.avgPowerWatts,
    this.maxPowerWatts,
    this.strokeCount,
    this.steps,
    this.gpsRouteJson,
  });

  factory WorkoutSession.fromJson(Map<String, dynamic> json) {
    return WorkoutSession(
      id: json['id'] as String?,
      activityId: json['activity_id'] as String?,
      date: json['date'] != null ? DateTime.parse(json['date'] as String) : DateTime.now(),
      startTime: json['start_time'] != null ? DateTime.parse(json['start_time'] as String) : null,
      endTime: json['end_time'] != null ? DateTime.parse(json['end_time'] as String) : null,
      durationSeconds: json['duration_seconds'] != null ? (json['duration_seconds'] as num).toInt() : null,
      workoutType: json['workout_type'] as String?,
      sportTypeCode: json['sport_type_code'] != null ? (json['sport_type_code'] as num).toInt() : null,
      distanceMeters: json['distance_meters'] != null ? (json['distance_meters'] as num).toDouble() : null,
      totalCaloriesKcal: json['total_calories_kcal'] != null ? (json['total_calories_kcal'] as num).toDouble() : null,
      avgHeartRate: json['avg_heart_rate'] != null ? (json['avg_heart_rate'] as num).toDouble() : null,
      maxHeartRate: json['max_heart_rate'] != null ? (json['max_heart_rate'] as num).toDouble() : null,
      minHeartRate: json['min_heart_rate'] != null ? (json['min_heart_rate'] as num).toDouble() : null,
      avgPaceMinPerKm: json['avg_pace_min_per_km'] != null ? (json['avg_pace_min_per_km'] as num).toDouble() : null,
      avgSpeedMps: json['avg_speed_mps'] != null ? (json['avg_speed_mps'] as num).toDouble() : null,
      maxSpeedMps: json['max_speed_mps'] != null ? (json['max_speed_mps'] as num).toDouble() : null,
      avgCadence: json['avg_cadence'] != null ? (json['avg_cadence'] as num).toInt() : null,
      maxCadence: json['max_cadence'] != null ? (json['max_cadence'] as num).toInt() : null,
      totalElevationGainMeters: json['total_elevation_gain_meters'] != null ? (json['total_elevation_gain_meters'] as num).toDouble() : null,
      totalElevationLossMeters: json['total_elevation_loss_meters'] != null ? (json['total_elevation_loss_meters'] as num).toDouble() : null,
      maxAltitudeMeters: json['max_altitude_meters'] != null ? (json['max_altitude_meters'] as num).toDouble() : null,
      minAltitudeMeters: json['min_altitude_meters'] != null ? (json['min_altitude_meters'] as num).toDouble() : null,
      heartRateZonesJson: json['heart_rate_zones_json'] as String?,
      vo2MaxEstimate: json['vo2_max_estimate'] != null ? (json['vo2_max_estimate'] as num).toDouble() : null,
      aerobicTrainingEffect: json['aerobic_training_effect'] != null ? (json['aerobic_training_effect'] as num).toDouble() : null,
      anaerobicTrainingEffect: json['anaerobic_training_effect'] != null ? (json['anaerobic_training_effect'] as num).toDouble() : null,
      avgPowerWatts: json['avg_power_watts'] != null ? (json['avg_power_watts'] as num).toDouble() : null,
      maxPowerWatts: json['max_power_watts'] != null ? (json['max_power_watts'] as num).toDouble() : null,
      strokeCount: json['stroke_count'] != null ? (json['stroke_count'] as num).toInt() : null,
      steps: json['steps'] != null ? (json['steps'] as num).toInt() : null,
      gpsRouteJson: json['gps_route_json'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    return {
      if (id != null) 'id': id,
      'activity_id': activityId,
      'date': dateStr,
      'start_time': startTime?.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'duration_seconds': durationSeconds,
      'workout_type': workoutType,
      'sport_type_code': sportTypeCode,
      'distance_meters': distanceMeters,
      'total_calories_kcal': totalCaloriesKcal,
      'avg_heart_rate': avgHeartRate,
      'max_heart_rate': maxHeartRate,
      'min_heart_rate': minHeartRate,
      'avg_pace_min_per_km': avgPaceMinPerKm,
      'avg_speed_mps': avgSpeedMps,
      'max_speed_mps': maxSpeedMps,
      'avg_cadence': avgCadence,
      'max_cadence': maxCadence,
      'total_elevation_gain_meters': totalElevationGainMeters,
      'total_elevation_loss_meters': totalElevationLossMeters,
      'max_altitude_meters': maxAltitudeMeters,
      'min_altitude_meters': minAltitudeMeters,
      'heart_rate_zones_json': heartRateZonesJson,
      'vo2_max_estimate': vo2MaxEstimate,
      'aerobic_training_effect': aerobicTrainingEffect,
      'anaerobic_training_effect': anaerobicTrainingEffect,
      'avg_power_watts': avgPowerWatts,
      'max_power_watts': maxPowerWatts,
      'stroke_count': strokeCount,
      'steps': steps,
      'gps_route_json': gpsRouteJson,
    };
  }
}
