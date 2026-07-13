import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme.dart';
import '../../../data/collections/workout_session.dart';
import '../../providers/data_providers.dart';
import '../../providers/providers.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/glass_container.dart';
import '../../../widgets/animated_background.dart';
import '../../../widgets/pulse_loader.dart';

/// Health screen — shows all health data for the selected day.
/// Every section maps to a specific health data type category.
class HealthScreen extends ConsumerWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricAsync = ref.watch(todayMetricsProvider);
    final workoutsAsync = ref.watch(todayWorkoutsProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Health Data'),
        actions: [
          metricAsync.when(
            data: (m) => m.lastHuaweiSyncTime != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Center(
                      child: Text(
                        'Synced ${_timeAgo(m.lastHuaweiSyncTime!)}',
                        style: TextStyle(
                            color: PulseTheme.secondary, fontSize: 11),
                      ),
                    ),
                  )
                : const SizedBox(),
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
          IconButton(
            icon: Icon(Icons.person_outline, color: PulseTheme.primary),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: AnimatedGradientBackground(
        child: SafeArea(
          child: metricAsync.when(
            data: (metric) {
              return RefreshIndicator(
                color: PulseTheme.primary,
                backgroundColor: PulseTheme.surfaceLight,
                onRefresh: () async {
                  final syncUseCase = ref.read(syncUseCaseProvider);
                  await syncUseCase.syncToday();
                  ref.invalidate(todayMetricsProvider);
                  ref.invalidate(todayWorkoutsProvider);
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    // ── Heart Rate & Cardiovascular ─────────────────────────────
                    _sectionHeader(context, 'Cardiovascular', Icons.favorite_rounded,
                        PulseTheme.recoveryLow),
                    _vitalsGrid([
                      _VitalItem('Resting HR', metric.restingHeartRate != null
                          ? '${metric.restingHeartRate!.toStringAsFixed(0)} bpm'
                          : '--',
                          Icons.favorite_border, PulseTheme.recoveryLow),
                      _VitalItem('Avg HR', metric.averageHeartRate != null
                          ? '${metric.averageHeartRate!.toStringAsFixed(0)} bpm'
                          : '--',
                          Icons.monitor_heart_outlined, PulseTheme.strainPrimary),
                      _VitalItem('Max HR', metric.maxHeartRate != null
                          ? '${metric.maxHeartRate!.toStringAsFixed(0)} bpm'
                          : '--',
                          Icons.arrow_upward_rounded, PulseTheme.recoveryLow),
                      _VitalItem('HRV', metric.hrv != null
                          ? '${metric.hrv!.toStringAsFixed(1)} ms'
                          : '--',
                          Icons.waves, PulseTheme.recoveryHigh),
                    ]),

                    const SizedBox(height: 20),

                    // ── Sleep ────────────────────────────────────────────────────
                    _sectionHeader(context, 'Sleep', Icons.bedtime_rounded,
                        PulseTheme.sleepPrimary),
                    _sleepCard(context, metric),

                    const SizedBox(height: 20),

                    // ── Activity ──────────────────────────────────────────────────
                    _sectionHeader(context, 'Activity', Icons.directions_run_rounded,
                        PulseTheme.strainPrimary),
                    _vitalsGrid([
                      _VitalItem('Steps', metric.steps?.toString() ?? '--',
                          Icons.directions_walk, PulseTheme.strainPrimary),
                      _VitalItem('Distance', metric.distanceMeters != null
                          ? '${(metric.distanceMeters! / 1000).toStringAsFixed(2)} km'
                          : '--',
                          Icons.map_outlined, PulseTheme.accent),
                      _VitalItem('Active Cal', metric.activeCalories != null
                          ? '${metric.activeCalories!.toStringAsFixed(0)} kcal'
                          : '--',
                          Icons.local_fire_department_rounded, PulseTheme.recoveryMedium),
                      _VitalItem('Active Min', metric.activeMinutes != null
                          ? '${metric.activeMinutes} min'
                          : '--',
                          Icons.timer_outlined, PulseTheme.strainPrimary),
                      _VitalItem('Elevation', metric.totalElevationGainMeters != null
                          ? '+${metric.totalElevationGainMeters!.toStringAsFixed(0)} m'
                          : '--',
                          Icons.terrain_rounded, PulseTheme.accent),
                      _VitalItem('Total Cal', metric.totalCalories != null
                          ? '${metric.totalCalories} kcal'
                          : '--',
                          Icons.bolt_rounded, PulseTheme.recoveryMedium),
                    ]),

                    const SizedBox(height: 20),

                    // ── Respiratory & Oxygen ──────────────────────────────────────
                    _sectionHeader(context, 'Respiratory & Oxygen',
                        Icons.air_rounded, PulseTheme.recoveryHigh),
                    _vitalsGrid([
                      _VitalItem('SpO2', metric.bloodOxygenSpO2 != null
                          ? '${metric.bloodOxygenSpO2!.toStringAsFixed(1)}%'
                          : '--',
                          Icons.water_drop_outlined, PulseTheme.recoveryHigh),
                      _VitalItem('Resp. Rate', metric.respiratoryRate != null
                          ? '${metric.respiratoryRate!.toStringAsFixed(1)} br/min'
                          : '--',
                          Icons.air, PulseTheme.recoveryHigh),
                    ]),

                    const SizedBox(height: 20),

                    // ── Stress & Wellbeing ───────────────────────────────────────
                    if (metric.stressScore != null) ...[
                      _sectionHeader(context, 'Stress & Wellbeing',
                          Icons.psychology_rounded, PulseTheme.recoveryMedium),
                      _stressCard(context, metric),
                      const SizedBox(height: 20),
                    ],

                    // ── Body Composition ─────────────────────────────────────────
                    if (metric.weightKg != null || metric.bmi != null ||
                        metric.bodyFatPercent != null) ...[
                      _sectionHeader(context, 'Body Composition',
                          Icons.accessibility_new_rounded, PulseTheme.accent),
                      _vitalsGrid([
                        if (metric.weightKg != null)
                          _VitalItem('Weight',
                              '${metric.weightKg!.toStringAsFixed(1)} kg',
                              Icons.scale_outlined, PulseTheme.accent),
                        if (metric.bmi != null)
                          _VitalItem('BMI',
                              metric.bmi!.toStringAsFixed(1),
                              Icons.square_foot_rounded, PulseTheme.accent),
                        if (metric.bodyFatPercent != null)
                          _VitalItem('Body Fat',
                              '${metric.bodyFatPercent!.toStringAsFixed(1)}%',
                              Icons.pie_chart_outline_rounded, PulseTheme.recoveryMedium),
                        if (metric.muscleMassKg != null)
                          _VitalItem('Muscle Mass',
                              '${metric.muscleMassKg!.toStringAsFixed(1)} kg',
                              Icons.fitness_center_rounded, PulseTheme.strainPrimary),
                      ]),
                      const SizedBox(height: 20),
                    ],

                    // ── Blood Markers ────────────────────────────────────────────
                    if (metric.systolicBP != null || metric.bloodGlucose != null ||
                        metric.bodyTemperature != null) ...[
                      _sectionHeader(context, 'Blood Markers',
                          Icons.opacity_rounded, PulseTheme.recoveryLow),
                      _vitalsGrid([
                        if (metric.systolicBP != null && metric.diastolicBP != null)
                          _VitalItem('Blood Pressure',
                              '${metric.systolicBP!.toStringAsFixed(0)}/'
                              '${metric.diastolicBP!.toStringAsFixed(0)}',
                              Icons.bloodtype_rounded, PulseTheme.recoveryLow),
                        if (metric.bloodGlucose != null)
                          _VitalItem('Blood Glucose',
                              '${metric.bloodGlucose!.toStringAsFixed(2)} mmol/L',
                              Icons.science_outlined, PulseTheme.recoveryMedium),
                        if (metric.bodyTemperature != null)
                          _VitalItem('Temperature',
                              '${metric.bodyTemperature!.toStringAsFixed(1)} °C',
                              Icons.thermostat_rounded, PulseTheme.strainPrimary),
                      ]),
                      const SizedBox(height: 20),
                    ],

                    // ── Advanced Fitness ─────────────────────────────────────────
                    _sectionHeader(context, 'Advanced Fitness',
                        Icons.speed_rounded, PulseTheme.recoveryHigh),
                    _vitalsGrid([
                      _VitalItem('VO2 Max', metric.vo2Max != null
                          ? '${metric.vo2Max!.toStringAsFixed(1)} mL/kg/min'
                          : '--',
                          Icons.trending_up_rounded, PulseTheme.recoveryHigh),
                      _VitalItem('Recovery', metric.recoveryTimeHours != null
                          ? '${metric.recoveryTimeHours}h recommended'
                          : '--',
                          Icons.hotel_rounded, PulseTheme.sleepPrimary),
                      _VitalItem('Avg Pace', metric.avgPaceMinPerKm != null
                          ? _fmtPace(metric.avgPaceMinPerKm!)
                          : '--',
                          Icons.timer_rounded, PulseTheme.strainPrimary),
                      _VitalItem('Cadence', metric.avgCadence != null
                          ? '${metric.avgCadence} spm'
                          : '--',
                          Icons.loop_rounded, PulseTheme.accent),
                    ]),

                    const SizedBox(height: 20),

                    // ── Workout Sessions ─────────────────────────────────────────
                    _sectionHeader(context, "Today's Workouts",
                        Icons.sports_rounded, PulseTheme.strainPrimary),
                    workoutsAsync.when(
                      data: (workouts) => workouts.isEmpty
                          ? GlassCard(
                              child: Center(
                                child: Text(
                                  'No workout sessions recorded today',
                                  style: TextStyle(color: PulseTheme.secondary),
                                ),
                              ),
                            )
                          : Column(
                              children: workouts
                                  .map((w) => _workoutCard(context, w))
                                  .toList(),
                            ),
                      loading: () => const SizedBox(
                        height: 80,
                        child: PulseLoadingIndicator(size: 40, message: 'Loading workouts...'),
                      ),
                      error: (e, _) => Text('Error: $e'),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
            loading: () => const Center(
              child: PulseLoadingIndicator(message: 'Retrieving health indicators...'),
            ),
            error: (e, _) => Center(child: Text('Error loading health data: $e')),
          ),
        ),
      ),
    );
  }

  // ─── UI helpers ────────────────────────────────────────────────────────────

  Widget _sectionHeader(BuildContext context, String title, IconData icon,
      Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }

  Widget _vitalsGrid(List<_VitalItem> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.4, // Increased height to prevent overflow
      ),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i];
        return GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(item.icon, color: item.color, size: 22),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(item.value,
                        style: TextStyle(
                            color: PulseTheme.isDark ? Colors.white : Colors.black87,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    ),
                    Text(item.label,
                        style: TextStyle(
                            color: PulseTheme.secondary, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sleepCard(BuildContext context, m) {
    final total = m.totalSleepMinutes;
    final deep = m.deepSleepMinutes ?? 0;
    final rem = m.remSleepMinutes ?? 0;
    final light = m.lightSleepMinutes ?? 0;
    final awake = m.awakeMinutes ?? 0;

    String fmtMins(int? mins) {
      if (mins == null || mins == 0) return '--';
      final h = mins ~/ 60;
      final min = mins % 60;
      return h > 0 ? '${h}h ${min}m' : '${min}m';
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Sleep',
                      style: TextStyle(
                          color: PulseTheme.secondary, fontSize: 12)),
                  Text(fmtMins(total),
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: PulseTheme.sleepPrimary)),
                ],
              ),
              if (m.sleepEfficiency != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Efficiency',
                        style: TextStyle(
                            color: PulseTheme.secondary, fontSize: 12)),
                    Text('${m.sleepEfficiency!.toStringAsFixed(0)}%',
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Sleep stage bar
          if (total != null && total > 0) ...[
            _sleepBar(deep, rem, light, awake, total),
            const SizedBox(height: 8),
          ],
          // Stage breakdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _stageLegend('Deep', fmtMins(m.deepSleepMinutes), const Color(0xFF6366F1)),
              _stageLegend('REM', fmtMins(m.remSleepMinutes), PulseTheme.sleepPrimary),
              _stageLegend('Light', fmtMins(m.lightSleepMinutes), PulseTheme.accent),
              _stageLegend('Awake', fmtMins(m.awakeMinutes), PulseTheme.secondary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sleepBar(int deep, int rem, int light, int awake, int total) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 10,
        child: Row(
          children: [
            _barSegment(deep, total, const Color(0xFF6366F1)),
            _barSegment(rem, total, PulseTheme.sleepPrimary),
            _barSegment(light, total, PulseTheme.accent),
            _barSegment(awake, total, PulseTheme.secondary),
          ],
        ),
      ),
    );
  }

  Widget _barSegment(int val, int total, Color color) {
    if (val <= 0) return const SizedBox.shrink();
    final flexVal = (val / total * 100).round().clamp(1, 100);
    return Expanded(
      flex: flexVal,
      child: Container(color: color),
    );
  }

  Widget _stageLegend(String label, String value, Color color) {
    return Column(
      children: [
        Container(width: 10, height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: PulseTheme.secondary, fontSize: 10)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Widget _stressCard(BuildContext context, m) {
    final score = m.stressScore ?? 0;
    final level = m.stressLevel ?? 'Unknown';
    final color = score < 30
        ? PulseTheme.recoveryHigh
        : score < 60
            ? PulseTheme.recoveryMedium
            : PulseTheme.recoveryLow;

    return GlassCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Stress Score',
                    style: TextStyle(color: PulseTheme.secondary, fontSize: 12)),
                Text('${score.toStringAsFixed(0)}/100',
                    style: TextStyle(
                        fontSize: 36, fontWeight: FontWeight.bold, color: color)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(level,
                      style: TextStyle(
                          color: color, fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 8,
              backgroundColor: Colors.white.withOpacity(0.05),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _workoutCard(BuildContext context, WorkoutSession w) {
    final dur = w.durationSeconds != null
        ? '${(w.durationSeconds! / 60).toStringAsFixed(0)} min'
        : '--';
    final dist = w.distanceMeters != null
        ? '${(w.distanceMeters! / 1000).toStringAsFixed(2)} km'
        : null;
    final cal = w.totalCaloriesKcal != null
        ? '${w.totalCaloriesKcal!.toStringAsFixed(0)} kcal'
        : null;
    final hr = w.avgHeartRate != null
        ? '${w.avgHeartRate!.toStringAsFixed(0)} bpm avg'
        : null;
    final pace = w.avgPaceMinPerKm != null
        ? _fmtPace(w.avgPaceMinPerKm!)
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: PulseTheme.strainPrimary.withOpacity(0.15),
              ),
              child: Icon(_sportIcon(w.workoutType),
                  color: PulseTheme.strainPrimary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(w.workoutType ?? 'Workout',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(dur,
                      style: TextStyle(
                          color: PulseTheme.secondary, fontSize: 13)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (dist != null) _chip(dist, PulseTheme.accent),
                      if (cal != null) _chip(cal, PulseTheme.strainPrimary),
                      if (hr != null) _chip(hr, PulseTheme.recoveryLow),
                      if (pace != null) _chip(pace, PulseTheme.recoveryHigh),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  IconData _sportIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'running': return Icons.directions_run;
      case 'cycling': return Icons.directions_bike;
      case 'swimming': return Icons.pool;
      case 'walking': return Icons.directions_walk;
      case 'strength training': return Icons.fitness_center;
      case 'yoga': return Icons.self_improvement;
      default: return Icons.sports;
    }
  }

  String _fmtPace(double minPerKm) {
    final mins = minPerKm.floor();
    final secs = ((minPerKm - mins) * 60).round();
    return '$mins:${secs.toString().padLeft(2, '0')} /km';
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _VitalItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _VitalItem(this.label, this.value, this.icon, this.color);
}
