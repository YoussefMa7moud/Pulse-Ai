class DailyScore {
  late DateTime date;
  bool isDataComplete = false;

  double? recoveryScore;
  double? sleepScore;
  double? strainScore;
  double? readinessScore;
  double? energyScore;
  double? stressBalanceScore;

  String? recoveryExplanation;
  String? sleepExplanation;
  String? strainExplanation;

  DailyScore({
    required this.date,
    this.isDataComplete = false,
    this.recoveryScore,
    this.sleepScore,
    this.strainScore,
    this.readinessScore,
    this.energyScore,
    this.stressBalanceScore,
    this.recoveryExplanation,
    this.sleepExplanation,
    this.strainExplanation,
  });

  factory DailyScore.fromJson(Map<String, dynamic> json) {
    return DailyScore(
      date: json['date'] != null ? DateTime.parse(json['date'] as String) : DateTime.now(),
      isDataComplete: json['is_data_complete'] as bool? ?? false,
      recoveryScore: json['recovery_score'] != null ? (json['recovery_score'] as num).toDouble() : null,
      sleepScore: json['sleep_score'] != null ? (json['sleep_score'] as num).toDouble() : null,
      strainScore: json['strain_score'] != null ? (json['strain_score'] as num).toDouble() : null,
      readinessScore: json['readiness_score'] != null ? (json['readiness_score'] as num).toDouble() : null,
      energyScore: json['energy_score'] != null ? (json['energy_score'] as num).toDouble() : null,
      stressBalanceScore: json['stress_balance_score'] != null ? (json['stress_balance_score'] as num).toDouble() : null,
      recoveryExplanation: json['recovery_explanation'] as String?,
      sleepExplanation: json['sleep_explanation'] as String?,
      strainExplanation: json['strain_explanation'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    return {
      'date': dateStr,
      'is_data_complete': isDataComplete,
      'recovery_score': recoveryScore,
      'sleep_score': sleepScore,
      'strain_score': strainScore,
      'readiness_score': readinessScore,
      'energy_score': energyScore,
      'stress_balance_score': stressBalanceScore,
      'recovery_explanation': recoveryExplanation,
      'sleep_explanation': sleepExplanation,
      'strain_explanation': strainExplanation,
    };
  }
}
