import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../providers/providers.dart';
import '../../providers/data_providers.dart';
import '../../../data/database_service.dart';
import '../../../widgets/glass_container.dart';
import '../../../widgets/styled_card.dart';
import '../../../widgets/animated_background.dart';
import '../../../widgets/pulse_loader.dart';
import '../../../services/ai_service.dart';
import '../../../widgets/animated_counter.dart';
import '../../../widgets/staggered_animation.dart';
import '../../../data/collections/daily_metric.dart';
import '../../../utils/sync_helper.dart';


class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Map<String, String> _estimateSleepTimes(int? totalSleepMinutes) {
    if (totalSleepMinutes == null || totalSleepMinutes == 0) {
      return {'bedtime': '--', 'waketime': '--'};
    }
    // Assume a default wake time of 7:30 AM for display
    final wakeTime = DateTime(2026, 1, 1, 7, 30);
    final bedTime = wakeTime.subtract(Duration(minutes: totalSleepMinutes));
    
    final timeFormat = DateFormat('h:mm a');
    return {
      'bedtime': timeFormat.format(bedTime),
      'waketime': timeFormat.format(wakeTime),
    };
  }

  Map<String, String> _getActualSleepTimes(DailyMetric metric) {
    final startVal = metric.systolicBP;
    final endVal = metric.diastolicBP;
    
    if (startVal != null && startVal >= 0 && endVal != null && endVal >= 0) {
      final startMin = startVal.toInt();
      final endMin = endVal.toInt();
      
      final bedtimeHour = startMin ~/ 60;
      final bedtimeMin = startMin % 60;
      final wakeHour = endMin ~/ 60;
      final wakeMin = endMin % 60;
      
      final bedtimeTime = DateTime(2026, 1, 1, bedtimeHour, bedtimeMin);
      final wakeTime = DateTime(2026, 1, 1, wakeHour, wakeMin);
      
      return {
        'bedtime': DateFormat('h:mm a').format(bedtimeTime),
        'waketime': DateFormat('h:mm a').format(wakeTime),
      };
    }
    
    return _estimateSleepTimes(metric.totalSleepMinutes);
  }

  Widget _buildBedtimeIndicator(DailyMetric metric) {
    final times = _getActualSleepTimes(metric);
    final isDark = PulseTheme.isDark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Stack(
      children: [
        Positioned(
          left: 16,
          top: -6,
          child: Opacity(
            opacity: isDark ? 0.05 : 0.03,
            child: Icon(Icons.nightlight_round, size: 76, color: Colors.indigoAccent),
          ),
        ),
        Positioned(
          right: 16,
          top: -6,
          child: Opacity(
            opacity: isDark ? 0.05 : 0.03,
            child: Icon(Icons.wb_sunny_rounded, size: 76, color: Colors.orangeAccent),
          ),
        ),
        StyledCard(
          color: PulseTheme.sleepPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: PulseTheme.sleepPrimary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.bedtime_rounded, color: PulseTheme.sleepPrimary, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BEDTIME',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: PulseTheme.secondary, letterSpacing: 1.0),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        times['bedtime']!,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                      ),
                    ],
                  ),
                ],
              ),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: CustomPaint(
                    painter: _CurveSeparatorPainter(
                      color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'WOKE UP',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: PulseTheme.secondary, letterSpacing: 1.0),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        times['waketime']!,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.wb_sunny_rounded, color: Colors.amber, size: 24),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good Morning';
    if (hour >= 12 && hour < 17) return 'Good Afternoon';
    if (hour >= 17 && hour < 21) return 'Good Evening';
    return 'Good Night';
  }

  Color _getRecoveryColor(double score) {
    if (score >= 67) return PulseTheme.recoveryHigh;
    if (score >= 34) return PulseTheme.recoveryMedium;
    return PulseTheme.recoveryLow;
  }

  Widget _buildPremiumScoreCard(
    BuildContext context,
    String title,
    double? value,
    Color color,
    IconData icon,
    String route,
  ) {
    final isDark = PulseTheme.isDark;
    final textColor = isDark ? Colors.white : Colors.black87;

    String statusText = '--';
    if (value != null) {
      final t = title.toLowerCase();
      if (t.contains('recovery')) {
        statusText = value >= 67 ? 'Optimal' : (value >= 34 ? 'Resting' : 'Low');
      } else if (t.contains('sleep')) {
        statusText = value >= 80 ? 'Optimal' : (value >= 50 ? 'Fair' : 'Poor');
      } else if (t.contains('strain')) {
        statusText = value >= 70 ? 'High' : (value >= 30 ? 'Moderate' : 'Light');
      } else if (t.contains('readiness')) {
        statusText = value >= 70 ? 'Peak' : (value >= 40 ? 'Moderate' : 'Low');
      } else if (t.contains('energy')) {
        statusText = value >= 70 ? 'Charged' : (value >= 40 ? 'Medium' : 'Low');
      } else if (t.contains('stress')) {
        statusText = value >= 70 ? 'Calm' : (value >= 40 ? 'Balanced' : 'High');
      } else {
        statusText = value >= 70 ? 'Good' : 'Elevated';
      }
    }

    IconData bgIcon = icon;
    final t = title.toLowerCase();
    if (t.contains('recovery')) {
      bgIcon = Icons.favorite_rounded;
    } else if (t.contains('sleep')) {
      bgIcon = Icons.bedtime_rounded;
    } else if (t.contains('strain')) {
      bgIcon = Icons.offline_bolt_rounded;
    } else if (t.contains('readiness')) {
      bgIcon = Icons.speed_rounded;
    } else if (t.contains('energy')) {
      bgIcon = Icons.battery_charging_full_rounded;
    } else if (t.contains('stress')) {
      bgIcon = Icons.spa_rounded;
    }

    return GestureDetector(
      onTap: () => context.push(route),
      child: StyledCard(
        color: color,
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Subtle background watermark icon
              Positioned(
                bottom: -20,
                left: -10,
                child: Icon(
                  bgIcon,
                  size: 90,
                  color: color.withOpacity(0.06),
                ),
              ),
              // Main content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(icon, color: color, size: 14),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: PulseTheme.secondary,
                                  letterSpacing: 1.0,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 1),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      statusText,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: textColor.withOpacity(0.9),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedProgressRing(
                      value: value == null ? 0.0 : (value / 100.0),
                      color: color,
                      size: 50,
                      strokeWidth: 3.5,
                      backgroundColor: color.withOpacity(0.08),
                      child: value == null
                          ? Text('-', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: textColor))
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedCounter(
                                  value: value,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: textColor,
                                    height: 1.0,
                                  ),
                                ),
                                Text(
                                  '/100',
                                  style: TextStyle(
                                    fontSize: 7,
                                    fontWeight: FontWeight.w700,
                                    color: PulseTheme.secondary,
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildIncompleteDataCard(BuildContext context, WidgetRef ref) {
    final textColor = PulseTheme.isDark ? Colors.white : Colors.black87;

    return Center(
      child: GlassContainer(
        padding: const EdgeInsets.all(24),
        borderColor: PulseTheme.recoveryLow.withOpacity(0.5),
        child: Column(
          children: [
            Icon(Icons.info_outline, color: PulseTheme.recoveryLow, size: 48),
            const SizedBox(height: 16),
            Text(
              "Incomplete Data",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: PulseTheme.recoveryLow,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              "We need more data (like Sleep and Heart Rate) to generate your scores for today. Please sync your band or Wear it to bed.",
              textAlign: TextAlign.center,
              style: TextStyle(color: textColor.withOpacity(0.7)),
            ),
            const SizedBox(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.sync_rounded),
                  label: const Text("Sync Now", style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    await runWithSyncOverlay(context, () async {
                      final syncUseCase = ref.read(syncUseCaseProvider);
                      await syncUseCase.syncAll(daysBack: 14);
                    }, message: 'Syncing your health data...');

                    if (!context.mounted) return;
                    ref.invalidate(todayMetricsProvider);
                    ref.invalidate(todayScoresProvider);
                    ref.invalidate(recentWorkoutsProvider);
                    ref.invalidate(historyScoresProvider);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PulseTheme.recoveryLow,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.lock_open_rounded),
                  label: const Text("Link Connect (Permissions)", style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    final health = ref.read(healthServiceProvider);
                    bool success = false;
                    try {
                      success = await health.requestPermissions();
                    } catch (_) {}

                    if (!success || !context.mounted) return;

                    await runWithSyncOverlay(context, () async {
                      final syncUseCase = ref.read(syncUseCaseProvider);
                      await syncUseCase.syncAll(daysBack: 14);
                    }, message: 'Connecting and syncing your data...');

                    if (!context.mounted) return;
                    ref.invalidate(todayMetricsProvider);
                    ref.invalidate(todayScoresProvider);
                    ref.invalidate(healthAuthStateProvider);
                    ref.invalidate(recentWorkoutsProvider);
                    ref.invalidate(historyScoresProvider);
                    ref.invalidate(historyMetricsProvider);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textColor,
                    side: BorderSide(color: textColor.withOpacity(0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final scoresAsync = ref.watch(todayScoresProvider);
    final metricsAsync = ref.watch(todayMetricsProvider);
    final historyScoresAsync = ref.watch(historyScoresProvider);
    final textColor = PulseTheme.isDark ? Colors.white : Colors.black87;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: AnimatedGradientBackground(
        child: SafeArea(
          child: RefreshIndicator(
            color: PulseTheme.primary,
            backgroundColor: PulseTheme.surfaceLight,
            onRefresh: () async {
              final db = ref.read(databaseProvider);
              await db.clearAllInsightsCache();
              final syncUseCase = ref.read(syncUseCaseProvider);
              await syncUseCase.syncToday();
              ref.invalidate(todayScoresProvider);
              ref.invalidate(todayMetricsProvider);
              ref.invalidate(historyMetricsProvider);
              ref.invalidate(historyScoresProvider);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [

                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Greeting & Profile Avatar Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getGreeting(),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: PulseTheme.secondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              profileAsync.when(
                                data: (profile) => Text(
                                  profile.name ?? 'User',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                loading: () => const Text('Loading...', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                                error: (_, __) => const Text('User', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: () => context.push('/profile'),
                            child: Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: PulseTheme.accent.withOpacity(0.4), width: 1.5),
                                gradient: LinearGradient(
                                  colors: [
                                    PulseTheme.accent.withOpacity(0.2),
                                    PulseTheme.sleepPrimary.withOpacity(0.2),
                                  ],
                                ),
                              ),
                              child: Icon(
                                Icons.person,
                                color: textColor,
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                      _DateNavigator(),
                      const SizedBox(height: 24),

                      // Scores 2x2 Grid + AI Brief underneath
                      scoresAsync.when(
                        data: (score) {
                          final isComplete = score?.isDataComplete ?? false;
                          final recoveryVal = isComplete ? score?.recoveryScore : null;
                          final sleepVal = isComplete ? score?.sleepScore : null;
                          final strainVal = isComplete ? score?.strainScore : null;
                          final readinessVal = isComplete ? score?.readinessScore : null;
                          final energyVal = isComplete ? score?.energyScore : null;
                          final stressVal = isComplete ? score?.stressBalanceScore : null;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              GridView(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 1.35,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                                children: [
                                  _buildPremiumScoreCard(
                                    context,
                                    'Recovery',
                                    recoveryVal,
                                    _getRecoveryColor(recoveryVal ?? 0.0),
                                    Icons.favorite_rounded,
                                    '/score_detail/recovery',
                                  ),
                                  _buildPremiumScoreCard(
                                    context,
                                    'Sleep',
                                    sleepVal,
                                    PulseTheme.sleepPrimary,
                                    Icons.bedtime_rounded,
                                    '/score_detail/sleep',
                                  ),
                                  _buildPremiumScoreCard(
                                    context,
                                    'Strain',
                                    strainVal,
                                    PulseTheme.strainPrimary,
                                    Icons.directions_run_rounded,
                                    '/score_detail/strain',
                                  ),
                                  _buildPremiumScoreCard(
                                    context,
                                    'Readiness',
                                    readinessVal,
                                    PulseTheme.accent,
                                    Icons.bolt_rounded,
                                    '/score_detail/readiness',
                                  ),
                                  _buildPremiumScoreCard(
                                    context,
                                    'Energy',
                                    energyVal,
                                    Colors.orangeAccent,
                                    Icons.battery_charging_full_rounded,
                                    '/score_detail/energy',
                                  ),
                                  _buildPremiumScoreCard(
                                    context,
                                    'Stress Balance',
                                    stressVal,
                                    Colors.tealAccent,
                                    Icons.psychology_rounded,
                                    '/score_detail/stress',
                                  ),
                                ].asMap().entries.map((entry) {
                                  return StaggeredFadeSlide(
                                    index: entry.key,
                                    child: entry.value,
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 24),
                              metricsAsync.when(
                                data: (metrics) => _buildBedtimeIndicator(metrics),
                                loading: () => const SizedBox(),
                                error: (_, __) => const SizedBox(),
                              ),
                              const SizedBox(height: 24),
                              if (!isComplete) ...[
                                _buildIncompleteDataCard(context, ref),
                              ] else ...[
                                _PremiumDailyBrief(score: score!),
                              ],
                              const SizedBox(height: 32),
                              Text(
                                'METRICS TRENDS',
                                style: TextStyle(
                                  letterSpacing: 2,
                                  color: PulseTheme.secondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              historyScoresAsync.when(
                                data: (history) => _TrendChart(scoresHistory: history),
                                loading: () => const SizedBox(
                                  height: 220,
                                  child: PulseLoadingIndicator(size: 60, message: 'Plotting trends...'),
                                ),
                                error: (_, __) => const SizedBox(),
                              ),
                            ],
                          );
                        },
                        loading: () => const SizedBox(
                          height: 220,
                          child: PulseLoadingIndicator(message: 'Loading health intelligence...'),
                        ),
                        error: (error, _) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              GridView(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 1.35,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                                children: [
                                  _buildPremiumScoreCard(
                                    context,
                                    'Recovery',
                                    null,
                                    PulseTheme.recoveryLow,
                                    Icons.favorite_rounded,
                                    '/score_detail/recovery',
                                  ),
                                  _buildPremiumScoreCard(
                                    context,
                                    'Sleep',
                                    null,
                                    PulseTheme.sleepPrimary,
                                    Icons.bedtime_rounded,
                                    '/score_detail/sleep',
                                  ),
                                  _buildPremiumScoreCard(
                                    context,
                                    'Strain',
                                    null,
                                    PulseTheme.strainPrimary,
                                    Icons.directions_run_rounded,
                                    '/score_detail/strain',
                                  ),
                                  _buildPremiumScoreCard(
                                    context,
                                    'Readiness',
                                    null,
                                    PulseTheme.accent,
                                    Icons.bolt_rounded,
                                    '/score_detail/readiness',
                                  ),
                                  _buildPremiumScoreCard(
                                    context,
                                    'Energy',
                                    null,
                                    Colors.orangeAccent,
                                    Icons.battery_charging_full_rounded,
                                    '/score_detail/energy',
                                  ),
                                  _buildPremiumScoreCard(
                                    context,
                                    'Stress Balance',
                                    null,
                                    Colors.tealAccent,
                                    Icons.psychology_rounded,
                                    '/score_detail/stress',
                                  ),
                                ].asMap().entries.map((entry) {
                                  return StaggeredFadeSlide(
                                    index: entry.key,
                                    child: entry.value,
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 16),
                              _buildIncompleteDataCard(context, ref),
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  'Sync Error: $error',
                                  style: TextStyle(color: PulseTheme.recoveryLow, fontSize: 12, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 96),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumMetricRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  const _PremiumMetricRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = PulseTheme.isDark ? Colors.white : Colors.black87;

    return StyledCard(
      color: color,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: PulseTheme.secondary, fontSize: 13)),
              ],
            ),
          ),
          Builder(builder: (context) {
            final parts = value.split(' ');
            final numVal = double.tryParse(parts.first) ?? 0.0;
            final suffix = parts.length > 1 ? ' ${parts.sublist(1).join(' ')}' : '';
            return AnimatedCounter(
              value: numVal,
              suffix: suffix,
              decimals: value.contains('.') ? 1 : 0,
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: textColor),
            );
          }),
        ],
      ),
    );
  }
}

class _MetricSquare extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String unit;
  final Color color;

  const _MetricSquare({
    required this.icon,
    required this.title,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = PulseTheme.isDark ? Colors.white : Colors.black87;

    return StyledCard(
      color: color,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: PulseTheme.secondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedCounter(
                value: double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0,
                decimals: value.contains('.') ? 1 : 0,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: textColor, height: 1),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(unit, style: TextStyle(color: PulseTheme.secondary, fontSize: 14)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PremiumDailyBrief extends ConsumerStatefulWidget {
  final dynamic score;
  const _PremiumDailyBrief({required this.score});

  @override
  ConsumerState<_PremiumDailyBrief> createState() => _PremiumDailyBriefState();
}

class _PremiumDailyBriefState extends ConsumerState<_PremiumDailyBrief> {
  String? brief;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadBrief();
  }

  @override
  void didUpdateWidget(_PremiumDailyBrief oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score != widget.score) {
      setState(() {
        loading = true;
      });
      _loadBrief();
    }
  }

  Future<void> _loadBrief() async {
    final aiService = ref.read(aiServicesProvider);
    try {
      final res = await aiService.getDailyBrief(widget.score);
      if (mounted) {
        setState(() {
          brief = res;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          brief = "Could not generate daily brief. Make sure you set GROQ_API_KEY in the .env file.";
          loading = false;
        });
      }
    }
  }

  Widget _buildBriefSection({
    required String title,
    required String content,
    required Color color,
    required IconData icon,
    required Color textColor,
  }) {
    return StyledCard(
      color: color,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: color,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  content,
                  style: TextStyle(fontSize: 13, height: 1.5, color: textColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = PulseTheme.isDark;
    final textColor = isDark ? Colors.white.withOpacity(0.9) : Colors.black87;

    final text = brief ?? '';
    String focusText = '';
    String avoidText = '';
    String tipText = '';

    if (text.isNotEmpty) {
      final RegExp focusReg = RegExp(r'FOCUS:\s*(.*?)(?=AVOID:|TIP:|$)', caseSensitive: false, dotAll: true);
      final RegExp avoidReg = RegExp(r'AVOID:\s*(.*?)(?=FOCUS:|TIP:|$)', caseSensitive: false, dotAll: true);
      final RegExp tipReg = RegExp(r'TIP:\s*(.*?)(?=FOCUS:|AVOID:|$)', caseSensitive: false, dotAll: true);

      focusText = focusReg.firstMatch(text)?.group(1)?.trim() ?? '';
      avoidText = avoidReg.firstMatch(text)?.group(1)?.trim() ?? '';
      tipText = tipReg.firstMatch(text)?.group(1)?.trim() ?? '';
    }

    if (focusText.isEmpty && avoidText.isEmpty && tipText.isEmpty) {
      focusText = text; // Fallback
    }

    if (loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(strokeWidth: 3, color: Colors.cyan),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'DAILY BRIEF',
          style: TextStyle(
            fontSize: 13,
            letterSpacing: 2,
            color: PulseTheme.secondary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (focusText.isNotEmpty)
          _buildBriefSection(
            title: 'TODAY\'S FOCUS',
            content: focusText,
            color: PulseTheme.recoveryHigh,
            icon: Icons.directions_run_rounded,
            textColor: textColor,
          ),
        if (avoidText.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildBriefSection(
            title: 'WHAT TO AVOID',
            content: avoidText,
            color: PulseTheme.recoveryLow,
            icon: Icons.warning_amber_rounded,
            textColor: textColor,
          ),
        ],
        if (tipText.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildBriefSection(
            title: 'NIGHT TIME TIP',
            content: tipText,
            color: PulseTheme.sleepPrimary,
            icon: Icons.bedtime_rounded,
            textColor: textColor,
          ),
        ],
      ],
    );
  }
}

class _TrendChart extends StatefulWidget {
  final List<dynamic> scoresHistory;

  const _TrendChart({required this.scoresHistory});

  @override
  State<_TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<_TrendChart> {
  bool _showRecovery = true;
  bool _showSleep = true;
  bool _showStrain = true;
  bool _showReadiness = false;
  bool _showEnergy = false;
  bool _showStress = false;

  Widget _buildToggleChip(String label, bool isSelected, Color color, VoidCallback onTap) {
    final activeBgColor = color.withOpacity(0.12);
    final activeBorderColor = color.withOpacity(0.4);
    final isDark = PulseTheme.isDark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeBgColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeBorderColor : (isDark ? Colors.white10 : Colors.black12),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.grey.shade400,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isSelected ? (isDark ? Colors.white : Colors.black87) : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.scoresHistory.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(color: PulseTheme.surface, borderRadius: BorderRadius.circular(24)),
        child: const Center(child: Text("Not enough data for trend chart.", style: TextStyle(color: Colors.grey))),
      );
    }

    final sorted = [...widget.scoresHistory]..sort((a, b) => a.date.compareTo(b.date));
    final recent = sorted.length > 7 ? sorted.sublist(sorted.length - 7) : sorted;

    final List<LineChartBarData> lineBarsData = [];

    List<FlSpot> getSpots(double? Function(dynamic) getter) {
      List<FlSpot> spots = [];
      for (int i = 0; i < recent.length; i++) {
        final val = getter(recent[i]);
        spots.add(FlSpot(i.toDouble(), val ?? 0.0));
      }
      return spots;
    }

    if (_showRecovery) {
      lineBarsData.add(LineChartBarData(
        spots: getSpots((s) => s.recoveryScore?.toDouble()),
        isCurved: true,
        color: PulseTheme.recoveryHigh,
        barWidth: 3.5,
        dotData: FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ));
    }
    if (_showSleep) {
      lineBarsData.add(LineChartBarData(
        spots: getSpots((s) => s.sleepScore?.toDouble()),
        isCurved: true,
        color: PulseTheme.sleepPrimary,
        barWidth: 3.5,
        dotData: FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ));
    }
    if (_showStrain) {
      lineBarsData.add(LineChartBarData(
        spots: getSpots((s) => s.strainScore?.toDouble()),
        isCurved: true,
        color: PulseTheme.strainPrimary,
        barWidth: 3.5,
        dotData: FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ));
    }
    if (_showReadiness) {
      lineBarsData.add(LineChartBarData(
        spots: getSpots((s) => s.readinessScore?.toDouble()),
        isCurved: true,
        color: PulseTheme.accent,
        barWidth: 3.5,
        dotData: FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ));
    }
    if (_showEnergy) {
      lineBarsData.add(LineChartBarData(
        spots: getSpots((s) => s.energyScore?.toDouble()),
        isCurved: true,
        color: Colors.orangeAccent,
        barWidth: 3.5,
        dotData: FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ));
    }
    if (_showStress) {
      lineBarsData.add(LineChartBarData(
        spots: getSpots((s) => s.stressBalanceScore?.toDouble()),
        isCurved: true,
        color: Colors.tealAccent,
        barWidth: 3.5,
        dotData: FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ));
    }

    return StyledCard(
      color: PulseTheme.accent,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildToggleChip('Recovery', _showRecovery, PulseTheme.recoveryHigh, () => setState(() => _showRecovery = !_showRecovery)),
              _buildToggleChip('Sleep', _showSleep, PulseTheme.sleepPrimary, () => setState(() => _showSleep = !_showSleep)),
              _buildToggleChip('Strain', _showStrain, PulseTheme.strainPrimary, () => setState(() => _showStrain = !_showStrain)),
              _buildToggleChip('Readiness', _showReadiness, PulseTheme.accent, () => setState(() => _showReadiness = !_showReadiness)),
              _buildToggleChip('Energy', _showEnergy, Colors.orangeAccent, () => setState(() => _showEnergy = !_showEnergy)),
              _buildToggleChip('Stress', _showStress, Colors.tealAccent, () => setState(() => _showStress = !_showStress)),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: PulseTheme.isDark ? Colors.white10 : Colors.black12,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()}',
                        style: const TextStyle(color: Colors.grey, fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < recent.length) {
                          final date = recent[idx].date;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              '${date.month}/${date.day}',
                              style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: lineBarsData.isEmpty
                    ? [
                        LineChartBarData(
                          spots: [const FlSpot(0, 0)],
                          color: Colors.transparent,
                        )
                      ]
                    : lineBarsData,
                minX: 0,
                maxX: (recent.length > 1 ? recent.length - 1 : 1).toDouble(),
                minY: 0,
                maxY: 100,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateNavigator extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final now = DateTime.now();
    final isToday = selectedDate.year == now.year && selectedDate.month == now.month && selectedDate.day == now.day;
    final textColor = PulseTheme.isDark ? Colors.white : Colors.black87;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(Icons.chevron_left, color: PulseTheme.secondary),
          onPressed: () {
            ref.read(selectedDateProvider.notifier).state = selectedDate.subtract(const Duration(days: 1));
          },
        ),
        const SizedBox(width: 16),
        Text(
          isToday ? 'TODAY' : DateFormat('MMM d, yyyy').format(selectedDate).toUpperCase(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: textColor,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 16),
        IconButton(
          icon: Icon(Icons.chevron_right, color: isToday ? Colors.transparent : PulseTheme.secondary),
          onPressed: isToday
              ? null
              : () {
                  ref.read(selectedDateProvider.notifier).state = selectedDate.add(const Duration(days: 1));
                },
        ),
      ],
    );
  }
}

class _CurveSeparatorPainter extends CustomPainter {
  final Color color;
  _CurveSeparatorPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(16, size.height / 2);
    path.cubicTo(
      size.width * 0.35, size.height / 2 - 10,
      size.width * 0.65, size.height / 2 + 10,
      size.width - 16, size.height / 2,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
