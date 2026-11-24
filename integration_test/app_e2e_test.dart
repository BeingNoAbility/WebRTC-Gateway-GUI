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
import 'package:webrtc_gateway_gui/models/runtime_state.dart';
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

Future<bool> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  int maxSteps = 40,
  Duration step = const Duration(milliseconds: 250),
}) async {
  for (var i = 0; i < maxSteps; i++) {
    if (condition()) return true;
    await tester.pump(step);
  }
  return condition();
}

Future<({
  AppState appState,
  Directory tempDir,
  int signalPort,
  int signalMetricsPort,
  GlobalKey boundaryKey,
})> _mountRealApp(WidgetTester tester) async {
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
  AppI18n().setLocale('zh');

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
  await tester.pumpAndSettle(const Duration(milliseconds: 400));

  return (
    appState: appState,
    tempDir: tempDir,
    signalPort: signalPort,
    signalMetricsPort: signalMetricsPort,
    boundaryKey: boundaryKey,
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('E2E-1: Navigation isolation, Settings binary probe, theme dropdown, font slider & locale roundtrip', (
    WidgetTester tester,
  ) async {
    final env = await _mountRealApp(tester);

    // 1. All 6 views navigate cleanly without overlap
    expect(find.text(AppI18n().t('dashboard_title')), findsOneWidget);
    await _saveScreenshot(env.boundaryKey, 'e2e_01_dashboard_dark.png');

    await tester.tap(find.text(AppI18n().t('nav_agents')).first);
    await tester.pumpAndSettle();
    expect(find.text(AppI18n().t('agent_list_title')), findsOneWidget);
    expect(find.text(AppI18n().t('dashboard_title')), findsNothing);
    await _saveScreenshot(env.boundaryKey, 'e2e_02_agents_initial.png');

    await tester.tap(find.text(AppI18n().t('nav_settings')).first);
    await tester.pumpAndSettle();
    expect(find.text(AppI18n().t('settings_theme_label')), findsOneWidget);
    expect(find.text(AppI18n().t('agent_list_title')), findsNothing);

    // 2. Real BinaryManager detection of bundled v3.1.11 binaries + Portable badge
    final detected = await _pumpUntil(
      tester,
      () => find.textContaining('v3.1.11').evaluate().length >= 2,
    );
    expect(detected, isTrue);
    expect(find.textContaining('便携免安装'), findsOneWidget);

    // 3. Switch theme via real DropdownButton interaction (Dark -> Light -> Dark)
    await tester.tap(find.text(AppI18n().t('settings_theme_dark')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppI18n().t('settings_theme_light')).last);
    await tester.pumpAndSettle();
    expect(env.appState.themePreference, AppThemePreference.light);
    await _saveScreenshot(env.boundaryKey, 'e2e_09_settings_light.png');

    await tester.tap(find.text(AppI18n().t('settings_theme_light')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppI18n().t('settings_theme_dark')).last);
    await tester.pumpAndSettle();
    expect(env.appState.themePreference, AppThemePreference.dark);

    // 4. Font scale adjustment & Reset button interaction
    env.appState.setFontScale(1.2);
    await tester.pumpAndSettle();
    expect(find.text('120%'), findsOneWidget);
    final resetBtn = find.text('恢复默认比例');
    await tester.ensureVisible(resetBtn);
    await tester.tap(resetBtn);
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsOneWidget);

    // 5. Real Locale toggle button (zh -> en -> zh)
    await tester.tap(find.byIcon(Icons.translate_rounded));
    await tester.pumpAndSettle();
    expect(AppI18n().currentLocale, 'en');
    expect(find.text('Settings'), findsWidgets);

    await tester.tap(find.byIcon(Icons.translate_rounded));
    await tester.pumpAndSettle();
    expect(AppI18n().currentLocale, 'zh');
    expect(find.text(AppI18n().t('settings_theme_label')), findsOneWidget);

    // 6. 18 rapid tab transitions stress check while verifying final tab exclusivity
    const rapidTabs = [
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
    expect(find.text(AppI18n().t('settings_theme_label')), findsNothing);
    expect(find.text(AppI18n().t('diag_nat_title')), findsNothing);
    await _saveScreenshot(env.boundaryKey, 'e2e_08_after_rapid_stress.png');
  });

  testWidgets('E2E-2: Real Signal + local HTTP backend + UI CRUD + security gate + ephemeral -sign-link + Prometheus + restart + logs', (
    WidgetTester tester,
  ) async {
    final env = await _mountRealApp(tester);

    // Start real local HTTP target server simulating user's local web app
    final targetServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    targetServer.listen((req) {
      req.response
        ..statusCode = HttpStatus.ok
        ..write('hello from local e2e target')
        ..close();
    });
    addTearDown(() async => targetServer.close(force: true));

    // 1. Signal tab: Start signal.exe -> Health check -> Pop-out LiveLogDialog + filter
    await tester.tap(find.text(AppI18n().t('nav_signal')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppI18n().t('signal_start_btn')).first);

    final sigStarted = await _pumpUntil(
      tester,
      () =>
          env.appState.isSignalRunning() &&
          env.appState.signalState.recentLogs.any((l) => l.contains('Listening')),
    );
    expect(sigStarted, isTrue);
    await tester.pumpAndSettle();
    await _saveScreenshot(env.boundaryKey, 'e2e_03_signal_running.png');

    // Click Health Check button
    await tester.tap(find.text(AppI18n().t('signal_health_btn')).first);
    final healthSnack = await _pumpUntil(
      tester,
      () => find.textContaining('HTTP 200 OK').evaluate().isNotEmpty,
    );
    expect(healthSnack, isTrue);

    // Pop out LiveLogDialog from Signal panel & filter keyword
    final popLogBtn = find.byIcon(Icons.open_in_new_rounded).first;
    await tester.ensureVisible(popLogBtn);
    await tester.tap(popLogBtn);
    await tester.pumpAndSettle();
    expect(find.text(AppI18n().t('logs_signal_node')), findsWidgets);
    final dialogFilter = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(dialogFilter, 'Listening');
    await tester.pumpAndSettle();
    expect(find.textContaining('Listening:'), findsWidgets);
    await tester.tap(find.descendant(
      of: find.byType(Dialog),
      matching: find.byIcon(Icons.close_rounded),
    ));
    await tester.pumpAndSettle();

    // 2. Agents tab: Create new node via real UI form + enforce password guard + One-Click Set Password
    await tester.tap(find.text(AppI18n().t('nav_agents')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppI18n().t('agent_add_btn')).first);
    await tester.pumpAndSettle();

    Finder fieldByLabel(String label) => find.ancestor(
          of: find.text(label),
          matching: find.byType(TextFormField),
        );

    await tester.enterText(fieldByLabel('节点友好名称'), 'UI Proxy E2E');
    await tester.enterText(fieldByLabel('Node ID (唯一标识 -node-id)'), 'ui-proxy-e2e');
    await tester.enterText(
      fieldByLabel('本地目标 URL (-target)'),
      'http://127.0.0.1:${targetServer.port}',
    );
    final signalField = fieldByLabel('信令服务地址 (-signal)');
    await tester.ensureVisible(signalField);
    await tester.enterText(
      signalField,
      'wss://127.0.0.1:${env.signalPort}/ws',
    );
    final insecureCheck = find.text('信任自签信令证书 (-insecure)');
    await tester.ensureVisible(insecureCheck);
    await tester.tap(insecureCheck);
    await tester.pumpAndSettle();

    // Saving without password & without allowPublic must be blocked
    await tester.tap(find.text(AppI18n().t('common_save')));
    await tester.pumpAndSettle();
    expect(find.text('添加新穿透节点'), findsOneWidget);

    // Click One-Click Set Password inside security banner
    final genPwdBtn = find.text('一键设密码');
    await tester.ensureVisible(genPwdBtn);
    await tester.tap(genPwdBtn);
    await tester.pumpAndSettle();
    expect(find.text('一键设密码'), findsNothing);
    await _saveScreenshot(env.boundaryKey, 'e2e_05b_agent_edit_dialog.png');

    await tester.tap(find.text(AppI18n().t('common_save')));
    await tester.pumpAndSettle();
    expect(find.text('UI Proxy E2E'), findsOneWidget);

    // Start the UI-created protected node via its Card Switch
    final proxySwitch = find.descendant(
      of: find.ancestor(of: find.text('UI Proxy E2E'), matching: find.byType(Card)),
      matching: find.byType(Switch),
    );
    await tester.tap(proxySwitch);

    final uiProxyProfile =
        env.appState.profiles.firstWhere((p) => p.nodeId == 'ui-proxy-e2e');
    final registered = await _pumpUntil(
      tester,
      () =>
          env.appState.isRunning(uiProxyProfile.id) &&
          env.appState
              .getRuntimeState(uiProxyProfile.id)
              .recentLogs
              .any((l) => l.contains('Server confirmed registration')),
      maxSteps: 48,
    );
    expect(registered, isTrue);
    await tester.pumpAndSettle();

    // While running, Edit & Delete buttons for UI Proxy E2E must be disabled
    final uiCard =
        find.ancestor(of: find.text('UI Proxy E2E'), matching: find.byType(Card));
    final editBtn = tester.widget<IconButton>(
      find.descendant(
        of: uiCard,
        matching: find.ancestor(
          of: find.byIcon(Icons.edit_outlined),
          matching: find.byType(IconButton),
        ),
      ),
    );
    final deleteBtn = tester.widget<IconButton>(
      find.descendant(
        of: uiCard,
        matching: find.ancestor(
          of: find.byIcon(Icons.delete_outline),
          matching: find.byType(IconButton),
        ),
      ),
    );
    expect(editBtn.onPressed, isNull);
    expect(deleteBtn.onPressed, isNull);

    // 3. Test unprotected node security confirmation dialog ("自动生成密码并启动")
    final defaultCard =
        find.ancestor(of: find.text('homeserver'), matching: find.byType(Card));
    await tester.tap(
      find.descendant(of: defaultCard, matching: find.byType(Switch)),
    );
    await tester.pumpAndSettle();
    expect(find.text('安全确认：未设置访客访问密码'), findsOneWidget);
    await tester.tap(find.text('自动生成密码并启动'));
    await tester.pumpAndSettle();

    final defaultProfile =
        env.appState.profiles.firstWhere((p) => p.nodeId == 'homeserver');
    final startedDefault = await _pumpUntil(
      tester,
      () => env.appState.isRunning(defaultProfile.id),
      maxSteps: 30,
    );
    expect(defaultProfile.accessSecret, isNotEmpty);
    expect(startedDefault, isTrue);

    // Stop default node via Switch so it cleans up
    await tester.tap(
      find.descendant(of: defaultCard, matching: find.byType(Switch)),
    );
    await _pumpUntil(tester, () => !env.appState.isRunning(defaultProfile.id));

    // 4. Ephemeral -sign-link node (no accessSecret, has signLink) starts WITHOUT public warning
    final ephemNode = AgentProfile(
      id: 'ephem_e2e',
      name: 'Ephemeral Lock Node',
      nodeId: 'ephem-e2e',
      mode: TunnelMode.dir,
      dirPath: env.tempDir.path,
      signalUrl: 'wss://127.0.0.1:${env.signalPort}/ws',
      accessSecret: '',
      signLink: '24h',
      insecure: true,
    );
    env.appState.addProfile(ephemNode);
    await tester.pumpAndSettle();
    expect(find.text('临时签名锁'), findsOneWidget);

    final ephemCard = find.ancestor(
      of: find.text('Ephemeral Lock Node'),
      matching: find.byType(Card),
    );
    await tester.tap(
      find.descendant(of: ephemCard, matching: find.byType(Switch)),
    );
    final ephemCapturedLink = await _pumpUntil(
      tester,
      () =>
          env.appState.isRunning(ephemNode.id) &&
          env.appState.getRuntimeState(ephemNode.id).generatedShareLink != null,
      maxSteps: 48,
    );
    expect(ephemCapturedLink, isTrue);
    await tester.pumpAndSettle();
    await _saveScreenshot(env.boundaryKey, 'e2e_04_agent_running.png');

    // Open Quick Share dialog on ephemeral node & verify CLI-generated signed URL
    await tester.tap(
      find.descendant(of: ephemCard, matching: find.byIcon(Icons.qr_code_2_rounded)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('#ephem-e2e?exp='), findsOneWidget);
    await tester.tap(find.text(AppI18n().t('common_close')));
    await tester.pumpAndSettle();

    // Open Quick Share dialog on protected node & check HMAC URL + buttons visible
    await tester.tap(
      find.descendant(of: uiCard, matching: find.byIcon(Icons.qr_code_2_rounded)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('#ui-proxy-e2e?exp='), findsOneWidget);
    await _saveScreenshot(env.boundaryKey, 'e2e_05_share_dialog.png');
    await tester.tap(find.text(AppI18n().t('common_close')));
    await tester.pumpAndSettle();

    // 5. Dashboard: real 1Hz Prometheus polling + Registered Agents >= 1 + Restart Agent via StreamInspector
    await tester.tap(find.text(AppI18n().t('nav_dashboard')).first);
    await tester.pumpAndSettle();
    final polledMetrics = await _pumpUntil(
      tester,
      () =>
          (env.appState.metricsService.latestSignalMetrics?.registeredNodes ?? 0) >=
              1 &&
          env.appState.metricsService.getHistory(uiProxyProfile.id).isNotEmpty,
      maxSteps: 28,
    );
    expect(polledMetrics, isTrue);
    await tester.pumpAndSettle();
    expect(find.textContaining('公开免密'), findsNothing);
    await _saveScreenshot(env.boundaryKey, 'e2e_10_dashboard_live_metrics.png');

    final oldPid = env.appState.getRuntimeState(uiProxyProfile.id).pid;
    final restartBtn = find.text(AppI18n().t('stream_reset_btn')).first;
    await tester.ensureVisible(restartBtn);
    await tester.tap(restartBtn);
    await tester.pumpAndSettle();
    expect(find.text('确认重启节点通道'), findsOneWidget);
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text(AppI18n().t('stream_reset_btn')),
    ));
    final restarted = await _pumpUntil(
      tester,
      () {
        final rt = env.appState.getRuntimeState(uiProxyProfile.id);
        return rt.status == ProcessStatus.running &&
            rt.pid != null &&
            rt.pid != oldPid;
      },
      maxSteps: 40,
    );
    expect(restarted, isTrue);

    // 6. Logs tab: verify live logs, tap-to-copy line, and clear
    await tester.tap(find.text(AppI18n().t('nav_logs')).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Agent'), findsWidgets);
    await _saveScreenshot(env.boundaryKey, 'e2e_07_logs_live.png');

    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first))
        .clearSnackBars();
    await tester.pumpAndSettle();

    final copyLineTarget = find.textContaining('[Agent]').first;
    await tester.tap(copyLineTarget);
    await tester.pumpAndSettle();
    expect(find.textContaining('已复制该行日志'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
    await tester.pumpAndSettle();
    expect(find.text(AppI18n().t('logs_empty')), findsOneWidget);

    // 7. Stop running agents via UI Switch, delete test node cleanly, and stop Signal Server
    await tester.tap(find.text(AppI18n().t('nav_agents')).first);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: uiCard, matching: find.byType(Switch)),
    );
    await tester.tap(
      find.descendant(of: ephemCard, matching: find.byType(Switch)),
    );
    final allStopped = await _pumpUntil(
      tester,
      () => env.appState.runningCount == 0,
      maxSteps: 30,
    );
    expect(allStopped, isTrue);
    await tester.pumpAndSettle();

    // Delete Ephemeral Lock Node via UI Delete Icon + Confirmation Dialog
    await tester.tap(
      find.descendant(of: ephemCard, matching: find.byIcon(Icons.delete_outline)),
    );
    await tester.pumpAndSettle();
    expect(find.text('确认删除节点'), findsOneWidget);
    await tester.tap(find.text(AppI18n().t('common_delete')));
    await tester.pumpAndSettle();
    expect(find.text('Ephemeral Lock Node'), findsNothing);

    await tester.tap(find.text(AppI18n().t('nav_signal')).first);
    await tester.pumpAndSettle();
    final stopSignalBtn = find.text(AppI18n().t('signal_stop_btn')).first;
    await tester.ensureVisible(stopSignalBtn);
    await tester.pumpAndSettle();
    await tester.tap(stopSignalBtn);
    final sigStopped = await _pumpUntil(
      tester,
      () => !env.appState.isSignalRunning(),
      maxSteps: 30,
    );
    expect(sigStopped, isTrue);
  });

  testWidgets('E2E-3: Real RFC 3489 NAT detection, STUN latency ranking, apply best STUN, and YAML/JSON config roundtrip', (
    WidgetTester tester,
  ) async {
    final env = await _mountRealApp(tester);

    // 1. Navigate to Diagnostics and run real RFC 3489 NAT Type probe
    await tester.tap(find.text(AppI18n().t('nav_diagnostics')).first);
    await tester.pumpAndSettle();
    expect(find.text(AppI18n().t('diag_nat_title')), findsOneWidget);

    await tester.tap(find.text(AppI18n().t('diag_nat_btn')).first);
    final natFinished = await _pumpUntil(
      tester,
      () =>
          find.byType(CircularProgressIndicator).evaluate().isEmpty &&
          find.textContaining('尚未检测').evaluate().isEmpty,
      maxSteps: 120,
    );
    expect(natFinished, isTrue);

    // 2. Run real STUN latency ping & apply fastest servers to all nodes
    await tester.tap(find.text(AppI18n().t('diag_stun_btn')).first);
    final stunFinished = await _pumpUntil(
      tester,
      () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
      maxSteps: 60,
    );
    expect(stunFinished, isTrue);
    await tester.pumpAndSettle();
    await _saveScreenshot(env.boundaryKey, 'e2e_06_diagnostics_stun.png');

    final applyBestFinder = find.text(AppI18n().t('diag_apply_stun_btn'));
    if (applyBestFinder.evaluate().isNotEmpty) {
      await tester.tap(applyBestFinder);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('已将最优 STUN'), findsOneWidget);
    }

    // 3. Real disk YAML / JSON export and import roundtrip verification
    final jsonBackupPath = p.join(env.tempDir.path, 'full_backup.json');
    final agentYamlPath = p.join(env.tempDir.path, 'agent_export.yaml');
    final signalYamlPath = p.join(env.tempDir.path, 'signal_export.yaml');

    final firstId = env.appState.profiles.first.id;
    await env.appState.exportAllConfig(jsonBackupPath);
    await env.appState.exportUpstreamAgentYaml(firstId, agentYamlPath);
    await env.appState.exportUpstreamSignalYaml(signalYamlPath);

    expect(File(jsonBackupPath).existsSync(), isTrue);
    expect(File(agentYamlPath).existsSync(), isTrue);
    expect(File(signalYamlPath).existsSync(), isTrue);

    final yamlImportRes = await env.appState.importConfigFile(agentYamlPath);
    expect(yamlImportRes['agents'], 1);
    final signalImportRes = await env.appState.importConfigFile(signalYamlPath);
    expect(signalImportRes['signal'], isTrue);
    final jsonImportRes = await env.appState.importConfigFile(jsonBackupPath);
    expect(jsonImportRes['settings'], isTrue);
  });
}
