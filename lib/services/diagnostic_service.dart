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
        return '全锥形 (Full Cone NAT / NAT 1) - 最佳穿透';
      case NatType.restrictedCone:
        return 'IP 受限锥形 (Restricted Cone / NAT 2) - 极佳';
      case NatType.portRestricted:
        return '端口受限锥形 (Port Restricted / NAT 3) - 良好';
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
        return 'Full Cone NAT (NAT 1, Best P2P)';
      case NatType.restrictedCone:
        return 'Restricted Cone NAT (NAT 2, Great)';
      case NatType.portRestricted:
        return 'Port Restricted NAT (NAT 3, Good)';
      case NatType.symmetric:
        return 'Symmetric NAT (NAT 4, Recommend TURN Relay)';
      case NatType.blocked:
        return 'UDP Blocked by Firewall';
      case NatType.detecting:
        return 'Detecting...';
    }
  }

  bool get isDirectP2PRecommended =>
      this == NatType.fullCone ||
      this == NatType.restrictedCone ||
      this == NatType.portRestricted ||
      this == NatType.openInternet;
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

class StunMappedAddress {
  final String ip;
  final int port;
  StunMappedAddress(this.ip, this.port);
  @override
  String toString() => '$ip:$port';
}

class DiagnosticService {
  // Built-in list of public STUN servers
  static const List<String> defaultStunServers = [
    'stun.cloudflare.com:3478',
    'stun.syncthing.net:3478',
    'stun.qq.com:3478',
    'stun.miwifi.com:3478',
    'stun.l.google.com:19302',
    'stun1.l.google.com:19302',
    'stun2.l.google.com:19302',
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

      final packet = _buildBindingRequest();
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

  /// Diagnoses NAT Type according to RFC 3489 multi-stage tests using a single UDP socket
  Future<NatType> detectNatType() async {
    RawDatagramSocket? socket;
    StreamSubscription<RawSocketEvent>? sub;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

      Completer<Datagram?>? activeCompleter;
      sub = socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = socket?.receive();
          if (dg != null && activeCompleter != null && !activeCompleter!.isCompleted) {
            activeCompleter!.complete(dg);
          }
        }
      });

      Future<StunMappedAddress?> probeAddress(String host, int port) async {
        try {
          final addresses = await InternetAddress.lookup(host).timeout(const Duration(seconds: 2));
          if (addresses.isEmpty) return null;
          final packet = _buildBindingRequest();
          activeCompleter = Completer<Datagram?>();
          socket?.send(packet, addresses.first, port);
          final dg = await activeCompleter!.future.timeout(const Duration(milliseconds: 1800), onTimeout: () => null);
          if (dg != null && dg.data.length >= 20) {
            return _parseMappedAddress(dg.data);
          }
          return null;
        } catch (_) {
          return null;
        }
      }

      Future<bool> probeChange(String host, int port, {required bool changeIP, required bool changePort}) async {
        try {
          final addresses = await InternetAddress.lookup(host).timeout(const Duration(seconds: 2));
          if (addresses.isEmpty) return false;
          final packet = _buildBindingRequest(changeIP: changeIP, changePort: changePort);
          activeCompleter = Completer<Datagram?>();
          socket?.send(packet, addresses.first, port);
          final dg = await activeCompleter!.future.timeout(const Duration(milliseconds: 1500), onTimeout: () => null);
          return dg != null && dg.data.length >= 20;
        } catch (_) {
          return false;
        }
      }

      // Stage 1: Primary STUN probe
      final mapped1 = await probeAddress('stun.cloudflare.com', 3478);

      // Stage 2: Secondary STUN probe from SAME socket
      final mapped2 = await probeAddress('stun.syncthing.net', 3478) ??
          await probeAddress('stun.qq.com', 3478);

      // If neither replied, UDP is blocked
      if (mapped1 == null && mapped2 == null) {
        return NatType.blocked;
      }

      final m1 = mapped1 ?? mapped2!;
      final m2 = mapped2 ?? mapped1!;

      // Check if mapped IP is equal to local network interface IP (Open Internet)
      try {
        final interfaces = await NetworkInterface.list();
        final localIps = interfaces.expand((i) => i.addresses).map((a) => a.address).toSet();
        if (localIps.contains(m1.ip)) {
          return NatType.openInternet;
        }
      } catch (_) {}

      // Stage 3: Compare mappings across different servers
      if (m1.port != m2.port || m1.ip != m2.ip) {
        // Destination dependent -> Symmetric NAT (NAT 4)
        return NatType.symmetric;
      }

      // Consistent mapping across destinations -> Cone family.
      // Stage 4: Test CHANGE-REQUEST (change IP & Port)
      final changedBoth = await probeChange('stun.cloudflare.com', 3478, changeIP: true, changePort: true);
      if (changedBoth) {
        return NatType.fullCone; // NAT 1
      }

      // Stage 5: Test CHANGE-PORT
      final changedPort = await probeChange('stun.cloudflare.com', 3478, changeIP: false, changePort: true);
      if (changedPort) {
        return NatType.restrictedCone; // NAT 2
      }

      // Port Restricted Cone (NAT 3)
      return NatType.portRestricted;
    } catch (_) {
      return NatType.portRestricted;
    } finally {
      await sub?.cancel();
      socket?.close();
    }
  }

  List<int> _buildBindingRequest({bool changeIP = false, bool changePort = false}) {
    if (!changeIP && !changePort) {
      final packet = List<int>.filled(20, 0);
      packet[0] = 0x00;
      packet[1] = 0x01; // Binding Request
      packet[2] = 0x00;
      packet[3] = 0x00; // Length
      packet[4] = 0x21;
      packet[5] = 0x12;
      packet[6] = 0xa4;
      packet[7] = 0x42; // Magic cookie
      for (int i = 8; i < 20; i++) {
        packet[i] = (i * 37) % 256;
      }
      return packet;
    } else {
      // 20 bytes header + 8 bytes CHANGE-REQUEST attribute
      final packet = List<int>.filled(28, 0);
      packet[0] = 0x00;
      packet[1] = 0x01; // Binding Request
      packet[2] = 0x00;
      packet[3] = 0x08; // Length 8
      packet[4] = 0x21;
      packet[5] = 0x12;
      packet[6] = 0xa4;
      packet[7] = 0x42; // Magic cookie
      for (int i = 8; i < 20; i++) {
        packet[i] = (i * 37) % 256;
      }
      // Attribute 0x0003 (CHANGE-REQUEST), len 4
      packet[20] = 0x00;
      packet[21] = 0x03;
      packet[22] = 0x00;
      packet[23] = 0x04;
      int flags = 0;
      if (changeIP) flags |= 0x04;
      if (changePort) flags |= 0x02;
      packet[27] = flags;
      return packet;
    }
  }

  StunMappedAddress? _parseMappedAddress(List<int> bytes) {
    if (bytes.length < 20) return null;
    final msgType = (bytes[0] << 8) | bytes[1];
    if (msgType != 0x0101) return null; // 0x0101 = Binding Response

    final msgLen = (bytes[2] << 8) | bytes[3];
    int offset = 20;
    final end = 20 + msgLen;

    while (offset + 4 <= bytes.length && offset + 4 <= end) {
      final attrType = (bytes[offset] << 8) | bytes[offset + 1];
      final attrLen = (bytes[offset + 2] << 8) | bytes[offset + 3];
      offset += 4;

      if (offset + attrLen > bytes.length) break;

      // 0x0020 = XOR-MAPPED-ADDRESS
      if (attrType == 0x0020 && attrLen >= 8) {
        final family = bytes[offset + 1];
        if (family == 0x01) {
          final rawPort = (bytes[offset + 2] << 8) | bytes[offset + 3];
          final port = rawPort ^ 0x2112;
          final ip1 = bytes[offset + 4] ^ 0x21;
          final ip2 = bytes[offset + 5] ^ 0x12;
          final ip3 = bytes[offset + 6] ^ 0xa4;
          final ip4 = bytes[offset + 7] ^ 0x42;
          return StunMappedAddress('$ip1.$ip2.$ip3.$ip4', port);
        }
      }
      // 0x0001 = MAPPED-ADDRESS
      else if (attrType == 0x0001 && attrLen >= 8) {
        final family = bytes[offset + 1];
        if (family == 0x01) {
          final port = (bytes[offset + 2] << 8) | bytes[offset + 3];
          final ip1 = bytes[offset + 4];
          final ip2 = bytes[offset + 5];
          final ip3 = bytes[offset + 6];
          final ip4 = bytes[offset + 7];
          return StunMappedAddress('$ip1.$ip2.$ip3.$ip4', port);
        }
      }

      offset += (attrLen + 3) & ~3;
    }
    return null;
  }
}
