import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class DiagnosticResult {
  final bool success;
  final String title;
  final String details;
  final int latencyMs;

  const DiagnosticResult({
    required this.success,
    required this.title,
    required this.details,
    required this.latencyMs,
  });
}

class NetworkTester {
  /// Probes whether a local or remote TCP port is open (e.g. 127.0.0.1:8080).
  static Future<DiagnosticResult> testTcpPort(String host, int port, {Duration timeout = const Duration(seconds: 3)}) async {
    final sw = Stopwatch()..start();
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      sw.stop();
      await socket.close();
      return DiagnosticResult(
        success: true,
        title: '$host:$port 连接成功',
        details: 'TCP 端口可达，响应耗时 ${sw.elapsedMilliseconds} ms',
        latencyMs: sw.elapsedMilliseconds,
      );
    } catch (e) {
      sw.stop();
      return DiagnosticResult(
        success: false,
        title: '$host:$port 连接失败',
        details: '端口未开启或拒绝连接: $e',
        latencyMs: sw.elapsedMilliseconds,
      );
    }
  }

  /// Probes an HTTP endpoint (e.g. local target or healthcheck).
  static Future<DiagnosticResult> testHttp(String urlStr, {Duration timeout = const Duration(seconds: 4)}) async {
    final sw = Stopwatch()..start();
    try {
      final uri = Uri.parse(urlStr);
      final response = await http.get(uri).timeout(timeout);
      sw.stop();
      return DiagnosticResult(
        success: response.statusCode >= 200 && response.statusCode < 400,
        title: 'HTTP 状态码: ${response.statusCode}',
        details: '耗时 ${sw.elapsedMilliseconds} ms，返回大小: ${response.bodyBytes.length} bytes',
        latencyMs: sw.elapsedMilliseconds,
      );
    } catch (e) {
      sw.stop();
      return DiagnosticResult(
        success: false,
        title: 'HTTP 请求失败',
        details: '错误: $e',
        latencyMs: sw.elapsedMilliseconds,
      );
    }
  }

  /// Sends a standard RFC 5389 STUN Binding Request (20 bytes) over UDP to test STUN server connectivity.
  static Future<DiagnosticResult> testStun(String stunServer, {Duration timeout = const Duration(seconds: 3)}) async {
    final sw = Stopwatch()..start();
    RawDatagramSocket? socket;
    try {
      var server = stunServer.trim();
      if (server.startsWith('stun:')) {
        server = server.substring(5);
      }
      String host = server;
      int port = 3478;
      if (server.contains(':')) {
        final parts = server.split(':');
        host = parts[0];
        port = int.tryParse(parts[1]) ?? 3478;
      }

      final addresses = await InternetAddress.lookup(host);
      if (addresses.isEmpty) {
        throw Exception('DNS 解析失败: $host');
      }

      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

      // RFC 5389 STUN Binding Request:
      // 0x0001 (Binding Request), Length: 0x0000, Magic Cookie: 0x2112A442, Transaction ID: 12 random bytes
      final packet = Uint8List(20);
      final bd = ByteData.sublistView(packet);
      bd.setUint16(0, 0x0001); // Binding Request
      bd.setUint16(2, 0x0000); // Message Length
      bd.setUint32(4, 0x2112A442); // Magic Cookie
      for (int i = 8; i < 20; i++) {
        packet[i] = (i * 37) & 0xFF; // Transaction ID
      }

      final completer = Completer<DiagnosticResult>();

      final timer = Timer(timeout, () {
        if (!completer.isCompleted) {
          completer.complete(DiagnosticResult(
            success: false,
            title: 'STUN 响应超时',
            details: '$stunServer (3秒未应答)',
            latencyMs: timeout.inMilliseconds,
          ));
        }
      });

      socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket?.receive();
          if (datagram != null && datagram.data.length >= 20) {
            final respBd = ByteData.sublistView(datagram.data);
            final msgType = respBd.getUint16(0);
            if (msgType == 0x0101) {
              // Binding Success Response
              sw.stop();
              timer.cancel();
              if (!completer.isCompleted) {
                completer.complete(DiagnosticResult(
                  success: true,
                  title: 'STUN 打洞协商成功',
                  details: '来自 ${datagram.address.address}:${datagram.port}，往返延迟 ${sw.elapsedMilliseconds} ms',
                  latencyMs: sw.elapsedMilliseconds,
                ));
              }
            }
          }
        }
      });

      socket.send(packet, addresses.first, port);
      final result = await completer.future;
      socket.close();
      return result;
    } catch (e) {
      socket?.close();
      sw.stop();
      return DiagnosticResult(
        success: false,
        title: 'STUN 测试异常',
        details: '$e',
        latencyMs: sw.elapsedMilliseconds,
      );
    }
  }
}
