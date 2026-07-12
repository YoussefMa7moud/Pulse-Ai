import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:home_widget/home_widget.dart';
import '../ai/ai_provider.dart';
import '../ai/prompt_manager.dart';
import '../data/database_service.dart';
import '../data/collections/ai_cache.dart';
import '../data/collections/daily_metric.dart';
import '../data/collections/daily_score.dart';
import '../data/collections/workout_session.dart';
import '../presentation/providers/providers.dart';

final aiServicesProvider = Provider<AiService>((ref) {
  final ai = ref.watch(aiServiceProvider);
  final db = ref.watch(databaseProvider);
  return AiService(ai, db);
});

/// Core AI service — every method fetches the maximum available health
/// data from Isar and injects it into the AI prompt so responses are always
/// grounded in the user's real physiological state.
class AiService {
  final AIProvider ai;
  final DatabaseService db;

  AiService(this.ai, this.db);

  // ─────────────────────────────────────────────────────────────────────────
  // CONTEXT BUILDER — shared by all methods
  // ─────────────────────────────────────────────────────────────────────────

  /// Fetches all context data from Isar and builds the full health context string.
  Future<String> _buildContext({
    DailyMetric? todayMetric,
    DailyScore? todayScore,
    List<DailyMetric>? history,
    List<WorkoutSession>? workouts,
  }) async {
    final profile = await db.getUserProfile();
    final metric = todayMetric ?? await db.getMetricForDay(DateTime.now())
        ?? DailyMetric(date: DateTime.utc(
            DateTime.now().year, DateTime.now().month, DateTime.now().day));
    final hist = history ?? await db.getRecentMetrics(days: 30);
    final ws = workouts ?? await db.getRecentWorkouts(days: 14);

    return PromptManager.buildHealthContext(
      today: metric,
      history: hist,
      recentWorkouts: ws,
      todayScore: todayScore,
      profile: profile,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DAILY BRIEF
  // ─────────────────────────────────────────────────────────────────────────

  /// Generates the daily brief shown on the Home screen.
  /// Uses today's full health data as context.
  Future<String> getDailyBrief(DailyScore score, {DailyMetric? todayMetric}) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(score.date);
    final cacheKey = 'daily_brief_$dateStr';

    final cached = await db.getCachedInsight(cacheKey);
    if (cached != null) return cached.content;

    final context = await _buildContext(
      todayMetric: todayMetric,
      todayScore: score,
    );

    final generated = await ai.generateContent(
      systemPrompt: PromptManager.dailyBriefPrompt,
      userPrompt: 'Generate today\'s brief based on my health data:\n\n$context',
    );

    if (_isError(generated)) return generated;

    await _cache(cacheKey, 'daily_brief', generated);
    return generated;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DYNAMIC INSIGHTS
  // ─────────────────────────────────────────────────────────────────────────

  /// Generates 5 AI insights for the Insights screen.
  /// Uses 7-day trend data + all current physiological data.
  Future<List<String>> getDynamicInsights(List<DailyScore> scoreHistory) async {
    if (scoreHistory.isEmpty) {
      return List.generate(5, (_) =>
          'Not enough data yet. Connect your health data source and sync to see personalised insights.');
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final cacheKey = 'insights_$dateStr';

    final cached = await db.getCachedInsight(cacheKey);
    if (cached != null) {
      final parts = cached.content.split('|||');
      if (parts.length == 5) return parts;
    }

    final context = await _buildContext();

    final generated = await ai.generateContent(
      systemPrompt: PromptManager.dynamicInsightsPrompt,
      userPrompt: 'Generate 5 personalised insights from my health data:\n\n$context',
    );

    if (_isError(generated)) return [generated, generated, generated, generated, generated];

    await _cache(cacheKey, 'dynamic_insights', generated);

    final parts = generated.split('|||');
    if (parts.length != 5) {
      return List.generate(5, (_) =>
          'Error parsing insights. Raw: ${generated.substring(0, generated.length.clamp(0, 100))}');
    }
    return parts;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SCORE EXPLANATIONS
  // ─────────────────────────────────────────────────────────────────────────

  /// Generates one-line explanations for each score card on the Home screen.
  Future<Map<String, String>> getScoreExplanations(DailyScore score,
      {DailyMetric? todayMetric}) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(score.date);
    final cacheKey = 'score_expl_$dateStr';

    final cached = await db.getCachedInsight(cacheKey);
    if (cached != null) {
      final parts = cached.content.split('|||');
      if (parts.length == 4) {
        return {
          'sleep': parts[0],
          'strain': parts[1],
          'readiness': parts[2],
          'energy': parts[3]
        };
      }
    }

    final context = await _buildContext(
      todayMetric: todayMetric,
      todayScore: score,
    );

    final generated = await ai.generateContent(
      systemPrompt: PromptManager.scoreExplanationsPrompt,
      userPrompt: 'Generate 4 score explanations from my health data:\n\n$context',
    );

    if (_isError(generated)) {
      return _errorExpl();
    }

    await _cache(cacheKey, 'score_explanations', generated);

    final parts = generated.split('|||');
    if (parts.length == 4) {
      return {
        'sleep': parts[0],
        'strain': parts[1],
        'readiness': parts[2],
        'energy': parts[3]
      };
    }
    return _errorExpl();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RECOVERY INSIGHT
  // ─────────────────────────────────────────────────────────────────────────

  /// Generates a 2-sentence recovery strategy for the Recovery screen + home widget.
  Future<String> getRecoveryInsight(DailyScore score,
      {DailyMetric? todayMetric}) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(score.date);
    final cacheKey = 'recovery_insight_$dateStr';

    final cached = await db.getCachedInsight(cacheKey);
    if (cached != null) return cached.content;

    final context = await _buildContext(
      todayMetric: todayMetric,
      todayScore: score,
    );

    final generated = await ai.generateContent(
      systemPrompt: PromptManager.recoveryAnalysisPrompt,
      userPrompt: 'Analyze my recovery based on my health data:\n\n$context',
    );

    if (_isError(generated)) return generated;

    await _cache(cacheKey, 'recovery_insight', generated);

    try {
      await HomeWidget.saveWidgetData<String>('ai_insight', generated);
      await HomeWidget.updateWidget(name: 'PulseLargeWidgetProvider');
    } catch (_) {}

    return generated;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // AI COACH CHAT — question answered using full health data
  // ─────────────────────────────────────────────────────────────────────────

  /// Answers a user question in the AI coach chat.
  ///
  /// The system prompt contains the user's FULL health data
  /// so every answer is grounded in actual physiological measurements.
  ///
  /// [conversationHistory] = prior messages in format [{role, content}, ...]
  Future<String> askCoach({
    required String userQuestion,
    List<Map<String, String>> conversationHistory = const [],
  }) async {
    // Build the rich health context
    final context = await _buildContext();

    // Coach system prompt embeds the full health data
    final systemPromptWithData =
        '${PromptManager.aiCoachPrompt}\n\n'
        'HEALTH DATA - use this to answer every question:\n\n'
        '$context';

    // Build messages array including conversation history
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPromptWithData},
    ];
    // Include prior conversation turns for context continuity
    for (final msg in conversationHistory.take(20)) {
      messages.add(msg);
    }
    messages.add({'role': 'user', 'content': userQuestion});

    return await ai.generateContentWithMessages(messages);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  Future<String?> generateDirectInsight(String promptText) async {
    try {
      final generated = await ai.generateContent(
        systemPrompt: "You are Pulse AI.",
        userPrompt: promptText,
      );
      if (_isError(generated)) return null;
      return generated;
    } catch (e) {
      return null;
    }
  }

  Future<void> _cache(String key, String type, String content) async {
    await db.cacheInsight(key, type, content);
  }

  bool _isError(String s) =>
      s.startsWith('API Error') || s.startsWith('AI Service') ||
      s.startsWith('Error:');

  Map<String, String> _errorExpl() => const {
    'sleep': 'Data unavailable',
    'strain': 'Data unavailable',
    'readiness': 'Data unavailable',
    'energy': 'Data unavailable',
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// RIVERPOD PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────

final dynamicInsightsProvider = FutureProvider<List<String>>((ref) async {
  final aiService = ref.watch(aiServicesProvider);
  final db = ref.watch(databaseProvider);
  final history = await db.getRecentScores(days: 30);
  return await aiService.getDynamicInsights(history);
});

final scoreExplanationsProvider =
    FutureProvider.family<Map<String, String>, DailyScore>((ref, score) async {
  final aiService = ref.watch(aiServicesProvider);
  return await aiService.getScoreExplanations(score);
});

final recoveryInsightProvider =
    FutureProvider.family<String, DailyScore>((ref, score) async {
  final aiService = ref.watch(aiServicesProvider);
  return await aiService.getRecoveryInsight(score);
});
