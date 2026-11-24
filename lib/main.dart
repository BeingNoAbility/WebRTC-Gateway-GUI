import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'services/binary_manager.dart';
import 'services/config_repository.dart';
import 'services/desktop_service.dart';
import 'services/diagnostic_service.dart';
import 'services/metrics_service.dart';
import 'services/process_supervisor.dart';
import 'state/app_state.dart';
import 'ui/main_window.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
  await desktopService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appState),
      ],
      child: const WebRTCGatewayApp(),
    ),
  );
}

class WebRTCGatewayApp extends StatelessWidget {
  const WebRTCGatewayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WebRTC Gateway',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'MiSans',
        fontFamilyFallback: const [
          'MiSans',
          'Microsoft YaHei UI',
          'Microsoft YaHei',
          'PingFang SC',
          'HarmonyOS Sans SC',
          'Segoe UI',
          'sans-serif',
        ],
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0284C7), // Cyber Cyan Blue from source logo
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
        fontFamilyFallback: const [
          'MiSans',
          'Microsoft YaHei UI',
          'Microsoft YaHei',
          'PingFang SC',
          'HarmonyOS Sans SC',
          'Segoe UI',
          'sans-serif',
        ],
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF38BDF8),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const MainWindow(),
    );
  }
}
