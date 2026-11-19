import 'package:flutter/foundation.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/network_tester.dart';

class DiagnosticsProvider extends ChangeNotifier {
  bool _isTesting = false;
  final List<DiagnosticResult> _results = [];

  bool get isTesting => _isTesting;
  List<DiagnosticResult> get results => List.unmodifiable(_results);

  void clearResults() {
    _results.clear();
    notifyListeners();
  }

  Future<void> runAllDiagnostics({
    required String targetUrl,
    required String signalUrl,
    required List<String> stunServers,
  }) async {
    if (_isTesting) return;
    _isTesting = true;
    _results.clear();
    notifyListeners();

    // 1. Test local target service (e.g. 127.0.0.1:8080)
    try {
      final uri = Uri.parse(targetUrl);
      final host = uri.host.isNotEmpty ? uri.host : '127.0.0.1';
      final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
      final targetPortResult = await NetworkTester.testTcpPort(host, port);
      _results.add(targetPortResult);
      notifyListeners();

      if (targetUrl.startsWith('http')) {
        final httpResult = await NetworkTester.testHttp(targetUrl);
        _results.add(httpResult);
        notifyListeners();
      }
    } catch (e) {
      _results.add(DiagnosticResult(
        success: false,
        title: '目标地址解析失败',
        details: '$targetUrl ($e)',
        latencyMs: 0,
      ));
      notifyListeners();
    }

    // 2. Test Signaling Server endpoint
    try {
      final sUri = Uri.parse(signalUrl);
      final sHost = sUri.host.isNotEmpty ? sUri.host : '127.0.0.1';
      final sPort = sUri.hasPort ? sUri.port : 8888;
      final signalResult = await NetworkTester.testTcpPort(sHost, sPort);
      _results.add(DiagnosticResult(
        success: signalResult.success,
        title: '信令服务器端口测试 ($sHost:$sPort)',
        details: signalResult.details,
        latencyMs: signalResult.latencyMs,
      ));
      notifyListeners();
    } catch (e) {
      _results.add(DiagnosticResult(
        success: false,
        title: '信令服务器地址无效',
        details: '$signalUrl ($e)',
        latencyMs: 0,
      ));
      notifyListeners();
    }

    // 3. Test STUN servers
    final serversToTest = stunServers.isNotEmpty ? stunServers : AppConstants.defaultStunServers;
    for (final stun in serversToTest) {
      final res = await NetworkTester.testStun(stun);
      _results.add(res);
      notifyListeners();
    }

    _isTesting = false;
    notifyListeners();
  }
}
