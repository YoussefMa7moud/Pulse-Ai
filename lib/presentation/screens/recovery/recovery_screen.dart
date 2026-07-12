import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme.dart';
import '../../providers/data_providers.dart';
import '../../../widgets/glass_container.dart';
import '../../../widgets/animated_background.dart';
import '../../../widgets/score_cards.dart';
import '../../../services/ai_service.dart';

class RecoveryScreen extends ConsumerWidget {
  const RecoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scoresAsync = ref.watch(todayScoresProvider);
    final historyAsync = ref.watch(historyMetricsProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: AnimatedGradientBackground(
        child: SafeArea(
        child: RefreshIndicator(
          color: PulseTheme.primary,
          backgroundColor: PulseTheme.surfaceLight,
          onRefresh: () async {
            ref.invalidate(todayScoresProvider);
            ref.invalidate(historyMetricsProvider);
          },
          child: CustomScrollView(
            slivers: [
              const SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                pinned: true,
                title: Text('Recovery', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    
                    scoresAsync.when(
                      data: (score) => Center(
                        child: HeroScoreCard(
                          title: 'Recovery Score', 
                          score: score.recoveryScore ?? 0, 
                          color: _getRecoveryColor(score.recoveryScore ?? 0)
                        ),
                      ),
                      loading: () => const SizedBox(height: 350, child: Center(child: CircularProgressIndicator(color: PulseTheme.recoveryHigh))),
                      error: (e, _) => Text('Error: $e', style: const TextStyle(color: Colors.red)),
                    ),
                    
                    const SizedBox(height: 48),

                    Text('RECOVERY BREAKDOWN', style: Theme.of(context).textTheme.titleLarge?.copyWith(letterSpacing: 2, color: PulseTheme.secondary, fontSize: 14)),
                    const SizedBox(height: 16),
                    
                    scoresAsync.when(
                      data: (score) => Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: _PremiumBreakdownItem(title: 'Sleep', value: '${score.sleepScore?.toInt() ?? 0}', color: PulseTheme.sleepPrimary)),
                          const SizedBox(width: 8),
                          Expanded(child: _PremiumBreakdownItem(title: 'Strain', value: '${score.strainScore?.toInt() ?? 0}', color: PulseTheme.strainPrimary)),
                          const SizedBox(width: 8),
                          Expanded(child: _PremiumBreakdownItem(title: 'Readiness', value: '${score.readinessScore?.toInt() ?? 0}', color: PulseTheme.accent)),
                        ],
                      ),
                      loading: () => const SizedBox(),
                      error: (_, __) => const SizedBox(),
                    ),

                    const SizedBox(height: 48),

                    Text('AI RECOVERY INSIGHT', style: Theme.of(context).textTheme.titleLarge?.copyWith(letterSpacing: 2, color: PulseTheme.secondary, fontSize: 14)),
                    const SizedBox(height: 16),
                    
                    scoresAsync.when(
                      data: (score) {
                        final insightAsync = ref.watch(recoveryInsightProvider(score));
                        return insightAsync.when(
                          data: (insight) => GlassContainer(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              insight,
                              style: TextStyle(height: 1.6, fontSize: 16, color: Colors.white.withOpacity(0.9)),
                            ),
                          ),
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (e, __) => Text('Error: $e'),
                        );
                      },
                      loading: () => const SizedBox(),
                      error: (_, __) => const SizedBox(),
                    ),

                    const SizedBox(height: 48),

                    Text('7-DAY RECOVERY HISTORY', style: Theme.of(context).textTheme.titleLarge?.copyWith(letterSpacing: 2, color: PulseTheme.secondary, fontSize: 14)),
                    const SizedBox(height: 16),
                    
                    historyAsync.when(
                      data: (history) => _BarChartTrend(),
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

class _PremiumBreakdownItem extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _PremiumBreakdownItem({required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 4),
          Text(title.toUpperCase(), style: TextStyle(color: PulseTheme.secondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
        ],
      ),
    );
  }
}

class _BarChartTrend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.only(top: 24, bottom: 16, left: 16, right: 16),
      child: SizedBox(
        height: 200,
        child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 100,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  const style = TextStyle(color: PulseTheme.secondary, fontWeight: FontWeight.bold, fontSize: 12);
                  String text;
                  switch (value.toInt()) {
                    case 0: text = 'M'; break;
                    case 1: text = 'T'; break;
                    case 2: text = 'W'; break;
                    case 3: text = 'T'; break;
                    case 4: text = 'F'; break;
                    case 5: text = 'S'; break;
                    case 6: text = 'S'; break;
                    default: text = ''; break;
                  }
                  return SideTitleWidget(axisSide: meta.axisSide, child: Text(text, style: style));
                },
              ),
            ),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: [
            _buildBarGroup(0, 40, PulseTheme.recoveryMedium),
            _buildBarGroup(1, 65, PulseTheme.recoveryMedium),
            _buildBarGroup(2, 85, PulseTheme.recoveryHigh),
            _buildBarGroup(3, 90, PulseTheme.recoveryHigh),
            _buildBarGroup(4, 25, PulseTheme.recoveryLow),
            _buildBarGroup(5, 50, PulseTheme.recoveryMedium),
            _buildBarGroup(6, 75, PulseTheme.recoveryHigh),
          ],
        ),
      ),
      ),
    );
  }

  BarChartGroupData _buildBarGroup(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 16,
          borderRadius: BorderRadius.circular(4),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: 100,
            color: PulseTheme.surfaceLight,
          ),
        ),
      ],
    );
  }
}
