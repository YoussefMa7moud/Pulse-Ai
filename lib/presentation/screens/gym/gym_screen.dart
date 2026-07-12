import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../widgets/glass_container.dart';
import '../../../widgets/animated_background.dart';
import '../../../data/database_service.dart';
import '../../../data/collections/gym_models.dart';
import '../../../data/collections/workout_session.dart';
import '../../providers/data_providers.dart';
import 'routine_builder_screen.dart';
import 'muscle_heatmap_screen.dart';
final gymTemplatesProvider = FutureProvider<List<GymRoutine>>((ref) async {
  final db = ref.watch(databaseProvider);
  return await db.getTemplates();
});

final recentRoutinesProvider = FutureProvider<List<GymRoutine>>((ref) async {
  final db = ref.watch(databaseProvider);
  return await db.getRecentRoutines();
});

final allExercisesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(databaseProvider);
  // Get custom exercises from DB
  final customExercises = await db.getCustomExercises();
  
  final Map<String, String> exerciseMuscles = {};
  
  // Base predefined
  final predefined = [
    {"name": "Bench Press", "muscle": "Chest"},
    {"name": "Squat", "muscle": "Legs"},
    {"name": "Deadlift", "muscle": "Back"},
    {"name": "Pull Up", "muscle": "Back"},
    {"name": "Push Up", "muscle": "Chest"},
    {"name": "Overhead Press", "muscle": "Shoulders"},
    {"name": "Barbell Row", "muscle": "Back"},
    {"name": "Bicep Curl", "muscle": "Arms"},
    {"name": "Tricep Extension", "muscle": "Arms"},
    {"name": "Leg Press", "muscle": "Legs"},
  ];

  for (final item in predefined) {
    exerciseMuscles[item["name"]!] = item["muscle"]!;
  }

  for (final ex in customExercises) {
    if (ex.name != null && ex.name!.isNotEmpty) {
      exerciseMuscles[ex.name!] = ex.targetMuscle ?? "Other";
    }
  }

  return exerciseMuscles.entries
      .map((entry) => {"name": entry.key, "muscle": entry.value})
      .toList()
    ..sort((a, b) => a["name"]!.compareTo(b["name"]!));
});

class GymScreen extends ConsumerStatefulWidget {
  const GymScreen({super.key});

  @override
  ConsumerState<GymScreen> createState() => _GymScreenState();
}

class _GymScreenState extends ConsumerState<GymScreen> {
  int _selectedTab = 0; // 0 = Workouts, 1 = Exercises
  String _exerciseSearchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final routinesAsync = ref.watch(recentRoutinesProvider);
    final templatesAsync = ref.watch(gymTemplatesProvider);
    final unlinkedAsync = ref.watch(unlinkedStrengthWorkoutsProvider);
    final exercisesAsync = ref.watch(allExercisesProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Gym Tracker', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        actions: [
          IconButton(
            icon: const Icon(Icons.accessibility_new, color: PulseTheme.accent),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MuscleHeatmapScreen()),
              );
            },
          ),
        ],
      ),
      floatingActionButton: _selectedTab == 0
          ? FloatingActionButton.extended(
              backgroundColor: PulseTheme.accent,
              icon: const Icon(Icons.add),
              label: const Text('Start Workout', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RoutineBuilderScreen()),
                ).then((_) {
                  ref.invalidate(recentRoutinesProvider);
                  ref.invalidate(gymTemplatesProvider);
                });
              },
            )
          : null,
      body: AnimatedGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Segmented Tab Selector
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: PulseTheme.surfaceLight.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedTab = 0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _selectedTab == 0 ? PulseTheme.accent.withOpacity(0.5) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: const Text("Workouts", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedTab = 1),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _selectedTab == 1 ? PulseTheme.accent.withOpacity(0.5) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: const Text("Exercises", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: _selectedTab == 0 
                    ? _buildWorkoutsTab(templatesAsync, unlinkedAsync, routinesAsync)
                    : _buildExercisesTab(exercisesAsync),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkoutsTab(
    AsyncValue<List<GymRoutine>> templatesAsync,
    AsyncValue<List<WorkoutSession>> unlinkedAsync,
    AsyncValue<List<GymRoutine>> routinesAsync,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16).copyWith(bottom: 100),
      children: [
        // 1. Templates Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Templates", style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RoutineBuilderScreen(isCreatingTemplate: true)),
                ).then((_) => ref.invalidate(gymTemplatesProvider));
              },
              icon: const Icon(Icons.add, color: PulseTheme.accent, size: 16),
              label: const Text("New Template", style: TextStyle(color: PulseTheme.accent, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        templatesAsync.when(
          data: (templates) => templates.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: const Center(child: Text("No templates yet. Create one above!", style: TextStyle(color: Colors.white54, fontSize: 13))),
                )
              : Column(
                  children: templates.map((t) => _buildTemplateCard(t)).toList(),
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text("Error: $e", style: const TextStyle(color: Colors.red)),
        ),

        const SizedBox(height: 24),

        // 2. Sync / Pending Workouts Section
        unlinkedAsync.when(
          data: (unlinkedSessions) {
            if (unlinkedSessions.isEmpty) return const SizedBox();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Pending Logs (from wearable)", style: Theme.of(context).textTheme.titleMedium?.copyWith(color: PulseTheme.accent, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...unlinkedSessions.map((session) => _buildPendingSessionCard(session)),
                const SizedBox(height: 24),
              ],
            );
          },
          loading: () => const SizedBox(),
          error: (_, __) => const SizedBox(),
        ),

        // 3. Workout History Section
        Text("Workout History", style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        routinesAsync.when(
          data: (routines) => routines.isEmpty
              ? Container(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      const Icon(Icons.history, size: 48, color: Colors.white24),
                      const SizedBox(height: 12),
                      const Text("No past workouts logged yet.", style: TextStyle(color: Colors.white54)),
                    ],
                  ),
                )
              : Column(
                  children: routines.map((r) => _buildHistoryCard(r)).toList(),
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text("Error: $e"),
        ),
      ],
    );
  }

  Widget _buildTemplateCard(GymRoutine template) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(template.name ?? "Routine Day", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.play_arrow, color: PulseTheme.accent),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => RoutineBuilderScreen(templateRoutine: template)),
                        ).then((_) {
                          ref.invalidate(recentRoutinesProvider);
                          ref.invalidate(gymTemplatesProvider);
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: PulseTheme.recoveryLow, size: 20),
                      onPressed: () => _deleteTemplate(template.id),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            template.exercises.isEmpty
                ? const Text("Empty template", style: TextStyle(color: Colors.white30, fontSize: 12))
                : Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: template.exercises.map((e) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(6)),
                      child: Text(e.name ?? "", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    )).toList(),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingSessionCard(WorkoutSession session) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => RoutineBuilderScreen(linkedSession: session)),
          ).then((_) {
            ref.invalidate(recentRoutinesProvider);
            ref.invalidate(unlinkedStrengthWorkoutsProvider);
          });
        },
        child: GlassContainer(
          padding: const EdgeInsets.all(16),
          borderColor: PulseTheme.accent.withOpacity(0.4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: PulseTheme.accent.withOpacity(0.15), shape: BoxShape.circle),
                child: const Icon(Icons.assignment_late, color: PulseTheme.accent),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Logged Strength Workout", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(
                      session.startTime != null 
                          ? "${session.startTime!.day}/${session.startTime!.month} at ${session.startTime!.hour}:${session.startTime!.minute.toString().padLeft(2, '0')}" 
                          : "Unknown time",
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: PulseTheme.secondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(GymRoutine routine) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(routine.name ?? "Workout Log", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                Text(
                  routine.startTime != null 
                      ? "${routine.startTime!.day}/${routine.startTime!.month}/${routine.startTime!.year}" 
                      : "",
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: routine.exercises.map((e) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Text("• ${e.name}", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      const Spacer(),
                      Text("${e.sets.length} sets", style: const TextStyle(color: Colors.white30, fontSize: 12)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExercisesTab(AsyncValue<List<Map<String, dynamic>>> exercisesAsync) {
    return Column(
      children: [
        // Exercise Search Bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              onChanged: (val) {
                setState(() {
                  _exerciseSearchQuery = val.trim().toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: "Search exercises...",
                hintStyle: const TextStyle(color: Colors.white30),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _exerciseSearchQuery = "";
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: exercisesAsync.when(
            data: (exercises) {
              final filtered = exercises.where((ex) {
                final name = ex["name"]!.toLowerCase();
                final muscle = ex["muscle"]!.toLowerCase();
                return name.contains(_exerciseSearchQuery) || muscle.contains(_exerciseSearchQuery);
              }).toList();

              if (filtered.isEmpty) {
                return const Center(child: Text("No exercises found", style: TextStyle(color: Colors.white54)));
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filtered.length,
                itemBuilder: (ctx, idx) {
                  final ex = filtered[idx];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GlassContainer(
                      padding: const EdgeInsets.all(12),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(ex["name"]!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text(ex["muscle"]!, style: const TextStyle(color: PulseTheme.accent, fontSize: 12)),
                        trailing: const Icon(Icons.history, color: Colors.white30, size: 20),
                        onTap: () => _showExerciseHistoryBottomSheet(ex["name"]!),
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text("Error: $e")),
          ),
        ),
      ],
    );
  }

  Future<void> _showExerciseHistoryBottomSheet(String exerciseName) async {
    final db = ref.read(databaseProvider);
    final List<Map<String, dynamic>> historyList = [];

    try {
      final exercises = await db.getExerciseHistory(exerciseName);

      for (final ex in exercises) {
        final routine = await db.client.from('gym_routines')
            .select('start_time')
            .eq('id', ex.routineId ?? '')
            .maybeSingle();

        if (routine != null && routine['start_time'] != null) {
          historyList.add({
            "date": DateTime.parse(routine['start_time'] as String),
            "sets": ex.sets..sort((a, b) => (a.setNumber ?? 0).compareTo(b.setNumber ?? 0)),
          });
        }
      }
    } catch (_) {}

    historyList.sort((a, b) => (b["date"] as DateTime).compareTo(a["date"] as DateTime));

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: const BoxDecoration(
          color: PulseTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(exerciseName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text("Exercise Logs & History", style: TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 24),
            Expanded(
              child: historyList.isEmpty
                  ? const Center(child: Text("No logged sets for this exercise yet.", style: TextStyle(color: Colors.white30)))
                  : ListView.builder(
                      itemCount: historyList.length,
                      itemBuilder: (ctx, idx) {
                        final log = historyList[idx];
                        final date = log["date"] as DateTime;
                        final sets = log["sets"] as List<GymSet>;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${date.day}/${date.month}/${date.year}",
                                style: const TextStyle(color: PulseTheme.accent, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 8),
                              ...sets.map((s) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                      children: [
                                        Text("Set ${s.setNumber}: ", style: const TextStyle(color: Colors.white70)),
                                        Text(
                                          "${s.weightKg?.toStringAsFixed(1) ?? "0"} kg × ${s.reps ?? 0} reps",
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  )),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteTemplate(String? id) async {
    if (id == null) return;
    final db = ref.read(databaseProvider);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PulseTheme.surface,
        title: const Text("Delete Template?", style: TextStyle(color: Colors.white)),
        content: const Text("Are you sure you want to delete this workout template?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel", style: TextStyle(color: PulseTheme.secondary))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("Delete", style: TextStyle(color: PulseTheme.recoveryLow, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );

    if (confirm == true) {
      await db.deleteRoutine(id);
      ref.invalidate(gymTemplatesProvider);
    }
  }
}
