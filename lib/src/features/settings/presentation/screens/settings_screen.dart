import 'package:flutter/material.dart';
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
                    value: settings.notificationsEnabled,
                    activeColor: AppColors.primary,
                    onChanged: (v) => _updateSettings(
                      context,
                      settings.copyWith(notificationsEnabled: v),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('روزهای یادآوری قبل از سررسید'),
                    subtitle: Text(
                        '${settings.reminderLeadDays} روز قبل'),
                    trailing: const Icon(Icons.chevron_left),
                    enabled: settings.notificationsEnabled,
                    onTap: settings.notificationsEnabled
                        ? () => _pickReminderDays(context, settings)
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
                    value: settings.showReconciliationOnLaunch,
                    activeColor: AppColors.primary,
                    onChanged: (v) => _updateSettings(
                      context,
                      settings.copyWith(
                          showReconciliationOnLaunch: v),
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
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700),
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
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
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
