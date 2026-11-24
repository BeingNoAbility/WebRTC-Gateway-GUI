import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

enum NatType {
  unknown,
  openInternet,
  fullCone,
  restrictedCone,
  portRestricted,
  coneUnknown,
  symmetric,
  blocked,
  detecting,
}

extension NatTypeExt on NatType {
  String get displayNameZh {
    switch (this) {
      case NatType.unknown:
        return '尚未检测 (点击右侧开始诊断)';
      case NatType.openInternet:
        return '公网独立 IP (Open Internet)';
      case NatType.fullCone:
        return '全锥形 (Full Cone NAT / NAT 1) - 最佳穿透';
      case NatType.restrictedCone:
        return 'IP 受限锥形 (Restricted Cone / NAT 2) - 极佳';
      case NatType.portRestricted:
        return '端口受限锥形 (Port Restricted / NAT 3) - 良好';
      case NatType.coneUnknown:
        return '锥形 NAT (NAT 1~3) - 支持 P2P 直连';
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
      case NatType.unknown:
        return 'Not Detected Yet (Click to Start)';
      case NatType.openInternet:
        return 'Open Internet (Public IP)';
      case NatType.fullCone:
        return 'Full Cone NAT (NAT 1, Best P2P)';
      case NatType.restrictedCone:
        return 'Restricted Cone NAT (NAT 2, Great)';
      case NatType.portRestricted:
        return 'Port Restricted NAT (NAT 3, Good)';
      case NatType.coneUnknown:
        return 'Cone NAT (NAT 1-3, Direct P2P Ready)';
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
      this == NatType.coneUnknown ||
      this == NatType.openInternet;
}

class StunLatencyResult {
  final String server;
  final int latencyMs;
  final bool available;

  const StunLatencyResult({
    required this.server,
    required this.latencyMs,
    required this.available,
  });
}

class StunMappedAddress {
  final String ip;
  final int port;
  const StunMappedAddress(this.ip, this.port);

  @override
  String toString() => '$ip:$port';
}

class StunResponseParsed {
  final StunMappedAddress? mappedAddress;
  final StunMappedAddress? otherAddress;

  const StunResponseParsed({
    this.mappedAddress,
    this.otherAddress,
  });
}

class StunPacketResult {
  final Uint8List packet;
  final Uint8List transactionId;

  const StunPacketResult(this.packet, this.transactionId);
}

class DiagnosticService {
  static final Random _random = Random.secure();

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

  // RFC 3489 / RFC 5780 capable STUN servers for CHANGE-REQUEST tests
  static const List<String> _rfc3489StunServers = [
    'stun.sipgate.net:3478',
    'stun.voip.blackberry.com:3478',
    'stun.freeswitch.org:3478',
  ];

  /// Pings a STUN server via lightweight UDP probe and returns roundtrip latency in ms.
  Future<StunLatencyResult> pingStunServer(String serverHostAndPort) async {
    final cleaned = serverHostAndPort.replaceFirst(RegExp(r'^stuns?:'), '');
    final parts = cleaned.split(':');
    final host = parts[0].trim();
    final port = parts.length > 1 ? int.tryParse(parts[1]) ?? 3478 : 3478;

    RawDatagramSocket? socket;
    StreamSubscription<RawSocketEvent>? sub;
    try {
      final addresses = await InternetAddress.lookup(
        host,
        type: InternetAddressType.IPv4,
      ).timeout(const Duration(seconds: 2));
      if (addresses.isEmpty) {
        return StunLatencyResult(
          server: serverHostAndPort,
          latencyMs: -1,
          available: false,
        );
      }

      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final req = buildBindingRequest();
      final completer = Completer<int>();
      final sw = Stopwatch();

      sub = socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket?.receive();
          if (datagram != null &&
              parseBindingResponse(datagram.data, req.transactionId) != null) {
            sw.stop();
            if (!completer.isCompleted) {
              completer.complete(sw.elapsedMilliseconds);
            }
          }
        }
      });

      sw.start();
      socket.send(req.packet, addresses.first, port);

      final latency = await completer.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () => -1,
      );

      return StunLatencyResult(
        server: serverHostAndPort,
        latencyMs: latency,
        available: latency >= 0,
      );
    } catch (_) {
      return StunLatencyResult(
        server: serverHostAndPort,
        latencyMs: -1,
        available: false,
      );
    } finally {
      await sub?.cancel();
      socket?.close();
    }
  }

  /// Pings all default STUN servers concurrently and sorts them by lowest latency.
  Future<List<StunLatencyResult>> rankStunServers([
    List<String>? candidates,
  ]) async {
    final list = candidates ?? defaultStunServers;
    final results = await Future.wait(list.map(pingStunServer));

    results.sort((a, b) {
      if (a.available && !b.available) return -1;
      if (!a.available && b.available) return 1;
      return a.latencyMs.compareTo(b.latencyMs);
    });

    return results;
  }

  /// Diagnoses NAT Type using RFC 3489 / RFC 5780 multi-stage UDP probes.
  Future<NatType> detectNatType() async {
    RawDatagramSocket? socket;
    StreamSubscription<RawSocketEvent>? sub;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

      Uint8List? pendingTxId;
      Completer<Datagram?>? activeCompleter;

      sub = socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = socket?.receive();
          if (dg != null &&
              activeCompleter != null &&
              !activeCompleter!.isCompleted &&
              pendingTxId != null &&
              matchesTransactionId(dg.data, pendingTxId!)) {
            activeCompleter!.complete(dg);
          }
        }
      });

      Future<({StunResponseParsed? parsed, InternetAddress? serverIp, int serverPort})>
          probeBinding(
        String host,
        int port, {
        bool changeIP = false,
        bool changePort = false,
        Duration timeout = const Duration(milliseconds: 1800),
      }) async {
        try {
          final addresses = await InternetAddress.lookup(
            host,
            type: InternetAddressType.IPv4,
          ).timeout(const Duration(seconds: 2));
          if (addresses.isEmpty) {
            return (parsed: null, serverIp: null, serverPort: port);
          }
          final targetAddress = addresses.first;
          final req = buildBindingRequest(
            changeIP: changeIP,
            changePort: changePort,
          );
          pendingTxId = req.transactionId;
          activeCompleter = Completer<Datagram?>();
          socket?.send(req.packet, targetAddress, port);

          final dg = await activeCompleter!.future.timeout(
            timeout,
            onTimeout: () => null,
          );
          pendingTxId = null;
          if (dg == null) {
            return (parsed: null, serverIp: targetAddress, serverPort: port);
          }

          // For CHANGE-REQUEST tests, response must come from alternate IP / port
          if (changeIP && dg.address == targetAddress) {
            return (parsed: null, serverIp: targetAddress, serverPort: port);
          }
          if (changePort && dg.port == port) {
            return (parsed: null, serverIp: targetAddress, serverPort: port);
          }

          final parsed = parseBindingResponse(dg.data, req.transactionId);
          return (parsed: parsed, serverIp: targetAddress, serverPort: port);
        } catch (_) {
          pendingTxId = null;
          return (parsed: null, serverIp: null, serverPort: port);
        }
      }

      // Stage 1 & 2: Collect mappings from two distinct STUN servers on the SAME local socket
      final mappings = <StunMappedAddress>[];
      String? rfc3489Host;
      var rfc3489Port = 3478;

      for (final endpoint in [
        ..._rfc3489StunServers,
        'stun.cloudflare.com:3478',
        'stun.syncthing.net:3478',
        'stun.qq.com:3478',
      ]) {
        final parts = endpoint.split(':');
        final host = parts[0];
        final port = int.parse(parts[1]);
        final res = await probeBinding(host, port);
        final mapped = res.parsed?.mappedAddress;
        if (mapped != null) {
          mappings.add(mapped);
          if (rfc3489Host == null && res.parsed?.otherAddress != null) {
            rfc3489Host = host;
            rfc3489Port = port;
          }
        }
        if (mappings.length >= 2 && rfc3489Host != null) {
          break;
        }
      }

      if (mappings.isEmpty) {
        return NatType.blocked;
      }

      final first = mappings.first;

      // Check if mapped IP equals a local non-loopback IPv4 interface (Open Internet)
      try {
        final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4,
        );
        final localIps = interfaces
            .expand((i) => i.addresses)
            .where((a) => !a.isLoopback)
            .map((a) => a.address)
            .toSet();
        if (localIps.contains(first.ip)) {
          return NatType.openInternet;
        }
      } catch (_) {}

      // Stage 3: Compare mappings across at least 2 distinct servers
      if (mappings.length >= 2) {
        final second = mappings[1];
        if (first.port != second.port || first.ip != second.ip) {
          return NatType.symmetric;
        }
      }

      // Stage 4 & 5: Only run CHANGE-REQUEST when a server advertised OTHER-ADDRESS / CHANGED-ADDRESS
      if (rfc3489Host != null) {
        final changedBoth = await probeBinding(
          rfc3489Host,
          rfc3489Port,
          changeIP: true,
          changePort: true,
          timeout: const Duration(milliseconds: 1600),
        );
        if (changedBoth.parsed != null) {
          return NatType.fullCone;
        }

        final changedPort = await probeBinding(
          rfc3489Host,
          rfc3489Port,
          changeIP: false,
          changePort: true,
          timeout: const Duration(milliseconds: 1600),
        );
        if (changedPort.parsed != null) {
          return NatType.restrictedCone;
        }

        return NatType.portRestricted;
      }

      // Mapping was consistent across servers, but no RFC 3489/5780 server with OTHER-ADDRESS responded
      return mappings.length >= 2 ? NatType.coneUnknown : NatType.unknown;
    } catch (_) {
      return NatType.unknown;
    } finally {
      await sub?.cancel();
      socket?.close();
    }
  }

  /// Builds a STUN Binding Request with a fresh random 96-bit Transaction ID.
  static StunPacketResult buildBindingRequest({
    bool changeIP = false,
    bool changePort = false,
    Uint8List? fixedTransactionId,
  }) {
    final txId = fixedTransactionId ??
        Uint8List.fromList(
          List<int>.generate(12, (_) => _random.nextInt(256)),
        );
    final hasChangeAttr = changeIP || changePort;
    final packet = Uint8List(hasChangeAttr ? 28 : 20);

    // Message Type: 0x0001 Binding Request
    packet[0] = 0x00;
    packet[1] = 0x01;
    // Message Length (excluding 20-byte header)
    packet[2] = 0x00;
    packet[3] = hasChangeAttr ? 0x08 : 0x00;
    // Magic Cookie: 0x2112A442
    packet[4] = 0x21;
    packet[5] = 0x12;
    packet[6] = 0xa4;
    packet[7] = 0x42;
    // 12-byte Transaction ID
    for (var i = 0; i < 12; i++) {
      packet[8 + i] = txId[i];
    }

    if (hasChangeAttr) {
      // Attribute 0x0003 (CHANGE-REQUEST), length 4
      packet[20] = 0x00;
      packet[21] = 0x03;
      packet[22] = 0x00;
      packet[23] = 0x04;
      var flags = 0;
      if (changeIP) flags |= 0x04;
      if (changePort) flags |= 0x02;
      packet[27] = flags;
    }

    return StunPacketResult(packet, txId);
  }

  static bool matchesTransactionId(List<int> bytes, List<int> expectedTxId) {
    if (bytes.length < 20 || expectedTxId.length != 12) return false;
    for (var i = 0; i < 12; i++) {
      if (bytes[8 + i] != expectedTxId[i]) return false;
    }
    return true;
  }

  /// Parses STUN Binding Response (0x0101), verifying Magic Cookie and Transaction ID.
  static StunResponseParsed? parseBindingResponse(
    List<int> bytes,
    List<int> expectedTxId,
  ) {
    if (bytes.length < 20) return null;
    final msgType = (bytes[0] << 8) | bytes[1];
    if (msgType != 0x0101) return null;
    if (bytes[4] != 0x21 ||
        bytes[5] != 0x12 ||
        bytes[6] != 0xa4 ||
        bytes[7] != 0x42) {
      return null;
    }
    if (!matchesTransactionId(bytes, expectedTxId)) return null;

    final msgLen = (bytes[2] << 8) | bytes[3];
    var offset = 20;
    final end = min(bytes.length, 20 + msgLen);

    StunMappedAddress? mapped;
    StunMappedAddress? xorMapped;
    StunMappedAddress? otherAddr;

    while (offset + 4 <= end) {
      final attrType = (bytes[offset] << 8) | bytes[offset + 1];
      final attrLen = (bytes[offset + 2] << 8) | bytes[offset + 3];
      offset += 4;

      if (offset + attrLen > bytes.length) break;

      if (attrType == 0x0020 && attrLen >= 8 && bytes[offset + 1] == 0x01) {
        final rawPort = (bytes[offset + 2] << 8) | bytes[offset + 3];
        final port = rawPort ^ 0x2112;
        final ip1 = bytes[offset + 4] ^ 0x21;
        final ip2 = bytes[offset + 5] ^ 0x12;
        final ip3 = bytes[offset + 6] ^ 0xa4;
        final ip4 = bytes[offset + 7] ^ 0x42;
        xorMapped = StunMappedAddress('$ip1.$ip2.$ip3.$ip4', port);
      } else if (attrType == 0x0001 &&
          attrLen >= 8 &&
          bytes[offset + 1] == 0x01) {
        final port = (bytes[offset + 2] << 8) | bytes[offset + 3];
        mapped = StunMappedAddress(
          '${bytes[offset + 4]}.${bytes[offset + 5]}.${bytes[offset + 6]}.${bytes[offset + 7]}',
          port,
        );
      } else if ((attrType == 0x802C || attrType == 0x0005) &&
          attrLen >= 8 &&
          bytes[offset + 1] == 0x01) {
        final port = (bytes[offset + 2] << 8) | bytes[offset + 3];
        otherAddr = StunMappedAddress(
          '${bytes[offset + 4]}.${bytes[offset + 5]}.${bytes[offset + 6]}.${bytes[offset + 7]}',
          port,
        );
      }

      offset += (attrLen + 3) & ~3;
    }

    final effectiveMapped = xorMapped ?? mapped;
    if (effectiveMapped == null) return null;
    return StunResponseParsed(
      mappedAddress: effectiveMapped,
      otherAddress: otherAddr,
    );
  }
}
