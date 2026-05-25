import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global "time origin" — replaces DateTime.now() for all business logic.
/// When the user manipulates the reference date, every relative calculation
/// (overdue, upcoming, days-left, cashflow) updates automatically.
class TimeOriginService extends ChangeNotifier {
  static final TimeOriginService instance = TimeOriginService._();
  TimeOriginService._();

  static const _kPrefKey = 'time_origin_epoch_ms';

  DateTime? _override; // null = real today

  /// Business-logic "today" — midnight-normalised.
  DateTime get today {
    final raw = _override ?? DateTime.now();
    return DateTime(raw.year, raw.month, raw.day);
  }

  /// True when user has set a custom origin different from real today.
  bool get isManipulated {
    if (_override == null) return false;
    final real = DateTime.now();
    final realDay = DateTime(real.year, real.month, real.day);
    return today != realDay;
  }

  /// Load persisted value on app start.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_kPrefKey);
    if (ms != null) {
      final saved = DateTime.fromMillisecondsSinceEpoch(ms);
      _override = DateTime(saved.year, saved.month, saved.day);
    }
    // Don't notify during init — no listeners yet.
  }

  Future<void> setOrigin(DateTime date) async {
    _override = DateTime(date.year, date.month, date.day);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPrefKey, _override!.millisecondsSinceEpoch);
    notifyListeners();
  }

  Future<void> resetToToday() async {
    _override = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefKey);
    notifyListeners();
  }

  /// Convenience — days between today (origin) and [date].
  int daysUntil(DateTime date) {
    final due = DateTime(date.year, date.month, date.day);
    return due.difference(today).inDays;
  }
}
