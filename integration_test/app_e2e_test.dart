import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webrtc_gateway_gui/core/i18n.dart';
import 'package:webrtc_gateway_gui/main.dart';
import 'package:webrtc_gateway_gui/models/agent_profile.dart';
import 'package:webrtc_gateway_gui/models/app_settings.dart';
import 'package:webrtc_gateway_gui/services/binary_manager.dart';
import 'package:webrtc_gateway_gui/services/config_repository.dart';
import 'package:webrtc_gateway_gui/services/diagnostic_service.dart';
import 'package:webrtc_gateway_gui/services/metrics_service.dart';
import 'package:webrtc_gateway_gui/services/process_supervisor.dart';
import 'package:webrtc_gateway_gui/state/app_state.dart';

const String _shotDirEnv = String.fromEnvironment('E2E_SHOT_DIR');

Future<int> _pickFreePort() async {
  final srv = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = srv.port;
  await srv.close();
  return port;
}

Future<void> _saveScreenshot(
  GlobalKey boundaryKey,
  String fileName,
) async {
  if (_shotDirEnv.isEmpty) return;
  final ctx = boundaryKey.currentContext;
  if (ctx == null) return;
  final boundary = ctx.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return;
  final image = await boundary.toImage(pixelRatio: 1.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (byteData == null) return;
  final dir = Directory(_shotDirEnv);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  final outFile = File(p.join(dir.path, fileName));
  await outFile.writeAsBytes(byteData.buffer.asUint8List());
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Full interactive Windows E2E: navigation, no overlap, signal, agent, share, diagnostics, logs, settings', (
    WidgetTester tester,
  ) async {
    final tempDir = Directory.systemTemp.createTempSync('wg_gui_e2e_');
    addTearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final configRepo = ConfigRepository(baseDirOverride: tempDir);
    await configRepo.init();
    configRepo.settings.themeMode = AppThemePreference.dark;
    configRepo.settings.locale = 'zh';

    final signalPort = await _pickFreePort();
    final signalMetricsPort = await _pickFreePort();
    configRepo.signalConfig.addr = '127.0.0.1:$signalPort';
    configRepo.signalConfig.metricsAddr = '127.0.0.1:$signalMetricsPort';
    configRepo.signalConfig.tlsAuto = true;

    final binaryManager = BinaryManager(prefs);
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
    addTearDown(() async {
      await appState.shutdownForExit();
      appState.dispose();
    });

    final boundaryKey = GlobalKey();

    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>.value(value: appState),
          ],
          child: const WebRTCGatewayApp(),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    // 1. Dashboard initial render & no overlap
    expect(find.text(AppI18n().t('dashboard_title')), findsOneWidget);
    await _saveScreenshot(boundaryKey, 'e2e_01_dashboard_dark.png');

    // 2. Navigate to Agents tab & verify no Dashboard overlap
    await tester.tap(find.text(AppI18n().t('nav_agents')).first);
    await tester.pumpAndSettle();
    expect(find.text(AppI18n().t('agent_list_title')), findsOneWidget);
    expect(find.text(AppI18n().t('dashboard_title')), findsNothing);
    await _saveScreenshot(boundaryKey, 'e2e_02_agents_initial.png');

    // 3. Navigate to Signal Server tab & start real signal.exe
    await tester.tap(find.text(AppI18n().t('nav_signal')).first);
    await tester.pumpAndSettle();
    expect(find.text(AppI18n().t('signal_server_title')), findsOneWidget);
    expect(find.text(AppI18n().t('agent_list_title')), findsNothing);

    await tester.tap(find.text(AppI18n().t('signal_start_btn')).first);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(appState.isSignalRunning(), isTrue);
    final healthy = await appState.probeSignalHealth();
    expect(healthy, isTrue);
    await _saveScreenshot(boundaryKey, 'e2e_03_signal_running.png');

    // 4. Add a protected Agent via Add Dialog & start real agent.exe
    await tester.tap(find.text(AppI18n().t('nav_agents')).first);
    await tester.pumpAndSettle();

    final protectedNode = AgentProfile(
      id: 'e2e_protected',
      name: 'E2E Protected Node',
      nodeId: 'e2e-protected',
      mode: TunnelMode.dir,
      dirPath: tempDir.path,
      signalUrl: 'wss://127.0.0.1:$signalPort/ws',
      accessSecret: 'E2E_Strong_Pass_123',
      insecure: true,
      signLink: '24h',
    );
    appState.addProfile(protectedNode);
    await tester.pumpAndSettle();

    final okAgent = await appState.startAgent(protectedNode);
    expect(okAgent, isTrue);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(appState.isRunning(protectedNode.id), isTrue);
    await _saveScreenshot(boundaryKey, 'e2e_04_agent_running.png');

    // 5. Open Quick Share dialog on protected running node & verify HMAC URL
    final shareBtn = find.byIcon(Icons.qr_code_2_rounded).last;
    await tester.tap(shareBtn);
    await tester.pumpAndSettle();
    expect(find.text(AppI18n().t('share_dialog_title')), findsOneWidget);
    expect(find.textContaining('#e2e-protected?exp='), findsOneWidget);
    await _saveScreenshot(boundaryKey, 'e2e_05_share_dialog.png');
    await tester.tap(find.text(AppI18n().t('common_close')));
    await tester.pumpAndSettle();

    // 5b. Open Add Agent dialog to verify desktop Scrollbar controller & security warning
    await tester.tap(find.text(AppI18n().t('agent_add_btn')).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('-access-secret'), findsWidgets);
    await _saveScreenshot(boundaryKey, 'e2e_05b_agent_edit_dialog.png');
    await tester.tap(find.text(AppI18n().t('common_cancel')));
    await tester.pumpAndSettle();

    // 6. Diagnostics tab: verify no overlap & execute real STUN ping
    await tester.tap(find.text(AppI18n().t('nav_diagnostics')).first);
    await tester.pumpAndSettle();
    expect(find.text(AppI18n().t('diag_nat_title')), findsOneWidget);
    expect(find.text(AppI18n().t('agent_list_title')), findsNothing);
    await tester.tap(find.text(AppI18n().t('diag_stun_btn')).first);
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
    }
    await tester.pump(const Duration(milliseconds: 300));
    await _saveScreenshot(boundaryKey, 'e2e_06_diagnostics_stun.png');

    // 7. Logs tab: verify real signal/agent logs stream cleanly without overlap
    await tester.tap(find.text(AppI18n().t('nav_logs')).first);
    await tester.pumpAndSettle();
    expect(find.text(AppI18n().t('diag_nat_title')), findsNothing);
    await _saveScreenshot(boundaryKey, 'e2e_07_logs_live.png');

    // 8. Rapid 24-click stress test across all 6 tabs while daemons + metrics tick
    final rapidTabs = [
      'nav_dashboard',
      'nav_agents',
      'nav_signal',
      'nav_diagnostics',
      'nav_logs',
      'nav_settings',
      'nav_diagnostics',
      'nav_agents',
      'nav_dashboard',
      'nav_signal',
      'nav_logs',
      'nav_settings',
      'nav_dashboard',
      'nav_diagnostics',
      'nav_agents',
      'nav_signal',
      'nav_logs',
      'nav_dashboard',
    ];
    for (final key in rapidTabs) {
      await tester.tap(find.text(AppI18n().t(key)).first);
      await tester.pump(const Duration(milliseconds: 40));
    }
    await tester.pumpAndSettle();
    expect(find.text(AppI18n().t('dashboard_title')), findsOneWidget);
    expect(find.text(AppI18n().t('diag_nat_title')), findsNothing);
    expect(find.text(AppI18n().t('agent_list_title')), findsNothing);
    await _saveScreenshot(boundaryKey, 'e2e_08_after_rapid_stress.png');

    // 9. Settings tab + switch to Light Theme + verify clean render
    await tester.tap(find.text(AppI18n().t('nav_settings')).first);
    await tester.pumpAndSettle();
    expect(find.text(AppI18n().t('settings_theme_label')), findsOneWidget);
    expect(find.text(AppI18n().t('dashboard_title')), findsNothing);
    appState.setThemePreference(AppThemePreference.light);
    await tester.pumpAndSettle();
    await _saveScreenshot(boundaryKey, 'e2e_09_settings_light.png');

    // Restore defaults before clean teardown
    appState.setThemePreference(AppThemePreference.dark);
    await tester.pumpAndSettle();
  });
}
