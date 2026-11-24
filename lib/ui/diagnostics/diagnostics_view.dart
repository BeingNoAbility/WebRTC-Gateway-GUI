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
  NatType _natType = NatType.fullCone;
  bool _detectingNat = false;

  List<StunLatencyResult> _stunResults = [];
  bool _pingingStun = false;

  @override
  void initState() {
    super.initState();
    _loadInitialStunList();
  }

  void _loadInitialStunList() {
    _stunResults = DiagnosticService.defaultStunServers.map((s) {
      return StunLatencyResult(server: s, latencyMs: 0, available: true);
    }).toList();
  }

  void _runNatDetection(DiagnosticService service) async {
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

  void _runStunPing(DiagnosticService service) async {
    setState(() => _pingingStun = true);

    final results = await service.rankStunServers();

    if (mounted) {
      setState(() {
        _stunResults = results;
        _pingingStun = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final i18n = AppI18n();
    final diag = state.diagnosticService;

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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: _detectingNat ? null : () => _runNatDetection(diag),
                        icon: _detectingNat
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
                      color: _natType.isDirectP2PRecommended
                          ? Colors.green.withValues(alpha: 0.08)
                          : Colors.orange.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _natType.isDirectP2PRecommended
                            ? Colors.green.withValues(alpha: 0.3)
                            : Colors.orange.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _natType.isDirectP2PRecommended ? Icons.check_circle_rounded : Icons.info_rounded,
                          color: _natType.isDirectP2PRecommended ? Colors.green : Colors.orange,
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                i18n.currentLocale == 'zh' ? _natType.displayNameZh : _natType.displayNameEn,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _natType.isDirectP2PRecommended
                                    ? '当前宽带网络环境极佳，支持 100% 纯点对点直连（零中继流量消耗，最高带宽）。'
                                    : '当前网络为对称型 NAT，跨运营商打洞可能受阻，建议在配置中填写 TURN 中继服务器以保底连通。',
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.network_ping_rounded, color: Colors.teal),
                      const SizedBox(width: 8),
                      Text(
                        i18n.t('diag_stun_title'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: _pingingStun ? null : () => _runStunPing(diag),
                        icon: _pingingStun
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.speed_rounded, size: 18),
                        label: Text(i18n.t('diag_stun_btn')),
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
                                color: i < 3 ? Colors.blueAccent.withValues(alpha: 0.15) : Colors.black12,
                              ),
                              child: Center(
                                child: Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: i < 3 ? Colors.blueAccent : Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                item.server,
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ),
                            Text(
                              item.available
                                  ? (item.latencyMs == 0 ? '待测速' : '${item.latencyMs} ms')
                                  : '连接超时',
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
          const SizedBox(height: 24),

          // 3. Local Signal Server Manager Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.dns_rounded, color: Colors.purpleAccent),
                      const SizedBox(width: 8),
                      Text(
                        i18n.t('signal_server_title'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.launch_rounded, size: 16),
                        label: const Text('信令独立工作台 (Signal Station)'),
                        onPressed: () => state.setTabIndex(2),
                      ),
                      const SizedBox(width: 12),
                      Switch(
                        value: state.isSignalRunning(),
                        activeThumbColor: Colors.purpleAccent,
                        onChanged: (val) {
                          if (val) {
                            state.startSignalServer();
                          } else {
                            state.stopSignalServer();
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    i18n.t('signal_server_desc'),
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: state.isSignalRunning() ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          state.isSignalRunning() ? '运行中 (Running on ${state.signalConfig.addr})' : '已停止',
                          style: TextStyle(
                            color: state.isSignalRunning() ? Colors.green : Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Chip(label: Text('自签 ECDSA 证书开启 (-tls-auto)', style: TextStyle(fontSize: 11))),
                      const SizedBox(width: 8),
                      const Chip(label: Text('内置 Web 门户控制台', style: TextStyle(fontSize: 11))),
                    ],
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
