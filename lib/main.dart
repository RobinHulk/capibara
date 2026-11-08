import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:capy_ui/capy_ui.dart';

import 'core/app_experience_controller.dart';
import 'core/app_navigation_controller.dart';
import 'core/efficiency_unit.dart';
import 'core/image_cache_budget.dart';
import 'core/preference_sync.dart';
import 'core/telemetry_api.dart';
import 'core/telemetry_scope.dart';
import 'core/theme_controller.dart';
import 'l10n/app_localizations.dart';
import 'screens_v2/app_shell_v2.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  applyImageCacheBudget();
  await (
    ThemeController.instance.load(),
    EfficiencyUnitController.instance.load(),
    AppExperienceController.instance.load(),
  ).wait;
  applyImmersiveMode();
  runApp(const CapyEnergyApp());
  AppNavigationController.instance.loadPending(TelemetryApi.shared);
  PreferenceSyncController.instance.start(TelemetryApi.shared);
}

void applyImmersiveMode() {
  final experience = AppExperienceController.instance;
  if (experience.immersiveEnabled) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    return;
  }
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [
      if (!experience.statusBarHidden) SystemUiOverlay.top,
      SystemUiOverlay.bottom,
    ],
  );
}

class CapyEnergyApp extends StatefulWidget {
  const CapyEnergyApp({super.key});

  @override
  State<CapyEnergyApp> createState() => _CapyEnergyAppState();
}

class _CapyEnergyAppState extends State<CapyEnergyApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppExperienceController.instance.addListener(applyImmersiveMode);
  }

  @override
  void dispose() {
    AppExperienceController.instance.removeListener(applyImmersiveMode);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) applyImmersiveMode();
  }

  @override
  Widget build(BuildContext context) {
    return TelemetryScope(
      api: TelemetryApi.shared,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          ThemeController.instance,
          AppExperienceController.instance,
        ]),
        builder: (context, _) {
          final selected = AppTheme.forId(ThemeController.instance.themeId);
          final isDark = ThemeController.instance.isDark;
          return MaterialApp(
            onGenerateTitle: (context) =>
                AppLocalizations.of(context)!.appTitle,
            debugShowCheckedModeBanner: false,
            theme: selected,
            darkTheme: selected,
            themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              CapyUiL10n.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('pt', 'BR'),
              Locale('pt'),
              Locale('es'),
              Locale('ru'),
              Locale('en'),
            ],
            home: const AppShellV2(),
          );
        },
      ),
    );
  }
}
