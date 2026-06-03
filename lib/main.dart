import 'dart:io';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:intl/date_symbol_data_local.dart';
import 'src/core/database/database_helper.dart';
import 'src/core/constants/app_strings.dart';
import 'src/core/services/time_origin_service.dart';
import 'src/features/cheques/presentation/screens/reconciliation_screen.dart';
import 'src/features/cheques/data/cheque_repository.dart';
import 'src/features/cheques/presentation/blocs/cheque_bloc.dart';
import 'src/features/cheque_books/data/cheque_book_repository.dart';
import 'src/features/cheque_books/presentation/blocs/cheque_book_bloc.dart';
import 'src/features/settings/data/settings_repository.dart';
import 'src/features/settings/presentation/blocs/settings_bloc.dart';
import 'src/shared/theme/app_theme.dart';
import 'src/shared/widgets/main_nav_shell.dart';
import 'src/core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fa_IR', null);
  tz.initializeTimeZones();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await DatabaseHelper.instance.database;
  await NotificationService.instance.initialize();
  await TimeOriginService.instance.init();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const ChequeApp());
}

class ChequeApp extends StatelessWidget {
  const ChequeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<TimeOriginService>.value(
      value: TimeOriginService.instance,
      child: MultiRepositoryProvider(
        providers: [
          RepositoryProvider(create: (_) => ChequeRepository()),
          RepositoryProvider(create: (_) => SettingsRepository()),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider(
              // Bug 1 fix: ChequeBookBloc created first so ChequeBloc can reference it
              create: (_) => ChequeBookBloc(ChequeBookRepository())
                ..add(const LoadChequeBooksEvent()),
            ),
            BlocProvider(
              create: (ctx) => ChequeBloc(
                ctx.read<ChequeRepository>(),
                chequeBookBloc: ctx.read<ChequeBookBloc>(),
              )..add(const LoadChequesEvent()),
            ),
            BlocProvider(
              create: (ctx) => SettingsBloc(ctx.read<SettingsRepository>())
                ..add(const LoadSettingsEvent()),
            ),
          ],
          child: BlocBuilder<SettingsBloc, SettingsState>(
            builder: (context, settingsState) {
              final isDark = settingsState is SettingsLoaded
                  ? settingsState.settings.darkMode
                  : false;
              return MaterialApp(
                title: AppStrings.appName,
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
                locale: const Locale('fa', 'IR'),
                supportedLocales: const [
                  Locale('fa', 'IR'),
                  Locale('en', 'US'),
                ],
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                builder: (context, child) {
                  return Directionality(
                    textDirection: TextDirection.rtl,
                    child: child!,
                  );
                },
                home: const AppEntryPoint(),
              );
            },
          ),
        ),
      ),
    );
  }
}

class AppEntryPoint extends StatefulWidget {
  const AppEntryPoint({super.key});

  @override
  State<AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<AppEntryPoint> {
  // null = still deciding, false = go straight to shell, true = show reconciliation
  bool? _needsReconciliation;

  /// Called once settings are confirmed loaded and cheque check is done.
  Future<void> _checkReconciliation(bool settingEnabled) async {
    if (!settingEnabled) {
      // Toggle is off — skip the screen entirely.
      if (mounted) setState(() => _needsReconciliation = false);
      return;
    }

    final repo = context.read<ChequeRepository>();
    final needs = await repo.hasChequesNeedingAttention();
    if (mounted) {
      setState(() => _needsReconciliation = needs);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SettingsBloc, SettingsState>(
      // Fire the cheque check as soon as settings finish loading.
      // listenWhen guards against re-firing on subsequent settings updates.
      listenWhen: (prev, curr) =>
          prev is! SettingsLoaded && curr is SettingsLoaded,
      listener: (context, state) {
        if (state is SettingsLoaded) {
          _checkReconciliation(state.settings.showReconciliationOnLaunch);
        }
      },
      child: Builder(builder: (context) {
        // Still waiting for settings load + async cheque check.
        if (_needsReconciliation == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (_needsReconciliation == true) {
          return ReconciliationScreen(
            onComplete: () => setState(() => _needsReconciliation = false),
          );
        }
        return const MainNavShell();
      }),
    );
  }
}
