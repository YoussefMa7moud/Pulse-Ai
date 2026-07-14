import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme.dart';
import '../../../widgets/glass_container.dart';
import '../../../widgets/animated_background.dart';
import '../../../widgets/pulse_loader.dart';
import '../../../services/ai_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../data/database_service.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(dynamicInsightsProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Insights Center', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(Icons.person_outline, color: PulseTheme.primary),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: AnimatedGradientBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              await ref.read(databaseProvider).clearInsightsCache();
              ref.invalidate(dynamicInsightsProvider);
              await ref.read(dynamicInsightsProvider.future);
            },
            color: PulseTheme.accent,
            backgroundColor: PulseTheme.surfaceLight,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('AI GENERATED REPORTS', style: Theme.of(context).textTheme.titleLarge?.copyWith(letterSpacing: 2, color: PulseTheme.secondary, fontSize: 14)),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(16.0),
                  sliver: insightsAsync.when(
                    data: (insights) {
                      return SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            IconData icon;
                            String title;
                            Color color;
                            switch (index) {
                              case 0: icon = Icons.fitness_center_rounded; title = 'TRAINING & STRAIN'; color = PulseTheme.strainPrimary; break;
                              case 1: icon = Icons.bedtime_rounded; title = 'SLEEP OPTIMIZATION'; color = PulseTheme.sleepPrimary; break;
                              case 2: icon = Icons.restaurant_rounded; title = 'DIET & METABOLISM'; color = Colors.orange; break;
                              case 3: icon = Icons.spa_rounded; title = 'RECOVERY & STRESS'; color = PulseTheme.recoveryHigh; break;
                              case 4: default: icon = Icons.trending_up_rounded; title = 'OVERALL TRAJECTORY'; color = PulseTheme.accent; break;
                            }
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: _PremiumInsightCard(
                                icon: icon,
                                title: title,
                                description: insights[index],
                                color: color,
                                date: 'Just now',
                              ),
                            );
                          },
                          childCount: insights.length,
                        ),
                      );
                    },
                    loading: () => const SliverFillRemaining(
                      child: Center(
                        child: PulseLoadingIndicator(message: 'Analyzing trends...'),
                      ),
                    ),
                    error: (e, __) => SliverFillRemaining(
                      child: Center(child: Text('Failed to load insights.\n$e', textAlign: TextAlign.center)),
                    ),
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

class _PremiumInsightCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String date;

  const _PremiumInsightCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: PulseTheme.isDark ? Colors.white : Colors.black87)),
              ),
              Text(date, style: TextStyle(color: PulseTheme.secondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),
          MarkdownBody(
            data: description,
            styleSheet: MarkdownStyleSheet(
              p: TextStyle(height: 1.5, fontSize: 15, color: PulseTheme.isDark ? Colors.white.withOpacity(0.9) : Colors.black87),
              strong: TextStyle(fontWeight: FontWeight.bold, color: color),
              h3: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
              h4: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
