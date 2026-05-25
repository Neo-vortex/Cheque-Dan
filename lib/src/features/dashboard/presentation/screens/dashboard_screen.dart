import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/models/cheque_model.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_utils.dart' as du;
import '../../../../features/cheques/data/cheque_repository.dart';
import '../../../../features/cheques/presentation/blocs/cheque_bloc.dart';
import '../../../../features/cheques/presentation/screens/cheque_detail_screen.dart';
import '../../../../shared/widgets/cheque_list_tile.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardSummary? _summary;
  List<CashflowPoint> _cashflow = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final repo = context.read<ChequeRepository>();
    final summary = await repo.getDashboardSummary();
    final cashflow = await repo.getCashflowForecast(days: 30);
    if (mounted) {
      setState(() {
        _summary = summary;
        _cashflow = cashflow;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ChequeBloc, ChequeState>(
      listener: (context, state) {
        if (state is ChequesLoaded || state is ChequeOperationSuccess) {
          _loadData();
        }
      },
      child: RefreshIndicator(
        onRefresh: _loadData,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildInsightCard(),
                  const SizedBox(height: 16),
                  _buildSummaryCards(),
                  const SizedBox(height: 16),
                  _buildRiskIndicator(),
                  const SizedBox(height: 16),
                  _buildCashflowChart(),
                  const SizedBox(height: 16),
                  _buildUpcomingSection(),
                ],
              ),
      ),
    );
  }

  Widget _buildInsightCard() {
    final s = _summary;
    if (s == null) return const SizedBox.shrink();

    String message;
    Color color;
    IconData icon;

    switch (s.riskLevel) {
      case RiskLevel.safe:
        message = AppStrings.insightAllGood;
        color = AppColors.riskSafe;
        icon = Icons.sentiment_satisfied_alt_outlined;
        break;
      case RiskLevel.warning:
        message = AppStrings.insightWarning;
        color = AppColors.riskWarning;
        icon = Icons.sentiment_neutral_outlined;
        break;
      case RiskLevel.critical:
        message = AppStrings.insightCritical;
        color = AppColors.riskCritical;
        icon = Icons.sentiment_dissatisfied_outlined;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final s = _summary;
    if (s == null) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            title: AppStrings.issuedTotal,
            amount: s.totalIssuedAmount,
            color: AppColors.issued,
            icon: Icons.arrow_upward,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            title: AppStrings.receivedTotal,
            amount: s.totalReceivedAmount,
            color: AppColors.received,
            icon: Icons.arrow_downward,
          ),
        ),
      ],
    );
  }

  Widget _buildRiskIndicator() {
    final s = _summary;
    if (s == null) return const SizedBox.shrink();

    Color riskColor;
    String riskLabel;
    double riskValue;

    switch (s.riskLevel) {
      case RiskLevel.safe:
        riskColor = AppColors.riskSafe;
        riskLabel = AppStrings.safe;
        riskValue = 0.2;
        break;
      case RiskLevel.warning:
        riskColor = AppColors.riskWarning;
        riskLabel = AppStrings.warning;
        riskValue = 0.6;
        break;
      case RiskLevel.critical:
        riskColor = AppColors.riskCritical;
        riskLabel = AppStrings.critical;
        riskValue = 1.0;
        break;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  AppStrings.riskStatus,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: riskColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    riskLabel,
                    style: TextStyle(
                      color: riskColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: riskValue,
                backgroundColor: AppColors.surfaceVariant,
                valueColor: AlwaysStoppedAnimation(riskColor),
                minHeight: 8,
              ),
            ),
            if (s.overdueCount > 0) ...[
              const SizedBox(height: 8),
              Text(
                '${s.overdueCount} چک معوق به مجموع ${CurrencyFormatter.formatCompact(s.overdueAmount)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.riskCritical,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCashflowChart() {
    if (_cashflow.isEmpty) return const SizedBox.shrink();

    final spots = _cashflow.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.balance);
    }).toList();

    final minY = _cashflow
        .map((p) => p.balance)
        .reduce((a, b) => a < b ? a : b);
    final maxY = _cashflow
        .map((p) => p.balance)
        .reduce((a, b) => a > b ? a : b);
    final yRange = (maxY - minY).abs();
    final interval = yRange == 0 ? 1.0 : yRange / 4;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              AppStrings.cashflowForecast,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '۳۰ روز آینده',
              style: TextStyle(fontSize: 12, color: AppColors.textHint),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                    gridData: FlGridData(
                      show: true,
                      horizontalInterval: (maxY - minY).abs() == 0 ? 1 : (maxY - minY).abs() / 4,
                      getDrawingHorizontalLine: (v) => FlLine(
                        color: AppColors.divider,
                        strokeWidth: 1,
                      ),
                      drawVerticalLine: false,
                    ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 80,
                        getTitlesWidget: (v, meta) {
                          if (v == meta.min || v == meta.max) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(
                              CurrencyFormatter.formatCompact(v),
                              style: const TextStyle(
                                fontSize: 9,
                                color: AppColors.textHint,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: 7,
                        getTitlesWidget: (v, meta) {
                          if (v.toInt() >= _cashflow.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              du.DateUtils.toPersianDayMonth(
                                  _cashflow[v.toInt()].date),
                              style: const TextStyle(
                                fontSize: 8,
                                color: AppColors.textHint,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: AppColors.primary,
                      barWidth: 2.5,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primary.withOpacity(0.1),
                      ),
                    ),
                  ],
                  minY: minY * 1.1,
                  maxY: maxY * 1.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingSection() {
    final s = _summary;
    if (s == null || s.upcomingCheques.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          AppStrings.upcomingCheques,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        ...s.upcomingCheques.take(5).map((c) => ChequeListTile(
              cheque: c,
              showSlidable: false,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: context.read<ChequeBloc>(),
                    child: ChequeDetailScreen(cheque: c),
                  ),
                ),
              ),
            )),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final double amount;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              CurrencyFormatter.formatCompact(amount),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
