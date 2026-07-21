import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../presentation/navigation/app_scaffold.dart';
import 'theme.dart';
import '../presentation/screens/splash/splash_screen.dart';
import '../presentation/screens/home/home_screen.dart';
import '../presentation/screens/gym/exercise_screen.dart';
import '../presentation/screens/gym/workout_detail_screen.dart';
import '../data/collections/workout_session.dart';
import '../data/collections/daily_metric.dart';
import '../presentation/screens/health/health_screen.dart';
import '../presentation/screens/health/sleep_detail_screen.dart';
import '../presentation/screens/insights/insights_screen.dart';
import '../presentation/screens/insights/score_detail_screen.dart';
import '../presentation/screens/coach/coach_screen.dart';
import '../presentation/screens/profile/profile_screen.dart';
import '../presentation/screens/profile/auth_screen.dart';
import '../presentation/screens/onboarding/onboarding_screen.dart';
import '../presentation/providers/providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) async {
      final user = sb.Supabase.instance.client.auth.currentUser;
      final isSplash = state.matchedLocation == '/splash';
      final isLoggingIn = state.matchedLocation == '/login';
      final isOnboarding = state.matchedLocation == '/onboarding';

      // Allow splash screen to handle its own navigation
      if (isSplash) return null;

      if (user == null) {
        final prefs = ref.read(sharedPreferencesProvider);
        final completedWalkthrough = prefs.getBool('completed_walkthrough') ?? false;

        if (!completedWalkthrough) {
          return isOnboarding ? null : '/onboarding';
        }
        return (isLoggingIn || isOnboarding) ? null : '/login';
      }

      if (isLoggingIn || isOnboarding) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) {
          final mode = state.uri.queryParameters['mode'] ?? 'login';
          return AuthScreen(initialMode: mode);
        },
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
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/exercise',
            builder: (context, state) => const ExerciseScreen(),
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
          GoRoute(
            path: '/workout_detail',
            builder: (context, state) {
              final workout = state.extra as WorkoutSession;
              return WorkoutDetailScreen(workout: workout);
            },
          ),
          GoRoute(
            path: '/sleep_detail',
            builder: (context, state) {
              final metric = state.extra as DailyMetric;
              return SleepDetailScreen(metric: metric);
            },
          ),
        ],
      ),
    ],
  );
});
