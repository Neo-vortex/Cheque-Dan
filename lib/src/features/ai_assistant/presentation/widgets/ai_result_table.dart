import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../cheques/presentation/screens/cheque_detail_screen.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/models/cheque_model.dart';
import '../../models/ai_message.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Columns never shown to the user
// ──────────────────────────────────────────────────────────────────────────────
const _hiddenColumns = {
  'id', 'cheque_book_id', 'sayyadi_id', 'image_paths',
  'tags', 'note', 'created_at', 'updated_at',
  'counterparty_phone', 'bank_id',
};

// ──────────────────────────────────────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────────────────────────────────────

String _toPersianNum(String s) {
  const d = ['۰','۱','۲','۳','۴','۵','۶','۷','۸','۹'];
  return s.split('').map((c) { final i = int.tryParse(c); return i != null ? d[i] : c; }).join();
}

String _toJalali(String isoDate) {
  final dt = DateTime.tryParse(isoDate);
  if (dt == null) return isoDate;
  final j = Jalali.fromDateTime(dt);
  return '${_toPersianNum(j.year.toString())}/${_toPersianNum(j.month.toString().padLeft(2,'0'))}/${_toPersianNum(j.day.toString().padLeft(2,'0'))}';
}

String _columnLabel(String col) {
  const exact = {
    'cheque_number': 'شماره چک', 'bank_name': 'بانک', 'amount': 'مبلغ',
    'due_date': 'سررسید', 'issue_date': 'تاریخ صدور', 'direction': 'نوع',
    'counterparty_name': 'طرف حساب', 'طرف_حساب': 'طرف حساب',
    'نام_طرف_حساب': 'طرف حساب', 'status': 'وضعیت',
    'is_archived': 'آرشیو', 'is_active': 'فعال',
    'title': 'عنوان', 'branch': 'شعبه', 'total_pages': 'تعداد برگ',
    'start_number': 'شماره ابتدا', 'end_number': 'شماره انتها',
    'تعداد': 'تعداد', 'مجموع': 'مجموع', 'میانگین': 'میانگین',
    'بیشترین': 'بیشترین', 'کمترین': 'کمترین',
  };
  if (exact.containsKey(col)) return exact[col]!;
  final lower = col.toLowerCase();
  if (lower.startsWith('count(')) return 'تعداد';
  if (lower.startsWith('sum(')) return 'مجموع';
  if (lower.startsWith('avg(')) return 'میانگین';
  if (lower.startsWith('max(')) return 'بیشترین';
  if (lower.startsWith('min(')) return 'کمترین';
  if (lower.contains('count')) return 'تعداد';
  if (lower.contains('sum') || lower.contains('total')) return 'مجموع';
  return col.replaceAll('_', ' ');
}

bool _isAmountCol(String col) {
  final l = col.toLowerCase();
  return l == 'amount' || l.startsWith('sum(') || l.contains('total') ||
      col == 'مجموع' || col == 'میانگین' || col == 'بیشترین' || col == 'کمترین';
}

bool _isDateCol(String col) {
  final l = col.toLowerCase();
  return l.contains('date') || l.contains('_at');
}

bool _isCountCol(String col) {
  final l = col.toLowerCase();
  return l.startsWith('count(') || l.contains('count') || col == 'تعداد';
}

String _formatCell(String col, dynamic value) {
  if (value == null) return '—';
  if (_isAmountCol(col) && value is num) return CurrencyFormatter.format(value.toDouble());
  if (_isCountCol(col)) return _toPersianNum(value.toString());
  if (_isDateCol(col) && value is String && value.contains('-')) return _toJalali(value);
  if (col == 'is_archived' || col == 'is_active') return value == 1 ? 'بله' : 'خیر';
  if (col == 'direction') return value == 'issued' ? 'صادره' : 'دریافتی';
  if (col == 'status') return _statusLabel(value.toString());
  return _toPersianNum(value.toString());
}

String _statusLabel(String s) => const {
  'draft': 'پیش‌نویس', 'active': 'فعال', 'pendingReview': 'در انتظار',
  'cleared': 'وصول شد', 'returned': 'برگشت خورد', 'cancelled': 'لغو شد',
}[s] ?? s;

Color _statusColor(String? s) => switch (s) {
  'cleared' => AppColors.cleared,
  'returned' => AppColors.returned,
  'active' => AppColors.active,
  'pendingReview' => AppColors.pending,
  'cancelled' => AppColors.cancelled,
  _ => AppColors.draft,
};

// ──────────────────────────────────────────────────────────────────────────────
// Main entry point — chooses rendering strategy from resultCategory
// ──────────────────────────────────────────────────────────────────────────────

class AiResultTable extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final String? resultCategory;

  const AiResultTable({
    super.key,
    required this.rows,
    this.resultCategory,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (rows.isEmpty) return _EmptyResult(isDark: isDark);

    final columns = rows.first.keys.where((c) => !_hiddenColumns.contains(c)).toList();
    final cat = resultCategory ?? _inferCategory(rows.first, columns);

    switch (cat) {
      case 'cheques':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (rows.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('${_toPersianNum(rows.length.toString())} چک',
                    style: TextStyle(fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
              ),
            ...rows.map((r) => _ChequeCard(row: r, isDark: isDark)),
          ],
        );

      case 'cheque_books':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows.map((r) => _ChequeBookCard(row: r, isDark: isDark)).toList(),
        );

      case 'names':
        return _NamesResult(rows: rows, columns: columns, isDark: isDark);

      case 'amount':
      case 'count':
        return _AggregateCard(row: rows.first, columns: columns, isDark: isDark);

      default:
        // Generic table for anything else
        if (rows.length == 1 && columns.every((c) =>
            rows.first[c] is num || rows.first[c] == null || _isCountCol(c))) {
          return _AggregateCard(row: rows.first, columns: columns, isDark: isDark);
        }
        return _GenericTable(rows: rows, columns: columns, isDark: isDark);
    }
  }

  String _inferCategory(Map<String, dynamic> first, List<String> cols) {
    if (cols.contains('cheque_number') || cols.contains('counterparty_name')) return 'cheques';
    if (cols.contains('total_pages') || cols.contains('start_number')) return 'cheque_books';
    if (cols.any((c) => c == 'طرف_حساب' || c == 'نام_طرف_حساب' || c == 'counterparty_name')) return 'names';
    if (cols.length == 1 && (_isAmountCol(cols.first) || _isCountCol(cols.first))) {
      return _isCountCol(cols.first) ? 'count' : 'amount';
    }
    return 'text';
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Analytical (multi-section) widget
// ──────────────────────────────────────────────────────────────────────────────

class AiAnalyticalResult extends StatelessWidget {
  final List<AnalyticalQuery> queries;
  final bool isDark;

  const AiAnalyticalResult({super.key, required this.queries, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: queries.map((q) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(isDark ? 0.2 : 0.08),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
              ),
              child: Text(q.label, style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: q.rows == null
                  ? const Center(child: SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)))
                  : q.rows!.isEmpty
                      ? Text('نتیجه‌ای یافت نشد',
                          style: TextStyle(fontSize: 12,
                              color: isDark ? AppColors.darkTextHint : AppColors.textHint))
                      : AiResultTable(rows: q.rows!),
            ),
          ],
        ),
      )).toList(),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Cheque card — direction badge only shown when relevant
// ──────────────────────────────────────────────────────────────────────────────

class _ChequeCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final bool isDark;
  const _ChequeCard({required this.row, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final amount = (row['amount'] as num?)?.toDouble();
    final status = row['status'] as String?;
    final direction = row['direction'] as String?;
    final dueDate = row['due_date'] != null ? _toJalali(row['due_date'] as String) : null;
    final counterparty = row['counterparty_name'] as String? ?? '';
    final bankName = row['bank_name'] as String? ?? '';
    final chequeNumber = row['cheque_number'] as String? ?? '';

    final statusColor = _statusColor(status);

    // Direction colours — صادره = red-ish, دریافتی = green-ish
    final isIssued = direction == 'issued';
    final directionColor = isIssued ? AppColors.issued : AppColors.received;
    final directionLabel = isIssued ? 'صادره' : 'دریافتی';

    return GestureDetector(
      onTap: row['id'] != null ? () => _openDetail(context, row['id'] as String) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Row 1: direction badge | counterparty name | status badge
          Row(children: [
            // Direction badge — always shown for cheque results
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: directionColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(directionLabel,
                  style: TextStyle(fontSize: 11, color: directionColor,
                      fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 8),
            if (counterparty.isNotEmpty)
              Expanded(child: Text(counterparty,
                  style: TextStyle(fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis)),
            if (status != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(_statusLabel(status),
                    style: TextStyle(fontSize: 11, color: statusColor,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ]),
          const SizedBox(height: 8),
          // Row 2: amount | bank | due_date
          Row(children: [
            if (amount != null) ...[
              Icon(Icons.account_balance_wallet_outlined, size: 14,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(CurrencyFormatter.format(amount),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
              const SizedBox(width: 4),
              Text('تومان', style: TextStyle(fontSize: 11,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
              const SizedBox(width: 12),
            ],
            if (bankName.isNotEmpty) ...[
              Icon(Icons.account_balance_outlined, size: 14,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
              const SizedBox(width: 4),
              Expanded(child: Text(bankName,
                  style: TextStyle(fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis)),
            ],
            if (dueDate != null) ...[
              Icon(Icons.calendar_today_outlined, size: 14,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(dueDate, style: TextStyle(fontSize: 12,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
            ],
          ]),
          if (chequeNumber.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('شماره: ${_toPersianNum(chequeNumber)}',
                style: TextStyle(fontSize: 11,
                    color: isDark ? AppColors.darkTextHint : AppColors.textHint)),
          ],
        ]),
      ),
    );
  }

  Future<void> _openDetail(BuildContext context, String id) async {
    if (!context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => _ChequeDetailLoader(chequeId: id)));
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Cheque Book card
// ──────────────────────────────────────────────────────────────────────────────

class _ChequeBookCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final bool isDark;
  const _ChequeBookCard({required this.row, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final title = row['title'] as String? ?? '—';
    final bank = row['bank_name'] as String? ?? '';
    final branch = row['branch'] as String? ?? '';
    final pages = row['total_pages'] as int?;
    final isActive = (row['is_active'] as int?) == 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.book_outlined, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
          if (bank.isNotEmpty)
            Text(bank, style: TextStyle(fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
          if (branch.isNotEmpty)
            Text('شعبه: $branch', style: TextStyle(fontSize: 11,
                color: isDark ? AppColors.darkTextHint : AppColors.textHint)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (isActive ? AppColors.active : AppColors.draft).withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(isActive ? 'فعال' : 'غیرفعال',
                style: TextStyle(fontSize: 11,
                    color: isActive ? AppColors.active : AppColors.draft,
                    fontWeight: FontWeight.w600)),
          ),
          if (pages != null) ...[
            const SizedBox(height: 4),
            Text('${_toPersianNum(pages.toString())} برگ',
                style: TextStyle(fontSize: 11,
                    color: isDark ? AppColors.darkTextHint : AppColors.textHint)),
          ],
        ]),
      ]),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Names result — for "بیشترین معاملات با کی" type queries
// ──────────────────────────────────────────────────────────────────────────────

class _NamesResult extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final List<String> columns;
  final bool isDark;
  const _NamesResult({required this.rows, required this.columns, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows.asMap().entries.map((e) {
        final rank = e.key + 1;
        final row = e.value;
        // Find the name column
        final nameCol = columns.firstWhere(
          (c) => c.contains('counterparty') || c.contains('طرف') || c.contains('نام'),
          orElse: () => columns.first,
        );
        final name = row[nameCol]?.toString() ?? '—';
        // Find an amount or count column
        final valueCol = columns.firstWhere(
          (c) => c != nameCol && (_isAmountCol(c) || _isCountCol(c)),
          orElse: () => '',
        );
        final value = valueCol.isNotEmpty ? row[valueCol] : null;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
          ),
          child: Row(children: [
            // Rank badge
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: rank == 1
                    ? Colors.amber.withOpacity(0.2)
                    : AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Center(child: Text(_toPersianNum(rank.toString()),
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: rank == 1 ? Colors.amber.shade700 : AppColors.primary))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(name, style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary))),
            if (value != null)
              Text(
                _isAmountCol(valueCol) && value is num
                    ? '${CurrencyFormatter.format((value as num).toDouble())} تومان'
                    : _toPersianNum(value.toString()),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: AppColors.primary),
              ),
          ]),
        );
      }).toList(),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Aggregate card (single-row sums/counts)
// ──────────────────────────────────────────────────────────────────────────────

class _AggregateCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final List<String> columns;
  final bool isDark;
  const _AggregateCard({required this.row, required this.columns, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: isDark
            ? [AppColors.primary.withOpacity(0.3), AppColors.primaryDark.withOpacity(0.2)]
            : [AppColors.primary.withOpacity(0.08), AppColors.primaryLight.withOpacity(0.06)]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(isDark ? 0.3 : 0.2)),
      ),
      child: Wrap(spacing: 24, runSpacing: 12, children: columns.map((col) {
        final value = row[col];
        final label = _columnLabel(col);
        final isAmount = _isAmountCol(col) && value is num;
        final display = isAmount
            ? CurrencyFormatter.format((value as num).toDouble())
            : _toPersianNum(value?.toString() ?? '—');
        return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(fontSize: 11,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(display, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : AppColors.primary)),
          if (isAmount)
            Text('تومان', style: TextStyle(fontSize: 11,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
        ]);
      }).toList()),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Generic table for misc queries
// ──────────────────────────────────────────────────────────────────────────────

class _GenericTable extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final List<String> columns;
  final bool isDark;
  const _GenericTable({required this.rows, required this.columns, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(
            isDark ? AppColors.darkSurfaceVariant : AppColors.primary.withOpacity(0.08)),
        dataRowColor: WidgetStateProperty.all(
            isDark ? AppColors.darkSurface : AppColors.surface),
        border: TableBorder.all(
            color: isDark ? AppColors.darkBorder : AppColors.border,
            borderRadius: BorderRadius.circular(10)),
        columnSpacing: 16,
        headingTextStyle: TextStyle(fontFamily: 'Vazirmatn',
            fontWeight: FontWeight.w700, fontSize: 12,
            color: isDark ? AppColors.darkTextPrimary : AppColors.primary),
        dataTextStyle: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
        columns: columns.map((c) => DataColumn(label: Text(_columnLabel(c)))).toList(),
        rows: rows.map((row) => DataRow(
            cells: columns.map((col) =>
                DataCell(Text(_formatCell(col, row[col])))).toList())).toList(),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────

class _EmptyResult extends StatelessWidget {
  final bool isDark;
  const _EmptyResult({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Icon(Icons.inbox_outlined,
            color: isDark ? AppColors.darkTextHint : AppColors.textHint),
        const SizedBox(width: 10),
        Text('نتیجه‌ای یافت نشد', style: TextStyle(
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
      ]),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Cheque detail loader (tap to open full cheque screen)
// ──────────────────────────────────────────────────────────────────────────────

class _ChequeDetailLoader extends StatefulWidget {
  final String chequeId;
  const _ChequeDetailLoader({required this.chequeId});

  @override
  State<_ChequeDetailLoader> createState() => _ChequeDetailLoaderState();
}

class _ChequeDetailLoaderState extends State<_ChequeDetailLoader> {
  Cheque? _cheque;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final row = await DatabaseHelper.instance.getChequeById(widget.chequeId);
    if (row == null || !mounted) return;
    final histRows = await DatabaseHelper.instance.getStatusHistory(widget.chequeId);
    final history = histRows.map(StatusChange.fromMap).toList();
    final tags = (row['tags'] as String? ?? '').split(',').where((t) => t.isNotEmpty).toList();
    final imagePaths = (row['image_paths'] as String? ?? '').split(',').where((p) => p.isNotEmpty).toList();
    setState(() {
      _cheque = Cheque(
        id: row['id'], sayyadiId: row['sayyadi_id'],
        chequeNumber: row['cheque_number'],
        bankId: row['bank_id'], bankName: row['bank_name'],
        amount: (row['amount'] as num).toDouble(),
        issueDate: DateTime.parse(row['issue_date']),
        dueDate: DateTime.parse(row['due_date']),
        direction: row['direction'] == 'issued' ? ChequeDirection.issued : ChequeDirection.received,
        counterpartyName: row['counterparty_name'],
        counterpartyPhone: row['counterparty_phone'],
        status: ChequeStatus.values.byName(row['status']),
        note: row['note'], tags: tags,
        statusHistory: history, imagePaths: imagePaths,
        chequeBookId: row['cheque_book_id'],
        isArchived: (row['is_archived'] as int) == 1,
        createdAt: DateTime.parse(row['created_at']),
        updatedAt: DateTime.parse(row['updated_at']),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cheque == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return ChequeDetailScreen(cheque: _cheque!);
  }
}
