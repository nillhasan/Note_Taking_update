import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';

class ActionItemRow extends StatelessWidget {
  final ActionItemEntity item;
  final VoidCallback onToggleCompleted;
  final VoidCallback onDelete;

  const ActionItemRow({
    super.key,
    required this.item,
    required this.onToggleCompleted,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Checkbox
          Transform.scale(
            scale: 1.1,
            child: Checkbox(
              value: item.isCompleted,
              onChanged: (_) => onToggleCompleted(),
              activeColor: AppColors.accentEmerald,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
          const SizedBox(width: 8),

          // Task details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.task,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                    color: item.isCompleted
                        ? (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)
                        : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    // Owner chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primarySky.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person, size: 12, color: AppColors.primarySky),
                          const SizedBox(width: 4),
                          Text(
                            item.owner,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primarySky,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (item.dueDate.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accentAmber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.schedule, size: 12, color: AppColors.accentAmber),
                            const SizedBox(width: 4),
                            Text(
                              item.dueDate,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accentAmber,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Delete button
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              size: 20,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
