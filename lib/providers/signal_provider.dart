import 'package:flutter/foundation.dart';
import '../core/models/signal_config.dart';
import '../core/models/log_entry.dart';
import '../services/signal_service.dart';
import '../services/storage_service.dart';

class SignalProvider extends ChangeNotifier {
  final SignalService _signalService;
  final StorageService _storageService;
  late SignalConfig _config;

  SignalProvider(this._signalService, this._storageService) {
    _config = _storageService.loadSignalConfig();
    _signalService.setCustomBinaryPath(_storageService.loadCustomSignalPath());
    _signalService.addListener(_onServiceChanged);
  }

  void _onServiceChanged() {
    notifyListeners();
  }

  SignalConfig get config => _config;
  SignalStatus get status => _signalService.status;
  bool get isRunning => _signalService.isRunning;
  String? get errorMessage => _signalService.errorMessage;
  int get registeredNodes => _signalService.registeredNodes;
  List<LogEntry> get logs => _signalService.logs;

  void updateConfig(SignalConfig newConfig) {
    _config = newConfig;
    _storageService.saveSignalConfig(_config);
    notifyListeners();
  }

  Future<bool> start() async {
    return await _signalService.start(_config);
  }

  Future<void> stop() async {
    await _signalService.stop();
  }

  void clearLogs() {
    _signalService.clearLogs();
  }

  @override
  void dispose() {
    _signalService.removeListener(_onServiceChanged);
    super.dispose();
  }
}
