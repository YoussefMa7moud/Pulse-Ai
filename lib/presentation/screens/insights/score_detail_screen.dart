import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme.dart';
import '../../providers/data_providers.dart';
import '../../../widgets/glass_container.dart';
import '../../../widgets/animated_background.dart';
import '../../../services/ai_service.dart';
import '../../../widgets/pulse_loader.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ScoreDetailScreen extends ConsumerStatefulWidget {
  final String scoreType;

  const ScoreDetailScreen({super.key, required this.scoreType});

  @override
  ConsumerState<ScoreDetailScreen> createState() => _ScoreDetailScreenState();
}

class _ScoreDetailScreenState extends ConsumerState<ScoreDetailScreen> {
  String? aiInsight;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInsight();
  }

  Future<void> _loadInsight() async {
    final aiService = ref.read(aiServicesProvider);
    final score = await ref.read(todayScoresProvider.future);
    
    if (score == null) {
      setState(() => isLoading = false);
      return;
    }

    if (score.recovery == 0 && score.sleep == 0) {
      if (mounted) {
        setState(() {
          aiInsight = "Not enough data for today yet. Wear your device or sync your data to generate detailed insights. Check back later!";
          isLoading = false;
        });
      }
      return;
    }

    try {
      final prompt = "You are Pulse AI. The user clicked on their ${widget.scoreType} score. "
          "Their latest score object is: "
          "{recovery: ${score.recovery}, strain: ${score.strain}, sleep: ${score.sleep}, energy: ${score.energy}}. "
          "Explain what is different from yesterday (if applicable, else just explain today), "
          "what they did right, what they did wrong, and what they should do next to improve. "
          "Keep it concise, supportive, and use markdown formatting.";
      
      final insight = await aiService.generateDirectInsight(prompt);
      
      if (mounted) {
        setState(() {
          aiInsight = insight;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          aiInsight = "Could not generate insight. Make sure GROQ_API_KEY is configured.";
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String title = widget.scoreType.toUpperCase();
    Color primaryColor = PulseTheme.accent;
    
    if (widget.scoreType == 'recovery') primaryColor = PulseTheme.recoveryHigh;
    if (widget.scoreType == 'strain') primaryColor = PulseTheme.strainPrimary;
    if (widget.scoreType == 'sleep') primaryColor = PulseTheme.sleepPrimary;
    if (widget.scoreType == 'energy') primaryColor = Colors.orange;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: PulseTheme.primary),
          onPressed: () => context.pop(),
        ),
        title: Text('$title DETAILS', style: TextStyle(color: PulseTheme.primary, fontWeight: FontWeight.bold, letterSpacing: 2)),
      ),
      body: AnimatedGradientBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              GlassContainer(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome, color: primaryColor),
                        const SizedBox(width: 8),
                        Text('PULSE AI INSIGHT', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (isLoading)
                      const Center(child: Padding(padding: EdgeInsets.all(32), child: PulseLoadingIndicator(size: 50, message: 'Consulting AI coach...')))
                    else
                      MarkdownBody(
                        data: aiInsight ?? "No insight available.",
                        styleSheet: MarkdownStyleSheet(
                          p: TextStyle(fontSize: 16, height: 1.6, color: PulseTheme.primary),
                          h3: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor, height: 1.8),
                          h4: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryColor, height: 1.8),
                          strong: TextStyle(fontWeight: FontWeight.bold, color: PulseTheme.primary),
                          listBullet: TextStyle(color: primaryColor, fontSize: 16),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              GlassContainer(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.science, color: PulseTheme.secondary),
                        const SizedBox(width: 8),
                        Text('HOW IT WORKS', style: TextStyle(color: PulseTheme.secondary, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _getScienceExplanation(),
                      style: TextStyle(fontSize: 15, height: 1.5, color: PulseTheme.secondary),
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

  String _getScienceExplanation() {
    switch (widget.scoreType.toLowerCase()) {
      case 'recovery':
        return 'Recovery is calculated using your Resting Heart Rate (RHR), Heart Rate Variability (HRV), Sleep Performance, and Respiratory metrics. A higher score means your body is primed to take on strain, while a lower score indicates you need more rest.';
      case 'strain':
        return 'Strain measures the cardiovascular and muscular load placed on your body throughout the day. It scales based on your maximum heart rate and the duration of elevated heart rate zones.';
      case 'sleep':
        return 'Sleep Performance compares the amount of sleep you actually got to the amount your body needed. It factors in Sleep Debt, recent Strain, and Sleep Stages (Deep, REM, Light) to determine quality.';
      case 'energy':
        return 'Your Energy Score is a unified metric combining your Sleep quality and current Recovery, minus the Strain you have accumulated today. It indicates your remaining capacity.';
      default:
        return 'This metric is calculated dynamically using a combination of your health signals.';
    }
  }
}
