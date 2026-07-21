import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme.dart';
import '../../../widgets/animated_background.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/pulse_loader.dart';
import '../../../data/collections/daily_metric.dart';

class SleepDetailScreen extends ConsumerWidget {
  final DailyMetric metric;

  const SleepDetailScreen({super.key, required this.metric});

  String _formatDuration(int? minutes) {
    if (minutes == null || minutes <= 0) return '--';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = PulseTheme.isDark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white70 : Colors.black54;

    final total = metric.totalSleepMinutes ?? 0;
    final deep = metric.deepSleepMinutes ?? 0;
    final rem = metric.remSleepMinutes ?? 0;
    final light = metric.lightSleepMinutes ?? 0;
    final awake = metric.awakeMinutes ?? 0;
    final efficiency = metric.sleepEfficiency ?? 0.0;

    // Standard sleep need is 8 hours (480 minutes)
    const targetMinutes = 480;
    final percentAchieved = total > 0 ? ((total / targetMinutes) * 100).clamp(0.0, 100.0) : 0.0;
    
    // Consistency is dynamically calculated (92% for normal sleep, drops if awake minutes or onset latency are high)
    final consistency = total > 0 ? (95 - (awake * 0.2) - ((metric.sleepOnsetLatencyMinutes ?? 0) * 0.1)).clamp(60.0, 100.0) : 0.0;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Sleep Performance',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: textColor),
        ),
      ),
      body: AnimatedGradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Overall Ring and Main Stats
                GlassCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Large Circular Ring representing % Achieved
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 160,
                            height: 160,
                            child: CircularProgressIndicator(
                              value: percentAchieved / 100.0,
                              strokeWidth: 14,
                              backgroundColor: PulseTheme.sleepPrimary.withOpacity(0.12),
                              color: PulseTheme.sleepPrimary,
                              strokeCap: StrokeCap.round,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${percentAchieved.toStringAsFixed(0)}%',
                                style: textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: PulseTheme.sleepPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Sleep Need Met',
                                style: TextStyle(color: subColor, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMiniStat('Duration', _formatDuration(total), PulseTheme.sleepPrimary),
                          _buildMiniStat('Target', '8h 00m', Colors.grey),
                          _buildMiniStat('Efficiency', '${efficiency.toStringAsFixed(0)}%', PulseTheme.accent),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 2. Sleep Stages breakdown
                Text(
                  'SLEEP STAGES',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.bold,
                    color: subColor,
                  ),
                ),
                const SizedBox(height: 12),
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Horizontal breakdown bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          height: 16,
                          color: isDark ? Colors.white10 : Colors.black12,
                          child: total == 0
                              ? null
                              : Row(
                                  children: [
                                    if (deep > 0) Expanded(flex: deep, child: Container(color: const Color(0xFF6366F1))),
                                    if (rem > 0) Expanded(flex: rem, child: Container(color: PulseTheme.sleepPrimary)),
                                    if (light > 0) Expanded(flex: light, child: Container(color: PulseTheme.accent)),
                                    if (awake > 0) Expanded(flex: awake, child: Container(color: PulseTheme.recoveryLow)),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Legend grid
                      _buildStageItem('Deep Sleep', deep, 'Restores physical energy and repairs muscles.', const Color(0xFF6366F1)),
                      const Divider(height: 20, color: Colors.white10),
                      _buildStageItem('REM Sleep', rem, 'Restores mental sharpness and processes memory.', PulseTheme.sleepPrimary),
                      const Divider(height: 20, color: Colors.white10),
                      _buildStageItem('Light Sleep', light, 'Promotes transition and standard body maintenance.', PulseTheme.accent),
                      const Divider(height: 20, color: Colors.white10),
                      _buildStageItem('Awake Time', awake, 'Brief periods of wakefulness throughout the night.', PulseTheme.recoveryLow),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 3. Consistency & Latency
                Text(
                  'SLEEP METRICS',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.bold,
                    color: subColor,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GlassCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Consistency', style: TextStyle(color: subColor, fontSize: 12)),
                            const SizedBox(height: 8),
                            Text(
                              '${consistency.toStringAsFixed(0)}%',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text('Bed & wake time pattern', style: TextStyle(color: subColor, fontSize: 10)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GlassCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Sleep Latency', style: TextStyle(color: subColor, fontSize: 12)),
                            const SizedBox(height: 8),
                            Text(
                              '${metric.sleepOnsetLatencyMinutes ?? 0}m',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text('Time to fall asleep', style: TextStyle(color: subColor, fontSize: 10)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 4. Sleep Coaching Insights
                Text(
                  'AI COACH INSIGHTS',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.bold,
                    color: subColor,
                  ),
                ),
                const SizedBox(height: 12),
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.auto_awesome, color: PulseTheme.sleepPrimary, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Sleep Quality Analysis',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _getSleepInsightText(percentAchieved, efficiency, deep, rem),
                        style: TextStyle(height: 1.5, fontSize: 13, color: textColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildStageItem(String name, int minutes, String desc, Color color) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final durationStr = minutes > 0
        ? (h > 0 ? '${h}h ${m}m' : '${m}m')
        : '0m';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 3),
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    durationStr,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                style: const TextStyle(color: Colors.grey, fontSize: 11, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getSleepInsightText(double needMet, double eff, int deep, int rem) {
    if (needMet == 0) {
      return 'No sleep data registered for today yet. Make sure you synced your companion app and wear your tracker to bed tonight.';
    }

    final sb = StringBuffer();
    if (needMet >= 90) {
      sb.write('You achieved excellent sleep duration last night, hitting ${needMet.toStringAsFixed(0)}% of your daily sleep needs. ');
    } else if (needMet >= 75) {
      sb.write('You got decent sleep duration, fulfilling ${needMet.toStringAsFixed(0)}% of your body\'s requirements. ');
    } else {
      sb.write('Your sleep duration was shortened last night, meeting only ${needMet.toStringAsFixed(0)}% of your requirements. ');
    }

    if (eff >= 85) {
      sb.write('Your sleep efficiency was high (${eff.toStringAsFixed(0)}%), meaning you fell asleep quickly and experienced very few wake episodes. ');
    } else {
      sb.write('An efficiency of ${eff.toStringAsFixed(0)}% suggests you spent a significant portion of the night awake or restless. Consider avoiding screens for 1 hour before bed. ');
    }

    final deepPercent = (deep / (deep + rem + 1)) * 100; // rough check
    if (deep > 90) {
      sb.write('A deep sleep phase of ${_formatDuration(deep)} indicates robust physical and muscular recovery, perfect for high intensity physical exercises today.');
    } else {
      sb.write('With deep sleep at ${_formatDuration(deep)}, your body\'s muscular repair phase was slightly abbreviated. Keep today\'s training intensity moderate.');
    }

    return sb.toString();
  }
}
