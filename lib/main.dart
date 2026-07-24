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
import 'presentation/providers/data_providers.dart';
import 'utils/widget_theme_sync.dart';

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
    _triggerSync();

    // Invalidate and refresh all providers when user logs in/out so they see their Supabase history
    sb.Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      final event = data.event;
      if (event == sb.AuthChangeEvent.signedIn || event == sb.AuthChangeEvent.signedOut) {
        invalidateAllDataProviders(ref);
      }
    });

    // Push saved widget theme to Android on launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = ref.read(themeSettingsProvider);
      syncWidgetThemeToAndroid(settings);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// When app comes to foreground, sync and refresh all data providers.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.syncUseCase.syncToday().then((_) {
        if (!mounted) return;
        invalidateAllDataProviders(ref);
      });
    }
  }

  /// On startup: run 14-day historical sync if first time, otherwise fast 2-day recent sync.
  Future<void> _triggerSync() async {
    final dbService = ref.read(databaseProvider);
    final profile = await dbService.getUserProfile();
    final isFirstSync = profile.lastSyncDate == null;

    final SyncResult result;
    if (isFirstSync) {
      debugPrint('[PIPELINE][MAIN] First launch: syncing 14 days of history to Supabase...');
      result = await widget.syncUseCase.syncAll(daysBack: 14);
    } else {
      debugPrint('[PIPELINE][MAIN] Routine launch: fast sync for recent 2 days...');
      result = await widget.syncUseCase.syncRecent(daysBack: 2);
    }

    debugPrint('[PIPELINE][MAIN] Startup sync complete: success=${result.success}, '
        'days=${result.daysImported}, workouts=${result.workoutsImported}');
    if (!mounted) return;
    if (result.success) {
      invalidateAllDataProviders(ref);
    }
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
