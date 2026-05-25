import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../core/models/cheque_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_utils.dart' as du;
import 'status_badge.dart';

class ChequeListTile extends StatelessWidget {
  final Cheque cheque;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Function(ChequeStatus)? onStatusChange;
  final bool showSlidable;

  const ChequeListTile({
    super.key,
    required this.cheque,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onStatusChange,
    this.showSlidable = true,
  });

  @override
  Widget build(BuildContext context) {
    final tile = _buildTile(context);

    if (!showSlidable) return tile;

    return Slidable(
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: [
          if (cheque.isActive) ...[
            SlidableAction(
              onPressed: (_) =>
                  onStatusChange?.call(ChequeStatus.cleared),
              backgroundColor: AppColors.cleared,
              foregroundColor: Colors.white,
              icon: Icons.check_circle_outline,
              label: 'وصول',
              borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(12)),
            ),
            SlidableAction(
              onPressed: (_) =>
                  onStatusChange?.call(ChequeStatus.returned),
              backgroundColor: AppColors.returned,
              foregroundColor: Colors.white,
              icon: Icons.cancel_outlined,
              label: 'برگشت',
            ),
          ],
          SlidableAction(
            onPressed: (_) => onDelete?.call(),
            backgroundColor: Colors.grey,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
            label: 'حذف',
            borderRadius: cheque.isActive
                ? BorderRadius.zero
                : const BorderRadius.horizontal(right: Radius.circular(12)),
          ),
        ],
      ),
      child: tile,
    );
  }

  Widget _buildTile(BuildContext context) {
    final isIssued = cheque.direction == ChequeDirection.issued;
    final amountColor =
        isIssued ? AppColors.issued : AppColors.received;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  DirectionBadge(direction: cheque.direction),
                  const Spacer(),
                  StatusBadge(status: cheque.status, small: true),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cheque.counterpartyName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          cheque.bankName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        CurrencyFormatter.format(cheque.amount),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: amountColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        du.DateUtils.toPersian(cheque.dueDate),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (cheque.isActive) ...[
                const SizedBox(height: 8),
                DueDateBadge(
                  state: cheque.dueDateState,
                  daysUntilDue: cheque.daysUntilDue,
                ),
              ],
              if (cheque.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: cheque.tags
                      .map((tag) => _TagChip(tag: tag))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String tag;

  const _TagChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        tag,
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
