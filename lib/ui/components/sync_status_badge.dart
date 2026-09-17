import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';

class SyncStatusBadge extends StatelessWidget {
  final SyncState syncState;
  final VoidCallback onClick;

  const SyncStatusBadge({
    super.key,
    required this.syncState,
    required this.onClick,
  });

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    Color textColor;
    IconData iconData;
    String label;

    switch (syncState) {
      case SyncState.SYNCED:
        badgeColor = AppColors.accentEmerald;
        textColor = AppColors.accentEmerald;
        iconData = Icons.cloud_done;
        label = "Cloud Synced";
        break;
      case SyncState.SYNCING:
        badgeColor = AppColors.primarySky;
        textColor = AppColors.primarySky;
        iconData = Icons.sync;
        label = "Syncing...";
        break;
      case SyncState.OFFLINE:
        badgeColor = AppColors.accentAmber;
        textColor = AppColors.accentAmber;
        iconData = Icons.cloud_off;
        label = "Local Storage";
        break;
    }

    return InkWell(
      onTap: onClick,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: badgeColor.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (syncState == SyncState.SYNCING)
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
                ),
              )
            else
              Icon(iconData, size: 14, color: badgeColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
