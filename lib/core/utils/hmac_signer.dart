import 'dart:convert';
import 'package:crypto/crypto.dart';

class HmacSigner {
  /// Computes HMAC-SHA256 hex string with given key and data (identical to Go Agent).
  static String computeHmac(String key, String data) {
    final hmac = Hmac(sha256, utf8.encode(key));
    final digest = hmac.convert(utf8.encode(data));
    return digest.toString();
  }

  /// Calculates an HMAC-SHA256 signature for a temporary share link.
  /// Format: secret, "$nodeId:$exp"
  static String generateShareSignature(String nodeId, int exp, String secret) {
    final data = '$nodeId:$exp';
    return computeHmac(secret, data);
  }

  /// Formats a complete ready-to-share URL with HMAC signature.
  static String generateShareLink({
    required String portalUrl,
    required String nodeId,
    required String accessSecret,
    required Duration duration,
  }) {
    final base = portalUrl.endsWith('/') ? portalUrl.substring(0, portalUrl.length - 1) : portalUrl;
    if (accessSecret.trim().isEmpty) {
      return '$base/#$nodeId';
    }

    final exp = (DateTime.now().add(duration).millisecondsSinceEpoch ~/ 1000);
    final sign = generateShareSignature(nodeId, exp, accessSecret.trim());
    return '$base/#$nodeId?exp=$exp&sign=$sign';
  }

  /// Parses a WebRTC-Gateway share link into components.
  static Map<String, dynamic>? parseShareLink(String urlStr) {
    try {
      final uri = Uri.parse(urlStr.trim());
      final fragment = uri.fragment; // e.g. "myhome?exp=1700000000&sign=abcd"
      if (fragment.isEmpty) return null;

      String nodeId = fragment;
      int? exp;
      String? sign;

      if (fragment.contains('?')) {
        final fragParts = fragment.split('?');
        nodeId = fragParts[0];
        final queryParams = Uri.splitQueryString(fragParts[1]);
        if (queryParams.containsKey('exp')) {
          exp = int.tryParse(queryParams['exp']!);
        }
        sign = queryParams['sign'];
      }

      var portalUrl = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}${uri.path}';
      if (portalUrl.endsWith('/')) {
        portalUrl = portalUrl.substring(0, portalUrl.length - 1);
      }

      return {
        'portalUrl': portalUrl,
        'nodeId': nodeId,
        'exp': exp,
        'sign': sign,
        'isExpired': exp != null && (DateTime.now().millisecondsSinceEpoch ~/ 1000) > exp,
      };
    } catch (_) {
      return null;
    }
  }
}
