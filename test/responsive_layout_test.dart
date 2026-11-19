import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webrtc_gateway_gui/core/theme/app_theme.dart';
import 'package:webrtc_gateway_gui/core/models/log_entry.dart';
import 'package:webrtc_gateway_gui/ui/widgets/metric_card.dart';
import 'package:webrtc_gateway_gui/ui/widgets/terminal_log_view.dart';

void main() {
  group('Responsive Layout Zero-Overflow Tests (Invariant 2.1)', () {
    testWidgets('MetricCard does not overflow on ultra-narrow 140px width', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 140,
                child: MetricCard(
                  icon: Icons.speed_rounded,
                  title: '全网活跃 P2P 对等连接',
                  value: '128.45 MB/s',
                  subtitle: '累计传输 1024.50 GB 数据流',
                  accentColor: Colors.cyan,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'TerminalLogView toolbar does not overflow on 320px narrow mobile viewport',
      (tester) async {
        // Set physical size to 320x640 (narrow phone)
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final testLogs = [
          LogEntry(
            timestamp: DateTime.now(),
            level: LogLevel.info,
            message: 'WebRTC Gateway agent node initialized successfully',
            source: LogSource.agent,
          ),
          LogEntry(
            timestamp: DateTime.now(),
            level: LogLevel.warning,
            message: 'STUN binding latency higher than usual: 120ms',
            source: LogSource.agent,
          ),
          LogEntry(
            timestamp: DateTime.now(),
            level: LogLevel.error,
            message: 'Failed to negotiate SDP handshake with remote peer',
            source: LogSource.signal,
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: SizedBox(
                  height: 400,
                  child: TerminalLogView(logs: testLogs, onClear: () {}),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        // Zero overflow invariant assertion: No FlutterError or RenderFlex overflow
        expect(tester.takeException(), isNull);
        expect(find.text('实时终端控制台'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
      },
    );
  });
}
