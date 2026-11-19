class AppConstants {
  static const String appName = 'WebRTC Gateway';
  static const String appVersion = 'v2.3.2';
  static const String githubRepo = 'https://github.com/BeingNoAbility/WebRTC-Gateway';
  static const String docsUrl = 'https://beingnoability.github.io/WebRTC-Gateway/';

  // Default signaling server
  static const String defaultSignalUrl = 'ws://127.0.0.1:8888/ws';
  static const String defaultPortalUrl = 'http://127.0.0.1:8888';
  static const String defaultNodeId = 'homeserver';
  static const String defaultTarget = 'http://127.0.0.1:8080';
  static const String defaultMetricsAddr = '127.0.0.1:9091';
  static const String defaultServerMetricsAddr = '127.0.0.1:9090';

  // Popular public STUN servers
  static const List<String> defaultStunServers = [
    'stun:stun.l.google.com:19302',
    'stun:stun1.l.google.com:19302',
    'stun:stun2.l.google.com:19302',
    'stun:stun.cloudflare.com:3478',
  ];

  // Storage Keys
  static const String keyAgentConfig = 'webrtc_agent_config';
  static const String keySignalConfig = 'webrtc_signal_config';
  static const String keySavedNodes = 'webrtc_saved_nodes';
  static const String keyProfiles = 'webrtc_profiles';
  static const String keyThemeMode = 'webrtc_theme_mode';
  static const String keyCustomBinaryPath = 'webrtc_custom_binary_path';
}
