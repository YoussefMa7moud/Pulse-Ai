import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme.dart';
import '../../providers/providers.dart';
import '../../providers/data_providers.dart';
import '../../../widgets/glass_container.dart';
import '../../../widgets/animated_background.dart';
import '../../../widgets/score_cards.dart';
import '../../../services/ai_service.dart';
import 'package:intl/intl.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final scoresAsync = ref.watch(todayScoresProvider);
    final metricsAsync = ref.watch(todayMetricsProvider);
    final historyScoresAsync = ref.watch(historyScoresProvider);
    final explanations = scoresAsync.hasValue ? ref.watch(scoreExplanationsProvider(scoresAsync.value!)).value : null;

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
            slivers: [
              // Dynamic Premium App Bar
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                pinned: true,
                expandedHeight: 80,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  title: profileAsync.when(
                    data: (profile) => Text(
                      "Good Morning, ${profile.name ?? 'User'}", 
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                    loading: () => const Text('Loading...', style: TextStyle(fontSize: 16)),
                    error: (_, __) => const Text('Welcome', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ),
              
              SliverPadding(
                padding: const EdgeInsets.all(24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    
                    // Date Navigator
                    _DateNavigator(),
                    
                    const SizedBox(height: 24),
                    
                    // Main Hero Score (Recovery)
                    scoresAsync.when(
                      data: (score) {
                        if (score.isDataComplete == false) {
                          return Center(
                            child: GlassContainer(
                              padding: const EdgeInsets.all(24),
                              borderColor: PulseTheme.recoveryLow.withOpacity(0.5),
                              child: Column(
                                children: [
                                  const Icon(Icons.info_outline, color: PulseTheme.recoveryLow, size: 48),
                                  const SizedBox(height: 16),
                                  Text("Incomplete Data", style: Theme.of(context).textTheme.titleLarge?.copyWith(color: PulseTheme.recoveryLow, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  const Text(
                                    "We need more data (like Sleep and Heart Rate) to generate your scores for today. Please sync your band or wear it to bed.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () async {
                                      final syncUseCase = ref.read(syncUseCaseProvider);
                                      await syncUseCase.syncToday();
                                      ref.invalidate(todayMetricsProvider);
                                      ref.invalidate(todayScoresProvider);
                                    },
                                    style: ElevatedButton.styleFrom(backgroundColor: PulseTheme.recoveryLow),
                                    child: const Text("Sync Now"),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.scale(
                                scale: 0.95 + (0.05 * value),
                                child: child,
                              ),
                            );
                          },
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => context.push('/score_detail/recovery'),
                                      child: CompactScoreCard(
                                        title: 'Recovery',
                                        score: score.recoveryScore ?? 0,
                                        color: _getRecoveryColor(score.recoveryScore ?? 0),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => context.push('/score_detail/sleep'),
                                      child: CompactScoreCard(
                                        title: 'Sleep',
                                        score: score.sleepScore ?? 0,
                                        color: PulseTheme.sleepPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => context.push('/score_detail/strain'),
                                      child: CompactScoreCard(
                                        title: 'Strain',
                                        score: score.strainScore ?? 0,
                                        color: PulseTheme.strainPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => context.push('/score_detail/readiness'),
                                      child: CompactScoreCard(
                                        title: 'Readiness',
                                        score: score.readinessScore ?? 0,
                                        color: PulseTheme.accent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              // AI Daily Brief Card - Premium Look
                              _PremiumDailyBrief(score: score),
                            ],
                          ),
                        );
                      },
                      loading: () => const SizedBox(height: 350, child: Center(child: CircularProgressIndicator(color: PulseTheme.recoveryHigh))),
                      error: (_, __) => const SizedBox(),
                    ),

                    const SizedBox(height: 48),

                    // Metrics Dashboard
                    Text('KEY METRICS', style: Theme.of(context).textTheme.titleLarge?.copyWith(letterSpacing: 2, color: PulseTheme.secondary, fontSize: 14)),
                    const SizedBox(height: 16),
                    
                    metricsAsync.when(
                      data: (metrics) => TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 650),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 15 * (1.0 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: Column(
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
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _MetricSquare(
                                    icon: Icons.local_fire_department_rounded, 
                                    title: 'Burned', 
                                    value: '${(metrics.caloriesBurned ?? 0).toInt()}', 
                                    unit: 'kcal', 
                                    color: PulseTheme.strainPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
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
                                const SizedBox(width: 16),
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
                            const SizedBox(height: 16),
                            _PremiumMetricRow(
                              icon: Icons.bedtime_rounded, 
                              title: 'Sleep Performance', 
                              value: '${((metrics.totalSleepMinutes ?? 0) / 60).toStringAsFixed(1)} h',
                              subtitle: '${(metrics.deepSleepMinutes ?? 0)}m Deep • ${(metrics.remSleepMinutes ?? 0)}m REM',
                              color: PulseTheme.sleepPrimary,
                            ),
                          ],
                        ),
                      ),
                      loading: () => const CircularProgressIndicator(),
                      error: (_, __) => const Text('Error loading metrics'),
                    ),

                    const SizedBox(height: 48),
                    
                    // Historical Trend Chart
                    Text('RECOVERY TREND', style: Theme.of(context).textTheme.titleLarge?.copyWith(letterSpacing: 2, color: PulseTheme.secondary, fontSize: 14)),
                    const SizedBox(height: 16),
                    historyScoresAsync.when(
                      data: (history) => TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: child,
                          );
                        },
                        child: _TrendChart(scoresHistory: history),
                      ),
                      loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
                      error: (_, __) => const SizedBox(),
                    ),

                    const SizedBox(height: 64),
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

  Color _getRecoveryColor(double score) {
    if (score >= 67) return PulseTheme.recoveryHigh;
    if (score >= 34) return PulseTheme.recoveryMedium;
    return PulseTheme.recoveryLow;
  }
}

class _PremiumMetricRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  const _PremiumMetricRow({required this.icon, required this.title, required this.value, required this.subtitle, required this.color});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
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
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: PulseTheme.secondary, fontSize: 13)),
              ],
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Colors.white)),
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
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title.toUpperCase(), style: TextStyle(color: PulseTheme.secondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, height: 1)),
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
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      borderColor: PulseTheme.accent.withOpacity(0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: PulseTheme.accent, size: 20),
              const SizedBox(width: 10),
              Text('PULSE AI BRIEF', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 14, letterSpacing: 2, color: PulseTheme.accent)),
            ],
          ),
          const SizedBox(height: 16),
          if (loading)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(strokeWidth: 3, color: PulseTheme.accent)))
          else
            Text(
              brief ?? '',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6, fontSize: 16, color: Colors.white.withOpacity(0.9)),
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

    return GlassContainer(
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
              spots: spots.isEmpty ? [const FlSpot(0,0)] : spots,
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

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, color: PulseTheme.secondary),
          onPressed: () {
            ref.read(selectedDateProvider.notifier).state = selectedDate.subtract(const Duration(days: 1));
          },
        ),
        const SizedBox(width: 16),
        Text(
          isToday ? 'TODAY' : DateFormat('MMM d, yyyy').format(selectedDate).toUpperCase(),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 16),
        IconButton(
          icon: Icon(Icons.chevron_right, color: isToday ? Colors.transparent : PulseTheme.secondary),
          onPressed: isToday ? null : () {
            ref.read(selectedDateProvider.notifier).state = selectedDate.add(const Duration(days: 1));
          },
        ),
      ],
    );
  }
}
