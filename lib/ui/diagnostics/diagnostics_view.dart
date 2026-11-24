import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../../core/i18n.dart';
import '../../services/diagnostic_service.dart';
import '../../state/app_state.dart';

class DiagnosticsView extends StatefulWidget {
  const DiagnosticsView({super.key});

  @override
  State<DiagnosticsView> createState() => _DiagnosticsViewState();
}

class _DiagnosticsViewState extends State<DiagnosticsView> {
  NatType _natType = NatType.unknown;
  bool _detectingNat = false;

  List<StunLatencyResult> _stunResults = [];
  bool _pingingStun = false;
  bool _hasPingedStun = false;

  @override
  void initState() {
    super.initState();
    _loadInitialStunList();
  }

  void _loadInitialStunList() {
    _stunResults = DiagnosticService.defaultStunServers
        .map((s) => StunLatencyResult(server: s, latencyMs: 0, available: true))
        .toList();
  }

  Future<void> _runNatDetection(DiagnosticService service) async {
    setState(() {
      _detectingNat = true;
      _natType = NatType.detecting;
    });

    final res = await service.detectNatType();

    if (mounted) {
      setState(() {
        _natType = res;
        _detectingNat = false;
      });
    }
  }

  Future<void> _runStunPing(DiagnosticService service) async {
    setState(() => _pingingStun = true);

    final results = await service.rankStunServers();

    if (mounted) {
      setState(() {
        _stunResults = results;
        _pingingStun = false;
        _hasPingedStun = true;
      });
    }
  }

  void _applyBestStunToAll(AppState state, AppI18n i18n) {
    final available = _stunResults
        .where((r) => r.available && r.latencyMs >= 0)
        .take(3)
        .map((r) => r.server.startsWith('stun:') ? r.server : 'stun:${r.server}')
        .toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            i18n.pick('当前没有可用的 STUN 服务器，请先完成测速', 'No reachable STUN servers found. Run ping first.'),
          ),
        ),
      );
      return;
    }

    state.applyBestStunServers(available);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          i18n.pick(
            '已将最优 STUN (${available.join(", ")}) 应用到全部 ${state.profiles.length} 个穿透节点',
            'Applied fastest STUN servers (${available.join(", ")}) to all ${state.profiles.length} agents.',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final i18n = AppI18n();
    final diag = state.diagnosticService;
    final colorScheme = Theme.of(context).colorScheme;
    final muted = colorScheme.onSurfaceVariant;

    final Color bannerColor;
    final IconData bannerIcon;
    final String bannerHint;

    if (_natType == NatType.unknown || _natType == NatType.detecting) {
      bannerColor = Colors.blueGrey;
      bannerIcon = Icons.help_outline_rounded;
      bannerHint = i18n.pick(
        '点击右上角按钮即可探测本地 UDP 与 NAT 类型，提前预判 P2P 直连成功率与是否需要配置 TURN 中继。',
        'Click the button on the top-right to probe local UDP & NAT type and see whether TURN relay is needed.',
      );
    } else if (_natType.isDirectP2PRecommended) {
      bannerColor = Colors.green;
      bannerIcon = Icons.check_circle_rounded;
      bannerHint = i18n.pick(
        '当前宽带网络环境良好，支持纯点对点直连（零中继流量消耗，最高带宽）。',
        'Your network supports direct P2P hole-punching with zero relay cost.',
      );
    } else {
      bannerColor = Colors.orange;
      bannerIcon = Icons.info_rounded;
      bannerHint = i18n.pick(
        '当前网络为对称型 NAT 或 UDP 受阻，跨网络打洞可能失败，建议在节点设置中填入 TURN 中继服务器保底连通。',
        'Symmetric NAT or UDP block detected. Configure a TURN relay server in agent settings for reliable fallback.',
      );
    }

    final hasReachablePing =
        _hasPingedStun && _stunResults.any((r) => r.available && r.latencyMs >= 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            i18n.t('nav_diagnostics'),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // 1. NAT Type Diagnostic Card
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.security_rounded, color: Colors.blueAccent),
                      const SizedBox(width: 8),
                      Text(
                        i18n.t('diag_nat_title'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: _detectingNat
                            ? null
                            : () => unawaited(_runNatDetection(diag)),
                        icon: _detectingNat
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(i18n.t('diag_nat_btn')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: bannerColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: bannerColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(bannerIcon, color: bannerColor, size: 32),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                i18n.isEnglish
                                    ? _natType.displayNameEn
                                    : _natType.displayNameZh,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                bannerHint,
                                style: TextStyle(color: muted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 2. Public STUN Server Latency Ranking
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.network_ping_rounded,
                            color: Colors.teal,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            i18n.t('diag_stun_title'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasReachablePing && state.profiles.isNotEmpty) ...[
                            OutlinedButton.icon(
                              onPressed: () => _applyBestStunToAll(state, i18n),
                              icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                              label: Text(i18n.t('diag_apply_stun_btn')),
                            ),
                            const SizedBox(width: 8),
                          ],
                          FilledButton.icon(
                            onPressed: _pingingStun
                                ? null
                                : () => unawaited(_runStunPing(diag)),
                            icon: _pingingStun
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.speed_rounded, size: 18),
                            label: Text(i18n.t('diag_stun_btn')),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _stunResults.length,
                    separatorBuilder: (ctx, i) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final item = _stunResults[i];
                      Color latencyColor = Colors.green;
                      if (!item.available) {
                        latencyColor = Colors.red;
                      } else if (!_hasPingedStun) {
                        latencyColor = muted;
                      } else if (item.latencyMs > 150) {
                        latencyColor = Colors.orange;
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10.0),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i < 3
                                    ? Colors.blueAccent.withValues(alpha: 0.15)
                                    : colorScheme.surfaceContainerHighest,
                              ),
                              child: Center(
                                child: Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: i < 3 ? Colors.blueAccent : muted,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                item.server,
                                style: const TextStyle(
                                  fontFamily: 'Consolas',
                                  fontFamilyFallback: [
                                    'Courier New',
                                    'monospace',
                                  ],
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Text(
                              item.available
                                  ? (!_hasPingedStun
                                      ? i18n.pick('待测速', 'Pending')
                                      : '${item.latencyMs} ms')
                                  : i18n.pick('连接超时', 'Timeout'),
                              style: TextStyle(
                                color: latencyColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
