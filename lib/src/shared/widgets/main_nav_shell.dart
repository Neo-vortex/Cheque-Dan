import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/cheques/presentation/screens/cheques_list_screen.dart';
import '../../features/calendar/presentation/screens/calendar_screen.dart';
import '../../features/analytics/presentation/screens/analytics_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/cheque_books/presentation/screens/cheque_books_screen.dart';
import '../../features/cheques/presentation/blocs/cheque_bloc.dart';
import '../../features/cheque_books/presentation/blocs/cheque_book_bloc.dart';
import 'time_origin_widgets.dart';

class MainNavShell extends StatefulWidget {
  const MainNavShell({super.key});

  @override
  State<MainNavShell> createState() => _MainNavShellState();
}

class _MainNavShellState extends State<MainNavShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      const DashboardScreen(),
      const ChequesListScreen(),
      BlocProvider.value(
        value: context.read<ChequeBookBloc>(),
        child: const ChequeBooksScreen(),
      ),
      const CalendarScreen(),
      const AnalyticsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      appBar: _currentIndex == 0
          ? AppBar(
              title: Column(
                children: [
                  const Text(
                    AppStrings.appName,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const Text(
                    AppStrings.appSubtitle,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: Colors.white70),
                  ),
                ],
              ),
              actions: [
                const TimeOriginButton(),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BlocProvider.value(
                        value: context.read<ChequeBloc>(),
                        child: const SearchScreen(),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : null,
      // ─── AI Assistant FAB ────────────────────────────────────────────────
/*      floatingActionButton: _AiAssistantFab(
        onTap: () => {Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => MultiBlocProvider(
              providers: [
                BlocProvider(create: (_) => AiAssistantBloc()),
                BlocProvider.value(value: ctx.read<ChequeBloc>()),
              ],
              child: const AiAssistantScreen(),
            ),
          ),
        )},
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,*/
      // ─────────────────────────────────────────────────────────────────────
      body: SafeArea(
        // Bug 9 fix: wrap in SafeArea so safe area constraints are
        // always respected regardless of the TimeOriginBanner state.
        child: Column(
          children: [
            const TimeOriginBanner(),
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: screens,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: AppStrings.dashboard,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: AppStrings.cheques,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book_outlined),
            activeIcon: Icon(Icons.book),
            label: 'دسته چک',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: AppStrings.calendar,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: AppStrings.analytics,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: AppStrings.settings,
          ),
        ],
      ),
    );
  }
}

/// Prominent AI assistant floating action button
class _AiAssistantFab extends StatelessWidget {
  final VoidCallback onTap;
  const _AiAssistantFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primaryDark, AppColors.primary, AppColors.primaryLight],
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.45),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'دستیار هوشمند',
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
