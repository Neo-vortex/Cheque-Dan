import '../../../core/database/database_helper.dart';
import '../../../core/models/settings_model.dart';

class SettingsRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<AppSettings> getSettings() async {
    final all = await _db.getAllSettings();
    if (all.isEmpty) return const AppSettings();

    return AppSettings(
      notificationsEnabled: all['notifications_enabled'] == '1',
      reminderLeadDays: int.tryParse(all['reminder_lead_days'] ?? '3') ?? 3,
      reminderHour: int.tryParse(all['reminder_hour'] ?? '9') ?? 9,
      overdueReminderFrequencyHours:
      int.tryParse(all['overdue_reminder_frequency_hours'] ?? '24') ?? 24,
      showReconciliationOnLaunch:
      all['show_reconciliation_on_launch'] != '0',
      darkMode: all['dark_mode'] == '1',
    );
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _db.setSetting(
        'notifications_enabled', settings.notificationsEnabled ? '1' : '0');
    await _db.setSetting(
        'reminder_lead_days', settings.reminderLeadDays.toString());
    await _db.setSetting(
        'reminder_hour', settings.reminderHour.toString());
    await _db.setSetting('overdue_reminder_frequency_hours',
        settings.overdueReminderFrequencyHours.toString());
    await _db.setSetting('show_reconciliation_on_launch',
        settings.showReconciliationOnLaunch ? '1' : '0');
    await _db.setSetting('dark_mode', settings.darkMode ? '1' : '0');
  }
}
