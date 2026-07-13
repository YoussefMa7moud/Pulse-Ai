import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme.dart';
import '../../../data/database_service.dart';
import '../../providers/providers.dart';
import '../../providers/data_providers.dart';
import '../../../widgets/glass_container.dart';
import '../../../widgets/animated_background.dart';
import '../../../data/collections/user_profile.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final syncResultAsync = ref.watch(forceSyncProvider);
    final authAsync = ref.watch(healthAuthStateProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Profile & Settings'),
      ),
      body: AnimatedGradientBackground(
        child: SafeArea(
          child: profileAsync.when(
            data: (profile) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── User Info Card ───────────────────────────────────────────
                GlassContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(colors: [
                                PulseTheme.accent.withOpacity(0.3),
                                PulseTheme.sleepPrimary.withOpacity(0.3),
                              ]),
                            ),
                            child: const Icon(Icons.person,
                                color: Colors.white, size: 30),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        profile.name ?? 'User',
                                        style: Theme.of(context).textTheme.titleLarge,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.edit, color: PulseTheme.secondary, size: 20),
                                      onPressed: () => _showEditProfileDialog(context, profile, ref),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${profile.age ?? '--'} years • ${profile.gender ?? '--'}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                Text(
                                  '${profile.heightCm?.toStringAsFixed(0) ?? '--'} cm • '
                                  '${profile.weightKg?.toStringAsFixed(1) ?? '--'} kg',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: PulseTheme.accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: PulseTheme.accent.withOpacity(0.3)),
                        ),
                        child: Text(
                          'Goal: ${profile.primaryGoal ?? "Not set"}',
                          style: TextStyle(
                              color: PulseTheme.accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Google Health Connect Section ────────────────────────────
                Text('Google Health Connect',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                GlassContainer(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Connection Status Row
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFFF6B35).withOpacity(0.15),
                            ),
                            child: const Icon(Icons.health_and_safety,
                                color: Color(0xFFFF6B35), size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                authAsync.when(
                                  data: (authorized) => Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      const Text('Health Connect',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: authorized
                                              ? PulseTheme.recoveryHigh
                                                  .withOpacity(0.15)
                                              : PulseTheme.recoveryLow
                                                  .withOpacity(0.15),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          authorized ? 'Connected' : 'Not connected',
                                          style: TextStyle(
                                              color: authorized
                                                  ? PulseTheme.recoveryHigh
                                                  : PulseTheme.recoveryLow,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  loading: () =>
                                      const Text('Checking connection...'),
                                  error: (_, __) =>
                                      const Text('Connection unknown'),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  profile.lastSyncDate != null
                                      ? 'Last sync: ${_formatDate(profile.lastSyncDate!)}'
                                      : 'Never synced',
                                  style: TextStyle(
                                      color: PulseTheme.secondary,
                                      fontSize: 12),
                                ),
                                if (profile.huaweiDisplayName != null)
                                  Text(
                                    'Account Linked',
                                    style: TextStyle(
                                        color: PulseTheme.secondary,
                                        fontSize: 12),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Sync Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: syncResultAsync.isLoading
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: PulseTheme.accent))
                              : const Icon(Icons.sync, size: 18),
                          label: Text(syncResultAsync.isLoading
                              ? 'Syncing Health Data...'
                              : 'Sync Now (Last 30 Days)'),
                          onPressed: syncResultAsync.isLoading
                              ? null
                              : () {
                                  ref.invalidate(forceSyncProvider);
                                  ref.invalidate(todayMetricsProvider);
                                  ref.invalidate(historyMetricsProvider);
                                  ref.invalidate(todayScoresProvider);
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PulseTheme.accent.withOpacity(0.15),
                            foregroundColor: PulseTheme.accent,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Re-authorize Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.vpn_key_outlined, size: 16),
                          label: const Text('Manage Permissions'),
                          onPressed: () async {
                            final health = ref.read(healthServiceProvider);
                            bool success = false;
                            String? errorMsg;
                            try {
                              success = await health.requestPermissions();
                            } catch (e) {
                              errorMsg = e.toString();
                            }

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(success
                                    ? '✓ Health Connect authorized'
                                    : (errorMsg ?? 'Authorization failed')),
                                backgroundColor: success
                                    ? PulseTheme.recoveryHigh
                                    : PulseTheme.recoveryLow,
                                duration: success ? const Duration(seconds: 4) : const Duration(seconds: 8),
                              ));
                              if (success) {
                                profile.isHuaweiHealthEnabled = true;
                                profile.lastSyncDate = DateTime.now();
                                await ref
                                    .read(databaseProvider)
                                    .saveUserProfile(profile);
                                ref.invalidate(userProfileProvider);
                                ref.invalidate(healthAuthStateProvider);
                              }
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: PulseTheme.secondary,
                            side: BorderSide(
                                color: PulseTheme.secondary.withOpacity(0.3)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),

                      // Sync result feedback
                      syncResultAsync.when(
                        data: (result) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                result.success
                                    ? '✓ Synced ${result.daysImported} days, ${result.workoutsImported} workouts'
                                    : 'Sync error: ${result.error ?? "unknown"}',
                                style: TextStyle(
                                    color: result.success ? PulseTheme.recoveryHigh : PulseTheme.recoveryLow,
                                    fontSize: 12),
                              ),
                            ),
                            // ── Debug: Show raw DB data for today ──
                            if (result.success)
                              FutureBuilder<String>(
                                future: _getDiagnosticInfo(ref),
                                builder: (ctx, snap) {
                                  if (!snap.hasData) return const SizedBox();
                                  return Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: PulseTheme.accent.withOpacity(0.3)),
                                    ),
                                    child: Text(
                                      snap.data!,
                                      style: TextStyle(color: PulseTheme.secondary, fontSize: 10, fontFamily: 'monospace'),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                        loading: () => const SizedBox(),
                        error: (e, __) => Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('Sync error: $e', style: TextStyle(color: PulseTheme.recoveryLow, fontSize: 11)),
                        ),
                      ),

                      const SizedBox(height: 16),
                      // Data types card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Data Imported from Health Connect:',
                                style: TextStyle(
                                    color: PulseTheme.secondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                'Steps', 'Distance', 'Calories', 'Heart Rate',
                                'HRV', 'Resting HR', 'Sleep Stages', 'SpO2',
                                'Body Fat', 'Weight', 'Blood Pressure',
                                'Temperature', 'Workout Sessions',
                              ].map((label) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: PulseTheme.accent.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(label,
                                        style: TextStyle(
                                            color: PulseTheme.accent,
                                            fontSize: 11)),
                                  )).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Theme Settings ───────────────────────────────────────────
                Text('Theme Settings',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                GlassContainer(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text('Theme Mode'),
                        trailing: DropdownButton<ThemeMode>(
                          value: ref.watch(themeSettingsProvider).mode,
                          dropdownColor: PulseTheme.surface,
                          items: ThemeMode.values
                              .map((m) => DropdownMenuItem(
                                  value: m,
                                  child: Text(m.name.toUpperCase(), style: const TextStyle(fontSize: 12))))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              ref.read(themeSettingsProvider.notifier).updateThemeMode(val);
                            }
                          },
                        ),
                      ),
                      ListTile(
                        title: const Text('Theme Variant'),
                        trailing: DropdownButton<ThemeVariant>(
                          value: ref.watch(themeSettingsProvider).variant,
                          dropdownColor: PulseTheme.surface,
                          items: ThemeVariant.values
                              .map((v) => DropdownMenuItem(
                                  value: v,
                                  child: Text(
                                    v.name == 'midnightSlate'
                                        ? 'Midnight Slate'
                                        : v.name == 'neonHorizon'
                                            ? 'Neon Horizon'
                                            : v.name == 'forestZen'
                                                ? 'Forest Zen'
                                                : 'Sunset Crimson',
                                    style: const TextStyle(fontSize: 12),
                                  )))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              ref.read(themeSettingsProvider.notifier).updateThemeVariant(val);
                            }
                          },
                        ),
                      ),
                      ListTile(
                        title: const Text('Widget Card Style'),
                        trailing: DropdownButton<WidgetCardTheme>(
                          value: ref.watch(themeSettingsProvider).widgetCardTheme,
                          dropdownColor: PulseTheme.surface,
                          items: WidgetCardTheme.values
                              .map((wt) => DropdownMenuItem(
                                  value: wt,
                                  child: Text(
                                    wt.name == 'glassmorphism'
                                        ? 'Glassmorphism'
                                        : wt.name == 'cyberpunk'
                                            ? 'Cyberpunk Neon'
                                            : wt.name == 'animatedAura'
                                                ? 'Animated Aura'
                                                : 'Minimal Stark',
                                    style: const TextStyle(fontSize: 12),
                                  )))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              ref.read(themeSettingsProvider.notifier).updateWidgetCardTheme(val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── AI Settings ──────────────────────────────────────────────
                Text('AI Settings',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                GlassContainer(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text('AI Provider'),
                        subtitle: Text(
                            'All responses are grounded in your health data',
                            style: TextStyle(
                                color: PulseTheme.secondary, fontSize: 11)),
                        trailing: DropdownButton<String>(
                          value: profile.defaultAiProvider,
                          dropdownColor: PulseTheme.surface,
                          items: ['groq', 'openai', 'gemini', 'claude']
                              .map((p) => DropdownMenuItem(
                                  value: p, child: Text(p)))
                              .toList(),
                          onChanged: (val) async {
                            profile.defaultAiProvider = val!;
                            await ref
                                .read(databaseProvider)
                                .saveUserProfile(profile);
                            ref.invalidate(userProfileProvider);
                          },
                        ),
                      ),
                      ListTile(
                        title: const Text('AI Model'),
                        trailing: DropdownButton<String>(
                          value: profile.defaultAiModel,
                          dropdownColor: PulseTheme.surface,
                          items: [
                            'llama-3.3-70b-versatile',
                            'llama-3.1-70b-versatile',
                            'gpt-4o',
                            'gemini-pro',
                          ]
                              .map((m) => DropdownMenuItem(
                                  value: m, child: Text(m, style: const TextStyle(fontSize: 12))))
                              .toList(),
                          onChanged: (val) async {
                            profile.defaultAiModel = val!;
                            await ref
                                .read(databaseProvider)
                                .saveUserProfile(profile);
                            ref.invalidate(userProfileProvider);
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ── Auth Zone ──────────────────────────────────────────────
                ElevatedButton(
                  onPressed: () async {
                    final db = ref.read(databaseProvider);
                    await db.client.auth.signOut();
                    if (context.mounted) {
                      context.go('/login');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PulseTheme.recoveryLow.withOpacity(0.15),
                    foregroundColor: PulseTheme.recoveryLow,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Sign Out',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 24),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ),
    );
  }

  Future<String> _getDiagnosticInfo(WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final now = DateTime.now();
    final utcToday = DateTime.utc(now.year, now.month, now.day);
    final metric = await db.getMetricForDay(now);
    final allMetrics = await db.getRecentMetrics(days: 30);
    final allScores = await db.getRecentScores(days: 30);

    final buf = StringBuffer();
    buf.writeln('=== DB Diagnostic ===');
    buf.writeln('Query date (UTC): $utcToday');
    buf.writeln('Total metrics in DB: ${allMetrics.length}');
    buf.writeln('Total scores in DB: ${allScores.length}');
    buf.writeln('');
    if (metric != null) {
      buf.writeln('TODAY (${metric.date}):');
      buf.writeln('  Steps: ${metric.steps}');
      buf.writeln('  ActiveCal: ${metric.activeCalories}');
      buf.writeln('  BasalCal: ${metric.caloriesBurned}');
      buf.writeln('  AvgHR: ${metric.averageHeartRate}');
      buf.writeln('  RestHR: ${metric.restingHeartRate}');
      buf.writeln('  HRV: ${metric.hrv}');
      buf.writeln('  SleepMin: ${metric.totalSleepMinutes}');
      buf.writeln('  Distance: ${metric.distanceMeters}');
      buf.writeln('  SpO2: ${metric.bloodOxygenSpO2}');
      buf.writeln('  Weight: ${metric.weightKg}');
    } else {
      buf.writeln('TODAY: NO METRIC FOUND for $utcToday');
      if (allMetrics.isNotEmpty) {
        buf.writeln('');
        buf.writeln('Most recent metric dates:');
        for (final m in allMetrics.take(5)) {
          buf.writeln('  ${m.date} steps=${m.steps} sleep=${m.totalSleepMinutes}');
        }
      }
    }
    return buf.toString();
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showEditProfileDialog(BuildContext context, UserProfile profile, WidgetRef ref) async {
    final ageController = TextEditingController(text: profile.age?.toString() ?? '');
    final heightController = TextEditingController(text: profile.heightCm?.toString() ?? '');
    final weightController = TextEditingController(text: profile.weightKg?.toString() ?? '');

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: PulseTheme.surfaceLight,
          title: const Text('Edit Profile', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ageController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Age (years)', labelStyle: TextStyle(color: PulseTheme.secondary)),
                style: const TextStyle(color: Colors.white),
              ),
              TextField(
                controller: heightController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Height (cm)', labelStyle: TextStyle(color: PulseTheme.secondary)),
                style: const TextStyle(color: Colors.white),
              ),
              TextField(
                controller: weightController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Weight (kg)', labelStyle: TextStyle(color: PulseTheme.secondary)),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: PulseTheme.secondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: PulseTheme.accent),
              onPressed: () async {
                final db = ref.read(databaseProvider);
                profile.age = int.tryParse(ageController.text) ?? profile.age;
                profile.heightCm = double.tryParse(heightController.text) ?? profile.heightCm;
                profile.weightKg = double.tryParse(weightController.text) ?? profile.weightKg;
                await db.saveUserProfile(profile);
                ref.invalidate(userProfileProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}
