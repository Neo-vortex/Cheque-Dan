// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_utils.dart' as du;

// ═══════════════════════════════════════════════════════════════════════════
// PUBLIC FIELD WIDGET
// ═══════════════════════════════════════════════════════════════════════════

class PersianDatePickerField extends StatelessWidget {
  final DateTime? selectedDate;
  final Function(DateTime) onDateSelected;
  final String label;
  final String? errorText;
  final DateTime? firstDate;
  final DateTime? lastDate;

  const PersianDatePickerField({
    super.key,
    this.selectedDate,
    required this.onDateSelected,
    required this.label,
    this.errorText,
    this.firstDate,
    this.lastDate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final fillColor = theme.inputDecorationTheme.fillColor ?? colorScheme.surfaceVariant;
    final borderColor = theme.inputDecorationTheme.enabledBorder?.borderSide.color
        ?? colorScheme.outline;

    return GestureDetector(
      onTap: () => _pickDate(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: errorText != null ? colorScheme.error : borderColor,
            width: errorText != null ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                color: colorScheme.onSurface.withOpacity(0.55), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurface.withOpacity(0.55))),
                  const SizedBox(height: 2),
                  Text(
                    selectedDate != null
                        ? du.DateUtils.toPersianFull(selectedDate!)
                        : 'انتخاب کنید',
                    style: TextStyle(
                      color: selectedDate != null
                          ? colorScheme.onSurface
                          : colorScheme.onSurface.withOpacity(0.38),
                      fontSize: 14,
                      fontWeight: selectedDate != null
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selectedDate != null
                  ? Icons.edit_calendar_outlined
                  : Icons.arrow_drop_down,
              color: selectedDate != null
                  ? colorScheme.primary
                  : colorScheme.onSurface.withOpacity(0.55),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final initial =
    selectedDate != null ? Jalali.fromDateTime(selectedDate!) : Jalali.now();
    final first = firstDate != null
        ? Jalali.fromDateTime(firstDate!)
        : Jalali(1379, 1, 1);
    final last = lastDate != null
        ? Jalali.fromDateTime(lastDate!)
        : Jalali(1414, 12, 29);

    final picked = await showJalaliDatePickerDialog(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );

    if (picked != null) onDateSelected(picked.toDateTime());
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DIALOG LAUNCHER
// ═══════════════════════════════════════════════════════════════════════════

Future<Jalali?> showJalaliDatePickerDialog({
  required BuildContext context,
  required Jalali initialDate,
  required Jalali firstDate,
  required Jalali lastDate,
}) {
  return showGeneralDialog<Jalali>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'dismiss',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 300),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.88, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
    pageBuilder: (ctx, _, __) => _JalaliPickerDialog(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════

const _kDialogWidth  = 340.0;
const _kHeaderHeight = 96.0;
const _kBodyHeight   = 300.0; // fixed — never changes regardless of mode
const _kFooterHeight = 60.0;

const _monthNames = [
  'فروردین', 'اردیبهشت', 'خرداد',
  'تیر',     'مرداد',    'شهریور',
  'مهر',     'آبان',     'آذر',
  'دی',      'بهمن',     'اسفند',
];
// Jalali week: Saturday first
const _weekHeaders = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];

// ═══════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════

/// Convert integer to Persian-digit string (used for ALL numbers now)
String _p(int n) {
  const d = ['۰','۱','۲','۳','۴','۵','۶','۷','۸','۹'];
  return n.toString().split('').map((c) {
    final i = int.tryParse(c);
    return i != null ? d[i] : c;
  }).join();
}

// Keep old alias for year labels
String _pYear(int n) => _p(n);

int _daysInMonth(int y, int m) => Jalali(y, m).monthLength;

/// Saturday-based column offset for the 1st of a given month (0=Sat … 6=Fri)
int _firstOffset(int y, int m) {
  final wd = Jalali(y, m, 1).toDateTime().weekday;
  return const {6:0, 7:1, 1:2, 2:3, 3:4, 4:5, 5:6}[wd] ?? 0;
}

String _weekDayName(int y, int m, int d) {
  final wd = Jalali(y, m, d).toDateTime().weekday;
  return const {
    1:'دوشنبه', 2:'سه‌شنبه', 3:'چهارشنبه',
    4:'پنج‌شنبه', 5:'جمعه', 6:'شنبه', 7:'یکشنبه',
  }[wd] ?? '';
}

extension _JalaliX on Jalali {
  bool isBefore(Jalali o) {
    if (year  != o.year)  return year  < o.year;
    if (month != o.month) return month < o.month;
    return day < o.day;
  }
  bool isAfter(Jalali o) {
    if (year  != o.year)  return year  > o.year;
    if (month != o.month) return month > o.month;
    return day > o.day;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DIALOG WIDGET
// ═══════════════════════════════════════════════════════════════════════════

enum _Mode { calendar, month, year }

class _JalaliPickerDialog extends StatefulWidget {
  final Jalali initialDate;
  final Jalali firstDate;
  final Jalali lastDate;

  const _JalaliPickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<_JalaliPickerDialog> createState() => _JalaliPickerDialogState();
}

class _JalaliPickerDialogState extends State<_JalaliPickerDialog>
    with TickerProviderStateMixin {

  late int _year, _month, _day;
  _Mode _mode = _Mode.calendar;

  // Slide animation for month navigation
  late AnimationController _slideCtrl;
  int _slideDir = 1;
  late int _prevYear, _prevMonth;

  // Fade animation for mode switching
  late AnimationController _modeCtrl;

  @override
  void initState() {
    super.initState();
    _year  = widget.initialDate.year;
    _month = widget.initialDate.month;
    _day   = widget.initialDate.day;
    _prevYear  = _year;
    _prevMonth = _month;

    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));

    _modeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200),
        value: 1.0);
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _modeCtrl.dispose();
    super.dispose();
  }

  // ── mode switching ────────────────────────────────────────────────────────

  void _setMode(_Mode m) {
    if (_mode == m) {
      // clicking same chip → go back to calendar
      _switchMode(_Mode.calendar);
    } else {
      _switchMode(m);
    }
  }

  void _switchMode(_Mode m) {
    HapticFeedback.lightImpact();
    _modeCtrl.reverse().then((_) {
      if (mounted) {
        setState(() => _mode = m);
        _modeCtrl.forward();
      }
    });
  }

  // ── month navigation ──────────────────────────────────────────────────────

  void _changeMonth(int delta) {
    HapticFeedback.selectionClick();
    setState(() {
      _slideDir  = delta;
      _prevYear  = _year;
      _prevMonth = _month;
      _month += delta;
      if (_month > 12) { _month = 1;  _year++; }
      if (_month < 1)  { _month = 12; _year--; }
      _day = _day.clamp(1, _daysInMonth(_year, _month));
    });
    _slideCtrl.forward(from: 0);
  }

  // ── range check ───────────────────────────────────────────────────────────

  bool _inRange(int y, int m, int d) {
    final j = Jalali(y, m, d);
    return !j.isBefore(widget.firstDate) && !j.isAfter(widget.lastDate);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final surfaceColor = Theme.of(context).colorScheme.surface;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width:  _kDialogWidth,
            height: _kHeaderHeight + _kBodyHeight + _kFooterHeight,
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.20),
                  blurRadius: 40,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Column(
                children: [
                  _buildHeader(),
                  SizedBox(
                    height: _kBodyHeight,
                    child: FadeTransition(
                      opacity: CurvedAnimation(
                          parent: _modeCtrl, curve: Curves.easeInOut),
                      child: _buildBody(),
                    ),
                  ),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final today = Jalali.now();
    final isToday = today.year == _year && today.month == _month
        && today.day == _day;

    return Container(
      height: _kHeaderHeight,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Selected date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isToday ? 'امروز' : _weekDayName(_year, _month, _day),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.25), end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: Text(
                    '${ _p(_day)} ${_monthNames[_month - 1]} ${_pYear(_year)}',
                    key: ValueKey('$_year/$_month/$_day'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Month / Year chips
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _HeaderChip(
                label: _monthNames[_month - 1],
                active: _mode == _Mode.month,
                onTap: () => _setMode(_Mode.month),
              ),
              const SizedBox(height: 6),
              _HeaderChip(
                label: _pYear(_year),
                active: _mode == _Mode.year,
                onTap: () => _setMode(_Mode.year),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BODY
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    switch (_mode) {
      case _Mode.calendar: return _buildCalendarView();
      case _Mode.month:    return _buildMonthGrid();
      case _Mode.year:     return _buildYearGrid();
    }
  }

  // ── Calendar view ──────────────────────────────────────────────────────────

  Widget _buildCalendarView() {
    return Column(
      children: [
        _buildMonthNavBar(),
        _buildWeekHeaders(),
        Expanded(child: _buildDayGrid()),
      ],
    );
  }

  Widget _buildMonthNavBar() {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          _NavBtn(icon: Icons.chevron_right, onTap: () => _changeMonth(-1)),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                '${_monthNames[_month - 1]}  ${_pYear(_year)}',
                key: ValueKey('$_year-$_month'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
          _NavBtn(icon: Icons.chevron_left, onTap: () => _changeMonth(1)),
        ],
      ),
    );
  }

  Widget _buildWeekHeaders() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: _weekHeaders.map((h) {
          return Expanded(
            child: Center(
              child: Text(h,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: h == 'ج' ? AppColors.returned : Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDayGrid() {
    const rows = 6;
    return AnimatedBuilder(
      animation: _slideCtrl,
      builder: (_, __) {
        final forward = _slideDir > 0;
        final t = CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic);
        final inStart  = forward ? const Offset(1, 0) : const Offset(-1, 0);
        final outEnd   = forward ? const Offset(-1, 0) : const Offset(1, 0);
        final animating = _slideCtrl.value > 0 && _slideCtrl.value < 1;

        return Stack(
          children: [
            // Previous month sliding out (only during animation)
            if (animating)
              SlideTransition(
                position: Tween(begin: Offset.zero, end: outEnd).animate(t),
                child: _gridWidget(_prevYear, _prevMonth, rows),
              ),
            // Current month sliding in (always visible)
            SlideTransition(
              position: animating
                  ? Tween(begin: inStart, end: Offset.zero).animate(t)
                  : AlwaysStoppedAnimation(Offset.zero),
              child: _gridWidget(_year, _month, rows),
            ),
          ],
        );
      },
    );
  }

  Widget _gridWidget(int year, int month, int rows) {
    final offset = _firstOffset(year, month);
    final dim    = _daysInMonth(year, month);
    final today  = Jalali.now();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: List.generate(rows, (row) {
          return Expanded(
            child: Row(
              children: List.generate(7, (col) {
                final d = row * 7 + col - offset + 1;
                if (d < 1 || d > dim) {
                  return const Expanded(child: SizedBox());
                }
                final inRange  = _inRange(year, month, d);
                final selected = year == _year && month == _month && d == _day;
                final isToday  = today.year == year && today.month == month
                    && today.day == d;
                final isFri    = col == 6;

                return Expanded(
                  child: _DayCell(
                    dayLabel: _p(d),          // Persian digits
                    selected: selected,
                    today: isToday,
                    inRange: inRange,
                    isFriday: isFri,
                    onTap: inRange
                        ? () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _year = year; _month = month; _day = d;
                      });
                    }
                        : null,
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }

  // ── Month grid (4×3) ──────────────────────────────────────────────────────

  Widget _buildMonthGrid() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 2.2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: 12,
        itemBuilder: (_, i) {
          final m = i + 1;
          final isSelected = m == _month;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _month = m);
              _switchMode(_Mode.calendar);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : Theme.of(context).dividerColor,
                ),
              ),
              child: Center(
                child: Text(
                  _monthNames[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Year grid ──────────────────────────────────────────────────────────────

  Widget _buildYearGrid() {
    final firstY = widget.firstDate.year;
    final lastY  = widget.lastDate.year;
    final years  = List.generate(lastY - firstY + 1, (i) => firstY + i);

    // Scroll to selected year
    final scrollCtrl = ScrollController(
      initialScrollOffset: ((_year - firstY) ~/ 4) * 52.0,
    );

    return Scrollbar(
      controller: scrollCtrl,
      child: GridView.builder(
        controller: scrollCtrl,
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 1.8,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
        ),
        itemCount: years.length,
        itemBuilder: (_, i) {
          final y = years[i];
          final isSelected = y == _year;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _year = y;
                _day = _day.clamp(1, _daysInMonth(_year, _month));
              });
              _switchMode(_Mode.calendar);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                ),
              ),
              child: Center(
                child: Text(
                  _pYear(y),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                    color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FOOTER
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    return Container(
      height: _kFooterHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: _goToToday,
            icon: const Icon(Icons.today_outlined,
                size: 16, color: AppColors.primary),
            label: const Text('امروز',
                style: TextStyle(fontSize: 13, color: AppColors.primary)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('انصراف', style: TextStyle(fontSize: 14)),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.pop(context, Jalali(_year, _month, _day));
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('تأیید',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _goToToday() {
    HapticFeedback.lightImpact();
    final t = Jalali.now();
    if (!_inRange(t.year, t.month, t.day)) return;
    // Always switch to calendar first, then update date
    if (_mode != _Mode.calendar) {
      _modeCtrl.reverse().then((_) {
        if (!mounted) return;
        setState(() {
          _mode  = _Mode.calendar;
          _prevYear  = _year;
          _prevMonth = _month;
          _year  = t.year;
          _month = t.month;
          _day   = t.day;
          _slideCtrl.value = 0; // no slide animation — instant
        });
        _modeCtrl.forward();
      });
    } else {
      setState(() {
        _prevYear  = _year;
        _prevMonth = _month;
        _year  = t.year;
        _month = t.month;
        _day   = t.day;
        _slideCtrl.value = 0;
      });
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// REUSABLE WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _HeaderChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _HeaderChip(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? Colors.white.withOpacity(0.25)
              : Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? Colors.white.withOpacity(0.7)
                : Colors.white.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                )),
            const SizedBox(width: 2),
            Icon(
              active ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: Colors.white.withOpacity(0.85),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NavBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44, height: 44,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Icon(icon, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), size: 22),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final String dayLabel;  // plain ASCII "1".."31"
  final bool selected;
  final bool today;
  final bool inRange;
  final bool isFriday;
  final VoidCallback? onTap;

  const _DayCell({
    required this.dayLabel,
    required this.selected,
    required this.today,
    required this.inRange,
    required this.isFriday,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    Color bg = Colors.transparent;
    Color fg;

    if (!inRange) {
      fg = colorScheme.onSurface.withOpacity(0.25);
    } else if (selected) {
      bg = colorScheme.primary;
      fg = Colors.white;
    } else if (today) {
      bg = colorScheme.primary.withOpacity(0.12);
      fg = colorScheme.primary;
    } else {
      fg = isFriday ? AppColors.returned : colorScheme.onSurface;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Center(
          child: Text(
            dayLabel,
            style: TextStyle(
              fontSize: 13,
              color: fg,
              fontWeight: selected || today ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
