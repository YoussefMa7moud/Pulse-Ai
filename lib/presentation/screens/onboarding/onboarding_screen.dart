import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme.dart';
import '../../providers/providers.dart';
import '../../../widgets/animated_background.dart';
import '../../../widgets/glass_container.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<WalkthroughPageData> _pages = [
    WalkthroughPageData(
      title: 'PULSE AI',
      subtitle: 'Your personal AI health intelligence platform powered by wearable telemetry.',
      description: 'Pulse AI monitors your recovery, strain, sleep, and physiological data in real-time, translating complex metrics into actionable insights.',
      icon: Icons.favorite_rounded,
      color: PulseTheme.recoveryLow,
    ),
    WalkthroughPageData(
      title: 'BIOMETRIC SYNC',
      subtitle: 'Seamless integration with Google Health Connect.',
      description: 'Automatically pull resting heart rate, HRV, sleep stages, active minutes, and steps directly from your device. No manual logging required.',
      icon: Icons.sync_rounded,
      color: PulseTheme.accent,
    ),
    WalkthroughPageData(
      title: 'AI COACHING',
      subtitle: 'Conversational coach built for your health goals.',
      description: 'Receive highly tailored daily advice and chat with an elite AI health coach that knows your historical baselines and training responses.',
      icon: Icons.auto_awesome,
      color: PulseTheme.sleepPrimary,
    ),
    WalkthroughPageData(
      title: 'READY TO START?',
      subtitle: 'Join Pulse AI today to unlock your performance potential.',
      description: 'Sign in to access your dashboard, or create a new account to configure your profile and synchronize your metrics.',
      icon: Icons.celebration_rounded,
      color: PulseTheme.strainPrimary,
    ),
  ];

  Future<void> _completeWalkthrough(String targetRoute) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool('completed_walkthrough', true);
    if (mounted) {
      context.go(targetRoute);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: AnimatedGradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              children: [
                // Top Progress Indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pages.length, (index) {
                    final isSelected = _currentPage == index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 6,
                      width: isSelected ? 24 : 6,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _pages[_currentPage].color
                            : Colors.white24,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),

                // Main Slider
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (page) {
                      setState(() {
                        _currentPage = page;
                      });
                    },
                    itemBuilder: (context, index) {
                      final item = _pages[index];
                      return Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Icon Graphic
                              Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      item.color.withOpacity(0.3),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                                child: index == 0
                                    ? Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Image.asset(
                                          'assets/logo.png',
                                          fit: BoxFit.contain,
                                        ),
                                      )
                                    : Icon(
                                        item.icon,
                                        size: 72,
                                        color: item.color,
                                      ),
                              ),
                              const SizedBox(height: 40),

                              // Text Content
                              Text(
                                item.title,
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 2,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item.subtitle,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: item.color,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              GlassContainer(
                                padding: const EdgeInsets.all(20),
                                borderColor: item.color.withOpacity(0.2),
                                child: Text(
                                  item.description,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white70,
                                    height: 1.6,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // Navigation Controls
                if (_currentPage < _pages.length - 1)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () {
                          _pageController.animateToPage(
                            _pages.length - 1,
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: Text(
                          'SKIP',
                          style: TextStyle(
                            color: PulseTheme.secondary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _pages[_currentPage].color,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: () {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: const Row(
                          children: [
                            Text(
                              'NEXT',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                                letterSpacing: 1.5,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward_rounded, color: Colors.black, size: 18),
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _pages[_currentPage].color,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                        ),
                        onPressed: () => _completeWalkthrough('/login?mode=register'),
                        child: const Text(
                          'CREATE ACCOUNT',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                            fontSize: 15,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.white.withOpacity(0.4), width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () => _completeWalkthrough('/login?mode=login'),
                        child: const Text(
                          'SIGN IN',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            fontSize: 15,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WalkthroughPageData {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color color;

  WalkthroughPageData({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.color,
  });
}
