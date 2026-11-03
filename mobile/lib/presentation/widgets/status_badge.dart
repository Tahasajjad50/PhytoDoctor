import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

enum StatusType { verified, pending, rejected, synced, offline }

class StatusBadge extends StatelessWidget {
  final String label;
  final StatusType type;

  const StatusBadge({
    Key? key,
    required this.label,
    required this.type,
  }) : super(key: key);

  factory StatusBadge.fromStatusString(String status) {
    final s = status.toUpperCase();
    if (s == 'VERIFIED') {
      return const StatusBadge(label: 'VERIFIED', type: StatusType.verified);
    } else if (s == 'PENDING') {
      return const StatusBadge(label: 'PENDING', type: StatusType.pending);
    } else if (s == 'REJECTED' || s == 'FLAGGED') {
      return const StatusBadge(label: 'REJECTED', type: StatusType.rejected);
    } else if (s == 'OFFLINE') {
      return const StatusBadge(label: 'OFFLINE', type: StatusType.offline);
    } else {
      return StatusBadge(label: status.toUpperCase(), type: StatusType.synced);
    }
  }

  @override
  Widget build(BuildContext context) {
    Color fgColor;
    Color bgColor;

    switch (type) {
      case StatusType.verified:
        fgColor = AppTheme.cropGreen;
        bgColor = AppTheme.cropGreenLight;
        break;
      case StatusType.pending:
        fgColor = AppTheme.earthAmber;
        bgColor = AppTheme.earthAmberLight;
        break;
      case StatusType.rejected:
        fgColor = AppTheme.alertCrimson;
        bgColor = AppTheme.alertCrimsonLight;
        break;
      case StatusType.synced:
        fgColor = AppTheme.botanicalPrimary;
        bgColor = AppTheme.sageLight;
        break;
      case StatusType.offline:
        fgColor = AppTheme.textMuted;
        bgColor = AppTheme.sageLight;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: fgColor.withOpacity(0.4), width: 1.0),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: fgColor,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
