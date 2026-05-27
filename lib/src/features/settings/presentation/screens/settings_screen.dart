import 'package:flutter/material.dart';
import '../../../../core/services/notification_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/models/settings_model.dart';
import '../blocs/settings_bloc.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.settings)),
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          final settings = state is SettingsLoaded
              ? state.settings
              : const AppSettings();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionTitle(title: 'ظاهر برنامه'),
              const SizedBox(height: 8),
              _SettingsCard(
                children: [
                  SwitchListTile(
                    title: const Text('حالت تاریک'),
                    subtitle: const Text('تغییر ظاهر برنامه به تم تیره'),
                    secondary: const Icon(Icons.dark_mode_outlined),
                    value: settings.darkMode,
                    activeColor: AppColors.primary,
                    onChanged: (v) => _updateSettings(
                      context,
                      settings.copyWith(darkMode: v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionTitle(title: 'اعلان‌ها'),
              const SizedBox(height: 8),
              _SettingsCard(
                children: [
                  SwitchListTile(
                    title: const Text('فعال کردن اعلان‌ها'),
                    subtitle:
                    const Text('دریافت یادآوری برای سررسید چک‌ها'),
                    secondary: const Icon(Icons.notifications_outlined),
                    value: settings.notificationsEnabled,
                    activeColor: AppColors.primary,
                    onChanged: (v) async {
                      if (v) {
                        final granted =
                        await NotificationService.instance.requestPermission();
                        if (!granted && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'برای دریافت اعلان، دسترسی را در تنظیمات گوشی فعال کنید'),
                              duration: Duration(seconds: 4),
                            ),
                          );
                          return;
                        }
                      }
                      if (context.mounted) {
                        _updateSettings(
                            context, settings.copyWith(notificationsEnabled: v));
                      }
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: const Text('روزهای یادآوری قبل از سررسید'),
                    subtitle: Text('${settings.reminderLeadDays} روز قبل'),
                    trailing: const Icon(Icons.chevron_left),
                    enabled: settings.notificationsEnabled,
                    onTap: settings.notificationsEnabled
                        ? () => _pickReminderDays(context, settings)
                        : null,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.access_time_outlined),
                    title: const Text('زمان ارسال اعلان'),
                    subtitle: Text(_formatHour(settings.reminderHour)),
                    trailing: const Icon(Icons.chevron_left),
                    enabled: settings.notificationsEnabled,
                    onTap: settings.notificationsEnabled
                        ? () => _pickReminderTime(context, settings)
                        : null,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.send_outlined),
                    title: const Text('تست اعلان'),
                    subtitle: const Text('ارسال یک اعلان آزمایشی'),
                    enabled: settings.notificationsEnabled,
                    onTap: settings.notificationsEnabled
                        ? () => _sendTestNotification(context)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionTitle(title: 'رفتار برنامه'),
              const SizedBox(height: 8),
              _SettingsCard(
                children: [
                  SwitchListTile(
                    title: const Text('بررسی در هنگام باز شدن'),
                    subtitle: const Text(
                        'نمایش صفحه بررسی چک‌ها هنگام باز شدن برنامه'),
                    secondary: const Icon(Icons.launch_outlined),
                    value: settings.showReconciliationOnLaunch,
                    activeColor: AppColors.primary,
                    onChanged: (v) => _updateSettings(
                      context,
                      settings.copyWith(showReconciliationOnLaunch: v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionTitle(title: 'درباره'),
              const SizedBox(height: 8),
              _SettingsCard(
                children: [
                  const ListTile(
                    title: Text('نسخه برنامه'),
                    trailing: Text(
                      '۱.۰.۰',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  const Divider(height: 1),
                  const ListTile(
                    title: Text('چک دان'),
                    subtitle: Text(
                        'مدیریت هوشمند چک‌ها با حال و هوای خوب!'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _updateSettings(BuildContext context, AppSettings settings) {
    context.read<SettingsBloc>().add(UpdateSettingsEvent(settings));
  }

  String _formatHour(int hour) {
    final period = hour < 12 ? 'صبح' : 'بعدازظهر';
    final h = hour == 0
        ? 12
        : hour <= 12
        ? hour
        : hour - 12;
    return 'ساعت $h $period';
  }

  Future<void> _sendTestNotification(BuildContext context) async {
    try {
      await NotificationService.instance.sendTestNotification();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('اعلان آزمایشی ارسال شد'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در ارسال اعلان: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _pickReminderDays(
      BuildContext context, AppSettings settings) async {
    final options = [1, 3, 7, 14];

    await showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'یادآوری قبل از سررسید',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...options.map(
                  (days) => RadioListTile<int>(
                title: Text('$days روز قبل'),
                value: days,
                groupValue: settings.reminderLeadDays,
                activeColor: AppColors.primary,
                onChanged: (v) {
                  if (v != null) {
                    _updateSettings(
                      context,
                      settings.copyWith(reminderLeadDays: v),
                    );
                    Navigator.pop(ctx);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickReminderTime(
      BuildContext context, AppSettings settings) async {
    // Preset hour options: common times
    final options = [6, 7, 8, 9, 10, 12, 14, 16, 18, 20];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'زمان ارسال اعلان',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'اعلان‌های یادآوری در این ساعت ارسال می‌شوند',
              style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.6)),
            ),
            const SizedBox(height: 12),
            ...options.map(
                  (hour) {
                final period = hour < 12 ? 'صبح' : 'بعدازظهر';
                final h = hour == 0
                    ? 12
                    : hour <= 12
                    ? hour
                    : hour - 12;
                return RadioListTile<int>(
                  title: Text('ساعت $h $period'),
                  value: hour,
                  groupValue: settings.reminderHour,
                  activeColor: AppColors.primary,
                  onChanged: (v) {
                    if (v != null) {
                      _updateSettings(
                        context,
                        settings.copyWith(reminderHour: v),
                      );
                      Navigator.pop(ctx);
                    }
                  },
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(children: children),
    );
  }
}
