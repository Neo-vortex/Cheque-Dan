import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/time_origin_service.dart';
import '../../core/utils/date_utils.dart' as du;
import 'persian_date_picker.dart';

// ═══════════════════════════════════════════════════════════════════════════
// BANNER — shown in AppBar when time is manipulated
// ═══════════════════════════════════════════════════════════════════════════

class TimeOriginBanner extends StatelessWidget {
  const TimeOriginBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TimeOriginService>(
      builder: (context, svc, _) {
        if (!svc.isManipulated) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () => showTimeOriginSheet(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.15),
              border: Border(
                bottom: BorderSide(
                    color: AppColors.secondary.withOpacity(0.4), width: 1),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.history_toggle_off,
                    size: 16, color: AppColors.secondaryDark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'مبدا زمانی: ${du.DateUtils.toPersianFull(svc.today)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    svc.resetToToday();
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryDark,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'بازگشت به امروز',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ICON BUTTON — for AppBar
// ═══════════════════════════════════════════════════════════════════════════

class TimeOriginButton extends StatelessWidget {
  const TimeOriginButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TimeOriginService>(
      builder: (context, svc, _) {
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.manage_history_outlined),
              tooltip: 'مبدا زمانی',
              onPressed: () => showTimeOriginSheet(context),
            ),
            if (svc.isManipulated)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BOTTOM SHEET
// ═══════════════════════════════════════════════════════════════════════════

Future<void> showTimeOriginSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _TimeOriginSheet(),
  );
}

class _TimeOriginSheet extends StatelessWidget {
  const _TimeOriginSheet();

  @override
  Widget build(BuildContext context) {
    final svc = context.read<TimeOriginService>();
    final today = DateTime.now();
    final todayJ = Jalali.fromDateTime(today);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.manage_history,
                        color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('مبدا زمانی',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800)),
                        Text('تاریخ مرجع برای تمام محاسبات',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Current origin indicator
            Consumer<TimeOriginService>(
              builder: (ctx, svc, _) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.all(16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: svc.isManipulated
                      ? AppColors.secondary.withOpacity(0.1)
                      : AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: svc.isManipulated
                        ? AppColors.secondary.withOpacity(0.4)
                        : AppColors.primary.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      svc.isManipulated
                          ? Icons.history_toggle_off
                          : Icons.today,
                      color: svc.isManipulated
                          ? AppColors.secondaryDark
                          : AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            svc.isManipulated
                                ? 'مبدا دستی'
                                : 'امروز (پیش‌فرض)',
                            style: TextStyle(
                              fontSize: 11,
                              color: svc.isManipulated
                                  ? AppColors.secondaryDark
                                  : AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            du.DateUtils.toPersianFull(svc.today),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (svc.isManipulated)
                      TextButton.icon(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          svc.resetToToday();
                        },
                        icon: const Icon(Icons.refresh,
                            size: 14, color: AppColors.primary),
                        label: const Text('بازگشت',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.primary)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Quick action tiles
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('انتخاب سریع',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _QuickChip(
                        label: 'دیروز',
                        icon: Icons.chevron_right,
                        onTap: () {
                          svc.setOrigin(today.subtract(const Duration(days: 1)));
                          Navigator.pop(context);
                        },
                      ),
                      const SizedBox(width: 8),
                      _QuickChip(
                        label: 'امروز',
                        icon: Icons.today,
                        primary: true,
                        onTap: () {
                          svc.resetToToday();
                          Navigator.pop(context);
                        },
                      ),
                      const SizedBox(width: 8),
                      _QuickChip(
                        label: 'فردا',
                        icon: Icons.chevron_left,
                        onTap: () {
                          svc.setOrigin(today.add(const Duration(days: 1)));
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Week shortcuts
                  Row(
                    children: [
                      _QuickChip(
                        label: 'یک هفته قبل',
                        icon: Icons.fast_rewind,
                        onTap: () {
                          svc.setOrigin(today.subtract(const Duration(days: 7)));
                          Navigator.pop(context);
                        },
                      ),
                      const SizedBox(width: 8),
                      _QuickChip(
                        label: 'یک هفته بعد',
                        icon: Icons.fast_forward,
                        onTap: () {
                          svc.setOrigin(today.add(const Duration(days: 7)));
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Custom date picker
                  const Text('تاریخ دلخواه',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  _CustomDateRow(
                    currentOrigin: svc.today,
                    onSelected: (dt) {
                      svc.setOrigin(dt);
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  const _QuickChip({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: primary
                ? AppColors.primary
                : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: primary ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 18,
                  color: primary ? Colors.white : AppColors.textSecondary),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: primary ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomDateRow extends StatelessWidget {
  final DateTime currentOrigin;
  final Function(DateTime) onSelected;

  const _CustomDateRow({
    required this.currentOrigin,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PersianDatePickerField(
      selectedDate: currentOrigin,
      label: 'تاریخ مرجع دلخواه',
      onDateSelected: onSelected,
      firstDate: DateTime(2000),
      lastDate: DateTime(2035),
    );
  }
}
