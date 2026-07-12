import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../data/database_service.dart';
import '../../../data/collections/gym_models.dart';
import '../../../data/collections/workout_session.dart';
import '../../../widgets/glass_container.dart';
import '../../../widgets/animated_background.dart';

final predefinedExercises = [
  "Bench Press",
  "Squat",
  "Deadlift",
  "Pull Up",
  "Push Up",
  "Overhead Press",
  "Barbell Row",
  "Bicep Curl",
  "Tricep Extension",
  "Leg Press"
];

class RoutineBuilderScreen extends ConsumerStatefulWidget {
  final WorkoutSession? linkedSession;
  final GymRoutine? templateRoutine;
  final bool isCreatingTemplate;

  const RoutineBuilderScreen({
    super.key,
    this.linkedSession,
    this.templateRoutine,
    this.isCreatingTemplate = false,
  });

  @override
  ConsumerState<RoutineBuilderScreen> createState() => _RoutineBuilderScreenState();
}

class _RoutineBuilderScreenState extends ConsumerState<RoutineBuilderScreen> {
  final List<GymExercise> _currentExercises = [];
  final Map<GymExercise, List<GymSet>> _exerciseSets = {};
  final Map<GymSet, TextEditingController> _weightControllers = {};
  final Map<GymSet, TextEditingController> _repsControllers = {};
  final Map<String, Map<String, dynamic>> _lastPerformances = {};
  late TextEditingController _nameController;
  bool _isCustomMode = false;

  @override
  void initState() {
    super.initState();
    
    String defaultName = "Strength Training";
    if (widget.isCreatingTemplate) {
      defaultName = "New Template";
    } else if (widget.templateRoutine != null) {
      defaultName = widget.templateRoutine!.name ?? "Strength Training";
    } else if (widget.linkedSession != null) {
      defaultName = "Strength Training (Linked)";
    }
    _nameController = TextEditingController(text: defaultName);

    if (widget.templateRoutine != null) {
      _loadFromTemplate(widget.templateRoutine!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final ctrl in _weightControllers.values) {
      ctrl.dispose();
    }
    for (final ctrl in _repsControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _loadFromTemplate(GymRoutine template) async {
    for (final ex in template.exercises) {
      final newEx = GymExercise()
        ..name = ex.name
        ..targetMuscle = ex.targetMuscle
        ..isCustom = ex.isCustom;
      
      _currentExercises.add(newEx);
      _exerciseSets[newEx] = [];

      final sortedSets = ex.sets.toList()
        ..sort((a, b) => (a.setNumber ?? 0).compareTo(b.setNumber ?? 0));

      for (final s in sortedSets) {
        final newSet = GymSet()
          ..setNumber = s.setNumber
          ..weightKg = s.weightKg
          ..reps = s.reps
          ..isCompleted = false;
        _exerciseSets[newEx]!.add(newSet);
        _initControllersForSet(newSet);
      }
      
      await _fetchLastPerformance(ex.name ?? "");
    }
    if (mounted) setState(() {});
  }

  void _initControllersForSet(GymSet set) {
    _weightControllers[set] = TextEditingController(
      text: set.weightKg != null && set.weightKg! > 0 ? set.weightKg!.toStringAsFixed(1) : ''
    );
    _repsControllers[set] = TextEditingController(
      text: set.reps != null && set.reps! > 0 ? set.reps!.toString() : ''
    );
  }

  Future<Map<String, dynamic>?> _getLastPerformance(String exerciseName) async {
    final db = ref.read(databaseProvider);
    try {
      final history = await db.getExerciseHistory(exerciseName);
      if (history.isNotEmpty) {
        final List<Map<String, dynamic>> sortedHistory = [];
        for (final ex in history) {
          final routine = await db.client.from('gym_routines')
              .select('start_time')
              .eq('id', ex.routineId ?? '')
              .maybeSingle();
          if (routine != null && routine['start_time'] != null) {
            sortedHistory.add({
              'time': DateTime.parse(routine['start_time'] as String),
              'sets': ex.sets,
            });
          }
        }
        
        if (sortedHistory.isNotEmpty) {
          sortedHistory.sort((a, b) => (b['time'] as DateTime).compareTo(a['time'] as DateTime));
          final latestExSets = sortedHistory.first['sets'] as List<GymSet>;
          return {
            'sets': latestExSets.map((s) => {'weight': s.weightKg, 'reps': s.reps}).toList(),
          };
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _fetchLastPerformance(String name) async {
    final perf = await _getLastPerformance(name);
    if (perf != null) {
      setState(() {
        _lastPerformances[name] = perf;
      });
    }
  }

  void _addPredefinedExercise(String name) {
    setState(() {
      final exercise = GymExercise()
        ..name = name
        ..isCustom = false;
      _currentExercises.add(exercise);
      _exerciseSets[exercise] = [];
      _fetchLastPerformance(name);
    });
  }

  void _addCustomExercise(String name, String muscle) {
    setState(() {
      final exercise = GymExercise()
        ..name = name
        ..targetMuscle = muscle
        ..isCustom = true;
      _currentExercises.add(exercise);
      _exerciseSets[exercise] = [];
      _fetchLastPerformance(name);
    });
  }

  void _addSet(GymExercise exercise) {
    setState(() {
      final sets = _exerciseSets[exercise] ?? [];
      final set = GymSet()
        ..setNumber = sets.length + 1
        ..weightKg = 0
        ..reps = 0;
      sets.add(set);
      _exerciseSets[exercise] = sets;
      _initControllersForSet(set);
    });
  }

  Future<void> _finishWorkout() async {
    if (_currentExercises.isEmpty) {
      Navigator.pop(context);
      return;
    }

    final db = ref.read(databaseProvider);
    final routine = GymRoutine(
      name: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : "Strength Training",
      startTime: widget.linkedSession?.startTime ?? DateTime.now(),
      endTime: DateTime.now(),
      isTemplate: widget.isCreatingTemplate,
      linkedActivityId: widget.linkedSession?.activityId,
    );

    for (final ex in _currentExercises) {
      final sets = _exerciseSets[ex] ?? [];
      final perf = _lastPerformances[ex.name];
      final prevSetsList = perf != null ? perf['sets'] as List<dynamic>? : null;

      final newEx = GymExercise(
        name: ex.name,
        targetMuscle: ex.targetMuscle,
        isCustom: ex.isCustom,
      );

      for (int i = 0; i < sets.length; i++) {
        final set = sets[i];
        double? weight = set.weightKg;
        int? reps = set.reps;
        if ((weight == null || weight == 0) && prevSetsList != null && i < prevSetsList.length) {
          weight = prevSetsList[i]['weight'] as double?;
        }
        if ((reps == null || reps == 0) && prevSetsList != null && i < prevSetsList.length) {
          reps = prevSetsList[i]['reps'] as int?;
        }

        newEx.sets.add(GymSet(
          setNumber: set.setNumber,
          weightKg: weight,
          reps: reps,
          isCompleted: set.isCompleted,
        ));
      }
      routine.exercises.add(newEx);
    }

    await db.saveRoutine(routine);

    // If it was a live workout, ask to save as template!
    if (!widget.isCreatingTemplate && widget.templateRoutine == null && mounted) {
      final saveAsTemplate = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: PulseTheme.surface,
          title: const Text("Save as Template?", style: TextStyle(color: Colors.white)),
          content: const Text("Would you like to save this workout day as a template to reuse later?", style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("No", style: TextStyle(color: PulseTheme.secondary))),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true), 
              child: const Text("Yes, Save", style: TextStyle(color: PulseTheme.accent, fontWeight: FontWeight.bold))
            ),
          ],
        ),
      );

      if (saveAsTemplate == true && mounted) {
        // Prompt for template name
        final nameCtrl = TextEditingController(text: routine.name);
        final templateName = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: PulseTheme.surface,
            title: const Text("Template Name", style: TextStyle(color: Colors.white)),
            content: TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Name",
                labelStyle: TextStyle(color: PulseTheme.secondary),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: PulseTheme.secondary)),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: PulseTheme.secondary))),
              TextButton(
                onPressed: () => Navigator.pop(ctx, nameCtrl.text),
                child: const Text("Save", style: TextStyle(color: PulseTheme.accent, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );

        if (templateName != null && templateName.trim().isNotEmpty && mounted) {
          final template = GymRoutine(
            name: templateName.trim(),
            startTime: DateTime.now(),
            endTime: DateTime.now(),
            isTemplate: true,
          );

          for (final ex in routine.exercises) {
            final templateEx = GymExercise(
              name: ex.name,
              targetMuscle: ex.targetMuscle,
              isCustom: ex.isCustom,
            );
            for (final s in ex.sets) {
              templateEx.sets.add(GymSet(
                setNumber: s.setNumber,
                weightKg: s.weightKg,
                reps: s.reps,
                isCompleted: false,
              ));
            }
            template.exercises.add(templateEx);
          }

          await db.saveRoutine(template);
        }
      }
    }

    if (mounted) Navigator.pop(context);
  }

  void _showAddExerciseDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
              color: PulseTheme.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Text("Add Exercise", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                      const Spacer(),
                      ToggleButtons(
                        isSelected: [!_isCustomMode, _isCustomMode],
                        onPressed: (index) {
                          setModalState(() {
                            _isCustomMode = index == 1;
                          });
                          setState(() {
                            _isCustomMode = index == 1;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        selectedColor: Colors.white,
                        fillColor: PulseTheme.accent.withOpacity(0.5),
                        color: PulseTheme.secondary,
                        children: const [
                          Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text("Predefined")),
                          Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text("Custom")),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: !_isCustomMode ? _buildPredefinedList(ctx) : _buildCustomForm(ctx),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPredefinedList(BuildContext ctx) {
    return ListView.builder(
      itemCount: predefinedExercises.length,
      itemBuilder: (context, index) {
        final ex = predefinedExercises[index];
        return ListTile(
          title: Text(ex, style: const TextStyle(color: Colors.white)),
          trailing: const Icon(Icons.add, color: PulseTheme.accent),
          onTap: () {
            _addPredefinedExercise(ex);
            Navigator.pop(ctx);
          },
        );
      },
    );
  }

  Widget _buildCustomForm(BuildContext ctx) {
    final nameCtrl = TextEditingController();
    String selectedMuscle = "Chest";
    final muscles = ["Chest", "Back", "Legs", "Arms", "Shoulders", "Core"];

    return StatefulBuilder(
      builder: (context, setFormState) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "Exercise Name", labelStyle: TextStyle(color: PulseTheme.secondary)),
              ),
              const SizedBox(height: 24),
              const Text("Target Muscle", style: TextStyle(color: PulseTheme.secondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: muscles.map((m) {
                  final isSel = m == selectedMuscle;
                  return ChoiceChip(
                    label: Text(m),
                    selected: isSel,
                    selectedColor: PulseTheme.accent,
                    backgroundColor: PulseTheme.surfaceLight,
                    onSelected: (val) {
                      if (val) setFormState(() => selectedMuscle = m);
                    },
                  );
                }).toList(),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: PulseTheme.accent, padding: const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: () {
                    if (nameCtrl.text.isNotEmpty) {
                      _addCustomExercise(nameCtrl.text, selectedMuscle);
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text("Add Custom Exercise", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: TextField(
          controller: _nameController,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: "Workout Name",
            hintStyle: TextStyle(color: Colors.white30),
          ),
        ),
        actions: [
          TextButton(onPressed: _finishWorkout, child: const Text("FINISH", style: TextStyle(color: PulseTheme.accent, fontWeight: FontWeight.bold))),
        ],
      ),
      body: AnimatedGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _currentExercises.length,
                  itemBuilder: (context, index) {
                    final ex = _currentExercises[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: GlassContainer(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(ex.name ?? "", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                              const Spacer(),
                              if (ex.isCustom)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: PulseTheme.recoveryMedium.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                                  child: Text(ex.targetMuscle ?? "", style: const TextStyle(color: PulseTheme.recoveryMedium, fontSize: 10)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: const [
                              SizedBox(width: 30, child: Text("Set", style: TextStyle(color: PulseTheme.secondary, fontSize: 12))),
                              Expanded(flex: 2, child: Text("Previous", textAlign: TextAlign.center, style: TextStyle(color: PulseTheme.secondary, fontSize: 12))),
                              Expanded(flex: 2, child: Text("kg", textAlign: TextAlign.center, style: TextStyle(color: PulseTheme.secondary, fontSize: 12))),
                              Expanded(flex: 2, child: Text("Reps", textAlign: TextAlign.center, style: TextStyle(color: PulseTheme.secondary, fontSize: 12))),
                              SizedBox(width: 40, child: Text("✓", textAlign: TextAlign.center, style: TextStyle(color: PulseTheme.secondary, fontSize: 12))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...(_exerciseSets[ex] ?? []).asMap().entries.map((entry) {
                            final idx = entry.key;
                            final set = entry.value;

                            // Previous performance lookup
                            final perf = _lastPerformances[ex.name];
                            String prevStr = "--";
                            double? prevWeight;
                            int? prevReps;
                            if (perf != null && perf['sets'] != null) {
                              final prevSetsList = perf['sets'] as List<dynamic>;
                              if (idx < prevSetsList.length) {
                                final prevSetMap = prevSetsList[idx];
                                prevWeight = prevSetMap['weight'] as double?;
                                prevReps = prevSetMap['reps'] as int?;
                                if (prevWeight != null && prevReps != null) {
                                  prevStr = "${prevWeight.toStringAsFixed(1)} × $prevReps";
                                }
                              }
                            }

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  SizedBox(width: 30, child: Text("${idx + 1}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                  Expanded(
                                    flex: 2,
                                    child: Center(
                                      child: Text(prevStr, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      decoration: BoxDecoration(color: PulseTheme.surfaceLight, borderRadius: BorderRadius.circular(8)),
                                      child: TextField(
                                        controller: _weightControllers[set],
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(color: Colors.white, fontSize: 14),
                                        decoration: InputDecoration(
                                          border: InputBorder.none,
                                          hintText: prevWeight != null ? prevWeight.toStringAsFixed(1) : "0",
                                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                                        ),
                                        onChanged: (val) => set.weightKg = double.tryParse(val),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      decoration: BoxDecoration(color: PulseTheme.surfaceLight, borderRadius: BorderRadius.circular(8)),
                                      child: TextField(
                                        controller: _repsControllers[set],
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(color: Colors.white, fontSize: 14),
                                        decoration: InputDecoration(
                                          border: InputBorder.none,
                                          hintText: prevReps != null ? prevReps.toString() : "0",
                                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                                        ),
                                        onChanged: (val) => set.reps = int.tryParse(val),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 40,
                                    child: IconButton(
                                      icon: Icon(set.isCompleted ? Icons.check_circle : Icons.check_circle_outline, color: set.isCompleted ? Colors.green : PulseTheme.secondary),
                                      onPressed: () {
                                        setState(() {
                                          set.isCompleted = !set.isCompleted;
                                          if (set.isCompleted) {
                                            if (_weightControllers[set]?.text.isEmpty ?? true) {
                                              if (prevWeight != null) {
                                                _weightControllers[set]?.text = prevWeight.toStringAsFixed(1);
                                                set.weightKg = prevWeight;
                                              }
                                            }
                                            if (_repsControllers[set]?.text.isEmpty ?? true) {
                                              if (prevReps != null) {
                                                _repsControllers[set]?.text = prevReps.toString();
                                                set.reps = prevReps;
                                              }
                                            }
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                          Center(
                            child: TextButton.icon(
                              onPressed: () => _addSet(ex),
                              icon: const Icon(Icons.add, color: PulseTheme.accent, size: 16),
                              label: const Text("Add Set", style: TextStyle(color: PulseTheme.accent)),
                            ),
                          ),
                        ],
                      ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: PulseTheme.accent.withOpacity(0.2), padding: const EdgeInsets.symmetric(vertical: 16)),
                    onPressed: _showAddExerciseDialog,
                    child: const Text("+ Add Exercise", style: TextStyle(color: PulseTheme.accent, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
