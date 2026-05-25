import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/models/cheque_model.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_utils.dart' as du;
import '../../../../features/cheques/presentation/blocs/cheque_bloc.dart';
import '../../../../features/cheques/presentation/screens/cheque_detail_screen.dart';
import '../../../../shared/widgets/status_badge.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  // Filter state
  ChequeDirection? _directionFilter;
  ChequeStatus? _statusFilter;
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Cheque> _applyFilters(List<Cheque> cheques) {
    return cheques.where((c) {
      if (_directionFilter != null && c.direction != _directionFilter) {
        return false;
      }
      if (_statusFilter != null && c.status != _statusFilter) {
        return false;
      }
      if (_fromDate != null &&
          c.dueDate.isBefore(_fromDate!)) {
        return false;
      }
      if (_toDate != null &&
          c.dueDate.isAfter(_toDate!.add(const Duration(days: 1)))) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          cursorColor: Colors.white,
          decoration: const InputDecoration(
            hintText: AppStrings.searchHint,
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
            prefixIcon: Icon(Icons.search, color: Colors.white70),
          ),
          onChanged: (q) {
            setState(() => _query = q);
            context.read<ChequeBloc>().add(SearchChequesEvent(q));
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: _showFilterSheet,
            tooltip: 'فیلتر',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_hasActiveFilters) _buildActiveFiltersBar(),
          Expanded(
            child: BlocBuilder<ChequeBloc, ChequeState>(
              builder: (context, state) {
                List<Cheque> results = [];

                if (state is ChequesLoaded) {
                  if (_query.isNotEmpty) {
                    results = state.searchResults ?? [];
                  } else {
                    results = state.cheques;
                  }
                } else if (state is ChequeOperationSuccess) {
                  results = state.cheques;
                }

                results = _applyFilters(results);

                if (_query.isEmpty && !_hasActiveFilters) {
                  return _buildEmptySearchPrompt();
                }

                if (results.isEmpty) {
                  return _buildNoResults();
                }

                return _buildResultsList(context, results);
              },
            ),
          ),
        ],
      ),
    );
  }

  bool get _hasActiveFilters =>
      _directionFilter != null ||
      _statusFilter != null ||
      _fromDate != null ||
      _toDate != null;

  Widget _buildActiveFiltersBar() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: AppColors.surfaceVariant,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (_directionFilter != null)
            _FilterChip(
              label: _directionFilter == ChequeDirection.issued
                  ? AppStrings.issued
                  : AppStrings.received,
              onRemove: () =>
                  setState(() => _directionFilter = null),
            ),
          if (_statusFilter != null)
            _FilterChip(
              label: _statusLabel(_statusFilter!),
              onRemove: () => setState(() => _statusFilter = null),
            ),
          if (_fromDate != null)
            _FilterChip(
              label: 'از ${du.DateUtils.toPersian(_fromDate!)}',
              onRemove: () => setState(() => _fromDate = null),
            ),
          if (_toDate != null)
            _FilterChip(
              label: 'تا ${du.DateUtils.toPersian(_toDate!)}',
              onRemove: () => setState(() => _toDate = null),
            ),
          TextButton(
            onPressed: _clearFilters,
            child: const Text('پاک کردن همه',
                style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySearchPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 72, color: AppColors.textHint),
          const SizedBox(height: 16),
          const Text(
            'برای جستجو تایپ کنید',
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: 15),
          ),
          const SizedBox(height: 8),
          const Text(
            'شناسه صیادی، مبلغ، طرف حساب و...',
            style: TextStyle(
                color: AppColors.textHint, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text(
            '"$_query" یافت نشد',
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList(BuildContext context, List<Cheque> results) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                '${results.length} نتیجه',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: results.length,
            itemBuilder: (ctx, i) {
              final c = results[i];
              return _SearchResultTile(
                cheque: c,
                query: _query,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BlocProvider.value(
                      value: context.read<ChequeBloc>(),
                      child: ChequeDetailScreen(cheque: c),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        directionFilter: _directionFilter,
        statusFilter: _statusFilter,
        fromDate: _fromDate,
        toDate: _toDate,
        onApply: (dir, status, from, to) {
          setState(() {
            _directionFilter = dir;
            _statusFilter = status;
            _fromDate = from;
            _toDate = to;
          });
        },
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      _directionFilter = null;
      _statusFilter = null;
      _fromDate = null;
      _toDate = null;
    });
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

class _SearchResultTile extends StatelessWidget {
  final Cheque cheque;
  final String query;
  final VoidCallback onTap;

  const _SearchResultTile({
    required this.cheque,
    required this.query,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isIssued = cheque.direction == ChequeDirection.issued;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (isIssued ? AppColors.issued : AppColors.received)
                      .withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isIssued ? Icons.arrow_upward : Icons.arrow_downward,
                  color: isIssued ? AppColors.issued : AppColors.received,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
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
                      '${cheque.bankName} • ${cheque.sayyadiId}',
                      style: const TextStyle(
                        fontSize: 11,
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
                      color: isIssued ? AppColors.issued : AppColors.received,
                    ),
                  ),
                  const SizedBox(height: 4),
                  StatusBadge(status: cheque.status, small: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _FilterChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.primary)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close,
                size: 14, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final ChequeDirection? directionFilter;
  final ChequeStatus? statusFilter;
  final DateTime? fromDate;
  final DateTime? toDate;
  final Function(ChequeDirection?, ChequeStatus?, DateTime?, DateTime?)
      onApply;

  const _FilterSheet({
    required this.directionFilter,
    required this.statusFilter,
    required this.fromDate,
    required this.toDate,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  ChequeDirection? _direction;
  ChequeStatus? _status;
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    _direction = widget.directionFilter;
    _status = widget.statusFilter;
    _from = widget.fromDate;
    _to = widget.toDate;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'فیلتر جستجو',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          const Text('جهت چک',
              style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _filterOption('همه', _direction == null,
                  () => setState(() => _direction = null)),
              _filterOption(AppStrings.issued,
                  _direction == ChequeDirection.issued,
                  () => setState(() => _direction = ChequeDirection.issued)),
              _filterOption(AppStrings.received,
                  _direction == ChequeDirection.received,
                  () => setState(
                      () => _direction = ChequeDirection.received)),
            ],
          ),
          const SizedBox(height: 16),
          const Text('وضعیت',
              style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _filterOption(
                  'همه', _status == null, () => setState(() => _status = null)),
              ...ChequeStatus.values.map((s) => _filterOption(
                    _statusLabel(s),
                    _status == s,
                    () => setState(() => _status = s),
                  )),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('انصراف'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    widget.onApply(_direction, _status, _from, _to);
                    Navigator.pop(context);
                  },
                  child: const Text('اعمال'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _filterOption(
      String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
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
