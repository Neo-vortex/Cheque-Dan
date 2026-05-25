import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/models/cheque_model.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_utils.dart' as du;
import '../../../../shared/widgets/status_badge.dart';
import '../blocs/cheque_bloc.dart';
import 'cheque_detail_screen.dart';

class ReconciliationScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const ReconciliationScreen({super.key, required this.onComplete});

  @override
  State<ReconciliationScreen> createState() =>
      _ReconciliationScreenState();
}

class _ReconciliationScreenState extends State<ReconciliationScreen> {
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChequeBloc, ChequeState>(
      listener: (context, state) {
        if (state is ChequeOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      builder: (context, state) {
        List<Cheque> all = [];
        if (state is ChequesLoaded) all = state.cheques;
        if (state is ChequeOperationSuccess) all = state.cheques;

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        final overdue = all
            .where((c) =>
                c.isActive && c.dueDateState == DueDateState.overdue)
            .toList();

        final dueToday = all
            .where((c) =>
                c.isActive && c.dueDateState == DueDateState.dueToday)
            .toList();

        final upcoming = all
            .where((c) =>
                c.isActive && c.dueDateState == DueDateState.upcoming)
            .toList();

        final allNeedAttention = [...overdue, ...dueToday, ...upcoming];

        if (allNeedAttention.isEmpty) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => widget.onComplete());
          return const SizedBox.shrink();
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(context, allNeedAttention),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (overdue.isNotEmpty) ...[
                        _SectionTitle(
                          title: AppStrings.overdueSection,
                          color: AppColors.overdue,
                          count: overdue.length,
                        ),
                        const SizedBox(height: 8),
                        ...overdue.map((c) => _ReconciliationTile(
                              cheque: c,
                              onStatusChange: (status) =>
                                  _updateStatus(context, c, status),
                              onTap: () => _openDetail(context, c),
                            )),
                        const SizedBox(height: 8),
                        _BulkActions(
                          cheques: overdue,
                          onBulkClear: () =>
                              _bulkUpdate(context, overdue, ChequeStatus.cleared),
                          onBulkPending: () => _bulkUpdate(
                              context, overdue, ChequeStatus.pendingReview),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (dueToday.isNotEmpty) ...[
                        _SectionTitle(
                          title: AppStrings.dueTodaySection,
                          color: AppColors.dueToday,
                          count: dueToday.length,
                        ),
                        const SizedBox(height: 8),
                        ...dueToday.map((c) => _ReconciliationTile(
                              cheque: c,
                              onStatusChange: (status) =>
                                  _updateStatus(context, c, status),
                              onTap: () => _openDetail(context, c),
                            )),
                        const SizedBox(height: 8),
                        _BulkActions(
                          cheques: dueToday,
                          onBulkClear: () => _bulkUpdate(
                              context, dueToday, ChequeStatus.cleared),
                          onBulkPending: () => _bulkUpdate(
                              context, dueToday, ChequeStatus.pendingReview),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (upcoming.isNotEmpty) ...[
                        _SectionTitle(
                          title: AppStrings.upcomingSection,
                          color: AppColors.upcoming,
                          count: upcoming.length,
                        ),
                        const SizedBox(height: 8),
                        ...upcoming.map((c) => _ReconciliationTile(
                              cheque: c,
                              onStatusChange: (status) =>
                                  _updateStatus(context, c, status),
                              onTap: () => _openDetail(context, c),
                            )),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
                _buildFooter(context, allNeedAttention),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, List<Cheque> cheques) {
    final totalAmount =
        cheques.fold(0.0, (s, c) => s + c.amount);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius:
            BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_active,
                  color: Colors.white, size: 28),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  AppStrings.reconciliationTitle,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  label: 'تعداد',
                  value: '${cheques.length}',
                  unit: 'چک',
                ),
                Container(
                    width: 1,
                    height: 40,
                    color: Colors.white30),
                _StatItem(
                  label: 'مجموع',
                  value: CurrencyFormatter.formatCompact(totalAmount),
                  unit: '',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, List<Cheque> cheques) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: widget.onComplete,
              child: const Text(AppStrings.skip),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: () => _snooze(context),
              icon: const Icon(Icons.snooze, size: 18),
              label: const Text(AppStrings.snooze),
            ),
          ),
        ],
      ),
    );
  }

  void _updateStatus(
      BuildContext context, Cheque cheque, ChequeStatus status) {
    context.read<ChequeBloc>().add(
          UpdateChequeStatusEvent(cheque: cheque, newStatus: status),
        );
  }

  void _bulkUpdate(
      BuildContext context, List<Cheque> cheques, ChequeStatus status) {
    context.read<ChequeBloc>().add(
          BulkUpdateStatusEvent(cheques: cheques, newStatus: status),
        );
  }

  void _openDetail(BuildContext context, Cheque cheque) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<ChequeBloc>(),
          child: ChequeDetailScreen(cheque: cheque),
        ),
      ),
    );
  }

  void _snooze(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'به تعویق انداختن تا:',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...[
              ('۱ ساعت', 1),
              ('۳ ساعت', 3),
              ('فردا', 24),
            ].map(
              (option) => ListTile(
                title: Text(option.$1),
                leading: const Icon(Icons.alarm_outlined,
                    color: AppColors.primary),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onComplete();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Color color;
  final int count;

  const _SectionTitle({
    required this.title,
    required this.color,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReconciliationTile extends StatelessWidget {
  final Cheque cheque;
  final Function(ChequeStatus) onStatusChange;
  final VoidCallback onTap;

  const _ReconciliationTile({
    required this.cheque,
    required this.onStatusChange,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cheque.counterpartyName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '${cheque.bankName} • ${du.DateUtils.toPersian(cheque.dueDate)}',
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
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: cheque.direction == ChequeDirection.issued
                              ? AppColors.issued
                              : AppColors.received,
                        ),
                      ),
                      DueDateBadge(
                        state: cheque.dueDateState,
                        daysUntilDue: cheque.daysUntilDue,
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 16),
              Row(
                children: [
                  _TileAction(
                    label: 'وصول',
                    color: AppColors.cleared,
                    icon: Icons.check_circle_outline,
                    onTap: () =>
                        onStatusChange(ChequeStatus.cleared),
                  ),
                  const SizedBox(width: 8),
                  _TileAction(
                    label: 'برگشت',
                    color: AppColors.returned,
                    icon: Icons.cancel_outlined,
                    onTap: () =>
                        onStatusChange(ChequeStatus.returned),
                  ),
                  const SizedBox(width: 8),
                  _TileAction(
                    label: 'در انتظار',
                    color: AppColors.pending,
                    icon: Icons.pending_outlined,
                    onTap: () =>
                        onStatusChange(ChequeStatus.pendingReview),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TileAction extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _TileAction({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BulkActions extends StatelessWidget {
  final List<Cheque> cheques;
  final VoidCallback onBulkClear;
  final VoidCallback onBulkPending;

  const _BulkActions({
    required this.cheques,
    required this.onBulkClear,
    required this.onBulkPending,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onBulkClear,
            icon: const Icon(Icons.done_all, size: 16),
            label: const Text('همه وصول', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.cleared,
                side: const BorderSide(color: AppColors.cleared)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onBulkPending,
            icon: const Icon(Icons.pending_outlined, size: 16),
            label: const Text('همه در انتظار', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.pending,
                side: const BorderSide(color: AppColors.pending)),
          ),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _StatItem(
      {required this.label, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
              color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (unit.isNotEmpty)
          Text(
            unit,
            style: const TextStyle(
                color: Colors.white70, fontSize: 11),
          ),
      ],
    );
  }
}
