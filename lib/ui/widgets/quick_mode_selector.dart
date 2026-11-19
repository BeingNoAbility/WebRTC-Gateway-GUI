import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/agent_config.dart';

class QuickModeSelector extends StatelessWidget {
  final AgentMode selectedMode;
  final ValueChanged<AgentMode> onModeChanged;

  const QuickModeSelector({
    super.key,
    required this.selectedMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;

        if (isNarrow) {
          return Column(
            children: [
              _buildModeCard(
                context,
                AgentMode.reverseProxy,
                Icons.alt_route_rounded,
                'Web 应用反代',
                '反向代理现有本地或局域网 HTTP/WS 站点',
              ),
              const SizedBox(height: 8),
              _buildModeCard(
                context,
                AgentMode.directory,
                Icons.folder_shared_rounded,
                '本地目录托管',
                '暗黑风文件浏览与只读下载',
              ),
              const SizedBox(height: 8),
              _buildModeCard(
                context,
                AgentMode.singleFile,
                Icons.file_download_rounded,
                '单文件分发',
                '零端口监听 P2P 极速直传大文件',
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: _buildModeCard(
                context,
                AgentMode.reverseProxy,
                Icons.alt_route_rounded,
                'Web 应用反代',
                '反向代理现有本地/局域网服务',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildModeCard(
                context,
                AgentMode.directory,
                Icons.folder_shared_rounded,
                '本地目录托管',
                '暗黑风文件浏览与下载',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildModeCard(
                context,
                AgentMode.singleFile,
                Icons.file_download_rounded,
                '单文件分发',
                'P2P 极速直传大文件',
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildModeCard(
    BuildContext context,
    AgentMode mode,
    IconData icon,
    String title,
    String description,
  ) {
    final isSelected = selectedMode == mode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => onModeChanged(mode),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF0C2A3A) : const Color(0xFFE0F2FE))
              : (isDark ? AppColors.darkCard : AppColors.lightCard),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryCyan
                : (isDark
                      ? AppColors.darkCardBorder
                      : AppColors.lightCardBorder),
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? AppColors.primaryCyan
                      : (isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                      color: isSelected
                          ? (isDark ? Colors.white : const Color(0xFF0369A1))
                          : (isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: AppColors.primaryCyan,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? AppColors.darkTextMuted
                    : AppColors.lightTextMuted,
                height: 1.25,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
