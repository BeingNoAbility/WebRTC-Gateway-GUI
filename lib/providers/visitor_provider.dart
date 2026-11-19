import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/models/remote_node.dart';
import '../core/utils/hmac_signer.dart';
import '../services/storage_service.dart';

class VisitorProvider extends ChangeNotifier {
  final StorageService _storageService;
  List<RemoteNode> _nodes = [];
  String _inputNodeId = '';
  String _inputPortalUrl = 'http://127.0.0.1:8888';
  String _inputAccessSecret = '';

  VisitorProvider(this._storageService) {
    _nodes = _storageService.loadRemoteNodes();
  }

  List<RemoteNode> get nodes => List.unmodifiable(_nodes);
  String get inputNodeId => _inputNodeId;
  String get inputPortalUrl => _inputPortalUrl;
  String get inputAccessSecret => _inputAccessSecret;

  void setInputNodeId(String val) {
    _inputNodeId = val;
    notifyListeners();
  }

  void setInputPortalUrl(String val) {
    _inputPortalUrl = val;
    notifyListeners();
  }

  void setInputAccessSecret(String val) {
    _inputAccessSecret = val;
    notifyListeners();
  }

  void addNode(RemoteNode node) {
    _nodes.insert(0, node);
    _storageService.saveRemoteNodes(_nodes);
    notifyListeners();
  }

  void updateNode(RemoteNode node) {
    final idx = _nodes.indexWhere((n) => n.id == node.id);
    if (idx != -1) {
      _nodes[idx] = node;
      _storageService.saveRemoteNodes(_nodes);
      notifyListeners();
    }
  }

  void deleteNode(String id) {
    _nodes.removeWhere((n) => n.id == id);
    _storageService.saveRemoteNodes(_nodes);
    notifyListeners();
  }

  /// Parses a pasted or scanned share link and fills the inputs.
  bool parseLink(String link) {
    final parsed = HmacSigner.parseShareLink(link);
    if (parsed != null) {
      _inputPortalUrl = parsed['portalUrl'] ?? _inputPortalUrl;
      _inputNodeId = parsed['nodeId'] ?? _inputNodeId;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Launches the WebRTC-Gateway portal URL in the system browser.
  Future<bool> openNode(RemoteNode node) async {
    node.lastConnected = DateTime.now();
    _storageService.saveRemoteNodes(_nodes);
    notifyListeners();

    final urlStr = node.accessUrl;
    final uri = Uri.parse(urlStr);
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Launches direct custom URL.
  Future<bool> launchCustomUrl(String urlStr) async {
    try {
      final uri = Uri.parse(urlStr);
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
