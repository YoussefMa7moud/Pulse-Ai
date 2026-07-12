import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme.dart';
import '../../../data/database_service.dart';
import '../../../data/collections/user_profile.dart';
import '../../providers/providers.dart';
import '../../../widgets/animated_background.dart';

/// 9-page onboarding flow:
/// Welcome → Name → Age → Gender → Height → Weight → Goal →
/// Google Health Connect → Finish
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();

  // User profile data to collect
  String name = '';
  int age = 25;
  String gender = 'Male';
  double heightCm = 175.0;
  double weightKg = 70.0;
  String primaryGoal = 'Improve Fitness';

  // Health Connect auth state
  bool _healthConnected = false;
  bool _connectingHealth = false;

  void _nextPage() {
    _pageController.nextPage(
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  Future<void> _finishSetup() async {
    final db = ref.read(databaseProvider);
    final profile = await db.getUserProfile();
    profile.name = name;
    profile.age = age;
    profile.gender = gender;
    profile.heightCm = heightCm;
    profile.weightKg = weightKg;
    profile.primaryGoal = primaryGoal;
    profile.hasCompletedOnboarding = true;
    profile.isHuaweiHealthEnabled = _healthConnected;
    profile.lastSyncDate = DateTime.now();

    await db.saveUserProfile(profile);

    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: AnimatedGradientBackground(
        child: SafeArea(
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildWelcome(),
              _buildName(),
              _buildAge(),
              _buildGender(),
              _buildHeight(),
              _buildWeight(),
              _buildGoal(),
              _buildHealthConnect(),
              _buildFinish(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Pages ─────────────────────────────────────────────────────────────────

  Widget _buildWelcome() {
    return _buildPage(
      title: 'Welcome to Pulse AI',
      subtitle: 'Your personal AI health intelligence platform powered by Google Health Connect.',
      child: Center(
        child: Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              PulseTheme.accent.withOpacity(0.3),
              Colors.transparent,
            ]),
          ),
          child: const Icon(Icons.favorite,
              size: 80, color: PulseTheme.recoveryHigh),
        ),
      ),
      buttonText: 'Get Started',
      onNext: _nextPage,
    );
  }

  Widget _buildName() {
    return _buildPage(
      title: 'What should we call you?',
      subtitle: 'Personalising your AI coaching experience.',
      child: Center(
        child: TextField(
          style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: 'Your Name',
            hintStyle: TextStyle(color: PulseTheme.secondary),
            border: InputBorder.none,
          ),
          onChanged: (val) => name = val,
        ),
      ),
      buttonText: 'Continue',
      onNext: () { if (name.isNotEmpty) _nextPage(); },
    );
  }

  Widget _buildAge() {
    return _buildPage(
      title: 'How old are you?',
      subtitle: 'Age affects heart rate zones and recovery baseline calculations.',
      child: Center(
        child: DropdownButton<int>(
          value: age,
          dropdownColor: PulseTheme.surface,
          style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
          items: List.generate(80, (i) => 15 + i).map((a) {
            return DropdownMenuItem(value: a, child: Text(a.toString()));
          }).toList(),
          onChanged: (val) => setState(() => age = val!),
        ),
      ),
      buttonText: 'Continue',
      onNext: _nextPage,
    );
  }

  Widget _buildGender() {
    return _buildPage(
      title: 'What is your gender?',
      subtitle: 'Used for precise physiological and hormonal calculations.',
      child: Center(
        child: DropdownButton<String>(
          value: gender,
          dropdownColor: PulseTheme.surface,
          style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
          items: ['Male', 'Female', 'Other'].map((g) {
            return DropdownMenuItem(value: g, child: Text(g));
          }).toList(),
          onChanged: (val) => setState(() => gender = val!),
        ),
      ),
      buttonText: 'Continue',
      onNext: _nextPage,
    );
  }

  Widget _buildHeight() {
    return _buildPage(
      title: 'What is your height?',
      subtitle: 'In centimetres — used for VO2 Max, BMI and pace calculations.',
      child: Center(
        child: DropdownButton<double>(
          value: heightCm,
          dropdownColor: PulseTheme.surface,
          style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
          items: List.generate(100, (i) => 120.0 + i).map((h) {
            return DropdownMenuItem(
                value: h, child: Text('${h.toStringAsFixed(0)} cm'));
          }).toList(),
          onChanged: (val) => setState(() => heightCm = val!),
        ),
      ),
      buttonText: 'Continue',
      onNext: _nextPage,
    );
  }

  Widget _buildWeight() {
    return _buildPage(
      title: 'What is your weight?',
      subtitle: 'In kilograms — used for calorie, strain, and body composition calculations.',
      child: Center(
        child: DropdownButton<double>(
          value: weightKg,
          dropdownColor: PulseTheme.surface,
          style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
          items: List.generate(150, (i) => 40.0 + i).map((w) {
            return DropdownMenuItem(
                value: w, child: Text('${w.toStringAsFixed(0)} kg'));
          }).toList(),
          onChanged: (val) => setState(() => weightKg = val!),
        ),
      ),
      buttonText: 'Continue',
      onNext: _nextPage,
    );
  }

  Widget _buildGoal() {
    const goals = [
      'Improve Fitness',
      'Maximize Recovery',
      'Optimize Sleep',
      'Lose Body Fat',
      'Build Muscle',
      'Manage Stress',
      'General Health',
    ];
    return _buildPage(
      title: 'What is your primary goal?',
      subtitle: 'Pulse AI will tailor every recommendation to this goal.',
      child: Center(
        child: DropdownButton<String>(
          value: primaryGoal,
          dropdownColor: PulseTheme.surface,
          style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
          items: goals.map((g) {
            return DropdownMenuItem(value: g, child: Text(g));
          }).toList(),
          onChanged: (val) => setState(() => primaryGoal = val!),
        ),
      ),
      buttonText: 'Continue',
      onNext: _nextPage,
    );
  }

  Widget _buildHealthConnect() {
    return _buildPage(
      title: 'Connect Health Data',
      subtitle: 'Authorize Google Health Connect so Pulse AI '
          'can give you data-driven insights based on your real physiological measurements.',
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFF4285F4).withOpacity(0.3),
                  Colors.transparent,
                ]),
              ),
              child: const Icon(Icons.health_and_safety,
                  size: 70, color: Color(0xFF4285F4)),
            ),
            const SizedBox(height: 24),
            if (_healthConnected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: PulseTheme.recoveryHigh.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: PulseTheme.recoveryHigh.withOpacity(0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: PulseTheme.recoveryHigh, size: 20),
                    SizedBox(width: 8),
                    Text('Health Connect Linked!',
                        style: TextStyle(color: PulseTheme.recoveryHigh,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Text(
              'Access includes: Steps · Heart Rate · HRV · Sleep Stages · SpO2 · '
              'Body Composition · Blood Pressure · Workout Sessions · and more.',
              textAlign: TextAlign.center,
              style: TextStyle(color: PulseTheme.secondary, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
      buttonText: _connectingHealth
          ? 'Connecting...'
          : (_healthConnected ? 'Connected — Continue' : 'Enable Health Connect'),
      onNext: _healthConnected
          ? _nextPage
          : () async {
              setState(() => _connectingHealth = true);
              final healthService = ref.read(healthServiceProvider);
              bool success = false;
              String? errorMessage;
              try {
                success = await healthService.requestPermissions();
              } catch (e) {
                errorMessage = e.toString();
              }
              
              if (!mounted) return;
              setState(() {
                _connectingHealth = false;
                _healthConnected = success;
              });
              
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✓ Health Connect authorized successfully!'),
                    backgroundColor: PulseTheme.recoveryHigh,
                  ),
                );
                // Kick off initial sync in background
                final syncUseCase = ref.read(syncUseCaseProvider);
                syncUseCase.syncAll(daysBack: 30);
                await Future.delayed(const Duration(milliseconds: 800));
                _nextPage();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        errorMessage ?? 'Authorization failed. Please try again.'),
                    backgroundColor: PulseTheme.recoveryLow,
                    duration: const Duration(seconds: 6),
                  ),
                );
              }
            },
    );
  }

  Widget _buildFinish() {
    return _buildPage(
      title: "You're All Set!",
      subtitle: 'Pulse AI is syncing your health data. Your personalised '
          'AI insights will be ready shortly.',
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle,
                size: 100, color: PulseTheme.recoveryHigh),
            const SizedBox(height: 24),
            Text(
              _healthConnected
                  ? 'Analysing your health data...'
                  : 'You can connect your health data later in Settings.',
              textAlign: TextAlign.center,
              style: TextStyle(color: PulseTheme.secondary, fontSize: 14),
            ),
          ],
        ),
      ),
      buttonText: 'Enter Pulse AI',
      onNext: _finishSetup,
    );
  }

  // ─── Page Template ──────────────────────────────────────────────────────────

  Widget _buildPage({
    required String title,
    required String subtitle,
    required Widget child,
    required String buttonText,
    required VoidCallback onNext,
  }) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .displayMedium
                      ?.copyWith(fontSize: 36),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Text(subtitle,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: PulseTheme.secondary, height: 1.5),
                  textAlign: TextAlign.center),
              const SizedBox(height: 48),
              child,
              const SizedBox(height: 48),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: PulseTheme.primary,
                  foregroundColor: PulseTheme.background,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  elevation: 0,
                ),
                onPressed: onNext,
                child: Text(buttonText,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
