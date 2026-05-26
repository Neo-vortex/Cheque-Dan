import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/cheque_book_model.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../features/cheque_books/data/cheque_book_repository.dart';
import '../blocs/cheque_book_bloc.dart';

class ChequeBookDetailScreen extends StatefulWidget {
  final EnrichedChequeBook enriched;

  const ChequeBookDetailScreen({super.key, required this.enriched});

  @override
  State<ChequeBookDetailScreen> createState() =>
      _ChequeBookDetailScreenState();
}

class _ChequeBookDetailScreenState extends State<ChequeBookDetailScreen> {
  List<ChequeBookPage>? _pages;

  @override
  void initState() {
    super.initState();
    _loadPages();
  }

  Future<void> _loadPages() async {
    final repo = ChequeBookRepository();
    final pages = await repo.getPagesForBook(widget.enriched.book);
    if (mounted) setState(() => _pages = pages);
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.enriched.book;
    final remaining = widget.enriched.remainingPages;
    final used = widget.enriched.usedPages;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress =
        book.totalPages > 0 ? used / book.totalPages : 0.0;

    return Scaffold(
      appBar: AppBar(title: Text(book.title)),
      body: Column(
        children: [
          // Summary card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(book.bankName,
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
                          Text('شعبه ${book.branch}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    _ActiveBadge(isActive: book.isActive),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _Stat(label: 'کل برگ', value: _p(book.totalPages)),
                    _Stat(
                        label: 'استفاده شده',
                        value: _p(used),
                        color: AppColors.issued),
                    _Stat(
                        label: 'باقی‌مانده',
                        value: _p(remaining),
                        color: remaining == 0
                            ? AppColors.returned
                            : AppColors.cleared),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 10,
                    backgroundColor: isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      remaining == 0
                          ? AppColors.returned
                          : remaining <= book.totalPages * 0.2
                              ? AppColors.upcoming
                              : AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'شماره‌ها: ${_p(book.startNumber)} تا ${_p(book.endNumber)}',
                  style: TextStyle(
                      fontSize: 12, color: isDark ? AppColors.darkTextHint : AppColors.textHint),
                ),
              ],
            ),
          ),
          // Pages list header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('برگ‌های دسته چک',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                const Spacer(),
                if (_pages != null)
                  Text(
                    '${_p(_pages!.where((p) => p.isUsed).length)} از ${_p(_pages!.length)}',
                    style: TextStyle(
                        fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _pages == null
                ? const Center(child: CircularProgressIndicator())
                : _pages!.isEmpty
                    ? const Center(child: Text('برگی موجود نیست'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        itemCount: _pages!.length,
                        itemBuilder: (ctx, i) =>
                            _PageRow(page: _pages![i]),
                      ),
          ),
        ],
      ),
    );
  }

  String _p(int n) {
    const d = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    return n.toString().split('').map((c) {
      final i = int.tryParse(c);
      return i != null ? d[i] : c;
    }).join();
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _Stat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: color ?? (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary))),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
      ],
    );
  }
}

class _PageRow extends StatelessWidget {
  final ChequeBookPage page;

  const _PageRow({required this.page});

  @override
  Widget build(BuildContext context) {
    final used = page.isUsed;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: used
            ? AppColors.primary.withOpacity(0.08)
            : (isDark ? AppColors.darkSurface : Colors.white),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: used
              ? AppColors.primary.withOpacity(0.3)
              : (isDark ? AppColors.darkBorder : AppColors.border),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (used ? AppColors.primary : AppColors.textHint)
                  .withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(
                used ? Icons.check : Icons.article_outlined,
                size: 18,
                color: used ? AppColors.primary : AppColors.textHint,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'برگ شماره ${_p(page.pageNumber)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: used
                        ? (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)
                        : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                  ),
                ),
                if (used && page.counterpartyName != null)
                  Text(
                    page.counterpartyName!,
                    style: TextStyle(
                        fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                  ),
              ],
            ),
          ),
          if (used && page.amount != null)
            Text(
              CurrencyFormatter.formatCompact(page.amount!),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.issued,
              ),
            )
          else if (!used)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.safe.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'خالی',
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.safe,
                    fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  String _p(int n) {
    const d = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    return n.toString().split('').map((c) {
      final i = int.tryParse(c);
      return i != null ? d[i] : c;
    }).join();
  }
}

class _ActiveBadge extends StatelessWidget {
  final bool isActive;
  const _ActiveBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (isActive ? AppColors.cleared : AppColors.draft)
            .withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isActive ? AppColors.cleared : AppColors.draft)
              .withOpacity(0.4),
        ),
      ),
      child: Text(
        isActive ? 'فعال' : 'غیرفعال',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isActive ? AppColors.cleared : AppColors.draft,
        ),
      ),
    );
  }
}
