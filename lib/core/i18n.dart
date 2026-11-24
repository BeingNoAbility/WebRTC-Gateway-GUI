class AppI18n {
  static final AppI18n _instance = AppI18n._internal();
  factory AppI18n() => _instance;
  AppI18n._internal();

  String _currentLocale = 'zh';
  String get currentLocale => _currentLocale;
  bool get isEnglish => _currentLocale == 'en';

  void setLocale(String locale) {
    _currentLocale = (locale == 'en') ? 'en' : 'zh';
  }

  static const Map<String, Map<String, String>> _localizedValues = {
    'zh': {
      'app_title': 'WebRTC Gateway',
      'nav_dashboard': '运行看板',
      'nav_agents': '穿透节点',
      'nav_signal': '信令服务',
      'nav_diagnostics': '网络诊断',
      'nav_logs': '实时日志',
      'nav_settings': '全局设置',

      'common_cancel': '取消',
      'common_close': '关闭',
      'common_save': '保存配置',
      'common_delete': '删除',
      'common_browse': '浏览...',
      'common_select': '选择...',
      'common_copy': '复制',
      'common_clear': '清空',

      'dashboard_title': '监控与流量总览',
      'dashboard_total_up': '总上传速率',
      'dashboard_total_down': '总下载速率',
      'dashboard_active_streams': '活跃数据流',
      'dashboard_total_nodes': '在线节点数',
      'dashboard_status_active': '服务活跃运行中',
      'dashboard_status_idle': '系统空闲待机中',
      'dashboard_agent_section': '穿透节点运行看板',
      'dashboard_manage_nodes': '管理节点',
      'dashboard_throughput_title': '实时聚合吞吐速率',
      'dashboard_up_legend': '上传 (Up)',
      'dashboard_down_legend': '下载 (Down)',
      'dashboard_signal_section': '信令与控制台看板',
      'dashboard_signal_workspace': '信令工作台',

      'agent_list_title': '穿透节点列表',
      'agent_add_btn': '添加节点',
      'agent_start_all': '全部启动',
      'agent_stop_all': '全部停止',
      'agent_import_yaml': '导入配置',
      'agent_mode_target': '本地反代',
      'agent_mode_dir': '静态目录',
      'agent_mode_file': '单文件直传',
      'agent_status_running': '运行中',
      'agent_status_stopped': '已停止',
      'agent_status_starting': '启动中...',
      'agent_status_stopping': '停止中...',
      'agent_status_error': '启动异常',
      'agent_public_badge': '公开免密',
      'agent_protected_badge': '密码保护',
      'agent_autostart_badge': '自启动',

      'share_card_btn': '复制分享卡片',
      'share_link_btn': '复制访问链接',
      'share_dialog_title': '快速分享与二维码',
      'share_tip': '手机或远程访客使用现代浏览器打开即可直连访问，无需安装任何客户端。',

      'stream_inspector_title': '节点会话与多路复用监控',
      'stream_reset_btn': '重启节点',
      'stream_no_active': '当前无运行中的穿透节点',

      'diag_nat_title': 'NAT 类型诊断 (RFC 3489 / 5780)',
      'diag_nat_btn': '开始 / 重新诊断',
      'diag_stun_title': '公共 STUN 服务器低延迟测速',
      'diag_stun_btn': '开始测速与排序',
      'diag_apply_stun_btn': '应用最优 STUN 到全部节点',

      'signal_server_title': '信令与 Web 门户服务',
      'signal_server_desc': 'WebRTC 拓扑撮合、DTLS/ICE 候选协商及免客户端 Web Portal。',
      'signal_start_btn': '启动信令服务',
      'signal_stop_btn': '停止信令服务',
      'signal_health_btn': '健康检查',
      'signal_open_portal': '打开 Web 门户',

      'logs_all_nodes': '全部节点日志 (All)',
      'logs_signal_node': '本地信令服务 (Signal)',
      'logs_filter_hint': '过滤关键字...',
      'logs_pause_scroll': '暂停滚动',
      'logs_resume_scroll': '恢复滚动',
      'logs_empty': '暂无日志输出，启动节点后将在此处实时打印 stdout / stderr',

      'settings_binary_title': '底层核心二进制管理',
      'settings_binary_custom': '自定义 agent 二进制文件',
      'settings_binary_browse': '浏览选择...',
      'settings_binary_detected': '已识别版本',
      'settings_config_backup': '配置全量备份与还原',
      'settings_export_btn': '导出配置 (.json)',
      'settings_import_btn': '导入配置 (.json)',
      'settings_update_check': '检查新版本更新',
      'settings_lang': '语言 (Language)',
      'settings_theme_label': '界面外观主题 (Theme)',
      'settings_theme_system': '跟随系统 (System)',
      'settings_theme_light': '浅色模式 (Light)',
      'settings_theme_dark': '深色模式 (Dark)',
    },
    'en': {
      'app_title': 'WebRTC Gateway',
      'nav_dashboard': 'Dashboard',
      'nav_agents': 'Agents',
      'nav_signal': 'Signal Server',
      'nav_diagnostics': 'Diagnostics',
      'nav_logs': 'Logs',
      'nav_settings': 'Settings',

      'common_cancel': 'Cancel',
      'common_close': 'Close',
      'common_save': 'Save',
      'common_delete': 'Delete',
      'common_browse': 'Browse...',
      'common_select': 'Select...',
      'common_copy': 'Copy',
      'common_clear': 'Clear',

      'dashboard_title': 'Metrics & Overview',
      'dashboard_total_up': 'Total Upload',
      'dashboard_total_down': 'Total Download',
      'dashboard_active_streams': 'Active Streams',
      'dashboard_total_nodes': 'Online Nodes',
      'dashboard_status_active': 'Services Active',
      'dashboard_status_idle': 'System Idle',
      'dashboard_agent_section': 'Tunnel Agents Overview',
      'dashboard_manage_nodes': 'Manage Agents',
      'dashboard_throughput_title': 'Real-time Aggregate Throughput',
      'dashboard_up_legend': 'Upload',
      'dashboard_down_legend': 'Download',
      'dashboard_signal_section': 'Signaling Server Overview',
      'dashboard_signal_workspace': 'Signal Workspace',

      'agent_list_title': 'Tunnel Agents',
      'agent_add_btn': 'Add Node',
      'agent_start_all': 'Start All',
      'agent_stop_all': 'Stop All',
      'agent_import_yaml': 'Import Config',
      'agent_mode_target': 'Reverse Proxy',
      'agent_mode_dir': 'Static Directory',
      'agent_mode_file': 'Single File',
      'agent_status_running': 'Running',
      'agent_status_stopped': 'Stopped',
      'agent_status_starting': 'Starting...',
      'agent_status_stopping': 'Stopping...',
      'agent_status_error': 'Error',
      'agent_public_badge': 'Public (No Password)',
      'agent_protected_badge': 'Password Protected',
      'agent_autostart_badge': 'Auto-Start',

      'share_card_btn': 'Copy Share Card',
      'share_link_btn': 'Copy Link',
      'share_dialog_title': 'Quick Share & QR Code',
      'share_tip': 'Visitors open the link in any modern browser for direct P2P access without installing a client.',

      'stream_inspector_title': 'Node Session & Mux Monitor',
      'stream_reset_btn': 'Restart Node',
      'stream_no_active': 'No active tunnel nodes running',

      'diag_nat_title': 'NAT Type Diagnostic (RFC 3489 / 5780)',
      'diag_nat_btn': 'Detect NAT Type',
      'diag_stun_title': 'Public STUN Latency Ranking',
      'diag_stun_btn': 'Ping & Rank STUNs',
      'diag_apply_stun_btn': 'Apply Best STUNs to All Agents',

      'signal_server_title': 'Local Signaling Server',
      'signal_server_desc': 'WebRTC signaling broker, ICE/DTLS coordination & zero-client Web Portal.',
      'signal_start_btn': 'Start Signal Server',
      'signal_stop_btn': 'Stop Signal Server',
      'signal_health_btn': 'Health Check',
      'signal_open_portal': 'Open Web Portal',

      'logs_all_nodes': 'All Nodes (All)',
      'logs_signal_node': 'Local Signal Server',
      'logs_filter_hint': 'Filter keyword...',
      'logs_pause_scroll': 'Pause Auto-Scroll',
      'logs_resume_scroll': 'Resume Auto-Scroll',
      'logs_empty': 'No logs yet. Start an agent or signal server to inspect live stdout/stderr.',

      'settings_binary_title': 'Core Binary Management',
      'settings_binary_custom': 'Custom agent binary path',
      'settings_binary_browse': 'Browse...',
      'settings_binary_detected': 'Detected Version',
      'settings_config_backup': 'Backup & Restore',
      'settings_export_btn': 'Export Config (.json)',
      'settings_import_btn': 'Import Config (.json)',
      'settings_update_check': 'Check for Updates',
      'settings_lang': 'Language',
      'settings_theme_label': 'Appearance Theme',
      'settings_theme_system': 'Follow System',
      'settings_theme_light': 'Light Mode',
      'settings_theme_dark': 'Dark Mode',
    },
  };

  String t(String key, [Map<String, String>? params]) {
    var val = _localizedValues[_currentLocale]?[key] ??
        _localizedValues['zh']?[key] ??
        key;
    if (params != null) {
      params.forEach((k, v) {
        val = val.replaceAll('{$k}', v);
      });
    }
    return val;
  }

  /// Convenience inline bilingual helper for prose/tooltips.
  String pick(String zh, String en) => _currentLocale == 'en' ? en : zh;
}
