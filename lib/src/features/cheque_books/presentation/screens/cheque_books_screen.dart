import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/cheque_book_model.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../blocs/cheque_book_bloc.dart';
import 'cheque_book_form_screen.dart';
import 'cheque_book_detail_screen.dart';

class ChequeBooksScreen extends StatelessWidget {
  const ChequeBooksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('دسته چک‌ها'),
      ),
      body: BlocBuilder<ChequeBookBloc, ChequeBookState>(
        builder: (context, state) {
          if (state is ChequeBooksLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is ChequeBookError) {
            return Center(child: Text(state.message));
          }
          if (state is ChequeBooksLoaded) {
            if (state.books.isEmpty) {
              return _buildEmpty(context);
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: state.books.length,
              itemBuilder: (ctx, i) =>
                  _ChequeBookCard(enriched: state.books[i]),
            );
          }
          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: context.read<ChequeBookBloc>(),
              child: const ChequeBookFormScreen(),
            ),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('دسته چک جدید'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.book_outlined, size: 72, color: AppColors.textHint),
          const SizedBox(height: 16),
          const Text('دسته چکی ثبت نشده است',
              style:
              TextStyle(color: AppColors.textSecondary, fontSize: 15)),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: context.read<ChequeBookBloc>(),
                  child: const ChequeBookFormScreen(),
                ),
              ),
            ),
            icon: const Icon(Icons.add),
            label: const Text('افزودن دسته چک'),
          ),
        ],
      ),
    );
  }
}

class _ChequeBookCard extends StatelessWidget {
  final EnrichedChequeBook enriched;

  const _ChequeBookCard({required this.enriched});

  @override
  Widget build(BuildContext context) {
    final book = enriched.book;
    final remaining = enriched.remainingPages;
    final used = enriched.usedPages;
    final progress = book.totalPages > 0 ? used / book.totalPages : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: context.read<ChequeBookBloc>(),
              child: ChequeBookDetailScreen(enriched: enriched),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                          book.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${book.bankName} • شعبه ${book.branch}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _ActiveBadge(isActive: book.isActive),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (v) => _handleMenu(context, v, book),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'toggle',
                        child: Text(book.isActive ? 'غیرفعال کردن' : 'فعال کردن'),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('ویرایش'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('حذف', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: AppColors.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    remaining == 0
                        ? AppColors.returned
                        : remaining <= book.totalPages * 0.2
                        ? AppColors.upcoming
                        : AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _InfoChip(
                    label: 'برگ باقی‌مانده',
                    value: _toPersian(remaining.toString()),
                    color: remaining == 0
                        ? AppColors.returned
                        : AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  _InfoChip(
                    label: 'استفاده شده',
                    value: _toPersian(used.toString()),
                    color: AppColors.textSecondary,
                  ),
                  const Spacer(),
                  Text(
                    '${_toPersian(book.startNumber.toString())} – ${_toPersian(book.endNumber.toString())}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textHint),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleMenu(BuildContext context, String action, ChequeBook book) {
    switch (action) {
      case 'toggle':
        context
            .read<ChequeBookBloc>()
            .add(ToggleChequeBookActiveEvent(book));
        break;
      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: context.read<ChequeBookBloc>(),
              child: ChequeBookFormScreen(book: book),
            ),
          ),
        );
        break;
      case 'delete':
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('حذف دسته چک'),
            content: const Text(
                'آیا مطمئن هستید؟ چک‌های مرتبط بدون دسته چک می‌مانند.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('انصراف'),
              ),
              TextButton(
                onPressed: () {
                  context
                      .read<ChequeBookBloc>()
                      .add(DeleteChequeBookEvent(book.id));
                  Navigator.pop(context);
                },
                child: const Text('حذف',
                    style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        break;
    }
  }

  String _toPersian(String s) {
    const d = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    return s.split('').map((c) {
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? AppColors.cleared : AppColors.draft,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            isActive ? 'فعال' : 'غیرفعال',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isActive ? AppColors.cleared : AppColors.draft,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _InfoChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontFamily: 'Vazirmatn'),
        children: [
          TextSpan(
            text: value,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color),
          ),
          TextSpan(
            text: ' $label',
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
