class UserProfile {
  String? id;
  String? name;
  int? age;
  String? gender;
  double? heightCm;
  double? weightKg;
  String? primaryGoal;

  bool hasCompletedOnboarding = false;
  bool isHuaweiHealthEnabled = false;
  String? huaweiDisplayName;
  DateTime? lastSyncDate;

  String defaultAiProvider = 'groq';
  String defaultAiModel = 'llama-3.3-70b-versatile';

  UserProfile({
    this.id,
    this.name,
    this.age,
    this.gender,
    this.heightCm,
    this.weightKg,
    this.primaryGoal,
    this.hasCompletedOnboarding = false,
    this.isHuaweiHealthEnabled = false,
    this.huaweiDisplayName,
    this.lastSyncDate,
    this.defaultAiProvider = 'groq',
    this.defaultAiModel = 'llama-3.3-70b-versatile',
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String?,
      name: json['name'] as String?,
      age: json['age'] != null ? (json['age'] as num).toInt() : null,
      gender: json['gender'] as String?,
      heightCm: json['height_cm'] != null ? (json['height_cm'] as num).toDouble() : null,
      weightKg: json['weight_kg'] != null ? (json['weight_kg'] as num).toDouble() : null,
      primaryGoal: json['primary_goal'] as String?,
      hasCompletedOnboarding: json['has_completed_onboarding'] as bool? ?? false,
      isHuaweiHealthEnabled: json['is_health_enabled'] as bool? ?? false,
      lastSyncDate: json['last_sync_date'] != null ? DateTime.parse(json['last_sync_date'] as String) : null,
      defaultAiProvider: json['default_ai_provider'] as String? ?? 'groq',
      defaultAiModel: json['default_ai_model'] as String? ?? 'llama-3.3-70b-versatile',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'age': age,
      'gender': gender,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'primary_goal': primaryGoal,
      'has_completed_onboarding': hasCompletedOnboarding,
      'is_health_enabled': isHuaweiHealthEnabled,
      'last_sync_date': lastSyncDate?.toIso8601String(),
      'default_ai_provider': defaultAiProvider,
      'default_ai_model': defaultAiModel,
    };
  }
}
