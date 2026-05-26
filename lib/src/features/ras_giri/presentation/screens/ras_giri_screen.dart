import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/cheque_model.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_utils.dart' as du;
import '../../../cheques/presentation/blocs/cheque_bloc.dart';
import '../../../cheques/presentation/screens/cheque_form_screen.dart';

/// راس‌گیری چک — weighted-average due date calculator.
///
/// Formula:
///   Ras = Σ(days_from_base × amount) / Σ(amount)
/// where base date = earliest due date among selected cheques.
class RasGiriScreen extends StatefulWidget {
  const RasGiriScreen({super.key});

  @override
  State<RasGiriScreen> createState() => _RasGiriScreenState();
}

class _RasGiriScreenState extends State<RasGiriScreen> {
  // Filter
  _DirectionFilter _filter = _DirectionFilter.all;

  // Selection
  final Set<String> _selectedIds = {};

  // Computed result
  DateTime? _rasDate;
  double? _totalAmount;
  int? _rasDay; // days from base

  List<Cheque> _filtered(List<Cheque> all) {
    return all.where((c) {
      if (c.isArchived) return false;
      if (_filter == _DirectionFilter.received) {
        return c.direction == ChequeDirection.received;
      }
      if (_filter == _DirectionFilter.issued) {
        return c.direction == ChequeDirection.issued;
      }
      return true;
    }).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  void _toggleSelect(Cheque c) {
    setState(() {
      if (_selectedIds.contains(c.id)) {
        _selectedIds.remove(c.id);
      } else {
        _selectedIds.add(c.id);
      }
      _rasDate = null;
      _rasDay = null;
      _totalAmount = null;
    });
  }

  void _selectAll(List<Cheque> list) {
    setState(() {
      _selectedIds.addAll(list.map((c) => c.id));
      _rasDate = null;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
      _rasDate = null;
    });
  }

  void _calculate(List<Cheque> all) {
    final selected = all.where((c) => _selectedIds.contains(c.id)).toList();
    if (selected.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('حداقل ۲ چک انتخاب کنید'),
      ));
      return;
    }

    // Base date = earliest due date
    final base = selected
        .map((c) => c.dueDate)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final baseDay = DateTime(base.year, base.month, base.day);

    double weightedSum = 0;
    double totalAmount = 0;

    for (final c in selected) {
      final due = DateTime(c.dueDate.year, c.dueDate.month, c.dueDate.day);
      final days = due.difference(baseDay).inDays;
      weightedSum += days * c.amount;
      totalAmount += c.amount;
    }

    final rasOffsetDays = totalAmount > 0 ? (weightedSum / totalAmount) : 0.0;
    final rasDate = baseDay.add(Duration(days: rasOffsetDays.round()));

    setState(() {
      _rasDate = rasDate;
      _rasDay = rasOffsetDays.round();
      _totalAmount = totalAmount;
    });
  }

  void _applyToNewCheque(List<Cheque> all) {
    if (_rasDate == null) return;
    final selected = all.where((c) => _selectedIds.contains(c.id)).toList();
    if (selected.isEmpty) return;

    // Pre-fill: amount = total, dueDate = rasDate, 
    // counterparty = same if all have same party, direction = opposite of selected's majority
    final allReceived = selected.every((c) => c.direction == ChequeDirection.received);
    final allIssued = selected.every((c) => c.direction == ChequeDirection.issued);

    String? commonParty;
    final parties = selected.map((c) => c.counterpartyName).toSet();
    if (parties.length == 1) commonParty = parties.first;

    // Create a stub cheque with prefilled values to pass to form
    // Direction: if replacing received cheques → issue one cheque; vice versa
    final direction = allReceived
        ? ChequeDirection.issued
        : allIssued
            ? ChequeDirection.received
            : ChequeDirection.issued;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<ChequeBloc>(),
          child: _PrefilledChequeForm(
            amount: _totalAmount!,
            dueDate: _rasDate!,
            counterpartyName: commonParty ?? '',
            direction: direction,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChequeBloc, ChequeState>(
      builder: (context, state) {
        List<Cheque> all = [];
        if (state is ChequesLoaded) all = state.cheques;
        if (state is ChequeOperationSuccess) all = state.cheques;

        final filtered = _filtered(all);
        final selectedCount = _selectedIds.intersection(filtered.map((c) => c.id).toSet()).length;

        return Scaffold(
          appBar: AppBar(
            title: const Text('راس‌گیری چک'),
            actions: [
              if (selectedCount > 0) ...[
                TextButton.icon(
                  onPressed: _clearSelection,
                  icon: const Icon(Icons.deselect, size: 18, color: Colors.white70),
                  label: const Text('لغو', style: TextStyle(color: Colors.white70)),
                ),
              ],
            ],
          ),
          body: Column(
            children: [
              _buildFilterBar(),
              _buildSelectionHeader(filtered, selectedCount),
              Expanded(child: _buildList(filtered)),
              if (_rasDate != null)
                _buildResultCard(all),
              _buildActionBar(selectedCount, all),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkDivider
                : AppColors.divider,
          ),
        ),
      ),
      child: Row(
        children: [
          const Text('نوع چک: ', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'همه',
            selected: _filter == _DirectionFilter.all,
            onTap: () => setState(() { _filter = _DirectionFilter.all; _selectedIds.clear(); _rasDate = null; }),
          ),
          const SizedBox(width: 6),
          _FilterChip(
            label: 'دریافتی',
            selected: _filter == _DirectionFilter.received,
            color: AppColors.received,
            onTap: () => setState(() { _filter = _DirectionFilter.received; _selectedIds.clear(); _rasDate = null; }),
          ),
          const SizedBox(width: 6),
          _FilterChip(
            label: 'پرداختی',
            selected: _filter == _DirectionFilter.issued,
            color: AppColors.issued,
            onTap: () => setState(() { _filter = _DirectionFilter.issued; _selectedIds.clear(); _rasDate = null; }),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionHeader(List<Cheque> filtered, int selectedCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkBackground
          : AppColors.background,
      child: Row(
        children: [
          Text(
            '$selectedCount چک انتخاب شده',
            style: TextStyle(
              fontSize: 13,
              color: selectedCount > 0 ? AppColors.primary : (
                Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary
              ),
              fontWeight: selectedCount > 0 ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          const Spacer(),
          if (filtered.isNotEmpty)
            TextButton(
              onPressed: () {
                if (selectedCount == filtered.length) {
                  _clearSelection();
                } else {
                  _selectAll(filtered);
                }
              },
              child: Text(
                selectedCount == filtered.length ? 'لغو همه' : 'انتخاب همه',
                style: const TextStyle(fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildList(List<Cheque> filtered) {
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calculate_outlined,
                size: 64,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkTextHint
                    : AppColors.textHint),
            const SizedBox(height: 16),
            Text(
              'چکی برای نمایش وجود ندارد',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: filtered.length,
      itemBuilder: (_, i) {
        final c = filtered[i];
        final isSelected = _selectedIds.contains(c.id);
        return _ChequeSelectTile(
          cheque: c,
          isSelected: isSelected,
          onTap: () => _toggleSelect(c),
        );
      },
    );
  }

  Widget _buildResultCard(List<Cheque> all) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.9),
            AppColors.primaryLight,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calculate, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'نتیجه راس‌گیری',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ResultItem(
                  label: 'تاریخ راس',
                  value: du.DateUtils.toPersian(_rasDate!),
                  icon: Icons.event,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ResultItem(
                  label: 'روز از مبدأ',
                  value: '${_toFarsi(_rasDay.toString())} روز',
                  icon: Icons.timelapse,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ResultItem(
            label: 'مبلغ کل',
            value: CurrencyFormatter.format(_totalAmount!),
            icon: Icons.payments_outlined,
            fullWidth: true,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _applyToNewCheque(all),
              icon: const Icon(Icons.add_circle_outline, color: Colors.white),
              label: const Text(
                'ثبت چک جدید با این تاریخ و مبلغ',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white70),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(int selectedCount, List<Cheque> all) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: selectedCount >= 2 ? () => _calculate(all) : null,
          icon: const Icon(Icons.calculate),
          label: Text(
            selectedCount < 2
                ? 'حداقل ۲ چک انتخاب کنید'
                : 'محاسبه راس ($selectedCount چک)',
          ),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }
}

String _toFarsi(String s) {
  const digits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  return s.split('').map((c) {
    final i = int.tryParse(c);
    return i != null ? digits[i] : c;
  }).join();
}

enum _DirectionFilter { all, received, issued }

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? c : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? c : (
              Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary
            ),
            fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _ChequeSelectTile extends StatelessWidget {
  final Cheque cheque;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChequeSelectTile({
    required this.cheque,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dirColor = cheque.direction == ChequeDirection.received
        ? AppColors.received
        : AppColors.issued;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.08)
              : (isDark ? AppColors.darkSurface : AppColors.surface),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.darkBorder : AppColors.border),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: isSelected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.border),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: dirColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cheque.counterpartyName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'سررسید: ${du.DateUtils.toPersian(cheque.dueDate)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.formatCompact(cheque.amount),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: dirColor,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: dirColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    cheque.direction == ChequeDirection.received ? 'دریافتی' : 'پرداختی',
                    style: TextStyle(fontSize: 10, color: dirColor, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool fullWidth;

  const _ResultItem({
    required this.label,
    required this.value,
    required this.icon,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(color: Colors.white70, fontSize: 10)),
              Text(value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  )),
            ],
          ),
        ],
      ),
    );
  }
}

/// A ChequeFormScreen wrapper that pre-fills amount, dueDate, counterparty, direction.
class _PrefilledChequeForm extends StatelessWidget {
  final double amount;
  final DateTime dueDate;
  final String counterpartyName;
  final ChequeDirection direction;

  const _PrefilledChequeForm({
    required this.amount,
    required this.dueDate,
    required this.counterpartyName,
    required this.direction,
  });

  @override
  Widget build(BuildContext context) {
    // Build a stub cheque to pass as the "editing" cheque so the form pre-fills,
    // but we override the ID so it creates a new one.
    // Instead, we open ChequeFormScreen in create mode with a different approach:
    // We'll use a custom wrapper that injects initial values.
    return _RasGiriChequeFormScreen(
      amount: amount,
      dueDate: dueDate,
      counterpartyName: counterpartyName,
      direction: direction,
    );
  }
}

class _RasGiriChequeFormScreen extends StatefulWidget {
  final double amount;
  final DateTime dueDate;
  final String counterpartyName;
  final ChequeDirection direction;

  const _RasGiriChequeFormScreen({
    required this.amount,
    required this.dueDate,
    required this.counterpartyName,
    required this.direction,
  });

  @override
  State<_RasGiriChequeFormScreen> createState() =>
      _RasGiriChequeFormScreenState();
}

class _RasGiriChequeFormScreenState extends State<_RasGiriChequeFormScreen> {
  @override
  Widget build(BuildContext context) {
    // We open the standard ChequeFormScreen but pass a pre-filled Cheque as if editing,
    // then override the submit to create instead.  
    // Simplest correct approach: just redirect to ChequeFormScreen with prefilled stub.
    // The ChequeFormScreen only uses cheque for initState() reads; we create a
    // minimal fake cheque with the desired prefill values. The ID will be blank so
    // _isEditing = false and it will create a new cheque.
    final prefill = Cheque(
      id: '', // empty id → treated as create
      sayyadiId: '',
      chequeNumber: '',
      bankId: '',
      bankName: '',
      amount: widget.amount,
      issueDate: DateTime.now(),
      dueDate: widget.dueDate,
      direction: widget.direction,
      counterpartyName: widget.counterpartyName,
      status: ChequeStatus.active,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return ChequeFormScreen(prefillFromRasGiri: prefill);
  }
}
