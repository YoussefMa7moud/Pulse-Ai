import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/theme.dart';
import '../../providers/providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  String _statusMessage = 'Initializing Health Engine...';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _updateStatusMessages();
    _navigateToNextScreen();
  }

  void _updateStatusMessages() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() => _statusMessage = 'Syncing Health Intelligence...');
    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) setState(() => _statusMessage = 'Pulse AI Ready');
  }

  Future<void> _navigateToNextScreen() async {
    await Future.delayed(const Duration(milliseconds: 2600));

    if (!mounted) return;

    final user = sb.Supabase.instance.client.auth.currentUser;
    final prefs = ref.read(sharedPreferencesProvider);
    final completedWalkthrough = prefs.getBool('completed_walkthrough') ?? false;

    if (!completedWalkthrough) {
      context.go('/onboarding');
    } else if (user == null) {
      context.go('/login');
    } else {
      context.go('/');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      body: Stack(
        children: [
          // Background ambient glowing ambient light orbs
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    PulseTheme.accent.withOpacity(0.25),
                    PulseTheme.accent.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -80,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    PulseTheme.sleepPrimary.withOpacity(0.22),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Central content
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),

                    // Animated Logo Container with Pulsing Bio-Rings
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final pulseVal = _pulseController.value;
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer pulsing aura
                            Container(
                              width: 170 + (pulseVal * 20),
                              height: 170 + (pulseVal * 20),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: PulseTheme.accent.withOpacity(0.15 * (1 - pulseVal)),
                                  width: 2,
                                ),
                              ),
                            ),
                            // Middle glowing ring
                            Container(
                              width: 140 + (pulseVal * 10),
                              height: 140 + (pulseVal * 10),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    PulseTheme.accent.withOpacity(0.35 * pulseVal),
                                    PulseTheme.sleepPrimary.withOpacity(0.1 * pulseVal),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                            // Glass core box
                            Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.06),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.18),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: PulseTheme.accent.withOpacity(0.3),
                                    blurRadius: 30,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Image.asset(
                                  'assets/logo.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.favorite_rounded,
                                    size: 48,
                                    color: PulseTheme.accent,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    )
                        .animate()
                        .scale(duration: 900.ms, curve: Curves.easeOutBack)
                        .fade(duration: 700.ms),

                    const SizedBox(height: 36),

                    // App Title with Gradient Effect
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [
                          Colors.white,
                          PulseTheme.accent.withOpacity(0.9),
                          Colors.white,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      child: const Text(
                        'PULSE AI',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 6,
                          height: 1.1,
                        ),
                      ),
                    )
                        .animate()
                        .slideY(begin: 0.4, end: 0, duration: 800.ms, curve: Curves.easeOutBack)
                        .fade(duration: 800.ms),

                    const SizedBox(height: 10),

                    // Tagline
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: PulseTheme.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: PulseTheme.accent.withOpacity(0.25),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'ADVANCED HEALTH INTELLIGENCE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: PulseTheme.accent,
                          letterSpacing: 2.5,
                        ),
                      ),
                    )
                        .animate()
                        .slideY(begin: 0.5, end: 0, duration: 800.ms, delay: 250.ms, curve: Curves.easeOutBack)
                        .fade(duration: 800.ms, delay: 250.ms),

                    const Spacer(),

                    // Progress Loader & Dynamic Status Message
                    Column(
                      children: [
                        SizedBox(
                          width: 140,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              minHeight: 3,
                              backgroundColor: Colors.white.withOpacity(0.1),
                              color: PulseTheme.accent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            _statusMessage,
                            key: ValueKey(_statusMessage),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.5),
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    )
                        .animate()
                        .fade(duration: 600.ms, delay: 400.ms),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

