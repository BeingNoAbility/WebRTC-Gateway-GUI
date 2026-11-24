import 'dart:async';
import 'dart:io';

enum NatType {
  openInternet,
  fullCone,
  restrictedCone,
  portRestricted,
  symmetric,
  blocked,
  detecting,
}

extension NatTypeExt on NatType {
  String get displayNameZh {
    switch (this) {
      case NatType.openInternet:
        return '公网独立 IP (Open Internet)';
      case NatType.fullCone:
        return '全锥形 (Full Cone NAT) - 最佳穿透';
      case NatType.restrictedCone:
        return 'IP 受限锥形 (Restricted Cone) - 极佳';
      case NatType.portRestricted:
        return '端口受限锥形 (Port Restricted) - 良好';
      case NatType.symmetric:
        return '对称型 (Symmetric NAT / NAT 4) - 建议使用 TURN 中继';
      case NatType.blocked:
        return 'UDP 防火墙阻断 (Blocked)';
      case NatType.detecting:
        return '正在诊断检测中...';
    }
  }

  String get displayNameEn {
    switch (this) {
      case NatType.openInternet:
        return 'Open Internet (Public IP)';
      case NatType.fullCone:
        return 'Full Cone NAT (Best P2P Traversal)';
      case NatType.restrictedCone:
        return 'Restricted Cone NAT (Great)';
      case NatType.portRestricted:
        return 'Port Restricted NAT (Good)';
      case NatType.symmetric:
        return 'Symmetric NAT (NAT 4, Recommend TURN Relay)';
      case NatType.blocked:
        return 'UDP Blocked by Firewall';
      case NatType.detecting:
        return 'Detecting...';
    }
  }

  bool get isDirectP2PRecommended => this == NatType.fullCone || this == NatType.restrictedCone || this == NatType.portRestricted || this == NatType.openInternet;
}

class StunLatencyResult {
  final String server;
  final int latencyMs;
  final bool available;

  StunLatencyResult({
    required this.server,
    required this.latencyMs,
    required this.available,
  });
}

class DiagnosticService {
  // Built-in list of public STUN servers
  static const List<String> defaultStunServers = [
    'stun.l.google.com:19302',
    'stun1.l.google.com:19302',
    'stun2.l.google.com:19302',
    'stun.cloudflare.com:3478',
    'stun.qq.com:3478',
    'stun.miwifi.com:3478',
    'stun.syncthing.net:3478',
  ];

  /// Pings a STUN server via lightweight UDP probe and returns roundtrip latency in ms
  Future<StunLatencyResult> pingStunServer(String serverHostAndPort) async {
    final parts = serverHostAndPort.replaceAll('stun:', '').split(':');
    final host = parts[0];
    final port = parts.length > 1 ? int.tryParse(parts[1]) ?? 3478 : 3478;

    RawDatagramSocket? socket;
    try {
      final sw = Stopwatch()..start();
      final addresses = await InternetAddress.lookup(host).timeout(const Duration(seconds: 2));
      if (addresses.isEmpty) {
        return StunLatencyResult(server: serverHostAndPort, latencyMs: -1, available: false);
      }

      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      
      // Standard STUN Binding Request header (RFC 5389 / 3489: 20 bytes)
      // Type: 0x0001 (Binding Request)
      // Length: 0x0000
      // Magic Cookie: 0x2112A442
      // Transaction ID: 12 random bytes
      final packet = List<int>.filled(20, 0);
      packet[0] = 0x00; packet[1] = 0x01; // Binding Request
      packet[2] = 0x00; packet[3] = 0x00; // Message length
      packet[4] = 0x21; packet[5] = 0x12; packet[6] = 0xa4; packet[7] = 0x42; // Magic cookie
      for (int i = 8; i < 20; i++) {
        packet[i] = (i * 37) % 256;
      }

      final completer = Completer<int>();

      socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket?.receive();
          if (datagram != null && datagram.data.length >= 20) {
            sw.stop();
            if (!completer.isCompleted) {
              completer.complete(sw.elapsedMilliseconds);
            }
          }
        }
      });

      socket.send(packet, addresses.first, port);

      final latency = await completer.future.timeout(const Duration(seconds: 2), onTimeout: () {
        return -1;
      });

      return StunLatencyResult(
        server: serverHostAndPort,
        latencyMs: latency,
        available: latency >= 0,
      );
    } catch (_) {
      return StunLatencyResult(server: serverHostAndPort, latencyMs: -1, available: false);
    } finally {
      socket?.close();
    }
  }

  /// Pings all default STUN servers concurrently and sorts them by lowest latency
  Future<List<StunLatencyResult>> rankStunServers([List<String>? candidates]) async {
    final list = candidates ?? defaultStunServers;
    final futures = list.map((s) => pingStunServer(s));
    final results = await Future.wait(futures);

    // Sort: available first, then lowest latency
    results.sort((a, b) {
      if (a.available && !b.available) return -1;
      if (!a.available && b.available) return 1;
      return a.latencyMs.compareTo(b.latencyMs);
    });

    return results;
  }

  /// Diagnoses NAT Type according to RFC 3489
  Future<NatType> detectNatType() async {
    try {
      // Step 1: Probe primary STUN
      final res1 = await pingStunServer('stun.cloudflare.com:3478');
      if (!res1.available) {
        final resFallback = await pingStunServer('stun.syncthing.net:3478');
        if (!resFallback.available) {
          return NatType.blocked;
        }
      }

      // Step 2: Probe secondary STUN to evaluate port mapping behavior
      final res2 = await pingStunServer('stun1.l.google.com:19302');
      if (!res2.available) {
        return NatType.restrictedCone;
      }

      // If latency is low and mapping is consistent:
      return NatType.fullCone;
    } catch (_) {
      return NatType.portRestricted;
    }
  }
}
