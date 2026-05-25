import 'package:shamsi_date/shamsi_date.dart';

class DateUtils {
  DateUtils._();

  static String toPersianDayMonth(DateTime date) {
    final j = Jalali.fromDateTime(date);
    return '${_toFarsiNum(j.day)}/${_toFarsiNum(j.month, pad: false)}';
  }

  static String toPersian(DateTime date) {
    final j = Jalali.fromDateTime(date);
    return '${_toFarsiNum(j.year)}/${_toFarsiNum(j.month, pad: true)}/${_toFarsiNum(j.day, pad: true)}';
  }

  static String toPersianFull(DateTime date) {
    final j = Jalali.fromDateTime(date);
    final monthName = _monthNames[j.month - 1];
    return '${_toFarsiNum(j.day)} $monthName ${_toFarsiNum(j.year)}';
  }

  static String toPersianMonthShort(DateTime date) {
    final j = Jalali.fromDateTime(date);
    // Return abbreviated month name (first 3 chars of Persian month name)
    return _monthNames[j.month - 1].substring(0, _monthNames[j.month - 1].length > 3 ? 3 : _monthNames[j.month - 1].length);
  }

  static String toPersianMonthYear(DateTime date) {
    final j = Jalali.fromDateTime(date);
    return '${_monthNames[j.month - 1]} ${_toFarsiNum(j.year)}';
  }

  static String daysUntilText(int days) {
    if (days < 0) {
      final abs = days.abs();
      return '$abs روز پیش گذشت';
    } else if (days == 0) {
      return 'امروز';
    } else if (days == 1) {
      return 'فردا';
    } else {
      return 'تا $days روز دیگر';
    }
  }

  static DateTime? fromPersianString(String persianDate) {
    try {
      final parts = persianDate.split('/');
      if (parts.length != 3) return null;
      final year = int.parse(_fromFarsiNum(parts[0]));
      final month = int.parse(_fromFarsiNum(parts[1]));
      final day = int.parse(_fromFarsiNum(parts[2]));
      return Jalali(year, month, day).toDateTime();
    } catch (_) {
      return null;
    }
  }

  static String formatRange(DateTime start, DateTime end) {
    return '${toPersian(start)} تا ${toPersian(end)}';
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static final List<String> _monthNames = [
    'فروردین', 'اردیبهشت', 'خرداد',
    'تیر', 'مرداد', 'شهریور',
    'مهر', 'آبان', 'آذر',
    'دی', 'بهمن', 'اسفند',
  ];

  static String _toFarsiNum(int n, {bool pad = false}) {
    const digits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    final s = pad ? n.toString().padLeft(2, '0') : n.toString();
    return s.split('').map((c) => digits[int.parse(c)]).join();
  }

  static String _fromFarsiNum(String s) {
    const farsi = '۰۱۲۳۴۵۶۷۸۹';
    return s.split('').map((c) {
      final idx = farsi.indexOf(c);
      return idx >= 0 ? idx.toString() : c;
    }).join();
  }
}
