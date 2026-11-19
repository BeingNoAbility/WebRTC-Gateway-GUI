import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/network_tester.dart';
import '../../providers/agent_provider.dart';
import '../../providers/diagnostics_provider.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  final _customStunCtrl = TextEditingController(text: 'stun:stun.l.google.com:19302');
  DiagnosticResult? _customStunResult;
  bool _isTestingCustomStun = false;

  @override
  void dispose() {
    _customStunCtrl.dispose();
    super.dispose();
  }

  Color _getLatencyColor(int ms) {
    if (ms < 80) return AppColors.successGreen;
    if (ms < 200) return AppColors.warningAmber;
    return AppColors.errorRed;
  }

  @override
  Widget build(BuildContext context) {
    final diag = context.watch<DiagnosticsProvider>();
    final agent = context.watch<AgentProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 620;

                  final headerInfo = Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryCyan.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.speed_rounded, color: AppColors.primaryCyan, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '网络与 P2P 穿透诊断工具箱 (Diagnostics Toolkit)',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '实时检测 STUN/TURN 连通性、NAT 打洞延迟与本地 Web 服务端口可用性',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );

                  final testBtn = ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryCyan,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                    icon: diag.isTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Icon(Icons.play_circle_filled_rounded, size: 18),
                    label: Text(diag.isTesting ? '正在体检...' : '开始全景体检'),
                    onPressed: diag.isTesting
                        ? null
                        : () {
                            diag.runAllDiagnostics(
                              targetUrl: agent.config.target,
                              signalUrl: agent.config.signal,
                              stunServers: agent.config.stunServers,
                            );
                          },
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        headerInfo,
                        const SizedBox(height: 12),
                        testBtn,
                      ],
                    );
                  } else {
                    return Row(
                      children: [
                        Expanded(child: headerInfo),
                        const SizedBox(width: 14),
                        testBtn,
                      ],
                    );
                  }
                },
              ),

              const SizedBox(height: 18),

              // Custom STUN server tester card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '单个 STUN/TURN 服务器 RFC 5389 连通测试',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 500;
                          final field = TextField(
                            controller: _customStunCtrl,
                            decoration: const InputDecoration(
                              labelText: 'STUN 服务器地址',
                              hintText: '如: stun:stun.l.google.com:19302',
                              prefixIcon: Icon(Icons.podcasts_rounded, size: 18),
                            ),
                          );
                          final btn = ElevatedButton.icon(
                            icon: _isTestingCustomStun
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.network_check_rounded, size: 18),
                            label: const Text('单点测速'),
                            onPressed: _isTestingCustomStun
                                ? null
                                : () async {
                                    setState(() => _isTestingCustomStun = true);
                                    final res = await NetworkTester.testStun(_customStunCtrl.text.trim());
                                    setState(() {
                                      _customStunResult = res;
                                      _isTestingCustomStun = false;
                                    });
                                  },
                          );

                          if (isNarrow) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                field,
                                const SizedBox(height: 10),
                                btn,
                              ],
                            );
                          } else {
                            return Row(
                              children: [
                                Expanded(child: field),
                                const SizedBox(width: 10),
                                btn,
                              ],
                            );
                          }
                        },
                      ),
                      if (_customStunResult != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _customStunResult!.success
                                ? AppColors.successGreen.withValues(alpha: 0.1)
                                : AppColors.errorRed.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _customStunResult!.success
                                  ? AppColors.successGreen.withValues(alpha: 0.3)
                                  : AppColors.errorRed.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _customStunResult!.success ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                color: _customStunResult!.success ? AppColors.successGreen : AppColors.errorRed,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${_customStunResult!.title} · ${_customStunResult!.details}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _customStunResult!.success ? AppColors.successGreen : AppColors.errorRed,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Test Results List
              Text(
                '体检诊断结果 (${diag.results.length})',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 10),

              if (diag.results.isEmpty && !diag.isTesting)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.network_ping_rounded, size: 40, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                          const SizedBox(height: 10),
                          const Text('尚未执行体检，点击右上角“开始全景体检”以测试网络'),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: diag.results.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final item = diag.results[idx];
                    final latencyColor = _getLatencyColor(item.latencyMs);

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: item.success ? AppColors.successGreen.withValues(alpha: 0.12) : AppColors.errorRed.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                item.success ? Icons.check_rounded : Icons.close_rounded,
                                color: item.success ? AppColors.successGreen : AppColors.errorRed,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.details,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (item.success)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: latencyColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: latencyColor.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  '${item.latencyMs} ms',
                                  style: TextStyle(
                                    color: latencyColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
