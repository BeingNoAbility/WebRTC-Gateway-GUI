import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

class ReleaseAsset {
  final String name;
  final String browserDownloadUrl;
  final int size;

  const ReleaseAsset({
    required this.name,
    required this.browserDownloadUrl,
    required this.size,
  });

  factory ReleaseAsset.fromJson(Map<String, dynamic> json) {
    return ReleaseAsset(
      name: json['name'] as String? ?? '',
      browserDownloadUrl: json['browser_download_url'] as String? ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
    );
  }
}

class ReleaseInfo {
  final String tagName;
  final String htmlUrl;
  final String body;
  final DateTime? publishedAt;
  final List<ReleaseAsset> assets;

  const ReleaseInfo({
    required this.tagName,
    required this.htmlUrl,
    required this.body,
    this.publishedAt,
    required this.assets,
  });

  factory ReleaseInfo.fromJson(Map<String, dynamic> json) {
    final rawAssets = json['assets'] as List<dynamic>? ?? const [];
    final publishedRaw = json['published_at']?.toString();
    return ReleaseInfo(
      tagName: json['tag_name'] as String? ?? '',
      htmlUrl: json['html_url'] as String? ?? '',
      body: json['body'] as String? ?? '',
      publishedAt: publishedRaw != null ? DateTime.tryParse(publishedRaw) : null,
      assets: rawAssets
          .whereType<Map<String, dynamic>>()
          .map(ReleaseAsset.fromJson)
          .toList(),
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

  /// Resolves the mirror URL for a given target URL.
  static String formatUrlWithMirror(String originalUrl, String mirrorPrefix) {
    final prefix = mirrorPrefix.trim();
    if (prefix.isEmpty ||
        prefix.contains('Direct') ||
        prefix.contains('直接')) {
      return originalUrl;
    }
    final normalized = prefix.endsWith('/') ? prefix : '$prefix/';
    return '$normalized$originalUrl';
  }

  /// Checks latest release info for a GitHub repo.
  static Future<ReleaseInfo?> fetchLatestRelease(
    String repo, {
    String mirrorPrefix = '',
  }) async {
    final directApiUrl = 'https://api.github.com/repos/$repo/releases/latest';
    final targetUrl = formatUrlWithMirror(directApiUrl, mirrorPrefix);

    try {
      final resp = await http
          .get(
            Uri.parse(targetUrl),
            headers: {
              'Accept': 'application/vnd.github.v3+json',
              'User-Agent': 'WebRTC-Gateway-GUI',
            },
          )
          .timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return ReleaseInfo.fromJson(data);
      }
    } catch (_) {}

    if (targetUrl != directApiUrl) {
      try {
        final resp = await http
            .get(
              Uri.parse(directApiUrl),
              headers: {
                'Accept': 'application/vnd.github.v3+json',
                'User-Agent': 'WebRTC-Gateway-GUI',
              },
            )
            .timeout(const Duration(seconds: 8));
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          return ReleaseInfo.fromJson(data);
        }
      } catch (_) {}
    }

    return null;
  }

  /// Fetches optional `SHA256SUMS.txt` map (`filename -> lowercase sha256`) from a release.
  static Future<Map<String, String>> fetchChecksums(
    ReleaseInfo release, {
    String mirrorPrefix = '',
  }) async {
    ReleaseAsset? checksumAsset;
    for (final a in release.assets) {
      if (a.name.toUpperCase() == 'SHA256SUMS.TXT') {
        checksumAsset = a;
        break;
      }
    }
    if (checksumAsset == null) return const {};

    final urls = [
      formatUrlWithMirror(checksumAsset.browserDownloadUrl, mirrorPrefix),
      checksumAsset.browserDownloadUrl,
    ];
    for (final url in urls) {
      try {
        final resp = await http.get(Uri.parse(url)).timeout(
              const Duration(seconds: 8),
            );
        if (resp.statusCode == 200) {
          return parseSha256Sums(resp.body);
        }
      } catch (_) {}
    }
    return const {};
  }

  static Map<String, String> parseSha256Sums(String content) {
    final map = <String, String>{};
    for (final line in content.split(RegExp(r'\r?\n'))) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final match = RegExp(r'^([0-9a-fA-F]{64})\s+\*?(.+)$').firstMatch(trimmed);
      if (match != null) {
        map[match.group(2)!.trim()] = match.group(1)!.toLowerCase();
      }
    }
    return map;
  }

  /// Downloads binary or compressed archive asset, verifies SHA256 if available,
  /// and installs `agent[.exe]` and `signal[.exe]` into the `bin/` folder.
  static Future<String> downloadAndInstallCoreAsset({
    required ReleaseAsset asset,
    required String mirrorPrefix,
    String? expectedSha256,
    bool hasRunningCore = false,
    void Function(double progress, String status)? onProgress,
  }) async {
    if (hasRunningCore) {
      return '请先停止所有运行中的穿透节点和本地信令服务，再更新底层核心文件。';
    }

    final downloadUrl =
        formatUrlWithMirror(asset.browserDownloadUrl, mirrorPrefix);
    onProgress?.call(0.05, '正在建立连接: $downloadUrl');

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response =
          await client.send(request).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return '下载失败，服务器返回 HTTP ${response.statusCode}';
      }

      final totalBytes = response.contentLength ?? asset.size;
      var receivedBytes = 0;
      final bytesBuilder = BytesBuilder(copy: false);

      await for (final chunk in response.stream) {
        bytesBuilder.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          final progress = (receivedBytes / totalBytes).clamp(0.05, 0.88);
          final recMb = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
          final totMb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
          onProgress?.call(
            progress,
            '正在下载 $recMb MB / $totMb MB (${(progress * 100).toInt()}%)',
          );
        }
      }

      final bytes = bytesBuilder.takeBytes();

      if (expectedSha256 != null && expectedSha256.isNotEmpty) {
        onProgress?.call(0.90, '正在校验 SHA256 完整性...');
        final actualSha = sha256.convert(bytes).toString().toLowerCase();
        if (actualSha != expectedSha256.toLowerCase()) {
          return '安全校验失败：SHA256 不匹配！期望 $expectedSha256，实际 $actualSha';
        }
      }

      onProgress?.call(0.94, '正在安装核心文件...');
      final exeDir = p.dirname(Platform.resolvedExecutable);
      final binDir = Directory(p.join(exeDir, 'bin'));
      if (!await binDir.exists()) {
        await binDir.create(recursive: true);
      }

      final ext = Platform.isWindows ? '.exe' : '';
      final agentName = 'agent$ext';
      final signalName = 'signal$ext';
      final lowerName = asset.name.toLowerCase();

      if (lowerName.endsWith('.zip') || lowerName.endsWith('.tar.gz') || lowerName.endsWith('.tgz')) {
        final Archive archive;
        if (lowerName.endsWith('.zip')) {
          archive = ZipDecoder().decodeBytes(bytes);
        } else {
          final tarBytes = GZipDecoder().decodeBytes(bytes);
          archive = TarDecoder().decodeBytes(tarBytes);
        }

        final installed = <String>[];
        for (final entry in archive) {
          if (!entry.isFile) continue;
          final base = p.basename(entry.name).toLowerCase();
          if (base == agentName || base == signalName) {
            final targetPath = p.join(binDir.path, base);
            final data = entry.content as List<int>;
            await _atomicWriteBinary(targetPath, data);
            if (!Platform.isWindows) {
              await Process.run('chmod', ['+x', targetPath]);
            }
            installed.add(base);
          }
        }

        if (installed.isEmpty) {
          return '压缩包 ${asset.name} 中未找到 $agentName 或 $signalName';
        }
        onProgress?.call(1.0, '核心更新成功 (${installed.join(", ")})');
        return '已成功校验并安装 ${installed.join("、")} 至 ${binDir.path}';
      } else if (lowerName.contains('agent')) {
        final targetPath = p.join(binDir.path, agentName);
        await _atomicWriteBinary(targetPath, bytes);
        if (!Platform.isWindows) {
          await Process.run('chmod', ['+x', targetPath]);
        }
        onProgress?.call(1.0, '$agentName 更新成功！');
        return '$agentName 已成功更新至: $targetPath';
      } else if (lowerName.contains('signal')) {
        final targetPath = p.join(binDir.path, signalName);
        await _atomicWriteBinary(targetPath, bytes);
        if (!Platform.isWindows) {
          await Process.run('chmod', ['+x', targetPath]);
        }
        onProgress?.call(1.0, '$signalName 更新成功！');
        return '$signalName 已成功更新至: $targetPath';
      } else {
        final target = File(p.join(binDir.path, asset.name));
        await target.writeAsBytes(bytes, flush: true);
        onProgress?.call(1.0, '已保存至 bin 目录');
        return '已下载资源包至: ${target.path}';
      }
    } on FileSystemException catch (e) {
      return '写入核心文件失败（文件可能正在被运行中的进程占用，请先停止所有节点和信令服务）: ${e.message}';
    } catch (e) {
      return '下载或安装过程中发生异常: $e';
    } finally {
      client.close();
    }
  }

  static Future<void> _atomicWriteBinary(
    String targetPath,
    List<int> data,
  ) async {
    final tmpFile = File('$targetPath.new');
    final targetFile = File(targetPath);
    await tmpFile.writeAsBytes(data, flush: true);
    if (await targetFile.exists()) {
      await targetFile.delete();
    }
    await tmpFile.rename(targetPath);
  }
}
