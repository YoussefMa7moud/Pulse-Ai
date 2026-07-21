import 'package:flutter/foundation.dart';
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
      
      final currentUser = client.auth.currentUser;
      final metadata = currentUser?.userMetadata ?? {};

      if (res != null) {
        final profile = UserProfile.fromJson(res);
        // If values are null in the database but exist in auth metadata (e.g. from sign up), copy them over
        bool changed = false;
        if (profile.name == null && metadata['name'] != null) {
          profile.name = metadata['name'] as String?;
          changed = true;
        }
        if (profile.age == null && metadata['age'] != null) {
          profile.age = (metadata['age'] as num).toInt();
          changed = true;
        }
        if (profile.gender == null && metadata['gender'] != null) {
          profile.gender = metadata['gender'] as String?;
          changed = true;
        }
        if (profile.heightCm == null && metadata['height_cm'] != null) {
          profile.heightCm = (metadata['height_cm'] as num).toDouble();
          changed = true;
        }
        if (profile.weightKg == null && metadata['weight_kg'] != null) {
          profile.weightKg = (metadata['weight_kg'] as num).toDouble();
          changed = true;
        }
        if (profile.primaryGoal == null && metadata['primary_goal'] != null) {
          profile.primaryGoal = metadata['primary_goal'] as String?;
          changed = true;
        }

        if (changed) {
          await saveUserProfile(profile);
        }
        return profile;
      } else {
        final profile = UserProfile(
          id: userId,
          name: metadata['name'] as String?,
          age: metadata['age'] != null ? (metadata['age'] as num).toInt() : null,
          gender: metadata['gender'] as String?,
          heightCm: metadata['height_cm'] != null ? (metadata['height_cm'] as num).toDouble() : null,
          weightKg: metadata['weight_kg'] != null ? (metadata['weight_kg'] as num).toDouble() : null,
          primaryGoal: metadata['primary_goal'] as String?,
          hasCompletedOnboarding: false,
        );
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
    final Map<String, Map<String, dynamic>> dedupedMap = {};
    for (final m in metrics) {
      final json = m.toJson();
      json['user_id'] = userId;
      final dateKey = json['date']?.toString() ?? '';
      dedupedMap['${userId}_$dateKey'] = json;
    }
    final list = dedupedMap.values.toList();

    // Strategy 1: Bulk upsert with onConflict
    try {
      await client.from('daily_metrics').upsert(
        list,
        onConflict: 'user_id,date',
      );
      return;
    } catch (e) {
      debugPrint('[PIPELINE][DB] ⚠ Bulk upsert metrics failed (likely missing UNIQUE constraint): $e');
      debugPrint('[PIPELINE][DB] Falling back to partitioned query + bulk insert + parallel updates...');
    }

    // Strategy 2: Partitioned query + bulk insert + parallel updates fallback
    try {
      final existingRecords = await client.from('daily_metrics')
          .select('id, date')
          .eq('user_id', userId);

      final Map<String, String> existingMap = {};
      for (final item in existingRecords as List) {
        final dateVal = item['date']?.toString() ?? '';
        final rowId = item['id']?.toString() ?? '';
        if (dateVal.isNotEmpty && rowId.isNotEmpty) {
          existingMap[dateVal] = rowId;
        }
      }

      final toInsert = <Map<String, dynamic>>[];
      final toUpdate = <Map<String, dynamic>>[];

      for (final row in list) {
        final dateVal = row['date'] as String;
        final payload = Map<String, dynamic>.from(row)..remove('id');

        if (existingMap.containsKey(dateVal)) {
          payload['id'] = existingMap[dateVal];
          toUpdate.add(payload);
        } else {
          toInsert.add(payload);
        }
      }

      if (toInsert.isNotEmpty) {
        await client.from('daily_metrics').insert(toInsert);
      }

      if (toUpdate.isNotEmpty) {
        const batchSize = 10;
        for (int i = 0; i < toUpdate.length; i += batchSize) {
          final batch = toUpdate.sublist(i, i + batchSize > toUpdate.length ? toUpdate.length : i + batchSize);
          await Future.wait(batch.map((row) async {
            final rowId = row['id'];
            final updatePayload = Map<String, dynamic>.from(row)..remove('id');
            await client.from('daily_metrics').update(updatePayload).eq('id', rowId);
          }));
        }
      }
      debugPrint('[PIPELINE][DB] ✅ Fallback metrics complete: inserted=${toInsert.length}, updated=${toUpdate.length}');
    } catch (e, stack) {
      debugPrint('[PIPELINE][DB] ❌ Error in fallback upsertMetrics: $e\n$stack');
    }
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


  Future<void> upsertWorkoutSessions(List<WorkoutSession> sessions) async {
    if (userId.isEmpty || sessions.isEmpty) return;
    debugPrint('[PIPELINE][DB] upsertWorkoutSessions called with ${sessions.length} sessions for user=$userId');

    // Deduplicate in memory by activity_id
    final Map<String, Map<String, dynamic>> dedupedMap = {};
    for (final s in sessions) {
      final json = s.toJson();
      json['user_id'] = userId;
      final actId = json['activity_id']?.toString() ?? '';
      if (actId.isEmpty) continue; // Skip entries with no activity_id
      dedupedMap['${userId}_$actId'] = json;
    }
    final list = dedupedMap.values.toList();
    if (list.isEmpty) return;

    debugPrint('[PIPELINE][DB] In-memory deduplicated from ${sessions.length} to ${list.length} unique activity_ids');

    // Strategy 1: Try bulk upsert with onConflict (fastest, requires UNIQUE constraint)
    try {
      await client.from('workout_sessions').upsert(
        list,
        onConflict: 'user_id,activity_id',
      );
      debugPrint('[PIPELINE][DB] ✅ Bulk upsert complete — ${list.length} sessions written');
      return; // Success — done
    } catch (e) {
      debugPrint('[PIPELINE][DB] ⚠ Bulk upsert failed (likely missing UNIQUE constraint): $e');
      debugPrint('[PIPELINE][DB] Falling back to individual row insert/update...');
    }

    // Strategy 2: Fall back to partitioned query + bulk insert + parallel updates
    int inserted = 0;
    int updated = 0;
    int errors = 0;
    try {
      // 1. Fetch all existing records' IDs and activity_ids for this user
      final existingRecords = await client.from('workout_sessions')
          .select('id, activity_id')
          .eq('user_id', userId);
      
      final Map<String, String> existingMap = {};
      for (final item in existingRecords as List) {
        final actId = item['activity_id']?.toString() ?? '';
        final rowId = item['id']?.toString() ?? '';
        if (actId.isNotEmpty && rowId.isNotEmpty) {
          existingMap[actId] = rowId;
        }
      }

      final toInsert = <Map<String, dynamic>>[];
      final toUpdate = <Map<String, dynamic>>[];

      for (final row in list) {
        final activityId = row['activity_id'] as String;
        final payload = Map<String, dynamic>.from(row)..remove('id');

        if (existingMap.containsKey(activityId)) {
          payload['id'] = existingMap[activityId];
          toUpdate.add(payload);
        } else {
          toInsert.add(payload);
        }
      }

      // 2. Perform bulk insert for new records
      if (toInsert.isNotEmpty) {
        try {
          await client.from('workout_sessions').insert(toInsert);
          inserted += toInsert.length;
        } catch (e) {
          debugPrint('[PIPELINE][DB] ⚠ Fallback: Error during bulk insert: $e');
          errors += toInsert.length;
        }
      }

      // 3. Perform updates in parallel batches of size 10 to avoid rate limit / connection exhaustion
      if (toUpdate.isNotEmpty) {
        const batchSize = 10;
        for (int i = 0; i < toUpdate.length; i += batchSize) {
          final batch = toUpdate.sublist(i, i + batchSize > toUpdate.length ? toUpdate.length : i + batchSize);
          try {
            await Future.wait(batch.map((row) async {
              final rowId = row['id'];
              final updatePayload = Map<String, dynamic>.from(row)..remove('id');
              await client.from('workout_sessions').update(updatePayload).eq('id', rowId);
              updated++;
            }));
          } catch (e) {
            debugPrint('[PIPELINE][DB] ⚠ Fallback: Error during parallel update batch: $e');
            errors += batch.length;
          }
        }
      }
    } catch (e) {
      debugPrint('[PIPELINE][DB] ❌ Fallback query/setup failed completely: $e');
      errors = list.length;
    }
    debugPrint('[PIPELINE][DB] ✅ Fallback complete — inserted=$inserted, updated=$updated, errors=$errors');

    // Post-fallback verification: confirm data was actually persisted
    if (inserted + updated > 0) {
      try {
        final verify = await client.from('workout_sessions')
            .select('id')
            .eq('user_id', userId);
        debugPrint('[PIPELINE][DB] Post-fallback verification: ${(verify as List).length} total workout rows in DB for this user');
      } catch (_) {}
    }

    if (errors == list.length) {
      debugPrint('[PIPELINE][DB] ❌ ALL individual inserts failed! Check:');
      debugPrint('[PIPELINE][DB]   1. Does the workout_sessions table exist in Supabase?');
      debugPrint('[PIPELINE][DB]   2. Are RLS policies configured to allow INSERT for auth.uid()?');
      debugPrint('[PIPELINE][DB]   3. Do the column names match? (activity_id, date, start_time, end_time, etc.)');
    }
  }


  Future<List<WorkoutSession>> getWorkoutsForDay(DateTime date) async {
    if (userId.isEmpty) return [];
    try {
      final dateStr = _formatDate(date);
      final res = await client.from('workout_sessions')
          .select()
          .eq('user_id', userId)
          .eq('date', dateStr);
      debugPrint('[PIPELINE][DB] getWorkoutsForDay($dateStr): ${(res as List).length} rows');
      return (res).map((e) => WorkoutSession.fromJson(e)).toList();
    } catch (e, stack) {
      debugPrint('[PIPELINE][DB] Error getting workouts for day: $e\n$stack');
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
          .order('date', ascending: false);
      debugPrint('[PIPELINE][DB] getRecentWorkouts(days=$days, cutoff=$cutoffStr): ${(res as List).length} rows');
      return (res).map((e) => WorkoutSession.fromJson(e)).toList();
    } catch (e, stack) {
      debugPrint('[PIPELINE][DB] Error getting recent workouts: $e\n$stack');
      return [];
    }
  }

  /// Fetches ALL workout sessions for this user — no date filter.
  /// Used by the Exercise tab to show the complete workout history.
  Future<List<WorkoutSession>> getAllWorkouts() async {
    if (userId.isEmpty) return [];
    try {
      final res = await client.from('workout_sessions')
          .select()
          .eq('user_id', userId)
          .order('date', ascending: false);
      debugPrint('[PIPELINE][DB] getAllWorkouts: ${(res as List).length} rows');
      return (res).map((e) => WorkoutSession.fromJson(e)).toList();
    } catch (e, stack) {
      debugPrint('[PIPELINE][DB] Error getting all workouts: $e\n$stack');
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
    final Map<String, Map<String, dynamic>> dedupedMap = {};
    for (final s in scores) {
      final json = s.toJson();
      json['user_id'] = userId;
      final dateKey = json['date']?.toString() ?? '';
      dedupedMap['${userId}_$dateKey'] = json;
    }
    final list = dedupedMap.values.toList();

    // Strategy 1: Bulk upsert with onConflict
    try {
      await client.from('daily_scores').upsert(
        list,
        onConflict: 'user_id,date',
      );
      return;
    } catch (e) {
      debugPrint('[PIPELINE][DB] ⚠ Bulk upsert scores failed (likely missing UNIQUE constraint): $e');
      debugPrint('[PIPELINE][DB] Falling back to partitioned query + bulk insert + parallel updates...');
    }

    // Strategy 2: Partitioned query + bulk insert + parallel updates fallback
    try {
      final existingRecords = await client.from('daily_scores')
          .select('id, date')
          .eq('user_id', userId);

      final Map<String, String> existingMap = {};
      for (final item in existingRecords as List) {
        final dateVal = item['date']?.toString() ?? '';
        final rowId = item['id']?.toString() ?? '';
        if (dateVal.isNotEmpty && rowId.isNotEmpty) {
          existingMap[dateVal] = rowId;
        }
      }

      final toInsert = <Map<String, dynamic>>[];
      final toUpdate = <Map<String, dynamic>>[];

      for (final row in list) {
        final dateVal = row['date'] as String;
        final payload = Map<String, dynamic>.from(row)..remove('id');

        if (existingMap.containsKey(dateVal)) {
          payload['id'] = existingMap[dateVal];
          toUpdate.add(payload);
        } else {
          toInsert.add(payload);
        }
      }

      if (toInsert.isNotEmpty) {
        await client.from('daily_scores').insert(toInsert);
      }

      if (toUpdate.isNotEmpty) {
        const batchSize = 10;
        for (int i = 0; i < toUpdate.length; i += batchSize) {
          final batch = toUpdate.sublist(i, i + batchSize > toUpdate.length ? toUpdate.length : i + batchSize);
          await Future.wait(batch.map((row) async {
            final rowId = row['id'];
            final updatePayload = Map<String, dynamic>.from(row)..remove('id');
            await client.from('daily_scores').update(updatePayload).eq('id', rowId);
          }));
        }
      }
      debugPrint('[PIPELINE][DB] ✅ Fallback scores complete: inserted=${toInsert.length}, updated=${toUpdate.length}');
    } catch (e, stack) {
      debugPrint('[PIPELINE][DB] ❌ Error in fallback upsertScores: $e\n$stack');
    }
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

  Future<void> clearInsightsCache() async {
    if (userId.isEmpty) return;
    await client.from('ai_cache').delete().eq('user_id', userId).eq('type', 'dynamic_insights');
  }

  Future<void> clearAllInsightsCache() async {
    if (userId.isEmpty) return;
    await client.from('ai_cache').delete().eq('user_id', userId);
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
