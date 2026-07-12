import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database_service.dart';
import '../../data/collections/user_profile.dart';
import '../../infrastructure/health/google_health_service.dart';
import '../../use_cases/sync_use_case.dart';
import '../../ai/ai_provider.dart';
import '../../ai/groq_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// USER PROFILE
// ─────────────────────────────────────────────────────────────────────────────

/// Provides the current user profile from Isar.
final userProfileProvider = FutureProvider<UserProfile>((ref) async {
  final db = ref.watch(databaseProvider);
  return await db.getUserProfile();
});

// ─────────────────────────────────────────────────────────────────────────────
// HEALTH SERVICE
// ─────────────────────────────────────────────────────────────────────────────

/// Provides the singleton GoogleHealthService instance.
final healthServiceProvider = Provider<GoogleHealthService>((ref) {
  return GoogleHealthService();
});

/// Provides the singleton SyncUseCase, wired to the health service and database.
final syncUseCaseProvider = Provider<SyncUseCase>((ref) {
  final health = ref.watch(healthServiceProvider);
  final db = ref.watch(databaseProvider);
  return SyncUseCase(health, db);
});

/// True when the user is authorized with Health Connect permissions.
final healthAuthStateProvider = FutureProvider<bool>((ref) async {
  final health = ref.watch(healthServiceProvider);
  return await health.hasPermissions();
});

// ─────────────────────────────────────────────────────────────────────────────
// AI PROVIDER
// ─────────────────────────────────────────────────────────────────────────────

/// Provides the AI backend (Groq / OpenAI / etc.) based on user profile settings.
final aiServiceProvider = Provider<AIProvider>((ref) {
  final profileAsync = ref.watch(userProfileProvider);
  return profileAsync.maybeWhen(
    data: (profile) {
      if (profile.defaultAiProvider == 'groq') {
        return GroqProvider(model: profile.defaultAiModel);
      }
      return GroqProvider(); // Fallback
    },
    orElse: () => GroqProvider(),
  );
});
