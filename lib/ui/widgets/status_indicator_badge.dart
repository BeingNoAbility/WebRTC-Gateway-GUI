import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/agent_instance.dart';

class StatusIndicatorBadge extends StatefulWidget {
  final AgentStatus status;

  const StatusIndicatorBadge({super.key, required this.status});

  @override
  State<StatusIndicatorBadge> createState() => _StatusIndicatorBadgeState();
}

class _StatusIndicatorBadgeState extends State<StatusIndicatorBadge> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.25).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Color _getStatusColor() {
    switch (widget.status) {
      case AgentStatus.online:
        return AppColors.successGreen;
      case AgentStatus.starting:
        return AppColors.warningAmber;
      case AgentStatus.stopping:
        return AppColors.warningAmber;
      case AgentStatus.error:
        return AppColors.errorRed;
      case AgentStatus.stopped:
        return AppColors.darkTextMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor();
    final isPulsing = widget.status == AgentStatus.online || widget.status == AgentStatus.starting;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          isPulsing
              ? ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.6),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                )
              : Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
          const SizedBox(width: 7),
          Text(
            widget.status.label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
