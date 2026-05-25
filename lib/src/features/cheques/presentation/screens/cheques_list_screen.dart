import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/models/cheque_model.dart';
import '../../../../core/services/time_origin_service.dart';
import '../../../../shared/widgets/cheque_list_tile.dart';
import '../blocs/cheque_bloc.dart';
import 'cheque_detail_screen.dart';
import 'cheque_form_screen.dart';

class ChequesListScreen extends StatefulWidget {
  const ChequesListScreen({super.key});

  @override
  State<ChequesListScreen> createState() => _ChequesListScreenState();
}

class _ChequesListScreenState extends State<ChequesListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchCtrl = TextEditingController();
  bool _isSearching = false;

  // Tab: (label, directionFilter, statusFilter, showArchive)
  // statusFilter empty = active only; specific = those statuses
  static const _tabs = [
    ('همه', null, <String>[], false),
    ('صادره', 'issued', <String>[], false),
    ('دریافتی', 'received', <String>[], false),
    ('وصول شده', null, ['cleared'], false),
    ('برگشت خورده', null, ['returned'], false),
    ('آرشیو', null, <String>[], true),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Cheque> _filterCheques(
      List<Cheque> all,
      String? directionStr,
      List<String> statusNames,
      bool archive,
      ) {
    return all.where((c) {
      // Archive tab
      if (archive) return c.isArchived;
      // Non-archive tabs hide archived cheques
      if (c.isArchived) return false;

      final direction = directionStr == null
          ? null
          : (directionStr == 'issued'
          ? ChequeDirection.issued
          : ChequeDirection.received);

      if (direction != null && c.direction != direction) return false;

      if (statusNames.isNotEmpty) {
        return statusNames.contains(c.status.name);
      }

      // Active-only tabs (همه, صادره, دریافتی)
      return c.isActive;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
          controller: _searchCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          cursorColor: Colors.white,
          decoration: const InputDecoration(
            hintText: AppStrings.searchHint,
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
          ),
          onChanged: (q) {
            context.read<ChequeBloc>().add(SearchChequesEvent(q));
          },
        )
            : const Text(AppStrings.cheques),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() => _isSearching = !_isSearching);
              if (!_isSearching) {
                _searchCtrl.clear();
                context.read<ChequeBloc>().add(const ClearSearchEvent());
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs
              .map((t) => Tab(
            child: Text(
              t.$1,
              style: const TextStyle(fontSize: 12),
            ),
          ))
              .toList(),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppColors.secondary,
          isScrollable: true,
        ),
      ),
      body: Consumer<TimeOriginService>(
        builder: (context, _, __) => BlocConsumer<ChequeBloc, ChequeState>(
          listener: (context, state) {
            if (state is ChequeOperationSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message)),
              );
            }
          },
          builder: (context, state) {
            List<Cheque> allCheques = [];

            if (state is ChequesLoaded) {
              allCheques = state.isSearching
                  ? (state.searchResults ?? [])
                  : state.cheques;
            } else if (state is ChequeOperationSuccess) {
              allCheques = state.cheques;
            }

            if (state is ChequesLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (_isSearching && state is ChequesLoaded && state.isSearching) {
              return _buildChequeList(context, allCheques, isArchive: false);
            }

            return TabBarView(
              controller: _tabController,
              children: _tabs.map((tab) {
                final filtered = _filterCheques(
                    allCheques, tab.$2, tab.$3, tab.$4);
                return _buildChequeList(context, filtered,
                    isArchive: tab.$4);
              }).toList(),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HeroMode(
              enabled: false,
              child: BlocProvider.value(
                value: context.read<ChequeBloc>(),
                child: const ChequeFormScreen(),
              ),
            ),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('چک جدید'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildChequeList(BuildContext context, List<Cheque> cheques,
      {required bool isArchive}) {
    if (cheques.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isArchive ? Icons.archive_outlined : Icons.inbox_outlined,
              size: 64,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 16),
            Text(
              _isSearching
                  ? AppStrings.noResults
                  : isArchive
                  ? 'چکی در آرشیو نیست'
                  : 'چکی ثبت نشده است',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
              ),
            ),
            if (!isArchive && !_isSearching) ...[
              const SizedBox(height: 8),
              const Text(
                'برای آرشیو، روی چک به چپ بکشید',
                style: TextStyle(color: AppColors.textHint, fontSize: 12),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: cheques.length,
      itemBuilder: (context, i) {
        final cheque = cheques[i];
        return _buildSwipeableRow(context, cheque, isArchive: isArchive);
      },
    );
  }

  Widget _buildSwipeableRow(BuildContext context, Cheque cheque,
      {required bool isArchive}) {
    return Slidable(
      key: ValueKey(cheque.id),
      // Left swipe → archive (for non-archived) or unarchive
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: isArchive ? 0.25 : 0.65,
        children: [
          if (!isArchive && cheque.isActive) ...[
            SlidableAction(
              onPressed: (_) => context
                  .read<ChequeBloc>()
                  .add(UpdateChequeStatusEvent(
                  cheque: cheque, newStatus: ChequeStatus.cleared)),
              backgroundColor: AppColors.cleared,
              foregroundColor: Colors.white,
              icon: Icons.check_circle_outline,
              label: 'وصول',
            ),
            SlidableAction(
              onPressed: (_) => context
                  .read<ChequeBloc>()
                  .add(UpdateChequeStatusEvent(
                  cheque: cheque, newStatus: ChequeStatus.returned)),
              backgroundColor: AppColors.returned,
              foregroundColor: Colors.white,
              icon: Icons.cancel_outlined,
              label: 'برگشت',
            ),
          ],
          SlidableAction(
            onPressed: (_) {
              if (isArchive) {
                context
                    .read<ChequeBloc>()
                    .add(UnarchiveChequeEvent(cheque.id));
              } else {
                context
                    .read<ChequeBloc>()
                    .add(ArchiveChequeEvent(cheque.id));
              }
            },
            backgroundColor:
            isArchive ? AppColors.primary : const Color(0xFF5C6670),
            foregroundColor: Colors.white,
            icon: isArchive ? Icons.unarchive_outlined : Icons.archive_outlined,
            label: isArchive ? 'بازگردانی' : 'آرشیو',
            borderRadius: !isArchive && cheque.isActive
                ? BorderRadius.zero
                : const BorderRadius.horizontal(right: Radius.circular(12)),
          ),
          if (!isArchive)
            SlidableAction(
              onPressed: (_) => context
                  .read<ChequeBloc>()
                  .add(DeleteChequeEvent(cheque.id)),
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              icon: Icons.delete_outline,
              label: 'حذف',
              borderRadius:
              const BorderRadius.horizontal(right: Radius.circular(12)),
            ),
        ],
      ),
      child: _StatusColoredRow(
        cheque: cheque,
        child: ChequeListTile(
          cheque: cheque,
          showSlidable: false,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: context.read<ChequeBloc>(),
                child: ChequeDetailScreen(cheque: cheque),
              ),
            ),
          ),
          onEdit: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HeroMode(
                enabled: false,
                child: BlocProvider.value(
                  value: context.read<ChequeBloc>(),
                  child: ChequeFormScreen(cheque: cheque),
                ),
              ),
            ),
          ),
          onDelete: () =>
              context.read<ChequeBloc>().add(DeleteChequeEvent(cheque.id)),
          onStatusChange: (status) => context.read<ChequeBloc>().add(
              UpdateChequeStatusEvent(cheque: cheque, newStatus: status)),
        ),
      ),
    );
  }
}

/// Wraps a cheque tile with a status-based colored background pattern
class _StatusColoredRow extends StatelessWidget {
  final Cheque cheque;
  final Widget child;

  const _StatusColoredRow({required this.cheque, required this.child});

  @override
  Widget build(BuildContext context) {
    final info = _statusDecoration(cheque.status);
    if (info == null) return child;

    return Stack(
      children: [
        // Background pattern layer
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CustomPaint(
              painter: _PatternPainter(
                color: info.$1,
                icon: info.$2,
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }

  // Returns (color, icon) or null for active/draft
  static (Color, IconData)? _statusDecoration(ChequeStatus status) {
    switch (status) {
      case ChequeStatus.cleared:
        return (const Color(0xFF4CAF50), Icons.check_circle_outline);
      case ChequeStatus.returned:
        return (const Color(0xFFF44336), Icons.cancel_outlined);
      case ChequeStatus.cancelled:
        return (const Color(0xFF607D8B), Icons.block_outlined);
      default:
        return null;
    }
  }
}

class _PatternPainter extends CustomPainter {
  final Color color;
  final IconData icon;

  _PatternPainter({required this.color, required this.icon});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.06)
      ..style = PaintingStyle.fill;

    // Subtle diagonal stripe pattern
    final stripeWidth = 24.0;
    final path = Path();
    for (double x = -size.height; x < size.width + size.height; x += stripeWidth * 2) {
      path.moveTo(x, 0);
      path.lineTo(x + stripeWidth, 0);
      path.lineTo(x + stripeWidth + size.height, size.height);
      path.lineTo(x + size.height, size.height);
      path.close();
    }
    canvas.drawPath(path, paint);

    // Draw large faded icon in the corner
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final iconSpan = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: 80,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: color.withOpacity(0.10),
      ),
    );
    textPainter.text = iconSpan;
    textPainter.layout();
    textPainter.paint(
        canvas,
        Offset(size.width - textPainter.width - 12,
            size.height / 2 - textPainter.height / 2));
  }

  @override
  bool shouldRepaint(_PatternPainter old) =>
      old.color != color || old.icon != icon;
}
