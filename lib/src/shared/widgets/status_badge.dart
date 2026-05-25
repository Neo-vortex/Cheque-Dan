import 'package:flutter/material.dart';
import '../../core/models/cheque_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';

class StatusBadge extends StatelessWidget {
  final ChequeStatus status;
  final bool small;

  const StatusBadge({
    super.key,
    required this.status,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final (color, label) = _statusInfo(status);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 10,
        vertical: small ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: small ? 11 : 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static (Color, String) _statusInfo(ChequeStatus status) {
    switch (status) {
      case ChequeStatus.draft:
        return (AppColors.draft, AppStrings.draft);
      case ChequeStatus.active:
        return (AppColors.active, AppStrings.active);
      case ChequeStatus.pendingReview:
        return (AppColors.pending, AppStrings.pendingReview);
      case ChequeStatus.cleared:
        return (AppColors.cleared, AppStrings.cleared);
      case ChequeStatus.returned:
        return (AppColors.returned, AppStrings.returned);
      case ChequeStatus.cancelled:
        return (AppColors.cancelled, AppStrings.cancelled);
    }
  }
}

class DueDateBadge extends StatelessWidget {
  final DueDateState state;
  final int daysUntilDue;

  const DueDateBadge({
    super.key,
    required this.state,
    required this.daysUntilDue,
  });

  @override
  Widget build(BuildContext context) {
    if (state == DueDateState.cleared || state == DueDateState.future) {
      return const SizedBox.shrink();
    }

    final (color, label) = _info;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            state == DueDateState.overdue
                ? Icons.warning_amber_rounded
                : Icons.schedule_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  (Color, String) get _info {
    switch (state) {
      case DueDateState.overdue:
        return (AppColors.overdue, '${daysUntilDue.abs()} روز گذشت');
      case DueDateState.dueToday:
        return (AppColors.dueToday, 'امروز');
      case DueDateState.upcoming:
        return (AppColors.upcoming, '$daysUntilDue روز دیگر');
      default:
        return (AppColors.safe, '');
    }
  }
}

class DirectionBadge extends StatelessWidget {
  final ChequeDirection direction;

  const DirectionBadge({super.key, required this.direction});

  @override
  Widget build(BuildContext context) {
    final isIssued = direction == ChequeDirection.issued;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (isIssued ? AppColors.issued : AppColors.received)
            .withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isIssued ? Icons.arrow_upward : Icons.arrow_downward,
            size: 12,
            color: isIssued ? AppColors.issued : AppColors.received,
          ),
          const SizedBox(width: 4),
          Text(
            isIssued ? AppStrings.issued : AppStrings.received,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isIssued ? AppColors.issued : AppColors.received,
            ),
          ),
        ],
      ),
    );
  }
}
