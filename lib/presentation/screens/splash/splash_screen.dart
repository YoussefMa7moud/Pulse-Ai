import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme.dart';
import '../../providers/providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNextScreen();
  }

  Future<void> _navigateToNextScreen() async {
    // Wait for the animations to complete
    await Future.delayed(const Duration(milliseconds: 2500));
    
    if (!mounted) return;

    final user = sb.Supabase.instance.client.auth.currentUser;
    final prefs = ref.read(sharedPreferencesProvider);
    final completedWalkthrough = prefs.getBool('completed_walkthrough') ?? false;

    if (!completedWalkthrough) {
      context.go('/onboarding');
    } else if (user == null) {
      context.go('/login');
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PulseTheme.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    PulseTheme.accent.withOpacity(0.4),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Image.asset(
                  'assets/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            )
                .animate(onPlay: (controller) => controller.repeat(reverse: true))
                .scaleXY(begin: 1.0, end: 1.1, duration: 1000.ms, curve: Curves.easeInOut)
                .fade(duration: 500.ms),
            const SizedBox(height: 24),
            Text(
              'PULSE AI',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 4,
              ),
            )
                .animate()
                .slideY(begin: 0.5, end: 0, duration: 800.ms, curve: Curves.easeOutBack)
                .fade(duration: 800.ms),
            const SizedBox(height: 8),
            Text(
              'ADVANCED HEALTH INTELLIGENCE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: PulseTheme.accent,
                letterSpacing: 2,
              ),
            )
                .animate()
                .slideY(begin: 0.5, end: 0, duration: 800.ms, delay: 300.ms, curve: Curves.easeOutBack)
                .fade(duration: 800.ms, delay: 300.ms),
          ],
        ),
      ),
    );
  }
}
