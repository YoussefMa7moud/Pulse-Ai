import '../data/collections/daily_metric.dart';
import '../data/collections/daily_score.dart';

/// Calculates all Pulse AI scores (0–100) from health data.
///
/// All calculations use the expanded DailyMetric fields including:
/// stress score, HRV, SpO2, body temperature, body composition,
/// blood pressure, VO2 Max, cadence, elevation — giving far more
/// physiological signal than the old Health Connect implementation.
class ScoreEngine {

  static DailyScore calculateScores(
      DailyMetric today, List<DailyMetric> history) {
    final score = DailyScore(date: today.date);

    // Check if we have ANY meaningful data at all
    final hasAnyData = (today.totalSleepMinutes != null && today.totalSleepMinutes! > 0) ||
        today.restingHeartRate != null ||
        today.averageHeartRate != null ||
        today.hrv != null ||
        (today.steps != null && today.steps! > 0) ||
        (today.activeCalories != null && today.activeCalories! > 0);

    if (!hasAnyData) {
      score.isDataComplete = false;
      score.sleepScore = null;
      score.strainScore = null;
      score.recoveryScore = null;
      score.readinessScore = null;
      score.energyScore = null;
      score.stressBalanceScore = null;
      return score;
    }

    // Mark as complete if we have sleep data; partial otherwise
    score.isDataComplete = (today.totalSleepMinutes != null && today.totalSleepMinutes! > 0);

    score.sleepScore       = _calculateSleepScore(today, history);
    score.strainScore      = _calculateStrainScore(today);

    double? yesterdayStrain;
    if (history.isNotEmpty) {
      final yesterdayDate = today.date.subtract(const Duration(days: 1));
      try {
        final yesterdayMetric = history.firstWhere(
          (m) =>
              m.date.year == yesterdayDate.year &&
              m.date.month == yesterdayDate.month &&
              m.date.day == yesterdayDate.day,
        );
        yesterdayStrain = _calculateStrainScore(yesterdayMetric);
      } catch (_) {
        yesterdayStrain = _calculateStrainScore(history.first);
      }
    }

    score.recoveryScore    = _calculateRecoveryScore(
        today, score.sleepScore, yesterdayStrain, history);
    score.readinessScore   = _calculateReadinessScore(
        score.recoveryScore, score.sleepScore);
    score.energyScore      = _calculateEnergyScore(
        score.sleepScore, score.recoveryScore, score.strainScore);
    score.stressBalanceScore = _calculateStressBalance(
        today, score.sleepScore, score.recoveryScore);

    return score;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SLEEP SCORE  (0–100)
  // ─────────────────────────────────────────────────────────────────────────

  static double _calculateSleepScore(
      DailyMetric m, List<DailyMetric> history) {
    // ── Duration component (0–40 pts) ───────────────────────────────────────
    double durationScore = 0;
    if (m.totalSleepMinutes != null) {
      // Ideal = 480 min (8 hours); penalty below 300 min, cap at 480
      durationScore = (m.totalSleepMinutes! / 480.0) * 40;
      durationScore = durationScore.clamp(0, 40);
    }

    // ── Quality component — deep + REM (0–40 pts) ───────────────────────────
    double qualityScore = 20; // neutral default
    if (m.totalSleepMinutes != null && m.totalSleepMinutes! > 0) {
      final deepSleep = m.deepSleepMinutes ?? 0;
      final remSleep = m.remSleepMinutes ?? 0;
      if (deepSleep == 0 && remSleep == 0) {
        // If stages are not recorded, fall back to a reasonable default based on sleep efficiency
        final efficiency = m.sleepEfficiency ?? 85.0;
        qualityScore = (efficiency / 100.0) * 35; // default to a safe 30-35 range
      } else {
        final qualityRatio = (deepSleep + remSleep) / m.totalSleepMinutes!;
        qualityScore = (qualityRatio / 0.4) * 40;
      }
      qualityScore = qualityScore.clamp(0, 40);
    }

    // ── Efficiency bonus (0–10 pts) ─────────────────────────────
    double efficiencyBonus = 0;
    if (m.sleepEfficiency != null) {
      efficiencyBonus = ((m.sleepEfficiency! - 70) / 30) * 10;
      efficiencyBonus = efficiencyBonus.clamp(0, 10);
    }

    // ── Awake penalty with 30-minute buffer (0-15 pts penalty max) ───────────
    double awakePenalty = 0;
    if (m.awakeMinutes != null && m.awakeMinutes! > 30) {
      // Subtract the 30-minute buffer, then penalize 0.3 points per minute awake
      awakePenalty = (m.awakeMinutes! - 30) * 0.3;
      awakePenalty = awakePenalty.clamp(0, 15);
    }

    // ── HRV bonus: high nocturnal HRV = restorative sleep ──────────────────
    double hrvBonus = 0;
    if (m.hrv != null && history.isNotEmpty) {
      final hrvHistory =
          history.where((h) => h.hrv != null).toList();
      if (hrvHistory.isNotEmpty) {
        final baseline =
            hrvHistory.map((h) => h.hrv!).reduce((a, b) => a + b) /
                hrvHistory.length;
        final diff = m.hrv! - baseline;
        hrvBonus = (diff * 0.3).clamp(-5, 5); // ±5 pts
      }
    }

    final finalScore =
        durationScore + qualityScore + efficiencyBonus - awakePenalty + hrvBonus;
    return finalScore.clamp(0, 100);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STRAIN SCORE  (0–100)
  // ─────────────────────────────────────────────────────────────────────────

  static double _calculateStrainScore(DailyMetric m) {
    // ── Cardiovascular Load (0-40 pts) — based on Heart Rate Reserve (HRR) ───
    double cardioScore = 15; // neutral baseline
    if (m.averageHeartRate != null && m.restingHeartRate != null && m.maxHeartRate != null) {
      final hrr = m.maxHeartRate! - m.restingHeartRate!;
      if (hrr > 30) {
        final hrrPercent = (m.averageHeartRate! - m.restingHeartRate!) / hrr;
        cardioScore = (hrrPercent * 100).clamp(0, 40);
      }
    } else if (m.averageHeartRate != null && m.restingHeartRate != null) {
      // Fallback with just avg + resting HR
      final diff = m.averageHeartRate! - m.restingHeartRate!;
      cardioScore = (diff * 1.5).clamp(0, 40);
    }

    // ── Active calories volume (0–30 pts) ────────────────────────────────────
    final calScore = (((m.activeCalories ?? 0) / 800) * 30).clamp(0.0, 30.0);

    // ── Exercise duration volume (0–20 pts) ──────────────────────────────────
    final exerScore = (((m.exerciseDurationMinutes ?? 0) / 45) * 20).clamp(0.0, 20.0);

    // ── Steps volume (0–10 pts) ──────────────────────────────────────────────
    final stepScore = (((m.steps ?? 0) / 10000) * 10).clamp(0.0, 10.0);

    // ── Elevation gain / Cadence Intensity bonus (0–10 pts) ──────────────────
    double intensityBonus = 0;
    if (m.totalElevationGainMeters != null && m.totalElevationGainMeters! > 100) {
      intensityBonus += (m.totalElevationGainMeters! / 100).clamp(0.0, 5.0);
    }
    if (m.avgCadence != null && m.avgCadence! > 160) {
      intensityBonus += 5.0; // High cadence = higher intensity running/cycling
    }

    final finalScore =
        cardioScore + calScore + exerScore + stepScore + intensityBonus;
    return finalScore.clamp(0, 100);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RECOVERY SCORE  (0–100)
  // ─────────────────────────────────────────────────────────────────────────

  static double _calculateRecoveryScore(DailyMetric m, double? sleepScore,
      double? yesterdayStrain, List<DailyMetric> history) {

    // ── RHR vs baseline (0–30 pts) ───────────────────────────────────────────
    final rhr = m.restingHeartRate ?? 62.0;
    double baselineRhr = 62.0;
    if (history.isNotEmpty) {
      final rhrHistory = history.where((h) => h.restingHeartRate != null);
      if (rhrHistory.isNotEmpty) {
        baselineRhr = rhrHistory
                .map((h) => h.restingHeartRate!)
                .reduce((a, b) => a + b) /
            rhrHistory.length;
      }
    }
    double rhrDiff = baselineRhr - rhr; // positive = lower than baseline = good
    double rhrScore = 20 + (rhrDiff * 2.5);
    rhrScore = rhrScore.clamp(0, 30);

    // ── HRV (0–20 pts) — higher HRV = better recovery ───────────────────────
    double hrvScore = 10; // neutral
    if (m.hrv != null && history.isNotEmpty) {
      final hrvHistory = history.where((h) => h.hrv != null).toList();
      if (hrvHistory.isNotEmpty) {
        final baseline = hrvHistory
                .map((h) => h.hrv!)
                .reduce((a, b) => a + b) /
            hrvHistory.length;
        final diff = m.hrv! - baseline;
        hrvScore = 10 + (diff * 0.5);
        hrvScore = hrvScore.clamp(0, 20);
      }
    }

    // ── Sleep component (0–25 pts) ───────────────────────────────────────────
    final sleepComponent = (sleepScore ?? 50) * 0.25;

    // ── Stress penalty from stress score (0–15 pts) ──────────────────
    double stressComponent = 12; // neutral
    if (m.stressScore != null) {
      stressComponent = 15 - (m.stressScore! / 100) * 15;
      stressComponent = stressComponent.clamp(0, 15);
    }

    // ── SpO2 component (0–5 pts) — low SpO2 reduces recovery ────────────────
    double spo2Bonus = 2.5; // neutral
    if (m.bloodOxygenSpO2 != null) {
      if (m.bloodOxygenSpO2! >= 98) {
        spo2Bonus = 5;
      } else if (m.bloodOxygenSpO2! >= 95) {
        spo2Bonus = 2.5;
      } else {
        spo2Bonus = 0; // below 95% is concerning
      }
    }

    // ── Body temperature deviation penalty ──────────────────────────────────
    double tempPenalty = 0;
    if (m.bodyTemperature != null) {
      final tempDev = (m.bodyTemperature! - 36.6).abs();
      if (tempDev > 0.5) tempPenalty = tempDev * 2;
    }

    // ── Yesterday strain penalty ─────────────────────────────────────────────
    final strainPenalty = (yesterdayStrain ?? 40) * 0.05;

    final finalScore = rhrScore + hrvScore + sleepComponent +
        stressComponent + spo2Bonus - tempPenalty - strainPenalty;
    return finalScore.clamp(0, 100);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // READINESS SCORE  (0–100)
  // ─────────────────────────────────────────────────────────────────────────

  static double _calculateReadinessScore(
      double? recovery, double? sleep) {
    // Weighted average: recovery (60%) + sleep (40%)
    return ((recovery ?? 50) * 0.6 + (sleep ?? 50) * 0.4).clamp(0, 100);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ENERGY SCORE  (0–100)
  // ─────────────────────────────────────────────────────────────────────────

  static double _calculateEnergyScore(
      double? sleep, double? recovery, double? strain) {
    final baseEnergy = ((sleep ?? 50) * 0.45 + (recovery ?? 50) * 0.45);
    final strainDrain = (strain ?? 30) * 0.10;
    return (baseEnergy - strainDrain).clamp(0, 100);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STRESS BALANCE SCORE  (0–100)
  // ─────────────────────────────────────────────────────────────────────────

  static double _calculateStressBalance(
      DailyMetric m, double? sleep, double? recovery) {

    // ── Stress score (primary signal) ────────────────────────────────
    double stressComponent = 50; // neutral default
    if (m.stressScore != null) {
      // Invert: 0 stress = 100 balance, 100 stress = 0 balance
      stressComponent = 100 - m.stressScore!;
    } else if (m.averageHeartRate != null) {
      // Fallback: elevated avg HR suggests stress
      stressComponent = 50;
      if (m.averageHeartRate! > 85) {
        stressComponent -= (m.averageHeartRate! - 85) * 2;
      }
    }
    stressComponent = stressComponent.clamp(0, 100);

    // Blend with sleep and recovery
    final balance = stressComponent * 0.5 +
        (sleep ?? 50) * 0.25 +
        (recovery ?? 50) * 0.25;

    return balance.clamp(0, 100);
  }
}
