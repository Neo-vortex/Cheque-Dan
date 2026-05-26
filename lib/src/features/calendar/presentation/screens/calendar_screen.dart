import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/models/cheque_model.dart';
import '../../../../core/services/time_origin_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_utils.dart' as du;
import '../../../../features/cheques/presentation/blocs/cheque_bloc.dart';
import '../../../../features/cheques/presentation/screens/cheque_detail_screen.dart';
import '../../../../shared/widgets/status_badge.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────

const _monthNames = [
  'فروردین','اردیبهشت','خرداد',
  'تیر',    'مرداد',   'شهریور',
  'مهر',    'آبان',    'آذر',
  'دی',     'بهمن',    'اسفند',
];
const _weekHeaders = ['ش','ی','د','س','چ','پ','ج'];

String _p(int n) {
  const d = ['۰','۱','۲','۳','۴','۵','۶','۷','۸','۹'];
  return n.toString().split('').map((c) {
    final i = int.tryParse(c);
    return i != null ? d[i] : c;
  }).join();
}

/// Saturday-first column for Jalali day 1
int _firstOffset(int y, int m) {
  final wd = Jalali(y, m, 1).toDateTime().weekday;
  return const {6:0,7:1,1:2,2:3,3:4,4:5,5:6}[wd] ?? 0;
}

int _daysInMonth(int y, int m) => Jalali(y, m).monthLength;

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with TickerProviderStateMixin {

  late int _year, _month;
  DateTime? _selectedDay;
  int _slideDir = 1;
  late int _prevYear, _prevMonth;

  late AnimationController _slideCtrl;
  late AnimationController _listCtrl;

  // view modes: 'month' | 'week' | 'agenda'
  String _viewMode = 'month';

  @override
  void initState() {
    super.initState();
    final now = Jalali.fromDateTime(TimeOriginService.instance.today);
    _year = now.year; _month = now.month;
    _prevYear = _year; _prevMonth = _month;

    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _listCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250),
        value: 1.0);
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _listCtrl.dispose();
    super.dispose();
  }

  void _changeMonth(int delta) {
    HapticFeedback.selectionClick();
    setState(() {
      _slideDir = delta;
      _prevYear = _year; _prevMonth = _month;
      _month += delta;
      if (_month > 12) { _month = 1; _year++; }
      if (_month < 1)  { _month = 12; _year--; }
    });
    _slideCtrl.forward(from: 0);
  }

  void _selectDay(DateTime day) {
    HapticFeedback.selectionClick();
    _listCtrl.reverse().then((_) {
      if (mounted) {
        setState(() => _selectedDay = day);
        _listCtrl.forward();
      }
    });
  }

  void _goToToday() {
    HapticFeedback.mediumImpact();
    final now = Jalali.fromDateTime(TimeOriginService.instance.today);
    final todayDt = TimeOriginService.instance.today;
    setState(() {
      _slideDir = now.year > _year || (now.year == _year && now.month >= _month) ? 1 : -1;
      _prevYear = _year; _prevMonth = _month;
      _year = now.year; _month = now.month;
      _selectedDay = todayDt;
    });
    _slideCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<ChequeBloc, ChequeState>(
        builder: (ctx, state) {
          List<Cheque> allCheques = [];
          if (state is ChequesLoaded) allCheques = state.cheques;
          if (state is ChequeOperationSuccess) allCheques = state.cheques;
          // exclude archived
          allCheques = allCheques.where((c) => !c.isArchived).toList();

          final eventMap = _buildEventMap(allCheques);
          final selectedEvents = _selectedDay != null
              ? _eventsForDay(_selectedDay!, eventMap)
              : <Cheque>[];

          return CustomScrollView(
            slivers: [
              _buildSliverAppBar(allCheques, eventMap),
              SliverToBoxAdapter(child: _buildCalendarBody(eventMap)),
              SliverToBoxAdapter(child: _buildSelectedDaySummary(selectedEvents)),
              _buildEventsList(ctx, selectedEvents),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
      ),
    );
  }

  // ── Sliver App Bar ─────────────────────────────────────────────────────────

  Widget _buildSliverAppBar(List<Cheque> all, Map<DateTime, List<Cheque>> map) {
    // monthly stats
    final monthStart = Jalali(_year, _month, 1).toDateTime();
    final monthEnd = Jalali(
        _year, _month, _daysInMonth(_year, _month)).toDateTime();
    final thisMonth = all.where((c) =>
        !c.dueDate.isBefore(monthStart) && !c.dueDate.isAfter(monthEnd)).toList();
    final totalIssued = thisMonth.where((c) => c.direction == ChequeDirection.issued)
        .fold(0.0, (s, c) => s + c.amount);
    final totalReceived = thisMonth.where((c) => c.direction == ChequeDirection.received)
        .fold(0.0, (s, c) => s + c.amount);
    final overdueCount = all.where((c) =>
        c.isActive && c.dueDate.isBefore(TimeOriginService.instance.today)).length;

    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      title: _buildMonthNavRow(),
      actions: [
        IconButton(
          icon: const Icon(Icons.today_outlined),
          onPressed: _goToToday,
          tooltip: 'برو به امروز',
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.view_agenda_outlined),
          onSelected: (v) => setState(() => _viewMode = v),
          itemBuilder: (_) => [
            PopupMenuItem(value: 'month', child: Row(children: [
              Icon(Icons.calendar_view_month, size: 18,
                  color: _viewMode == 'month' ? AppColors.primary : null),
              const SizedBox(width: 8), const Text('ماهانه'),
            ])),
            PopupMenuItem(value: 'agenda', child: Row(children: [
              Icon(Icons.view_agenda, size: 18,
                  color: _viewMode == 'agenda' ? AppColors.primary : null),
              const SizedBox(width: 8), const Text('دفترچه'),
            ])),
          ],
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryDark, AppColors.primary, AppColors.primaryLight],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 56, left: 20, right: 20, bottom: 12),
              child: Row(
                children: [
                  _StatPill(label: 'صادره این ماه', value: CurrencyFormatter.formatCompact(totalIssued),
                      color: AppColors.issued, icon: Icons.arrow_upward_rounded),
                  const SizedBox(width: 8),
                  _StatPill(label: 'دریافتی این ماه', value: CurrencyFormatter.formatCompact(totalReceived),
                      color: AppColors.received, icon: Icons.arrow_downward_rounded),
                  const SizedBox(width: 8),
                  if (overdueCount > 0)
                    _StatPill(label: 'سررسید گذشته', value: _p(overdueCount),
                        color: AppColors.overdue, icon: Icons.warning_amber_rounded),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMonthNavRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => _changeMonth(-1),
          child: const Icon(Icons.chevron_right, size: 22),
        ),
        const SizedBox(width: 4),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            '${_monthNames[_month - 1]} ${_p(_year)}',
            key: ValueKey('$_year-$_month'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => _changeMonth(1),
          child: const Icon(Icons.chevron_left, size: 22),
        ),
      ],
    );
  }

  // ── Calendar body ──────────────────────────────────────────────────────────

  Widget _buildCalendarBody(Map<DateTime, List<Cheque>> eventMap) {
    if (_viewMode == 'agenda') return _buildAgendaView(eventMap);
    return _buildMonthGrid(eventMap);
  }

  Widget _buildMonthGrid(Map<DateTime, List<Cheque>> eventMap) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Week day headers
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Row(
              children: _weekHeaders.map((h) => Expanded(
                child: Center(
                  child: Text(h,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: h == 'ج'
                          ? AppColors.returned
                          : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ),
              )).toList(),
            ),
          ),
          const Divider(height: 1),
          // Animated month grid
          SizedBox(
            height: 252,
            child: _buildAnimatedGrid(eventMap),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildAnimatedGrid(Map<DateTime, List<Cheque>> eventMap) {
    return AnimatedBuilder(
      animation: _slideCtrl,
      builder: (_, __) {
        final t = CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic);
        final forward = _slideDir > 0;
        final inStart = forward ? const Offset(1, 0) : const Offset(-1, 0);
        final outEnd  = forward ? const Offset(-1, 0) : const Offset(1, 0);
        final animating = _slideCtrl.value > 0 && _slideCtrl.value < 1;

        return Stack(
          children: [
            if (animating)
              SlideTransition(
                position: Tween(begin: Offset.zero, end: outEnd).animate(t),
                child: _MonthGridWidget(
                  year: _prevYear, month: _prevMonth,
                  selectedDay: _selectedDay, eventMap: eventMap,
                  onDayTap: _selectDay,
                  today: TimeOriginService.instance.today,
                ),
              ),
            SlideTransition(
              position: animating
                  ? Tween(begin: inStart, end: Offset.zero).animate(t)
                  : AlwaysStoppedAnimation(Offset.zero),
              child: _MonthGridWidget(
                year: _year, month: _month,
                selectedDay: _selectedDay, eventMap: eventMap,
                onDayTap: _selectDay,
                today: TimeOriginService.instance.today,
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Agenda view ────────────────────────────────────────────────────────────

  Widget _buildAgendaView(Map<DateTime, List<Cheque>> eventMap) {
    // Show next 30 days with cheques, grouped by day
    final today = TimeOriginService.instance.today;
    final days = List.generate(45, (i) => today.add(Duration(days: i)));
    final daysWithEvents = days.where((d) {
      final key = DateTime(d.year, d.month, d.day);
      return eventMap.containsKey(key);
    }).toList();

    if (daysWithEvents.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Text('چکی در ۴۵ روز آینده ندارید',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: daysWithEvents.map((day) {
          final key = DateTime(day.year, day.month, day.day);
          final cheques = eventMap[key]!;
          final jalali = Jalali.fromDateTime(day);
          final isToday = du.DateUtils.isSameDay(day, today);
          return _AgendaDay(
            jalali: jalali,
            cheques: cheques,
            isToday: isToday,
            onChequeTap: (c) => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: context.read<ChequeBloc>(),
                  child: ChequeDetailScreen(cheque: c),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Selected day ───────────────────────────────────────────────────────────

  Widget _buildSelectedDaySummary(List<Cheque> events) {
    if (_selectedDay == null || _viewMode == 'agenda') {
      return const SizedBox(height: 8);
    }
    final j = Jalali.fromDateTime(_selectedDay!);
    final issued   = events.where((c) => c.direction == ChequeDirection.issued).toList();
    final received = events.where((c) => c.direction == ChequeDirection.received).toList();
    final totalI = issued.fold(0.0, (s, c) => s + c.amount);
    final totalR = received.fold(0.0, (s, c) => s + c.amount);

    return AnimatedBuilder(
      animation: _listCtrl,
      builder: (_, child) => FadeTransition(
        opacity: _listCtrl,
        child: SlideTransition(
          position: Tween<Offset>(
              begin: const Offset(0, 0.1), end: Offset.zero)
              .animate(_listCtrl),
          child: child,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withOpacity(0.08),
              AppColors.primary.withOpacity(0.03),
            ],
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withOpacity(0.18)),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(_p(j.day),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_monthNames[j.month-1]} ${_p(j.year)}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: AppColors.primary),
                  ),
                  if (events.isEmpty)
                    const Text('چکی ندارد', style: TextStyle(fontSize: 12,
                        color: AppColors.textSecondary))
                  else
                    Text('${_p(events.length)} چک',
                        style: const TextStyle(fontSize: 12,
                            color: AppColors.textSecondary)),
                ],
              ),
            ),
            if (events.isNotEmpty) ...[
              if (issued.isNotEmpty)
                _MiniStat(
                    label: 'صادره',
                    value: CurrencyFormatter.formatCompact(totalI),
                    color: AppColors.issued),
              const SizedBox(width: 8),
              if (received.isNotEmpty)
                _MiniStat(
                    label: 'دریافتی',
                    value: CurrencyFormatter.formatCompact(totalR),
                    color: AppColors.received),
            ],
          ],
        ),
      ),
    );
  }

  // ── Events list ────────────────────────────────────────────────────────────

  Widget _buildEventsList(BuildContext ctx, List<Cheque> events) {
    if (_viewMode == 'agenda') return const SliverToBoxAdapter(child: SizedBox.shrink());
    if (_selectedDay == null) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 32),
          child: Column(
            children: [
              Icon(Icons.touch_app_outlined, size: 48,
                  color: Colors.grey.withOpacity(0.4)),
              const SizedBox(height: 8),
              Text('یک روز را انتخاب کنید',
                  style: TextStyle(
                      color: Colors.grey.withOpacity(0.6), fontSize: 14)),
            ],
          ),
        ),
      );
    }
    if (events.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Center(
            child: Text(AppStrings.noChequesForDay,
                style: const TextStyle(color: AppColors.textSecondary)),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (_, i) => AnimatedBuilder(
          animation: _listCtrl,
          builder: (_, child) => FadeTransition(
            opacity: _listCtrl,
            child: SlideTransition(
              position: Tween<Offset>(
                      begin: Offset(0, 0.05 * (i + 1)), end: Offset.zero)
                  .animate(_listCtrl),
              child: child,
            ),
          ),
          child: _RichChequeTile(
            cheque: events[i],
            onTap: () => Navigator.push(
              ctx,
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: ctx.read<ChequeBloc>(),
                  child: ChequeDetailScreen(cheque: events[i]),
                ),
              ),
            ),
          ),
        ),
        childCount: events.length,
      ),
    );
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  Map<DateTime, List<Cheque>> _buildEventMap(List<Cheque> cheques) {
    final map = <DateTime, List<Cheque>>{};
    for (final c in cheques) {
      final key = DateTime(c.dueDate.year, c.dueDate.month, c.dueDate.day);
      map[key] = [...(map[key] ?? []), c];
    }
    return map;
  }

  List<Cheque> _eventsForDay(DateTime day, Map<DateTime, List<Cheque>> map) {
    return map[DateTime(day.year, day.month, day.day)] ?? [];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MONTH GRID WIDGET (stateless, drawn per month)
// ─────────────────────────────────────────────────────────────────────────────

class _MonthGridWidget extends StatelessWidget {
  final int year, month;
  final DateTime? selectedDay;
  final Map<DateTime, List<Cheque>> eventMap;
  final ValueChanged<DateTime> onDayTap;
  final DateTime today;

  const _MonthGridWidget({
    required this.year, required this.month,
    required this.selectedDay, required this.eventMap,
    required this.onDayTap, required this.today,
  });

  @override
  Widget build(BuildContext context) {
    final offset = _firstOffset(year, month);
    final dim    = _daysInMonth(year, month);
    const rows = 6;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: List.generate(rows, (row) => Expanded(
          child: Row(
            children: List.generate(7, (col) {
              final d = row * 7 + col - offset + 1;
              if (d < 1 || d > dim) return const Expanded(child: SizedBox());

              final dt = Jalali(year, month, d).toDateTime();
              final key = DateTime(dt.year, dt.month, dt.day);
              final events = eventMap[key] ?? [];
              final isSelected = selectedDay != null &&
                  du.DateUtils.isSameDay(dt, selectedDay!);
              final isToday = du.DateUtils.isSameDay(dt, today);
              final isFri = col == 6;
              final hasOverdue = events.any((c) => c.isActive && c.dueDate.isBefore(today));
              final hasEvents = events.isNotEmpty;

              return Expanded(
                child: _DayCell(
                  label: _p(d),
                  isSelected: isSelected,
                  isToday: isToday,
                  isFriday: isFri,
                  hasEvents: hasEvents,
                  hasOverdue: hasOverdue,
                  eventCount: events.length,
                  onTap: () => onDayTap(dt),
                ),
              );
            }),
          ),
        )),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final String label;
  final bool isSelected, isToday, isFriday, hasEvents, hasOverdue;
  final int eventCount;
  final VoidCallback onTap;

  const _DayCell({
    required this.label,
    required this.isSelected,
    required this.isToday,
    required this.isFriday,
    required this.hasEvents,
    required this.hasOverdue,
    required this.eventCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bg = Colors.transparent;
    Color fg;

    if (isSelected) {
      bg = AppColors.primary;
      fg = Colors.white;
    } else if (isToday) {
      bg = AppColors.primary.withOpacity(0.14);
      fg = AppColors.primary;
    } else {
      fg = isFriday ? AppColors.returned : Theme.of(context).colorScheme.onSurface;
    }

    final dotColor = hasOverdue
        ? AppColors.overdue
        : (hasEvents ? AppColors.secondary : Colors.transparent);

    return GestureDetector(
      onTap: onTap,
      // Bug 8 fix: ensure minimum 44×44 touch target (accessibility standard)
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.all(1),
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: isToday && !isSelected
              ? Border.all(color: AppColors.primary.withOpacity(0.5), width: 1.5)
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(label,
              style: TextStyle(
                fontSize: 13,
                color: fg,
                fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
            // dot indicator at bottom
            if (hasEvents)
              Positioned(
                bottom: 3,
                child: Container(
                  width: eventCount > 1 ? 12 : 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white.withOpacity(0.8) : dotColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AGENDA VIEW
// ─────────────────────────────────────────────────────────────────────────────

class _AgendaDay extends StatelessWidget {
  final Jalali jalali;
  final List<Cheque> cheques;
  final bool isToday;
  final ValueChanged<Cheque> onChequeTap;

  const _AgendaDay({
    required this.jalali, required this.cheques,
    required this.isToday, required this.onChequeTap,
  });

  @override
  Widget build(BuildContext context) {
    const weekdays = {1:'دو',2:'سه',3:'چهار',4:'پنج',5:'جمعه',6:'شنبه',7:'یک'};
    final wd = weekdays[Jalali(jalali.year, jalali.month, jalali.day)
        .toDateTime().weekday] ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day column
          SizedBox(
            width: 48,
            child: Column(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: isToday ? AppColors.primary : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(_p(jalali.day),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isToday ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(wd,
                  style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              children: cheques.map((c) => _RichChequeTile(
                cheque: c, onTap: () => onChequeTap(c),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RICH CHEQUE TILE
// ─────────────────────────────────────────────────────────────────────────────

class _RichChequeTile extends StatelessWidget {
  final Cheque cheque;
  final VoidCallback onTap;

  const _RichChequeTile({required this.cheque, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isIssued = cheque.direction == ChequeDirection.issued;
    final accentColor = isIssued ? AppColors.issued : AppColors.received;
    final today = TimeOriginService.instance.today;
    final overdue = cheque.isActive && cheque.dueDate.isBefore(today);
    final daysLeft = cheque.dueDate.difference(today).inDays;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Colored accent bar
              Container(
                width: 4, height: 52,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(cheque.counterpartyName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(cheque.amount),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(cheque.bankName,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary)),
                        const Spacer(),
                        StatusBadge(status: cheque.status, small: true),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Due date badge
              _DueBadge(overdue: overdue, daysLeft: daysLeft, status: cheque.status),
            ],
          ),
        ),
      ),
    );
  }
}

class _DueBadge extends StatelessWidget {
  final bool overdue;
  final int daysLeft;
  final ChequeStatus status;

  const _DueBadge({required this.overdue, required this.daysLeft, required this.status});

  @override
  Widget build(BuildContext context) {
    if (!status.isActive) return const SizedBox.shrink();

    final color = overdue
        ? AppColors.overdue
        : daysLeft == 0
            ? AppColors.dueToday
            : daysLeft <= 3
                ? AppColors.upcoming
                : AppColors.safe;

    final label = overdue
        ? '${_p(daysLeft.abs())}d پیش'
        : daysLeft == 0
            ? 'امروز'
            : '${_p(daysLeft)} روز';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SMALL HELPERS
// ─────────────────────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;

  const _StatPill({required this.label, required this.value,
      required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(label,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 9),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  final Color color;

  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(value,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        Text(label,
          style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
      ],
    );
  }
}
