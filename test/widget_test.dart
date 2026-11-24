import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webrtc_gateway_gui/main.dart';
import 'package:webrtc_gateway_gui/services/binary_manager.dart';
import 'package:webrtc_gateway_gui/services/config_repository.dart';
import 'package:webrtc_gateway_gui/services/diagnostic_service.dart';
import 'package:webrtc_gateway_gui/services/metrics_service.dart';
import 'package:webrtc_gateway_gui/services/process_supervisor.dart';
import 'package:webrtc_gateway_gui/state/app_state.dart';

void main() {
  testWidgets('App renders MainWindow and navigation correctly', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final configRepo = ConfigRepository();
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
    addTearDown(() => appState.dispose());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: appState),
        ],
        child: const WebRTCGatewayApp(),
      ),
    );

    // Verify Title and Navigation items render
    expect(find.text('WebRTC'), findsOneWidget);
    expect(find.text('Gateway'), findsOneWidget);
    expect(find.byType(NavigationRail), findsOneWidget);
  });
}
