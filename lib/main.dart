import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'models/app_settings.dart';
import 'services/binary_manager.dart';
import 'services/config_repository.dart';
import 'services/desktop_service.dart';
import 'services/diagnostic_service.dart';
import 'services/metrics_service.dart';
import 'services/process_supervisor.dart';
import 'state/app_state.dart';
import 'ui/main_window.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final startMinimized = args.contains('--minimized');

  final configRepo = ConfigRepository();
  await configRepo.init();

  final binaryManager = await BinaryManager.init();
  final supervisor = ProcessSupervisor(binaryManager);
  final metricsService = MetricsService();
  final diagnosticService = DiagnosticService();

  final appState = AppState(
    configRepo: configRepo,
    binaryManager: binaryManager,
    supervisor: supervisor,
    metricsService: metricsService,
    diagnosticService: diagnosticService,
  );

  final desktopService = DesktopService(appState);
  await desktopService.init(startMinimized: startMinimized);

  unawaited(appState.runAutoStarts());

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: appState),
      ],
      child: const WebRTCGatewayApp(),
    ),
  );
}

class WebRTCGatewayApp extends StatelessWidget {
  const WebRTCGatewayApp({super.key});

  static const List<String> _fontFallbacks = [
    'MiSans',
    'Microsoft YaHei UI',
    'Microsoft YaHei',
    'PingFang SC',
    'HarmonyOS Sans SC',
    'Segoe UI',
    'sans-serif',
  ];

  ThemeMode _resolveThemeMode(AppThemePreference pref) {
    switch (pref) {
      case AppThemePreference.light:
        return ThemeMode.light;
      case AppThemePreference.dark:
        return ThemeMode.dark;
      case AppThemePreference.system:
        return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themePref = context.select<AppState, AppThemePreference>(
      (s) => s.themePreference,
    );

    return MaterialApp(
      title: 'WebRTC Gateway',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'MiSans',
        fontFamilyFallback: _fontFallbacks,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0284C7),
          brightness: Brightness.light,
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        fontFamily: 'MiSans',
        fontFamilyFallback: _fontFallbacks,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF38BDF8),
          brightness: Brightness.dark,
        ),
        cardTheme: const CardThemeData(
          surfaceTintColor: Colors.transparent,
        ),
      ),
      themeMode: _resolveThemeMode(themePref),
      builder: (context, child) {
        final display = context.select<
            AppState,
            ({double fontScale, bool autoDpi, double customDpiScale})>(
          (s) => (
            fontScale: s.fontScale,
            autoDpi: s.autoDpi,
            customDpiScale: s.customDpiScale,
          ),
        );
        final mediaQuery = MediaQuery.of(context);
        final uiScale = display.autoDpi ? 1.0 : display.customDpiScale;

        if (uiScale == 1.0) {
          return MediaQuery(
            data: mediaQuery.copyWith(
              textScaler: TextScaler.linear(display.fontScale),
            ),
            child: child ?? const SizedBox(),
          );
        }

        final scaledWidth = mediaQuery.size.width / uiScale;
        final scaledHeight = mediaQuery.size.height / uiScale;
        final scaledSize = Size(scaledWidth, scaledHeight);

        return MediaQuery(
          data: mediaQuery.copyWith(
            size: scaledSize,
            textScaler: TextScaler.linear(display.fontScale),
          ),
          child: Transform.scale(
            scale: uiScale,
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: scaledWidth,
              height: scaledHeight,
              child: child ?? const SizedBox(),
            ),
          ),
        );
      },
      home: const MainWindow(),
    );
  }
}
