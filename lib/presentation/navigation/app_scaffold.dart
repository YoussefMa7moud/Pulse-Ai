import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';

class AppScaffold extends ConsumerWidget {
  final Widget child;

  const AppScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch themeSettingsProvider to trigger rebuild of bottom navigation on theme changes
    ref.watch(themeSettingsProvider);

    return Scaffold(
      extendBody: true, // Content flows behind the floating navigation bar
      body: child,
      bottomNavigationBar: const _BottomNav(),
    );
  }
}

class _BottomNav extends ConsumerWidget {
  const _BottomNav();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch themeSettingsProvider to rebuild immediately when theme updates
    ref.watch(themeSettingsProvider);

    final String location = GoRouterState.of(context).uri.path;

    int currentIndex = 0;
    if (location.startsWith('/exercise')) currentIndex = 1;
    if (location.startsWith('/coach')) currentIndex = 2;
    if (location.startsWith('/health')) currentIndex = 3;
    if (location.startsWith('/insights')) currentIndex = 4;

    return SafeArea(
      bottom: true,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: PulseTheme.surface.withOpacity(0.75),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildTabItem(context, 0, Icons.home_rounded, Icons.home_outlined, 'Home', currentIndex == 0),
                  _buildTabItem(context, 1, Icons.directions_run_rounded, Icons.directions_run_outlined, 'Exercises', currentIndex == 1),
                  _buildCenterCoachItem(context, currentIndex == 2),
                  _buildTabItem(context, 3, Icons.favorite_rounded, Icons.favorite_border_rounded, 'Health', currentIndex == 3),
                  _buildTabItem(context, 4, Icons.insights_rounded, Icons.insights_outlined, 'Insights', currentIndex == 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(
    BuildContext context,
    int index,
    IconData activeIcon,
    IconData inactiveIcon,
    String label,
    bool isActive,
  ) {
    final color = isActive ? PulseTheme.accent : PulseTheme.secondary;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          switch (index) {
            case 0: context.go('/'); break;
            case 1: context.go('/exercise'); break;
            case 3: context.go('/health'); break;
            case 4: context.go('/insights'); break;
          }
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : inactiveIcon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 2),
            // Tiny active indicator dot
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 3,
              width: isActive ? 12 : 0,
              decoration: BoxDecoration(
                color: PulseTheme.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterCoachItem(BuildContext context, bool isActive) {
    return GestureDetector(
      onTap: () => context.go('/coach'),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              PulseTheme.accent,
              PulseTheme.sleepPrimary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: PulseTheme.accent.withOpacity(0.35),
              blurRadius: 12,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.auto_awesome,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}
