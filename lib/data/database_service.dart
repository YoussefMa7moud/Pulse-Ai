import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'collections/ai_cache.dart';
import 'collections/chat_message.dart';
import 'collections/daily_metric.dart';
import 'collections/daily_score.dart';
import 'collections/user_profile.dart';
import 'collections/workout_session.dart';
import 'collections/gym_models.dart';

final databaseProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

class DatabaseService {
  final sb.SupabaseClient client = sb.Supabase.instance.client;

  String get userId => client.auth.currentUser?.id ?? '';

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  Future<void> init() async {
    // Supabase client is initialized globally in main.dart
  }

  // ─────────────────────────────────────────────────────────────────────────
  // USER PROFILE
  // ─────────────────────────────────────────────────────────────────────────

  Future<UserProfile> getUserProfile() async {
    if (userId.isEmpty) return UserProfile();
    try {
      final res = await client.from('profiles').select().eq('id', userId).maybeSingle();
      if (res != null) {
        return UserProfile.fromJson(res);
      } else {
        final profile = UserProfile(id: userId, hasCompletedOnboarding: false);
        await saveUserProfile(profile);
        return profile;
      }
    } catch (e) {
      return UserProfile();
    }
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    if (userId.isEmpty) return;
    profile.id = userId;
    await client.from('profiles').upsert(profile.toJson());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DAILY METRICS
  // ─────────────────────────────────────────────────────────────────────────

  Future<DailyMetric?> getMetricForDay(DateTime date) async {
    if (userId.isEmpty) return null;
    try {
      final dateStr = _formatDate(date);
      final res = await client.from('daily_metrics')
          .select()
          .eq('user_id', userId)
          .eq('date', dateStr)
          .maybeSingle();
      if (res != null) {
        return DailyMetric.fromJson(res);
      }
    } catch (_) {}
    return null;
  }

  Future<void> upsertMetric(DailyMetric metric) async {
    if (userId.isEmpty) return;
    final json = metric.toJson();
    json['user_id'] = userId;
    await client.from('daily_metrics').upsert(json);
  }

  Future<void> upsertMetrics(List<DailyMetric> metrics) async {
    if (userId.isEmpty || metrics.isEmpty) return;
    final list = metrics.map((m) {
      final json = m.toJson();
      json['user_id'] = userId;
      return json;
    }).toList();
    await client.from('daily_metrics').upsert(list);
  }

  Future<List<DailyMetric>> getMetricsRange(DateTime start, DateTime end) async {
    if (userId.isEmpty) return [];
    try {
      final startStr = _formatDate(start);
      final endStr = _formatDate(end);
      final res = await client.from('daily_metrics')
          .select()
          .eq('user_id', userId)
          .gte('date', startStr)
          .lte('date', endStr)
          .order('date', ascending: true);
      return (res as List).map((e) => DailyMetric.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<DailyMetric>> getRecentMetrics({int days = 30}) async {
    if (userId.isEmpty) return [];
    try {
      final cutoff = DateTime.now().subtract(Duration(days: days));
      final cutoffStr = _formatDate(cutoff);
      final res = await client.from('daily_metrics')
          .select()
          .eq('user_id', userId)
          .gt('date', cutoffStr)
          .order('date', ascending: false);
      return (res as List).map((e) => DailyMetric.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WORKOUT SESSIONS
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> upsertWorkoutSessions(List<WorkoutSession> sessions) async {
    if (userId.isEmpty || sessions.isEmpty) return;
    final list = sessions.map((s) {
      final json = s.toJson();
      json['user_id'] = userId;
      return json;
    }).toList();
    await client.from('workout_sessions').upsert(list);
  }

  Future<List<WorkoutSession>> getWorkoutsForDay(DateTime date) async {
    if (userId.isEmpty) return [];
    try {
      final dateStr = _formatDate(date);
      final res = await client.from('workout_sessions')
          .select()
          .eq('user_id', userId)
          .eq('date', dateStr);
      return (res as List).map((e) => WorkoutSession.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<WorkoutSession>> getRecentWorkouts({int days = 14}) async {
    if (userId.isEmpty) return [];
    try {
      final cutoff = DateTime.now().subtract(Duration(days: days));
      final cutoffStr = _formatDate(cutoff);
      final res = await client.from('workout_sessions')
          .select()
          .eq('user_id', userId)
          .gt('date', cutoffStr)
          .order('start_time', ascending: false);
      return (res as List).map((e) => WorkoutSession.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DAILY SCORES
  // ─────────────────────────────────────────────────────────────────────────

  Future<DailyScore?> getScoreForDay(DateTime date) async {
    if (userId.isEmpty) return null;
    try {
      final dateStr = _formatDate(date);
      final res = await client.from('daily_scores')
          .select()
          .eq('user_id', userId)
          .eq('date', dateStr)
          .maybeSingle();
      if (res != null) {
        return DailyScore.fromJson(res);
      }
    } catch (_) {}
    return null;
  }

  Future<void> upsertScore(DailyScore score) async {
    if (userId.isEmpty) return;
    final json = score.toJson();
    json['user_id'] = userId;
    await client.from('daily_scores').upsert(json);
  }

  Future<void> upsertScores(List<DailyScore> scores) async {
    if (userId.isEmpty || scores.isEmpty) return;
    final list = scores.map((s) {
      final json = s.toJson();
      json['user_id'] = userId;
      return json;
    }).toList();
    await client.from('daily_scores').upsert(list);
  }

  Future<List<DailyScore>> getRecentScores({int days = 30}) async {
    if (userId.isEmpty) return [];
    try {
      final cutoff = DateTime.now().subtract(Duration(days: days));
      final cutoffStr = _formatDate(cutoff);
      final res = await client.from('daily_scores')
          .select()
          .eq('user_id', userId)
          .gt('date', cutoffStr)
          .order('date', ascending: false);
      return (res as List).map((e) => DailyScore.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GYM OPERATIONS
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<GymRoutine>> getTemplates() async {
    if (userId.isEmpty) return [];
    try {
      final res = await client.from('gym_routines')
          .select('*, gym_exercises(*, gym_sets(*))')
          .eq('user_id', userId)
          .eq('is_template', true)
          .order('start_time', ascending: false);
      return (res as List).map((e) => GymRoutine.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<GymRoutine>> getRecentRoutines() async {
    if (userId.isEmpty) return [];
    try {
      final res = await client.from('gym_routines')
          .select('*, gym_exercises(*, gym_sets(*))')
          .eq('user_id', userId)
          .eq('is_template', false)
          .order('start_time', ascending: false);
      return (res as List).map((e) => GymRoutine.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveRoutine(GymRoutine routine) async {
    if (userId.isEmpty) return;
    final routineJson = routine.toJson();
    routineJson['user_id'] = userId;
    
    // 1. Upsert routine and retrieve the uuid
    final res = await client.from('gym_routines').upsert(routineJson).select('id').single();
    final routineId = res['id'] as String;

    // 2. Clear old exercises (this makes updating simple)
    if (routine.id != null) {
      await client.from('gym_exercises').delete().eq('routine_id', routineId);
    }

    // 3. Insert new exercises & sets
    for (final ex in routine.exercises) {
      final exJson = ex.toJson();
      exJson['routine_id'] = routineId;
      final exRes = await client.from('gym_exercises').insert(exJson).select('id').single();
      final exId = exRes['id'] as String;

      for (final s in ex.sets) {
        final setJson = s.toJson();
        setJson['exercise_id'] = exId;
        await client.from('gym_sets').insert(setJson);
      }
    }
  }

  Future<void> deleteRoutine(String id) async {
    await client.from('gym_routines').delete().eq('id', id);
  }

  Future<List<GymExercise>> getCustomExercises() async {
    if (userId.isEmpty) return [];
    try {
      final res = await client.from('gym_exercises')
          .select('*, gym_routines!inner(*)')
          .eq('gym_routines.user_id', userId);
      return (res as List).map((e) => GymExercise.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<GymExercise>> getExerciseHistory(String name) async {
    if (userId.isEmpty) return [];
    try {
      final res = await client.from('gym_exercises')
          .select('*, gym_sets(*), gym_routines!inner(*)')
          .eq('gym_routines.user_id', userId)
          .eq('gym_routines.is_template', false)
          .eq('name', name);
      return (res as List).map((e) => GymExercise.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // AI INSIGHT CACHE
  // ─────────────────────────────────────────────────────────────────────────

  Future<AiCache?> getCachedInsight(String key) async {
    if (userId.isEmpty) return null;
    try {
      final res = await client.from('ai_cache')
          .select()
          .eq('user_id', userId)
          .eq('cache_key', key)
          .maybeSingle();
      if (res != null) {
        return AiCache.fromJson(res);
      }
    } catch (_) {}
    return null;
  }

  Future<void> cacheInsight(String key, String type, String content) async {
    if (userId.isEmpty) return;
    await client.from('ai_cache').upsert({
      'user_id': userId,
      'cache_key': key,
      'type': type,
      'content': content,
      'generated_at': DateTime.now().toIso8601String(),
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CHAT HISTORY
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<ChatMessage>> getChatHistory() async {
    if (userId.isEmpty) return [];
    try {
      final res = await client.from('chat_messages')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: true);
      return (res as List).map((e) => ChatMessage.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addChatMessage(ChatMessage message) async {
    if (userId.isEmpty) return;
    final json = message.toJson();
    json['user_id'] = userId;
    await client.from('chat_messages').insert(json);
  }

  Future<void> clearChatHistory() async {
    if (userId.isEmpty) return;
    await client.from('chat_messages').delete().eq('user_id', userId);
  }
}
