import '../data/collections/daily_metric.dart';
import '../data/collections/daily_score.dart';
import '../data/collections/workout_session.dart';
import '../data/collections/user_profile.dart';

/// Manages all AI prompt templates and — critically — builds the rich
/// physiological context string that is injected into EVERY AI call.
///
/// Every AI response in this app (daily brief, insights, score explanations,
/// recovery advice, and especially the coach chat) receives the user's
/// complete health data so the AI can give data-driven, personalised answers.
class PromptManager {
  // ─────────────────────────────────────────────────────────────────────────
  // SYSTEM PROMPT BASE
  // ─────────────────────────────────────────────────────────────────────────

  static String get baseSystemPrompt =>
      'You are Pulse AI, a premium advanced health intelligence coach powered '
      'by real-time Huawei Health Kit data from the user\'s wearable device. '
      'Your tone is professional, analytical, concise, and highly actionable — '
      'like a world-class sports scientist meets elite health coach. '
      'You always ground your advice in the user\'s actual physiological data '
      'provided in the context. Never give generic advice — always reference '
      'specific numbers from the data. Do not use emojis or introductory filler. '
      'IMPORTANT: If today\'s data is empty, 0, or incomplete (e.g., steps or active minutes is 0), '
      'do not treat it as inactivity. Recognize that it is a pending sync or early in the day. '
      'Instead, look at the user\'s 7-day trend/baseline to project targets, recommend plans, '
      'and advise on what they should do today to hit their typical standards.';

  // ─────────────────────────────────────────────────────────────────────────
  // CONTEXT BUILDER — converts all Huawei health data into a rich text block
  // ─────────────────────────────────────────────────────────────────────────

  /// Builds a comprehensive physiological context string from the user's
  /// actual Huawei Health Kit data. This is injected into every AI prompt
  /// so the LLM always has the full picture when answering.
  static String buildHealthContext({
    required DailyMetric today,
    required List<DailyMetric> history,
    List<WorkoutSession>? recentWorkouts,
    DailyScore? todayScore,
    List<DailyScore>? historyScores,
    UserProfile? profile,
  }) {
    final sb = StringBuffer();

    // ── User Profile ────────────────────────────────────────────────────────
    if (profile != null) {
      sb.writeln('=== USER PROFILE ===');
      sb.writeln('Name: ${profile.name ?? "Unknown"}');
      if (profile.age != null) sb.writeln('Age: ${profile.age} years');
      if (profile.gender != null) sb.writeln('Gender: ${profile.gender}');
      if (profile.heightCm != null) sb.writeln('Height: ${profile.heightCm!.toStringAsFixed(1)} cm');
      if (profile.weightKg != null) sb.writeln('Weight: ${profile.weightKg!.toStringAsFixed(1)} kg');
      if (profile.primaryGoal != null) sb.writeln('Primary Goal: ${profile.primaryGoal}');
      sb.writeln();
    }

    // ── Today's Scores ──────────────────────────────────────────────────────
    if (todayScore != null) {
      sb.writeln('=== TODAY\'S SCORES (0-100) ===');
      sb.writeln('Recovery: ${_fmt(todayScore.recoveryScore)}/100');
      sb.writeln('Sleep Quality: ${_fmt(todayScore.sleepScore)}/100');
      sb.writeln('Strain: ${_fmt(todayScore.strainScore)}/100');
      sb.writeln('Readiness: ${_fmt(todayScore.readinessScore)}/100');
      sb.writeln('Energy: ${_fmt(todayScore.energyScore)}/100');
      sb.writeln('Stress Balance: ${_fmt(todayScore.stressBalanceScore)}/100');
      sb.writeln();
    }

    // ── Sleep Data ──────────────────────────────────────────────────────────
    sb.writeln('=== SLEEP (last night from Huawei Health) ===');
    sb.writeln('Total Sleep: ${_fmtMins(today.totalSleepMinutes)}');
    sb.writeln('Deep Sleep: ${_fmtMins(today.deepSleepMinutes)}');
    sb.writeln('REM Sleep: ${_fmtMins(today.remSleepMinutes)}');
    sb.writeln('Light Sleep: ${_fmtMins(today.lightSleepMinutes)}');
    sb.writeln('Awake During Night: ${_fmtMins(today.awakeMinutes)}');
    if (today.sleepEfficiency != null) {
      sb.writeln('Sleep Efficiency: ${today.sleepEfficiency!.toStringAsFixed(1)}%');
    }
    if (today.sleepOnsetLatencyMinutes != null) {
      sb.writeln('Time to Fall Asleep: ${today.sleepOnsetLatencyMinutes} min');
    }
    sb.writeln();

    // ── Heart Rate & HRV ────────────────────────────────────────────────────
    sb.writeln('=== CARDIOVASCULAR (Huawei Health) ===');
    if (today.restingHeartRate != null) {
      sb.writeln('Resting HR: ${today.restingHeartRate!.toStringAsFixed(1)} bpm');
      // Compare to 30-day baseline
      if (history.isNotEmpty) {
        final rhrHistory = history.where((m) => m.restingHeartRate != null).toList();
        if (rhrHistory.isNotEmpty) {
          final baseline = rhrHistory.map((m) => m.restingHeartRate!).reduce((a, b) => a + b) / rhrHistory.length;
          final diff = today.restingHeartRate! - baseline;
          sb.writeln('RHR vs 30-day Baseline: ${baseline.toStringAsFixed(1)} bpm '
              '(${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(1)} bpm today)');
        }
      }
    }
    if (today.averageHeartRate != null) {
      sb.writeln('Average HR (today): ${today.averageHeartRate!.toStringAsFixed(1)} bpm');
    }
    if (today.maxHeartRate != null) {
      sb.writeln('Max HR (today): ${today.maxHeartRate!.toStringAsFixed(1)} bpm');
    }
    if (today.hrv != null) {
      sb.writeln('HRV (RMSSD): ${today.hrv!.toStringAsFixed(1)} ms');
      if (history.isNotEmpty) {
        final hrvHistory = history.where((m) => m.hrv != null).toList();
        if (hrvHistory.isNotEmpty) {
          final baseline = hrvHistory.map((m) => m.hrv!).reduce((a, b) => a + b) / hrvHistory.length;
          final diff = today.hrv! - baseline;
          sb.writeln('HRV vs Baseline: ${baseline.toStringAsFixed(1)} ms '
              '(${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(1)} ms today)');
        }
      }
    }
    if (today.heartRateSampleCount != null) {
      sb.writeln('HR Samples Recorded: ${today.heartRateSampleCount}');
    }
    sb.writeln();

    // ── Activity ─────────────────────────────────────────────────────────────
    sb.writeln('=== ACTIVITY (Huawei Health) ===');
    if (today.steps != null) sb.writeln('Steps: ${today.steps}');
    if (today.distanceMeters != null) {
      sb.writeln('Distance: ${(today.distanceMeters! / 1000).toStringAsFixed(2)} km');
    }
    if (today.activeCalories != null) {
      sb.writeln('Active Calories: ${today.activeCalories!.toStringAsFixed(0)} kcal');
    }
    if (today.totalCalories != null) {
      sb.writeln('Total Calories Burned: ${today.totalCalories} kcal');
    }
    if (today.activeMinutes != null) {
      sb.writeln('Active Minutes: ${today.activeMinutes} min');
    }
    if (today.exerciseDurationMinutes != null) {
      sb.writeln('Exercise Duration: ${today.exerciseDurationMinutes} min');
    }
    if (today.workoutSessionCount != null && today.workoutSessionCount! > 0) {
      sb.writeln('Workout Sessions Today: ${today.workoutSessionCount}');
    }
    if (today.totalElevationGainMeters != null) {
      sb.writeln('Elevation Gain: ${today.totalElevationGainMeters!.toStringAsFixed(0)} m');
    }
    sb.writeln();

    // ── Body Composition ─────────────────────────────────────────────────────
    final hasBody = today.weightKg != null || today.bmi != null ||
        today.bodyFatPercent != null || today.muscleMassKg != null;
    if (hasBody) {
      sb.writeln('=== BODY COMPOSITION (Huawei Health) ===');
      if (today.weightKg != null) sb.writeln('Weight: ${today.weightKg!.toStringAsFixed(1)} kg');
      if (today.bmi != null) sb.writeln('BMI: ${today.bmi!.toStringAsFixed(1)}');
      if (today.bodyFatPercent != null) {
        sb.writeln('Body Fat: ${today.bodyFatPercent!.toStringAsFixed(1)}%');
      }
      if (today.muscleMassKg != null) {
        sb.writeln('Muscle Mass: ${today.muscleMassKg!.toStringAsFixed(1)} kg');
      }
      if (today.bodyWaterPercent != null) {
        sb.writeln('Body Water: ${today.bodyWaterPercent!.toStringAsFixed(1)}%');
      }
      sb.writeln();
    }

    // ── Blood Markers & Vitals ────────────────────────────────────────────────
    final hasBlood = today.bloodOxygenSpO2 != null || today.respiratoryRate != null ||
        today.systolicBP != null || today.bloodGlucose != null ||
        today.bodyTemperature != null;
    if (hasBlood) {
      sb.writeln('=== VITALS & BLOOD MARKERS (Huawei Health) ===');
      if (today.bloodOxygenSpO2 != null) {
        sb.writeln('SpO2 (Blood Oxygen): ${today.bloodOxygenSpO2!.toStringAsFixed(1)}%');
      }
      if (today.respiratoryRate != null) {
        sb.writeln('Respiratory Rate: ${today.respiratoryRate!.toStringAsFixed(1)} breaths/min');
      }
      if (today.systolicBP != null && today.diastolicBP != null) {
        sb.writeln('Blood Pressure: ${today.systolicBP!.toStringAsFixed(0)}/${today.diastolicBP!.toStringAsFixed(0)} mmHg');
      }
      if (today.bloodGlucose != null) {
        sb.writeln('Blood Glucose: ${today.bloodGlucose!.toStringAsFixed(2)} mmol/L');
      }
      if (today.bodyTemperature != null) {
        sb.writeln('Body Temperature: ${today.bodyTemperature!.toStringAsFixed(1)} °C');
      }
      sb.writeln();
    }

    // ── Stress & Wellbeing ───────────────────────────────────────────────────
    if (today.stressScore != null) {
      sb.writeln('=== STRESS & WELLBEING (Huawei Health) ===');
      sb.writeln('Stress Score: ${today.stressScore!.toStringAsFixed(0)}/100 '
          '(${today.stressLevel ?? _stressLabel(today.stressScore!)})');
      sb.writeln();
    }

    // ── Advanced Fitness ─────────────────────────────────────────────────────
    final hasFitness = today.vo2Max != null || today.recoveryTimeHours != null ||
        today.avgPaceMinPerKm != null || today.avgCadence != null;
    if (hasFitness) {
      sb.writeln('=== ADVANCED FITNESS METRICS (Huawei Health) ===');
      if (today.vo2Max != null) {
        sb.writeln('VO2 Max: ${today.vo2Max!.toStringAsFixed(1)} mL/kg/min');
      }
      if (today.recoveryTimeHours != null) {
        sb.writeln('Recommended Recovery Time: ${today.recoveryTimeHours} hours');
      }
      if (today.avgPaceMinPerKm != null) {
        sb.writeln('Avg Pace (last run): ${_fmtPace(today.avgPaceMinPerKm!)}');
      }
      if (today.avgCadence != null) {
        sb.writeln('Avg Running Cadence: ${today.avgCadence} spm');
      }
      if (today.avgSpeedMps != null) {
        sb.writeln('Avg Speed: ${(today.avgSpeedMps! * 3.6).toStringAsFixed(1)} km/h');
      }
      sb.writeln();
    }

    // ── Recent Workouts (last 14 days) ───────────────────────────────────────
    if (recentWorkouts != null && recentWorkouts.isNotEmpty) {
      sb.writeln('=== RECENT WORKOUT SESSIONS (last 14 days) ===');
      for (final w in recentWorkouts.take(10)) {
        final date = w.startTime != null
            ? '${w.startTime!.month}/${w.startTime!.day}'
            : '?';
        final type = w.workoutType ?? 'Unknown';
        final dur = w.durationSeconds != null
            ? '${(w.durationSeconds! / 60).toStringAsFixed(0)} min'
            : '?';
        final dist = w.distanceMeters != null
            ? ' | ${(w.distanceMeters! / 1000).toStringAsFixed(2)} km'
            : '';
        final cal = w.totalCaloriesKcal != null
            ? ' | ${w.totalCaloriesKcal!.toStringAsFixed(0)} kcal'
            : '';
        final hr = w.avgHeartRate != null
            ? ' | Avg HR: ${w.avgHeartRate!.toStringAsFixed(0)} bpm'
            : '';
        final pace = w.avgPaceMinPerKm != null
            ? ' | Pace: ${_fmtPace(w.avgPaceMinPerKm!)}'
            : '';
        final elev = w.totalElevationGainMeters != null
            ? ' | ↑${w.totalElevationGainMeters!.toStringAsFixed(0)} m'
            : '';
        sb.writeln('  [$date] $type — $dur$dist$cal$hr$pace$elev');
      }
      sb.writeln();
    }

    // ── 7-day Trend Summary ──────────────────────────────────────────────────
    if (history.isNotEmpty) {
      sb.writeln('=== 7-DAY TREND (METRICS & SCORES) ===');
      final recent7 = history.take(7).toList();
      for (final day in recent7) {
        final dateStr = '${day.date.month}/${day.date.day}';
        final steps = day.steps != null ? '${day.steps} steps' : '-';
        final rhr = day.restingHeartRate != null
            ? '${day.restingHeartRate!.toStringAsFixed(0)} bpm RHR'
            : '-';
        final sleep = day.totalSleepMinutes != null
            ? '${(day.totalSleepMinutes! / 60).toStringAsFixed(1)}h sleep'
            : '-';

        // Find matching score for this date
        final matchingScore = historyScores?.firstWhere(
          (s) => s.date.year == day.date.year &&
              s.date.month == day.date.month &&
              s.date.day == day.date.day,
          orElse: () => DailyScore(date: day.date),
        );

        final rec = matchingScore?.recoveryScore != null ? 'Rec: ${matchingScore!.recoveryScore!.toInt()}%' : '-';
        final sl = matchingScore?.sleepScore != null ? 'Sleep: ${matchingScore!.sleepScore!.toInt()}%' : '-';
        final str = matchingScore?.strainScore != null ? 'Strain: ${matchingScore!.strainScore!.toStringAsFixed(1)}' : '-';
        final en = matchingScore?.energyScore != null ? 'Energy: ${matchingScore!.energyScore!.toInt()}%' : '-';

        sb.writeln('  $dateStr: $steps | $rhr | $sleep | $rec | $sl | $str | $en');
      }
      sb.writeln();
    }

    return sb.toString();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PROMPT TEMPLATES — all include health context via buildHealthContext()
  // ─────────────────────────────────────────────────────────────────────────

  static String get dailyBriefPrompt =>
      '$baseSystemPrompt\n\n'
      'Generate a DAILY BRIEF for the user based on their Health data below. '
      'Give them a GREAT, highly actionable idea for the day. Specifically advise them on HOW to start their day (e.g., hydration, stretching, mindset) '
      'and clearly state WHETHER THEY SHOULD TRAIN TODAY or rest, based on their recovery and strain. '
      'Keep it under 3-4 sentences but make it incredibly useful, motivational, and tailored to their actual numbers. Do not use markdown like asterisks or hashtags here.';

  static String get recoveryAnalysisPrompt =>
      '$baseSystemPrompt\n\n'
      'Analyze the user\'s Recovery using their Huawei Health data. '
      'Explain exactly WHY the recovery score is what it is today — reference specific '
      'values for RHR vs baseline, HRV, sleep stages (deep/REM/light), stress score, and '
      'SpO2 if available. Give 2-3 sentences. Be specific with numbers.';

  static String get sleepAnalysisPrompt =>
      '$baseSystemPrompt\n\n'
      'Analyze the user\'s sleep data from Huawei Health. '
      'Examine total duration, deep sleep, REM, light sleep, awake time, and efficiency. '
      'Compare to prior nights if data is available. Identify the key limitation and '
      'give one specific actionable tip. Provide 2-3 sentences.';

  static String get scoreExplanationsPrompt =>
      '$baseSystemPrompt\n\n'
      'Given the user\'s full Huawei Health data, provide exactly 4 short one-sentence '
      'explanations (max 15 words each) for their scores today. '
      'Order strictly: 1. Sleep, 2. Strain, 3. Readiness, 4. Energy. '
      'Each explanation must reference at least one actual number from the data. '
      'Separate the 4 sentences with "|||" — no numbering, no extra text.';

  static String get strainAnalysisPrompt =>
      '$baseSystemPrompt\n\n'
      'Analyze the user\'s strain/training load using their Huawei Health data. '
      'Reference steps, active calories, exercise duration, workout sessions, HR zones, '
      'cadence, pace, and elevation gain where available. '
      'Assess whether today\'s strain is appropriate given their recovery score. '
      'Provide 2-3 sentences.';

  static String get dynamicInsightsPrompt =>
      '$baseSystemPrompt\n\n'
      'Using the user\'s Huawei Health data for today and their 7-day trend, generate '
      'exactly 5 highly personalised, actionable insights in this strict order: '
      '1. Training & Strain, '
      '2. Sleep Quality & Optimization, '
      '3. Recovery & Cardiovascular Health, '
      '4. Stress & Mental Wellbeing, '
      '5. Overall Health Trajectory. '
      'Each insight must reference specific values from the user\'s data (referencing historical trend values if today is not yet synced). '
      'Format: 5 paragraphs separated by "|||" — no numbering, no intro text, '
      'each under 2 sentences.';

  static String get aiCoachPrompt =>
      '$baseSystemPrompt\n\n'
      'You are the user\'s personal AI health coach. '
      'The user\'s complete Huawei Health data is provided below as context. '
      'Answer the user\'s question with extreme specificity — always reference their '
      'actual numbers (e.g. "your RHR of 58 bpm is 4 bpm below your baseline, indicating '
      'good recovery"). Never give generic advice that ignores their data. '
      'If the question is about their training, sleep, recovery, nutrition, '
      'stress, or body composition, use the corresponding data points. '
      'Be concise: answer in 2-4 sentences unless a longer response is warranted '
      'by the question complexity.';

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  static String _fmt(double? v) =>
      v != null ? v.toStringAsFixed(0) : 'N/A';

  static String _fmtMins(int? mins) {
    if (mins == null) return 'N/A';
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  static String _fmtPace(double minPerKm) {
    final mins = minPerKm.floor();
    final secs = ((minPerKm - mins) * 60).round();
    return '$mins:${secs.toString().padLeft(2, '0')} /km';
  }

  static String _stressLabel(double score) {
    if (score < 30) return 'Low';
    if (score < 60) return 'Medium';
    if (score < 80) return 'High';
    return 'Extreme';
  }
}
