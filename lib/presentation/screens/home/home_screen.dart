import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../providers/providers.dart';
import '../../providers/data_providers.dart';
import '../../../widgets/glass_container.dart';
import '../../../widgets/styled_card.dart';
import '../../../widgets/animated_background.dart';
import '../../../widgets/pulse_loader.dart';
import '../../../services/ai_service.dart';
import '../../../widgets/animated_counter.dart';
import '../../../widgets/staggered_animation.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
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

    return GestureDetector(
      onTap: () => context.push(route),
      child: StyledCard(
        color: color,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: textColor.withOpacity(0.9),
                        ),
                        overflow: TextOverflow.ellipsis,
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
              size: 48,
              strokeWidth: 3.5,
              backgroundColor: color.withOpacity(0.08),
              child: value == null
                  ? Text('-', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: textColor))
                  : AnimatedCounter(
                      value: value,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ),
                    ),
            ),
          ],
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
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                    try {
                      final syncUseCase = ref.read(syncUseCaseProvider);
                      await syncUseCase.syncAll(daysBack: 14);
                    } catch (_) {}
                    if (context.mounted) Navigator.pop(context);

                    ref.invalidate(todayMetricsProvider);
                    ref.invalidate(todayScoresProvider);
                    ref.invalidate(recentWorkoutsProvider);
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

                    if (success) {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                      try {
                        final syncUseCase = ref.read(syncUseCaseProvider);
                        await syncUseCase.syncAll(daysBack: 14);
                      } catch (_) {}
                      if (context.mounted) Navigator.pop(context);

                      ref.invalidate(todayMetricsProvider);
                      ref.invalidate(todayScoresProvider);
                      ref.invalidate(healthAuthStateProvider);
                      ref.invalidate(recentWorkoutsProvider);
                    }
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
                              const SizedBox(height: 16),
                              if (!isComplete) ...[
                                _buildIncompleteDataCard(context, ref),
                              ] else ...[
                                _PremiumDailyBrief(score: score!),
                              ],
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

                      const SizedBox(height: 32),

                      // Metrics Dashboard
                      Text(
                        'KEY METRICS',
                        style: TextStyle(
                          letterSpacing: 2,
                          color: PulseTheme.secondary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      metricsAsync.when(
                        data: (metrics) => Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _MetricSquare(
                                    icon: Icons.favorite_rounded,
                                    title: 'RHR',
                                    value: '${(metrics.restingHeartRate ?? 0).toInt()}',
                                    unit: 'bpm',
                                    color: PulseTheme.recoveryLow,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _MetricSquare(
                                    icon: Icons.local_fire_department_rounded,
                                    title: 'Burned',
                                    value: '${(metrics.activeCalories ?? 0).toInt()}',
                                    unit: 'kcal',
                                    color: PulseTheme.strainPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _MetricSquare(
                                    icon: Icons.directions_walk_rounded,
                                    title: 'Steps',
                                    value: '${metrics.steps ?? 0}',
                                    unit: 'steps',
                                    color: PulseTheme.accent,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _MetricSquare(
                                    icon: Icons.timer_rounded,
                                    title: 'Active',
                                    value: '${metrics.activeMinutes ?? 0}',
                                    unit: 'min',
                                    color: Colors.greenAccent,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _PremiumMetricRow(
                              icon: Icons.bedtime_rounded,
                              title: 'Sleep Performance',
                              value: '${((metrics.totalSleepMinutes ?? 0) / 60).toStringAsFixed(1)} h',
                              subtitle: '${(metrics.deepSleepMinutes ?? 0)}m Deep • ${(metrics.remSleepMinutes ?? 0)}m REM',
                              color: PulseTheme.sleepPrimary,
                            ),
                          ],
                        ),
                        loading: () => const SizedBox(
                          height: 180,
                          child: PulseLoadingIndicator(size: 50, message: 'Loading metrics...'),
                        ),
                        error: (_, __) => const Text('Error loading metrics'),
                      ),

                      const SizedBox(height: 32),

                      // Historical Trend Chart
                      Text(
                        'RECOVERY TREND',
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
                          height: 200,
                          child: PulseLoadingIndicator(size: 60, message: 'Plotting trend...'),
                        ),
                        error: (_, __) => const SizedBox(),
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

  @override
  Widget build(BuildContext context) {
    final textColor = PulseTheme.isDark ? Colors.white.withOpacity(0.9) : Colors.black87;

    return StyledCard(
      color: PulseTheme.accent,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: PulseTheme.accent, size: 20),
              const SizedBox(width: 10),
              Text(
                'ADVICE FOR THE DAY',
                style: TextStyle(
                  fontSize: 13,
                  letterSpacing: 2,
                  color: PulseTheme.accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(strokeWidth: 3, color: Colors.cyan),
              ),
            )
          else
            Text(
              brief ?? '',
              style: TextStyle(height: 1.6, fontSize: 15, color: textColor),
            ),
        ],
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  final List<dynamic> scoresHistory;

  const _TrendChart({required this.scoresHistory});

  @override
  Widget build(BuildContext context) {
    if (scoresHistory.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(color: PulseTheme.surface, borderRadius: BorderRadius.circular(24)),
        child: const Center(child: Text("Not enough data for trend chart.", style: TextStyle(color: Colors.grey))),
      );
    }

    // Sort by date ascending to plot left-to-right
    final sorted = [...scoresHistory]..sort((a, b) => a.date.compareTo(b.date));

    // Take up to 7 most recent
    final recent = sorted.length > 7 ? sorted.sublist(sorted.length - 7) : sorted;

    List<FlSpot> spots = [];
    for (int i = 0; i < recent.length; i++) {
      spots.add(FlSpot(i.toDouble(), recent[i].recoveryScore ?? 0.0));
    }

    return StyledCard(
      color: PulseTheme.recoveryHigh,
      padding: const EdgeInsets.only(right: 24, left: 16, top: 24, bottom: 16),
      child: SizedBox(
        height: 220,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(show: false),
            titlesData: FlTitlesData(
              show: true,
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots.isEmpty ? [const FlSpot(0, 0)] : spots,
                isCurved: true,
                color: PulseTheme.recoveryHigh,
                barWidth: 4,
                isStrokeCapRound: true,
                dotData: FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: PulseTheme.recoveryHigh.withOpacity(0.1),
                ),
              ),
            ],
            minX: 0,
            maxX: (recent.length > 1 ? recent.length - 1 : 1).toDouble(),
            minY: 0,
            maxY: 100,
          ),
        ),
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
