import 'dart:io' show Platform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/cheque_model.dart';
import '../constants/app_strings.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_utils.dart' as du;

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Open',
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      linux: linuxSettings,
    );

    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  Future<void> scheduleReminder({
    required Cheque cheque,
    required int daysBeforeDue,
  }) async {
    final scheduledDate = cheque.dueDate.subtract(Duration(days: daysBeforeDue));
    if (scheduledDate.isBefore(DateTime.now())) return;

    final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);

    await _plugin.zonedSchedule(
      cheque.hashCode,
      AppStrings.reminderTitle,
      'چک ${cheque.counterpartyName} به مبلغ ${CurrencyFormatter.format(cheque.amount)} در ${du.DateUtils.toPersian(cheque.dueDate)} سررسید دارد',
      tzDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'cheque_reminders',
          'یادآوری چک',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> showOverdueNotification({
    required int count,
    required double totalAmount,
  }) async {
    await _plugin.show(
      0,
      AppStrings.overdueTitle,
      '$count چک به مبلغ ${CurrencyFormatter.formatCompact(totalAmount)} گذشته از سررسید دارید',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'cheque_overdue',
          'چک معوق',
          importance: Importance.max,
          priority: Priority.max,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// Bug 3 fix: Request notification permission from the OS.
  /// Returns true if permission is granted.
  Future<bool> requestPermission() async {
    if (!_initialized) await initialize();
    // Android 13+ requires explicit permission
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      return granted ?? false;
    }
    // iOS: DarwinInitializationSettings already requests permission on init.
    // Re-request to ensure we have it.
    final iosPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      final granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    // On other platforms, assume granted
    return true;
  }

  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
