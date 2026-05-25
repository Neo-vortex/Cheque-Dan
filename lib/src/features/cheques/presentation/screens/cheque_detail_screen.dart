import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/models/cheque_model.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_utils.dart' as du;
import '../../../../shared/widgets/status_badge.dart';
import '../blocs/cheque_bloc.dart';
import 'cheque_form_screen.dart';

class ChequeDetailScreen extends StatelessWidget {
  final Cheque cheque;

  const ChequeDetailScreen({super.key, required this.cheque});

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
        Cheque current = cheque;
        if (state is ChequesLoaded) {
          final found = state.cheques.where((c) => c.id == cheque.id).toList();
          if (found.isNotEmpty) current = found.first;
        } else if (state is ChequeOperationSuccess) {
          final found = state.cheques.where((c) => c.id == cheque.id).toList();
          if (found.isNotEmpty) current = found.first;
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('جزئیات چک'),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BlocProvider.value(
                      value: context.read<ChequeBloc>(),
                      child: ChequeFormScreen(cheque: current),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _confirmDelete(context, current),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeaderCard(context, current),
              const SizedBox(height: 12),
              _buildDetailsCard(current),
              const SizedBox(height: 12),
              if (current.isActive) _buildActionsCard(context, current),
              if (current.note != null) ...[
                const SizedBox(height: 12),
                _buildNoteCard(current),
              ],
              if (current.tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildTagsCard(current),
              ],
              if (current.imagePaths.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildImagesCard(current),
              ],
              if (current.statusHistory.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildHistoryCard(current),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard(BuildContext context, Cheque c) {
    final isIssued = c.direction == ChequeDirection.issued;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                DirectionBadge(direction: c.direction),
                StatusBadge(status: c.status),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              CurrencyFormatter.format(c.amount),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: isIssued ? AppColors.issued : AppColors.received,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              c.counterpartyName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (c.counterpartyPhone != null && c.counterpartyPhone!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                c.counterpartyPhone!,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 4),
            if (c.isActive)
              DueDateBadge(
                state: c.dueDateState,
                daysUntilDue: c.daysUntilDue,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard(Cheque c) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'اطلاعات چک',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            _DetailRow(icon: Icons.fingerprint, label: AppStrings.sayyadiId, value: c.sayyadiId),
            _DetailRow(icon: Icons.numbers, label: AppStrings.chequeNumber, value: c.chequeNumber),
            _DetailRow(icon: Icons.account_balance_outlined, label: AppStrings.bankName, value: c.bankName),
            _DetailRow(icon: Icons.calendar_today_outlined, label: AppStrings.issueDate, value: du.DateUtils.toPersianFull(c.issueDate)),
            _DetailRow(icon: Icons.event_outlined, label: AppStrings.dueDate, value: du.DateUtils.toPersianFull(c.dueDate)),
            _DetailRow(icon: Icons.person_outline, label: AppStrings.counterparty, value: c.counterpartyName),
            if (c.counterpartyPhone != null && c.counterpartyPhone!.isNotEmpty)
              _DetailRow(icon: Icons.phone_outlined, label: 'موبایل', value: c.counterpartyPhone!),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard(BuildContext context, Cheque c) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'تغییر وضعیت',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: AppStrings.markCleared,
                    color: AppColors.cleared,
                    icon: Icons.check_circle_outline,
                    onTap: () => _changeStatus(context, c, ChequeStatus.cleared),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    label: AppStrings.markReturned,
                    color: AppColors.returned,
                    icon: Icons.cancel_outlined,
                    onTap: () => _changeStatus(context, c, ChequeStatus.returned),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    label: AppStrings.markPending,
                    color: AppColors.pending,
                    icon: Icons.pending_outlined,
                    onTap: () => _changeStatus(context, c, ChequeStatus.pendingReview),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteCard(Cheque c) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.note_outlined, size: 16, color: AppColors.textSecondary),
                SizedBox(width: 6),
                Text('یادداشت',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 8),
            Text(c.note!, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.6)),
          ],
        ),
      ),
    );
  }

  Widget _buildTagsCard(Cheque c) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('برچسب‌ها',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: c.tags
                  .map((t) => Chip(
                label: Text(t, style: const TextStyle(fontSize: 12)),
                backgroundColor: AppColors.primary.withOpacity(0.1),
                side: const BorderSide(color: Colors.transparent),
              ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(Cheque c) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('تاریخچه وضعیت',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            ...c.statusHistory.map((h) => _HistoryItem(change: h)),
          ],
        ),
      ),
    );
  }

  void _changeStatus(BuildContext context, Cheque c, ChequeStatus newStatus) {
    context.read<ChequeBloc>().add(UpdateChequeStatusEvent(cheque: c, newStatus: newStatus));
  }

  void _confirmDelete(BuildContext context, Cheque c) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف چک'),
        content: const Text('آیا از حذف این چک مطمئن هستید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.returned),
            onPressed: () {
              context.read<ChequeBloc>().add(DeleteChequeEvent(c.id));
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  Widget _buildImagesCard(Cheque c) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.photo_library_outlined, size: 18, color: AppColors.textSecondary),
                SizedBox(width: 8),
                Text('تصاویر چک',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: c.imagePaths.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final path = c.imagePaths[i];
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      ctx,
                      MaterialPageRoute(builder: (_) => _FullImageView(path: path)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        File(path),
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 90,
                          height: 90,
                          color: AppColors.surfaceVariant,
                          child: const Icon(Icons.broken_image_outlined, color: AppColors.textHint),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionButton({required this.label, required this.color, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final StatusChange change;
  const _HistoryItem({required this.change});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 8, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(_statusLabel(change.fromStatus),
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const Icon(Icons.arrow_forward, size: 12, color: AppColors.textSecondary),
          Text(_statusLabel(change.toStatus),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(du.DateUtils.toPersian(change.changedAt),
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  String _statusLabel(ChequeStatus s) {
    switch (s) {
      case ChequeStatus.draft: return AppStrings.draft;
      case ChequeStatus.active: return AppStrings.active;
      case ChequeStatus.pendingReview: return AppStrings.pendingReview;
      case ChequeStatus.cleared: return AppStrings.cleared;
      case ChequeStatus.returned: return AppStrings.returned;
      case ChequeStatus.cancelled: return AppStrings.cancelled;
    }
  }
}

class _FullImageView extends StatelessWidget {
  final String path;
  const _FullImageView({required this.path});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('تصویر چک'),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.file(
            File(path),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 80,
            ),
          ),
        ),
      ),
    );
  }
}
