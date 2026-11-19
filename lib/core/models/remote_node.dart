class RemoteNode {
  final String id;
  String title;
  String nodeId;
  String portalUrl;
  String accessSecret;
  DateTime lastConnected;
  List<String> tags;

  RemoteNode({
    required this.id,
    required this.title,
    required this.nodeId,
    required this.portalUrl,
    this.accessSecret = '',
    required this.lastConnected,
    List<String>? tags,
  }) : tags = tags ?? [];

  String get accessUrl {
    final base = portalUrl.endsWith('/') ? portalUrl.substring(0, portalUrl.length - 1) : portalUrl;
    return '$base/#$nodeId';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'node_id': nodeId,
      'portal_url': portalUrl,
      'access_secret': accessSecret,
      'last_connected': lastConnected.toIso8601String(),
      'tags': tags,
    };
  }

  factory RemoteNode.fromJson(Map<String, dynamic> json) {
    return RemoteNode(
      id: json['id'] as String,
      title: json['title'] as String? ?? '未命名节点',
      nodeId: json['node_id'] as String? ?? '',
      portalUrl: json['portal_url'] as String? ?? 'http://127.0.0.1:8888',
      accessSecret: json['access_secret'] as String? ?? '',
      lastConnected: DateTime.tryParse(json['last_connected'] as String? ?? '') ?? DateTime.now(),
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}
