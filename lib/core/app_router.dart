import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../presentation/navigation/app_scaffold.dart';
import '../presentation/screens/home/home_screen.dart';
import '../presentation/screens/gym/gym_screen.dart';
import '../presentation/screens/health/health_screen.dart';
import '../presentation/screens/insights/insights_screen.dart';
import '../presentation/screens/insights/score_detail_screen.dart';
import '../presentation/screens/coach/coach_screen.dart';
import '../presentation/screens/profile/profile_screen.dart';
import '../presentation/screens/profile/auth_screen.dart';
import '../presentation/screens/onboarding/onboarding_screen.dart';
import '../data/database_service.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final db = ref.watch(databaseProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) async {
      final user = sb.Supabase.instance.client.auth.currentUser;
      final loggingIn = state.matchedLocation == '/login';

      if (user == null) {
        return loggingIn ? null : '/login';
      }

      if (loggingIn) {
        return '/';
      }

      // Check onboarding state from Supabase
      final profile = await db.getUserProfile();
      final hasCompletedOnboarding = profile.hasCompletedOnboarding;
      final isOnboarding = state.matchedLocation == '/onboarding';

      if (!hasCompletedOnboarding) {
        return isOnboarding ? null : '/onboarding';
      }

      if (isOnboarding) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return AppScaffold(child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/gym',
            builder: (context, state) => const GymScreen(),
          ),
          GoRoute(
            path: '/health',
            builder: (context, state) => const HealthScreen(),
          ),
          GoRoute(
            path: '/insights',
            builder: (context, state) => const InsightsScreen(),
          ),
          GoRoute(
            path: '/coach',
            builder: (context, state) => const CoachScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/score_detail/:type',
            builder: (context, state) {
              final type = state.pathParameters['type'] ?? 'recovery';
              return ScoreDetailScreen(scoreType: type);
            },
          ),
        ],
      ),
    ],
  );
});
