import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/signal_provider.dart';
import '../widgets/metric_card.dart';

class ServerScreen extends StatefulWidget {
  final VoidCallback onNavigateToLogs;

  const ServerScreen({super.key, required this.onNavigateToLogs});

  @override
  State<ServerScreen> createState() => _ServerScreenState();
}

class _ServerScreenState extends State<ServerScreen> {
  late TextEditingController _addrCtrl;
  late TextEditingController _signalSecretCtrl;
  late TextEditingController _allowedOriginsCtrl;
  late TextEditingController _metricsAddrCtrl;
  bool _allowAllOrigins = false;
  bool _tlsAuto = false;

  @override
  void initState() {
    super.initState();
    final config = context.read<SignalProvider>().config;
    _addrCtrl = TextEditingController(text: config.addr);
    _signalSecretCtrl = TextEditingController(text: config.signalSecret);
    _allowedOriginsCtrl = TextEditingController(text: config.allowedOrigins);
    _metricsAddrCtrl = TextEditingController(text: config.metricsAddr);
    _allowAllOrigins = config.allowAllOrigins;
    _tlsAuto = config.tlsAuto;
  }

  @override
  void dispose() {
    _addrCtrl.dispose();
    _signalSecretCtrl.dispose();
    _allowedOriginsCtrl.dispose();
    _metricsAddrCtrl.dispose();
    super.dispose();
  }

  void _saveCurrentFields(SignalProvider provider) {
    provider.updateConfig(
      provider.config.copyWith(
        addr: _addrCtrl.text.trim(),
        signalSecret: _signalSecretCtrl.text.trim(),
        allowedOrigins: _allowedOriginsCtrl.text.trim(),
        allowAllOrigins: _allowAllOrigins,
        tlsAuto: _tlsAuto,
        metricsAddr: _metricsAddrCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SignalProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRunning = provider.isRunning;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                        : [const Color(0xFFF1F5F9), Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkCardBorder
                        : AppColors.lightCardBorder,
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 620;

                    final infoWidget = Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isRunning
                                ? AppColors.successGreen.withValues(alpha: 0.15)
                                : AppColors.accentIndigo.withValues(
                                    alpha: 0.12,
                                  ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isRunning
                                ? Icons.cell_tower_rounded
                                : Icons.portable_wifi_off_rounded,
                            color: isRunning
                                ? AppColors.successGreen
                                : AppColors.accentIndigo,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  const Text(
                                    '信令中继服务端 (Signaling Server Host)',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isRunning
                                          ? AppColors.successGreen.withValues(
                                              alpha: 0.12,
                                            )
                                          : AppColors.darkTextMuted.withValues(
                                              alpha: 0.12,
                                            ),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isRunning
                                            ? AppColors.successGreen.withValues(
                                                alpha: 0.3,
                                              )
                                            : AppColors.darkTextMuted
                                                  .withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Text(
                                      provider.status.label,
                                      style: TextStyle(
                                        color: isRunning
                                            ? AppColors.successGreen
                                            : AppColors.darkTextMuted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '协调所有 Agent 与访客的 WebRTC SDP/ICE 撮合，内置 Service Worker Web 控制台',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppColors.darkTextMuted
                                      : AppColors.lightTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );

                    final actionButton = ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isRunning
                            ? AppColors.errorRed
                            : AppColors.accentIndigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                      icon: Icon(
                        isRunning
                            ? Icons.stop_rounded
                            : Icons.play_arrow_rounded,
                        size: 20,
                      ),
                      label: Text(isRunning ? '停止服务端' : '启动信令服务'),
                      onPressed: () async {
                        if (isRunning) {
                          await provider.stop();
                        } else {
                          _saveCurrentFields(provider);
                          await provider.start();
                        }
                      },
                    );

                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          infoWidget,
                          const SizedBox(height: 14),
                          actionButton,
                        ],
                      );
                    } else {
                      return Row(
                        children: [
                          Expanded(child: infoWidget),
                          const SizedBox(width: 14),
                          actionButton,
                        ],
                      );
                    }
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Metrics Row
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrowMetrics = constraints.maxWidth < 500;
                  final card1 = MetricCard(
                    icon: Icons.dns_rounded,
                    title: '注册 Agent 节点数',
                    value: '${provider.registeredNodes} 个',
                    subtitle: isRunning ? '集群在线客户端' : '未启动',
                    accentColor: AppColors.accentIndigo,
                  );
                  final card2 = MetricCard(
                    icon: Icons.web_rounded,
                    title: '内置 Web 门户',
                    value: provider.config.addr,
                    subtitle: '浏览器可直接访问控制台',
                    accentColor: AppColors.primaryCyan,
                  );

                  if (isNarrowMetrics) {
                    return Column(
                      children: [card1, const SizedBox(height: 10), card2],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: card1),
                      const SizedBox(width: 12),
                      Expanded(child: card2),
                    ],
                  );
                },
              ),

              const SizedBox(height: 18),

              // Configuration Form
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: LayoutBuilder(
                    builder: (context, formConstraints) {
                      final isNarrowForm = formConstraints.maxWidth < 560;

                      final addrField = TextFormField(
                        controller: _addrCtrl,
                        decoration: const InputDecoration(
                          labelText: '服务监听地址 (-addr)',
                          hintText: '如: :8888 或 0.0.0.0:8888',
                          prefixIcon: Icon(Icons.hearing_rounded, size: 18),
                        ),
                        onChanged: (_) => _saveCurrentFields(provider),
                      );

                      final secretField = TextFormField(
                        controller: _signalSecretCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: '集群入网令牌 (-signal-secret)',
                          hintText: '防伪造节点接入，需与 Agent 保持一致',
                          prefixIcon: Icon(Icons.security_rounded, size: 18),
                        ),
                        onChanged: (_) => _saveCurrentFields(provider),
                      );

                      final originsField = TextFormField(
                        controller: _allowedOriginsCtrl,
                        enabled: !_allowAllOrigins,
                        decoration: const InputDecoration(
                          labelText: '跨域来源白名单 (-allowed-origins)',
                          hintText: '如: https://*.pages.dev,http://localhost:*',
                          prefixIcon: Icon(Icons.shield_rounded, size: 18),
                        ),
                        onChanged: (_) => _saveCurrentFields(provider),
                      );

                      final metricsField = TextFormField(
                        controller: _metricsAddrCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Prometheus 监控端口 (-metrics-addr)',
                          hintText: '如: :9090',
                          prefixIcon: Icon(Icons.analytics_rounded, size: 18),
                        ),
                        onChanged: (_) => _saveCurrentFields(provider),
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '信令监听与安全防御策略',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 14),

                          if (isNarrowForm) ...[
                            addrField,
                            const SizedBox(height: 12),
                            secretField,
                            const SizedBox(height: 12),
                            originsField,
                            const SizedBox(height: 12),
                            metricsField,
                          ] else ...[
                            Row(
                              children: [
                                Expanded(child: addrField),
                                const SizedBox(width: 12),
                                Expanded(child: secretField),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(child: originsField),
                                const SizedBox(width: 12),
                                Expanded(child: metricsField),
                              ],
                            ),
                          ],
                          const SizedBox(height: 12),

                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              '允许所有跨域请求 (-allow-all-origins)',
                              style: TextStyle(fontSize: 13),
                            ),
                            subtitle: const Text(
                              '适用于多域名 CDN 或调试环境',
                              style: TextStyle(fontSize: 11),
                            ),
                            value: _allowAllOrigins,
                            activeTrackColor: AppColors.primaryCyan,
                            onChanged: (val) {
                              setState(() {
                                _allowAllOrigins = val;
                                _saveCurrentFields(provider);
                              });
                            },
                          ),

                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              '自动生成内存自签名 HTTPS 证书 (-tls-auto)',
                              style: TextStyle(fontSize: 13),
                            ),
                            subtitle: const Text(
                              '为局域网环境激活 Service Worker Secure Context 安全上下文',
                              style: TextStyle(fontSize: 11),
                            ),
                            value: _tlsAuto,
                            activeTrackColor: AppColors.primaryCyan,
                            onChanged: (val) {
                              setState(() {
                                _tlsAuto = val;
                                _saveCurrentFields(provider);
                              });
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Portal launcher button if running
              if (isRunning) ...[
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(
                          Icons.open_in_browser_rounded,
                          size: 18,
                        ),
                        label: Text(
                          '打开本地 Web 门户 (http://127.0.0.1${provider.config.addr.startsWith(':') ? provider.config.addr : ':${provider.config.addr}'})',
                        ),
                        onPressed: () {
                          final portStr = provider.config.addr.startsWith(':')
                              ? provider.config.addr
                              : ':${provider.config.addr}';
                          launchUrl(
                            Uri.parse('http://127.0.0.1$portStr'),
                            mode: LaunchMode.externalApplication,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
