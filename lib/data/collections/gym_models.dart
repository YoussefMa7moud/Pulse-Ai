class GymRoutine {
  String? id;
  String? name;
  DateTime? startTime;
  DateTime? endTime;
  String? linkedActivityId;
  String? notes;
  bool isTemplate = false;

  List<GymExercise> exercises = [];

  GymRoutine({
    this.id,
    this.name,
    this.startTime,
    this.endTime,
    this.linkedActivityId,
    this.notes,
    this.isTemplate = false,
    List<GymExercise>? exercises,
  }) : exercises = exercises ?? [];

  factory GymRoutine.fromJson(Map<String, dynamic> json) {
    var rawExercises = json['gym_exercises'] as List? ?? [];
    return GymRoutine(
      id: json['id'] as String?,
      name: json['name'] as String?,
      startTime: json['start_time'] != null ? DateTime.parse(json['start_time'] as String) : null,
      endTime: json['end_time'] != null ? DateTime.parse(json['end_time'] as String) : null,
      linkedActivityId: json['linked_activity_id'] as String?,
      notes: json['notes'] as String?,
      isTemplate: json['is_template'] as bool? ?? false,
      exercises: rawExercises.map((e) => GymExercise.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'start_time': startTime?.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'linked_activity_id': linkedActivityId,
      'notes': notes,
      'is_template': isTemplate,
    };
  }
}

class GymExercise {
  String? id;
  String? routineId;
  String? name;
  String? targetMuscle;
  bool isCustom = false;

  List<GymSet> sets = [];

  GymExercise({
    this.id,
    this.routineId,
    this.name,
    this.targetMuscle,
    this.isCustom = false,
    List<GymSet>? sets,
  }) : sets = sets ?? [];

  factory GymExercise.fromJson(Map<String, dynamic> json) {
    var rawSets = json['gym_sets'] as List? ?? [];
    return GymExercise(
      id: json['id'] as String?,
      routineId: json['routine_id'] as String?,
      name: json['name'] as String?,
      targetMuscle: json['target_muscle'] as String?,
      isCustom: json['is_custom'] as bool? ?? false,
      sets: rawSets.map((s) => GymSet.fromJson(s as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (routineId != null) 'routine_id': routineId,
      'name': name,
      'target_muscle': targetMuscle,
      'is_custom': isCustom,
    };
  }
}

class GymSet {
  String? id;
  String? exerciseId;
  int? setNumber;
  double? weightKg;
  int? reps;
  bool isCompleted = false;

  GymSet({
    this.id,
    this.exerciseId,
    this.setNumber,
    this.weightKg,
    this.reps,
    this.isCompleted = false,
  });

  factory GymSet.fromJson(Map<String, dynamic> json) {
    return GymSet(
      id: json['id'] as String?,
      exerciseId: json['exercise_id'] as String?,
      setNumber: json['set_number'] != null ? (json['set_number'] as num).toInt() : null,
      weightKg: json['weight_kg'] != null ? (json['weight_kg'] as num).toDouble() : null,
      reps: json['reps'] != null ? (json['reps'] as num).toInt() : null,
      isCompleted: json['is_completed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (exerciseId != null) 'exercise_id': exerciseId,
      'set_number': setNumber,
      'weight_kg': weightKg,
      'reps': reps,
      'is_completed': isCompleted,
    };
  }
}
