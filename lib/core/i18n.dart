class AppI18n {
  static final AppI18n _instance = AppI18n._internal();
  factory AppI18n() => _instance;
  AppI18n._internal();

  String _currentLocale = 'zh';

  String get currentLocale => _currentLocale;

  void setLocale(String locale) {
    _currentLocale = locale;
  }

  static const Map<String, Map<String, String>> _localizedValues = {
    'zh': {
      'app_title': 'WebRTC Gateway',
      'nav_dashboard': '运行看板',
      'nav_agents': '节点管理',
      'nav_diagnostics': '网络诊断',
      'nav_logs': '实时日志',
      'nav_settings': '全局设置',

      'dashboard_title': '监控与流量总览',
      'dashboard_total_up': '总上传速率',
      'dashboard_total_down': '总下载速率',
      'dashboard_active_streams': '活跃数据流',
      'dashboard_total_nodes': '在线节点数',
      'dashboard_connection_type': '连接拓扑',
      'dashboard_rtt': '网络延迟 (RTT)',

      'agent_list_title': '穿透节点列表',
      'agent_add_btn': '添加节点',
      'agent_start_all': '全部启动',
      'agent_stop_all': '全部停止',
      'agent_mode_target': '本地反代',
      'agent_mode_dir': '静态目录',
      'agent_mode_file': '单文件直传',
      'agent_status_running': '运行中',
      'agent_status_stopped': '已停止',
      'agent_status_starting': '启动中...',
      'agent_status_error': '启动异常',

      'share_card_btn': '复制分享卡片',
      'share_link_btn': '复制访问链接',
      'share_dialog_title': '快速分享与二维码',
      'share_tip': '手机或远程访客使用现代浏览器打开即可直连访问，无需安装任何客户端。',

      'stream_inspector_title': '活跃数据流掌控仪 (HUD 2.0)',
      'stream_reset_btn': '强杀 (RST)',
      'stream_no_active': '当前无活跃传输流',

      'diag_nat_title': 'NAT 类型诊断 (RFC 3489)',
      'diag_nat_btn': '重新诊断 NAT',
      'diag_stun_title': '公共 STUN 服务器低延迟测速',
      'diag_stun_btn': '开始测速与排序',

      'signal_server_title': '内置信令服务端管理器',
      'signal_server_desc': '在局域网或私有网络下一键启动内置信令协调服务与 Web 控制台。',

      'settings_binary_title': '底层核心二进制管理',
      'settings_binary_custom': '自定义 agent 二进制文件',
      'settings_binary_browse': '浏览选择...',
      'settings_binary_detected': '已识别版本',
      'settings_config_backup': '配置全量备份与还原',
      'settings_export_btn': '导出配置 (.json)',
      'settings_import_btn': '导入配置 (.json)',
      'settings_update_check': '检查新版本更新',
      'settings_lang': '语言 (Language)',
    },
    'en': {
      'app_title': 'WebRTC Gateway',
      'nav_dashboard': 'Dashboard',
      'nav_agents': 'Agents',
      'nav_diagnostics': 'Diagnostics',
      'nav_logs': 'Logs',
      'nav_settings': 'Settings',

      'dashboard_title': 'Metrics & Overview',
      'dashboard_total_up': 'Total Upload',
      'dashboard_total_down': 'Total Download',
      'dashboard_active_streams': 'Active Streams',
      'dashboard_total_nodes': 'Online Nodes',
      'dashboard_connection_type': 'Topology',
      'dashboard_rtt': 'Latency (RTT)',

      'agent_list_title': 'Tunnel Agents',
      'agent_add_btn': 'Add Node',
      'agent_start_all': 'Start All',
      'agent_stop_all': 'Stop All',
      'agent_mode_target': 'Reverse Proxy',
      'agent_mode_dir': 'Static Directory',
      'agent_mode_file': 'Single File',
      'agent_status_running': 'Running',
      'agent_status_stopped': 'Stopped',
      'agent_status_starting': 'Starting...',
      'agent_status_error': 'Error',

      'share_card_btn': 'Copy Share Card',
      'share_link_btn': 'Copy Direct URL',
      'share_dialog_title': 'Quick Share & QR Code',
      'share_tip': 'Visitors open link in any modern browser for direct P2P access without any client installation.',

      'stream_inspector_title': 'Stream Inspector (HUD 2.0)',
      'stream_reset_btn': 'Reset (RST)',
      'stream_no_active': 'No active streams currently',

      'diag_nat_title': 'NAT Type Diagnostic (RFC 3489)',
      'diag_nat_btn': 'Detect NAT Type',
      'diag_stun_title': 'Public STUN Latency Ranking',
      'diag_stun_btn': 'Ping & Rank STUNs',

      'signal_server_title': 'Local Signaling Server',
      'signal_server_desc': 'Launch local signaling server and web portal for offline LAN or private testing.',

      'settings_binary_title': 'Core Binary Management',
      'settings_binary_custom': 'Custom agent binary path',
      'settings_binary_browse': 'Browse...',
      'settings_binary_detected': 'Detected Version',
      'settings_config_backup': 'Backup & Restore',
      'settings_export_btn': 'Export Config (.json)',
      'settings_import_btn': 'Import Config (.json)',
      'settings_update_check': 'Check for Updates',
      'settings_lang': 'Language',
    },
  };

  String t(String key) {
    return _localizedValues[_currentLocale]?[key] ??
        _localizedValues['zh']?[key] ??
        key;
  }
}
