import 'package:equatable/equatable.dart';

class AppSettings extends Equatable {
  final bool notificationsEnabled;
  final int reminderLeadDays;
  final int overdueReminderFrequencyHours;
  final bool showReconciliationOnLaunch;
  final bool darkMode;

  const AppSettings({
    this.notificationsEnabled = true,
    this.reminderLeadDays = 3,
    this.overdueReminderFrequencyHours = 24,
    this.showReconciliationOnLaunch = true,
    this.darkMode = false,
  });

  AppSettings copyWith({
    bool? notificationsEnabled,
    int? reminderLeadDays,
    int? overdueReminderFrequencyHours,
    bool? showReconciliationOnLaunch,
    bool? darkMode,
  }) {
    return AppSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      reminderLeadDays: reminderLeadDays ?? this.reminderLeadDays,
      overdueReminderFrequencyHours:
          overdueReminderFrequencyHours ?? this.overdueReminderFrequencyHours,
      showReconciliationOnLaunch:
          showReconciliationOnLaunch ?? this.showReconciliationOnLaunch,
      darkMode: darkMode ?? this.darkMode,
    );
  }

  Map<String, dynamic> toMap() => {
        'notifications_enabled': notificationsEnabled ? 1 : 0,
        'reminder_lead_days': reminderLeadDays,
        'overdue_reminder_frequency_hours': overdueReminderFrequencyHours,
        'show_reconciliation_on_launch': showReconciliationOnLaunch ? 1 : 0,
        'dark_mode': darkMode ? 1 : 0,
      };

  factory AppSettings.fromMap(Map<String, dynamic> map) => AppSettings(
        notificationsEnabled: map['notifications_enabled'] == 1,
        reminderLeadDays: map['reminder_lead_days'] ?? 3,
        overdueReminderFrequencyHours:
            map['overdue_reminder_frequency_hours'] ?? 24,
        showReconciliationOnLaunch:
            map['show_reconciliation_on_launch'] == 1,
        darkMode: map['dark_mode'] == 1,
      );

  @override
  List<Object?> get props => [
        notificationsEnabled,
        reminderLeadDays,
        overdueReminderFrequencyHours,
        showReconciliationOnLaunch,
        darkMode,
      ];
}
