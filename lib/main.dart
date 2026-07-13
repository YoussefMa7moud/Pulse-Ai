import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme.dart';
import 'core/app_router.dart';
import 'data/database_service.dart';
import 'infrastructure/health/google_health_service.dart';
import 'use_cases/sync_use_case.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables (.env contains GROQ_API_KEY, SUPABASE_URL, SUPABASE_ANON_KEY)
  await dotenv.load(fileName: '.env').catchError((e) {
    debugPrint('No .env file found. Proceeding without it.');
  });

  final prefs = await SharedPreferences.getInstance();

  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await sb.Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  } else {
    // Empty fallbacks for building/testing
    debugPrint('[Supabase] Warning: SUPABASE_URL or SUPABASE_ANON_KEY is empty in .env');
    await sb.Supabase.initialize(
      url: 'https://placeholder-project-id.supabase.co',
      anonKey: 'placeholder-anon-key',
    );
  }

  final dbService = DatabaseService();
  await dbService.init();

  // Create Google Health + sync use case instances for startup sync
  final healthService = GoogleHealthService();
  final syncUseCase = SyncUseCase(healthService, dbService);

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(dbService),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: PulseApp(syncUseCase: syncUseCase),
    ),
  );
}

class PulseApp extends ConsumerStatefulWidget {
  final SyncUseCase syncUseCase;
  const PulseApp({super.key, required this.syncUseCase});

  @override
  ConsumerState<PulseApp> createState() => _PulseAppState();
}

class _PulseAppState extends ConsumerState<PulseApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Kick off background sync on first launch
    _triggerSync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// When app comes to foreground, do a lightweight today-only sync
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.syncUseCase.syncToday();
    }
  }

  /// On startup: check if authorized and run full 30-day sync if so.
  Future<void> _triggerSync() async {
    // syncAll internally checks authorization before fetching data
    // Run in background — don't await so UI loads immediately
    widget.syncUseCase.syncAll(daysBack: 30);
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeSettings = ref.watch(themeSettingsProvider);
    final isSystemDark = MediaQuery.of(context).platformBrightness == Brightness.dark;

    return MaterialApp.router(
      title: 'Pulse AI',
      theme: PulseTheme.getThemeData(themeSettings.mode, themeSettings.variant, themeSettings.widgetCardTheme, isSystemDark),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
