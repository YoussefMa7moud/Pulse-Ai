import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme.dart';
import '../../providers/providers.dart';
import '../../../widgets/animated_background.dart';
import '../../../widgets/glass_container.dart';

import 'package:flutter_animate/flutter_animate.dart';

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
      title: 'WEARABLE SYNC',
      subtitle: 'Connects with any wearable device via Health Connect.',
      description: 'Pulse AI seamlessly pulls your vital data — including resting heart rate, HRV, and sleep stages. Connect your favorite wearable directly through Health Connect.',
      icon: Icons.sync_rounded, // Fallback if image fails
      useLogoImage: true,
      imagePath: 'assets/health_connect_logo.png',
      color: PulseTheme.accent,
    ),
    WalkthroughPageData(
      title: 'PHYSIOLOGICAL SCORES',
      subtitle: 'Understand your body like never before.',
      description: 'Every morning, your data is translated into 0-100 scores for Recovery, Strain, and Sleep Quality, helping you know exactly when to push and when to rest.',
      icon: Icons.analytics_rounded,
      useLogoImage: false,
      color: PulseTheme.recoveryMedium,
    ),
    WalkthroughPageData(
      title: 'AI COACHING & INSIGHTS',
      subtitle: 'Your personal sports scientist in your pocket.',
      description: 'Our advanced AI analyzes your daily and 30-day trends to provide highly personalized, dynamic coaching and daily advice tailored specifically to your metrics.',
      icon: Icons.auto_awesome,
      useLogoImage: false,
      color: PulseTheme.sleepPrimary,
    ),
    WalkthroughPageData(
      title: 'MEDICAL DISCLAIMER',
      subtitle: 'Pulse AI is not a medical device.',
      description: 'This app helps you track data and gives insights based on it. However, this cannot be considered reliable medical advice, and the AI can make mistakes. Always consult a doctor for medical concerns.',
      icon: Icons.warning_rounded,
      useLogoImage: false,
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
                ).animate().fade(duration: 500.ms),
                const SizedBox(height: 20),

                // Main Slider
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (page) {
                      setState(() {
                        _currentPage = page;
                      });
                    },
                    itemCount: _pages.length,
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
                                child: item.useLogoImage
                                    ? Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Image.asset(
                                          item.imagePath ?? '',
                                          fit: BoxFit.contain,
                                          errorBuilder: (context, error, stackTrace) => Icon(item.icon, size: 72, color: item.color),
                                        ),
                                      )
                                    : Icon(
                                        item.icon,
                                        size: 72,
                                        color: item.color,
                                      ),
                              ).animate(key: ValueKey(index)).scale(duration: 600.ms, curve: Curves.easeOutBack).fade(),
                              const SizedBox(height: 40),

                              // Text Content
                              Text(
                                item.title,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 2,
                                ),
                                textAlign: TextAlign.center,
                              ).animate(key: ValueKey('title_$index')).slideY(begin: 0.5, end: 0, duration: 500.ms, curve: Curves.easeOutQuad).fade(),
                              const SizedBox(height: 12),
                              Text(
                                item.subtitle,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: item.color,
                                ),
                                textAlign: TextAlign.center,
                              ).animate(key: ValueKey('sub_$index')).slideY(begin: 0.5, end: 0, duration: 500.ms, delay: 100.ms, curve: Curves.easeOutQuad).fade(),
                              const SizedBox(height: 28),
                              GlassContainer(
                                padding: const EdgeInsets.all(20),
                                borderColor: item.color.withOpacity(0.2),
                                child: Text(
                                  item.description,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Colors.white70,
                                    height: 1.6,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ).animate(key: ValueKey('desc_$index')).slideY(begin: 0.5, end: 0, duration: 500.ms, delay: 200.ms, curve: Curves.easeOutQuad).fade(),
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
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _pages[_currentPage].color,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, color: Colors.black, size: 20),
                          ],
                        ),
                      ),
                    ],
                  ).animate(key: ValueKey('btn_next_${_currentPage}')).fade(duration: 400.ms)
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _pages[_currentPage].color,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                        ),
                        onPressed: () => _completeWalkthrough('/login'),
                        child: const Text(
                          'ACCEPT',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                            fontSize: 16,
                            letterSpacing: 2,
                          ),
                        ),
                      ).animate().slideY(begin: 0.5, end: 0, duration: 500.ms, curve: Curves.easeOutBack).fade(),
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
  final bool useLogoImage;
  final String? imagePath;
  final Color color;

  WalkthroughPageData({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    this.useLogoImage = false,
    this.imagePath,
    required this.color,
  });
}
