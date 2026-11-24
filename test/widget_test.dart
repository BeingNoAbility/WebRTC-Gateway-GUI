import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
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
import 'package:webrtc_gateway_gui/ui/agents/agent_edit_dialog.dart';
import 'package:webrtc_gateway_gui/ui/agents/agent_list_view.dart';
import 'package:webrtc_gateway_gui/ui/logs/live_log_dialog.dart';
import 'package:webrtc_gateway_gui/ui/share/share_dialog.dart';

void main() {
  Future<AppState> createTestAppState({
    AppThemePreference themeMode = AppThemePreference.light,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final configRepo = ConfigRepository(inMemory: true);
    await configRepo.init();
    configRepo.settings.themeMode = themeMode;

    final binaryManager = BinaryManager(prefs, disableProcessProbe: true);
    final supervisor = ProcessSupervisor(binaryManager);
    final metricsService = MetricsService();
    final diagnosticService = DiagnosticService();

    return AppState(
      configRepo: configRepo,
      binaryManager: binaryManager,
      supervisor: supervisor,
      metricsService: metricsService,
      diagnosticService: diagnosticService,
    );
  }

  testWidgets('App navigates all 6 views in Light and Dark mode without overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 680);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final appState = await createTestAppState(themeMode: AppThemePreference.light);
    addTearDown(appState.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: appState),
        ],
        child: const WebRTCGatewayApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('WebRTC'), findsOneWidget);
    expect(find.text('Gateway'), findsOneWidget);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text(AppI18n().t('dashboard_title')), findsOneWidget);

    await tester.tap(find.text(AppI18n().t('nav_agents')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text(AppI18n().t('agent_list_title')), findsOneWidget);

    await tester.tap(find.text(AppI18n().t('nav_signal')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text(AppI18n().t('signal_server_title')), findsOneWidget);

    await tester.tap(find.text(AppI18n().t('nav_diagnostics')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text(AppI18n().t('diag_nat_title')), findsOneWidget);
    expect(find.textContaining('尚未检测'), findsOneWidget);

    await tester.tap(find.text(AppI18n().t('nav_logs')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text(AppI18n().t('logs_empty')), findsOneWidget);

    await tester.tap(find.text(AppI18n().t('nav_settings')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text(AppI18n().t('settings_theme_label')), findsOneWidget);

    // Switch to Dark Mode and re-verify key views + locale toggle
    appState.setThemePreference(AppThemePreference.dark);
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text(AppI18n().t('nav_logs')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text(AppI18n().t('logs_empty')), findsOneWidget);

    await tester.tap(find.text(AppI18n().t('nav_settings')));
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.byIcon(Icons.translate_rounded));
    await tester.pump(const Duration(milliseconds: 200));
    expect(AppI18n().currentLocale, 'en');
    expect(find.text('Settings'), findsWidgets);

    appState.toggleLocale();
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('ShareDialog generates HMAC signed URL for protected node', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final appState = await createTestAppState();
    addTearDown(appState.dispose);

    final profile = AgentProfile(
      id: 'p_secret',
      name: 'Private NAS',
      nodeId: 'private-nas',
      signalUrl: 'wss://signal.example.com/ws',
      accessSecret: 'super-secret',
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: appState),
        ],
        child: MaterialApp(
          home: Scaffold(body: ShareDialog(profile: profile)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.textContaining('https://signal.example.com/#private-nas?exp='),
      findsOneWidget,
    );
    expect(find.textContaining('&sign='), findsOneWidget);
  });

  testWidgets('AgentEditDialog renders portalUrl and enforces public-mode confirmation', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    AgentProfile? savedProfile;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AgentEditDialog(
            onSave: (p) => savedProfile = p,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.textContaining('-portal-url'), findsOneWidget);
    expect(find.textContaining('随软件启动自动运行该节点'), findsOneWidget);

    await tester.tap(find.text(AppI18n().t('common_save')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(savedProfile, isNull);
  });

  testWidgets('LiveLogDialog displays runtime logs and filters by keyword', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final appState = await createTestAppState();
    addTearDown(appState.dispose);

    final runtime = appState.getRuntimeState('p_log');
    runtime.addLog('INFO p2p connected to peer-1');
    runtime.addLog('ERROR timeout connecting stun');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: appState),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: LiveLogDialog(
              title: 'Log Test Agent',
              profileId: 'p_log',
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Log Test Agent'), findsOneWidget);
    expect(find.textContaining('p2p connected'), findsOneWidget);
    expect(find.textContaining('timeout connecting'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'timeout');
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('p2p connected'), findsNothing);
    expect(find.textContaining('timeout connecting'), findsOneWidget);
  });

  testWidgets('AgentListView prompts security confirmation before starting unprotected node', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 760);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final appState = await createTestAppState();
    addTearDown(appState.dispose);

    final publicProfile = AgentProfile(
      id: 'p_unprotected',
      name: 'Unprotected Test',
      nodeId: 'unprotected-node',
      signalUrl: 'wss://signal.example.com/ws',
      accessSecret: '',
      allowPublic: false,
    );
    appState.addProfile(publicProfile);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: appState),
        ],
        child: const MaterialApp(
          home: Scaffold(body: AgentListView()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    final cardSwitch = find.byWidgetPredicate(
      (w) => w is Switch,
    );
    expect(cardSwitch, findsAtLeastNWidgets(1));
    await tester.tap(cardSwitch.last);
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('安全确认：未设置访客访问密码'), findsOneWidget);
    expect(find.text('自动生成密码并启动'), findsOneWidget);
    expect(find.text('确认公开免密启动'), findsOneWidget);

    await tester.tap(find.text(AppI18n().t('common_cancel')));
    await tester.pump(const Duration(milliseconds: 200));
  });
}
