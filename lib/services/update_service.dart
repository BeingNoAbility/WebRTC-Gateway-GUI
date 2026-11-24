import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

class ReleaseAsset {
  final String name;
  final String browserDownloadUrl;
  final int size;

  ReleaseAsset({
    required this.name,
    required this.browserDownloadUrl,
    required this.size,
  });

  factory ReleaseAsset.fromJson(Map<String, dynamic> json) {
    return ReleaseAsset(
      name: json['name'] as String? ?? '',
      browserDownloadUrl: json['browser_download_url'] as String? ?? '',
      size: json['size'] as int? ?? 0,
    );
  }
}

class ReleaseInfo {
  final String tagName;
  final String htmlUrl;
  final String body;
  final DateTime? publishedAt;
  final List<ReleaseAsset> assets;

  ReleaseInfo({
    required this.tagName,
    required this.htmlUrl,
    required this.body,
    this.publishedAt,
    required this.assets,
  });

  factory ReleaseInfo.fromJson(Map<String, dynamic> json) {
    final rawAssets = json['assets'] as List<dynamic>? ?? [];
    return ReleaseInfo(
      tagName: json['tag_name'] as String? ?? '',
      htmlUrl: json['html_url'] as String? ?? '',
      body: json['body'] as String? ?? '',
      publishedAt: json['published_at'] != null ? DateTime.tryParse(json['published_at']) : null,
      assets: rawAssets.map((e) => ReleaseAsset.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class UpdateService {
  static const String repoGui = 'BeingNoAbility/WebRTC-Gateway-GUI';
  static const String repoCore = 'BeingNoAbility/WebRTC-Gateway';

  static const List<String> presetMirrors = [
    'https://ghproxy.net/',
    'https://mirror.ghproxy.com/',
    'https://cf.ghproxy.cc/',
    '直接访问 (Direct)',
  ];

  /// Resolves the mirror URL for a given target URL
  static String formatUrlWithMirror(String originalUrl, String mirrorPrefix) {
    final prefix = mirrorPrefix.trim();
    if (prefix.isEmpty || prefix.contains('Direct') || prefix.contains('直接')) {
      return originalUrl;
    }
    final normalized = prefix.endsWith('/') ? prefix : '$prefix/';
    return '$normalized$originalUrl';
  }

  /// Checks latest release info for a GitHub repo
  static Future<ReleaseInfo?> fetchLatestRelease(String repo, {String mirrorPrefix = ''}) async {
    final directApiUrl = 'https://api.github.com/repos/$repo/releases/latest';
    final targetUrl = formatUrlWithMirror(directApiUrl, mirrorPrefix);

    try {
      final resp = await http.get(
        Uri.parse(targetUrl),
        headers: {'Accept': 'application/vnd.github.v3+json', 'User-Agent': 'WebRTC-Gateway-GUI'},
      ).timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return ReleaseInfo.fromJson(data);
      }
    } catch (_) {}

    // Fallback directly to api.github.com if mirror failed
    if (targetUrl != directApiUrl) {
      try {
        final resp = await http.get(
          Uri.parse(directApiUrl),
          headers: {'Accept': 'application/vnd.github.v3+json', 'User-Agent': 'WebRTC-Gateway-GUI'},
        ).timeout(const Duration(seconds: 8));
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          return ReleaseInfo.fromJson(data);
        }
      } catch (_) {}
    }

    return null;
  }

  /// Downloads binary or zip asset and updates core binaries
  static Future<String> downloadAndInstallCoreAsset({
    required ReleaseAsset asset,
    required String mirrorPrefix,
    void Function(double progress, String status)? onProgress,
  }) async {
    final downloadUrl = formatUrlWithMirror(asset.browserDownloadUrl, mirrorPrefix);
    onProgress?.call(0.05, '正在建立连接: $downloadUrl');

    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await client.send(request);

      if (response.statusCode != 200 && response.statusCode != 302) {
        return '下载失败，服务器返回 HTTP ${response.statusCode}';
      }

      final totalBytes = response.contentLength ?? asset.size;
      int receivedBytes = 0;
      final bytesBuilder = BytesBuilder(copy: false);

      await for (final chunk in response.stream) {
        bytesBuilder.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          final p = (receivedBytes / totalBytes).clamp(0.0, 0.95);
          onProgress?.call(p, '正在下载 ${(receivedBytes / (1024 * 1024)).toStringAsFixed(1)} MB / ${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB (${(p * 100).toInt()}%)');
        }
      }

      final bytes = bytesBuilder.takeBytes();
      onProgress?.call(0.96, '下载完成，正在准备安装核心文件...');

      // Find local bin target dir
      final exeDir = p.dirname(Platform.resolvedExecutable);
      final binDir = Directory(p.join(exeDir, 'bin'));
      if (!await binDir.exists()) {
        await binDir.create(recursive: true);
      }

      // Check if file is direct agent/signal binary or an archive
      final lowerName = asset.name.toLowerCase();
      if (lowerName.contains('agent') && lowerName.endsWith('.exe')) {
        final target = File(p.join(binDir.path, 'agent.exe'));
        await target.writeAsBytes(bytes);
        onProgress?.call(1.0, 'agent.exe 更新成功！');
        return 'agent.exe 已成功更新至: ${target.path}';
      } else if (lowerName.contains('signal') && lowerName.endsWith('.exe')) {
        final target = File(p.join(binDir.path, 'signal.exe'));
        await target.writeAsBytes(bytes);
        onProgress?.call(1.0, 'signal.exe 更新成功！');
        return 'signal.exe 已成功更新至: ${target.path}';
      } else {
        // Save as downloaded package in bin directory
        final target = File(p.join(binDir.path, asset.name));
        await target.writeAsBytes(bytes);
        onProgress?.call(1.0, '核心安装包已保存至 bin 目录');
        return '已成功下载核心包: ${target.path}，请解压或直接选用。';
      }
    } catch (e) {
      return '下载过程中发生异常: $e';
    }
  }
}
