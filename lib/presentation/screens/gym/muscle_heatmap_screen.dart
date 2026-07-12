import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../widgets/glass_container.dart';
import '../../../widgets/animated_background.dart';
import '../../../data/database_service.dart';
import '../../../data/collections/gym_models.dart';
final muscleFatigueProvider = FutureProvider<Map<String, double>>((ref) async {
  final db = ref.watch(databaseProvider);
  final routines = await db.getRecentRoutines();
  
  // Calculate a mock fatigue based on volume (sets * reps * weight)
  Map<String, double> fatigue = {
    "Chest": 0.0,
    "Back": 0.0,
    "Legs": 0.0,
    "Arms": 0.0,
    "Shoulders": 0.0,
    "Core": 0.0,
  };

  for (final r in routines) {
    for (final ex in r.exercises) {
      if (ex.isCustom && ex.targetMuscle != null && fatigue.containsKey(ex.targetMuscle)) {
        for (final set in ex.sets) {
          if (set.isCompleted) {
            double volume = (set.weightKg ?? 1.0) * (set.reps ?? 1);
            fatigue[ex.targetMuscle!] = (fatigue[ex.targetMuscle!] ?? 0) + volume;
          }
        }
      } else if (!ex.isCustom) {
        // Map predefined exercises
        String m = "Core";
        if (["Bench Press", "Push Up"].contains(ex.name)) m = "Chest";
        if (["Squat", "Leg Press", "Deadlift"].contains(ex.name)) m = "Legs";
        if (["Pull Up", "Barbell Row"].contains(ex.name)) m = "Back";
        if (["Bicep Curl", "Tricep Extension"].contains(ex.name)) m = "Arms";
        if (["Overhead Press"].contains(ex.name)) m = "Shoulders";
        
        for (final set in ex.sets) {
          if (set.isCompleted) {
            double volume = (set.weightKg ?? 1.0) * (set.reps ?? 1);
            fatigue[m] = (fatigue[m] ?? 0) + volume;
          }
        }
      }
    }
  }

  // Normalize to 0-100 for display
  double maxV = 1;
  for (final v in fatigue.values) {
    if (v > maxV) maxV = v;
  }
  
  for (final k in fatigue.keys.toList()) {
    fatigue[k] = (fatigue[k]! / maxV) * 100.0;
  }

  return fatigue;
});

class MuscleHeatmapScreen extends ConsumerWidget {
  const MuscleHeatmapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fatigueAsync = ref.watch(muscleFatigueProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Muscle Heatmap', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
      ),
      body: AnimatedGradientBackground(
        child: SafeArea(
          child: fatigueAsync.when(
            data: (fatigueMap) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  GlassContainer(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.local_fire_department, color: PulseTheme.strainPrimary),
                            SizedBox(width: 8),
                            Text('MUSCLE FATIGUE / LOAD', style: TextStyle(color: PulseTheme.strainPrimary, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text("Based on your recent workout volume (weight × reps).", style: TextStyle(color: PulseTheme.secondary, fontSize: 12)),
                        const SizedBox(height: 24),
                        ...fatigueMap.entries.map((e) {
                          Color c = PulseTheme.recoveryLow;
                          if (e.value > 66) c = PulseTheme.strainPrimary;
                          else if (e.value > 33) c = Colors.orange;
                          else if (e.value > 0) c = Colors.yellow;
                          else c = PulseTheme.surfaceLight;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                    Text("${e.value.toInt()}%", style: TextStyle(color: c, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(
                                  value: e.value / 100.0,
                                  backgroundColor: PulseTheme.surfaceLight,
                                  color: c,
                                  minHeight: 8,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text("Error loading heatmap: $e", style: const TextStyle(color: Colors.white))),
          ),
        ),
      ),
    );
  }
}
