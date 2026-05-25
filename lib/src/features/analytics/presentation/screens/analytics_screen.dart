import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/models/cheque_model.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_utils.dart' as du;
import '../../../../core/services/time_origin_service.dart';
import '../../../../features/cheques/presentation/blocs/cheque_bloc.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.analyticsTitle)),
      body: BlocBuilder<ChequeBloc, ChequeState>(
        builder: (context, state) {
          List<Cheque> cheques = [];
          if (state is ChequesLoaded) cheques = state.cheques;
          if (state is ChequeOperationSuccess) cheques = state.cheques;

          if (cheques.isEmpty) {
            return const Center(
              child: Text(
                'داده‌ای برای نمایش وجود ندارد',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSummaryStats(cheques),
              const SizedBox(height: 16),
              _buildDirectionPieChart(cheques),
              const SizedBox(height: 16),
              _buildStatusDistribution(cheques),
              const SizedBox(height: 16),
              _buildMonthlyBarChart(cheques),
              const SizedBox(height: 16),
              _buildTopCounterparties(cheques),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryStats(List<Cheque> cheques) {
    final issued = cheques.where(
        (c) => c.direction == ChequeDirection.issued && c.isActive);
    final received = cheques.where(
        (c) => c.direction == ChequeDirection.received && c.isActive);
    final cleared =
        cheques.where((c) => c.status == ChequeStatus.cleared);
    final returned =
        cheques.where((c) => c.status == ChequeStatus.returned);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _StatCard(
          title: 'چک‌های فعال',
          value: '${issued.length + received.length}',
          subtitle: 'صادره و دریافتی',
          color: AppColors.active,
          icon: Icons.receipt_long_outlined,
        ),
        _StatCard(
          title: 'وصول شده',
          value: '${cleared.length}',
          subtitle: CurrencyFormatter.formatCompact(
              cleared.fold(0.0, (s, c) => s + c.amount)),
          color: AppColors.cleared,
          icon: Icons.check_circle_outline,
        ),
        _StatCard(
          title: 'برگشتی',
          value: '${returned.length}',
          subtitle: CurrencyFormatter.formatCompact(
              returned.fold(0.0, (s, c) => s + c.amount)),
          color: AppColors.returned,
          icon: Icons.cancel_outlined,
        ),
        _StatCard(
          title: 'خالص موقعیت',
          value: CurrencyFormatter.formatCompact(
            received.fold(0.0, (s, c) => s + c.amount) -
                issued.fold(0.0, (s, c) => s + c.amount),
          ),
          subtitle: 'دریافتی منهای صادره',
          color: AppColors.primary,
          icon: Icons.account_balance_wallet_outlined,
        ),
      ],
    );
  }

  Widget _buildDirectionPieChart(List<Cheque> cheques) {
    final activeIssued = cheques
        .where((c) =>
            c.direction == ChequeDirection.issued && c.isActive)
        .fold(0.0, (s, c) => s + c.amount);
    final activeReceived = cheques
        .where((c) =>
            c.direction == ChequeDirection.received && c.isActive)
        .fold(0.0, (s, c) => s + c.amount);

    final total = activeIssued + activeReceived;
    if (total == 0) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              AppStrings.incomingVsOutgoing,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 160,
                    child: PieChart(
                      PieChartData(
                        sections: [
                          PieChartSectionData(
                            value: activeReceived,
                            color: AppColors.received,
                            title:
                                '${(activeReceived / total * 100).toStringAsFixed(0)}٪',
                            titleStyle: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          PieChartSectionData(
                            value: activeIssued,
                            color: AppColors.issued,
                            title:
                                '${(activeIssued / total * 100).toStringAsFixed(0)}٪',
                            titleStyle: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        sectionsSpace: 3,
                        centerSpaceRadius: 36,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Legend(
                      color: AppColors.received,
                      label: 'دریافتی',
                      value:
                          CurrencyFormatter.formatCompact(activeReceived),
                    ),
                    const SizedBox(height: 12),
                    _Legend(
                      color: AppColors.issued,
                      label: 'صادره',
                      value: CurrencyFormatter.formatCompact(activeIssued),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDistribution(List<Cheque> cheques) {
    final statusCounts = <ChequeStatus, int>{};
    for (final c in cheques) {
      statusCounts[c.status] = (statusCounts[c.status] ?? 0) + 1;
    }

    final statuses = [
      (ChequeStatus.active, AppColors.active, AppStrings.active),
      (ChequeStatus.cleared, AppColors.cleared, AppStrings.cleared),
      (ChequeStatus.returned, AppColors.returned, AppStrings.returned),
      (ChequeStatus.pendingReview, AppColors.pending, AppStrings.pendingReview),
      (ChequeStatus.draft, AppColors.draft, AppStrings.draft),
      (ChequeStatus.cancelled, AppColors.cancelled, AppStrings.cancelled),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'توزیع وضعیت چک‌ها',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            ...statuses.map((s) {
              final count = statusCounts[s.$1] ?? 0;
              if (count == 0) return const SizedBox.shrink();
              return _StatusBar(
                label: s.$3,
                count: count,
                total: cheques.length,
                color: s.$2,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyBarChart(List<Cheque> cheques) {
    final now = DateTime.now();
    final months = List.generate(6, (i) {
      return DateTime(now.year, now.month - 5 + i);
    });

    final issuedByMonth = months.map((m) {
      return cheques
          .where((c) =>
              c.direction == ChequeDirection.issued &&
              c.dueDate.year == m.year &&
              c.dueDate.month == m.month)
          .fold(0.0, (s, c) => s + c.amount);
    }).toList();

    final receivedByMonth = months.map((m) {
      return cheques
          .where((c) =>
              c.direction == ChequeDirection.received &&
              c.dueDate.year == m.year &&
              c.dueDate.month == m.month)
          .fold(0.0, (s, c) => s + c.amount);
    }).toList();

    final maxVal = [
      ...issuedByMonth,
      ...receivedByMonth,
    ].fold(0.0, (a, b) => a > b ? a : b);

    if (maxVal == 0) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'نمودار ماهانه (۶ ماه گذشته)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  barGroups: List.generate(months.length, (i) {
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: issuedByMonth[i],
                          color: AppColors.issued,
                          width: 10,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4)),
                        ),
                        BarChartRodData(
                          toY: receivedByMonth[i],
                          color: AppColors.received,
                          width: 10,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (v, meta) {
                          final m = months[v.toInt()];
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            space: 6,
                            child: Text(
                              du.DateUtils.toPersianMonthShort(m),
                              style: const TextStyle(
                                fontSize: 9,
                                color: AppColors.textHint,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 88,
                        getTitlesWidget: (v, meta) {
                          if (v == 0 || v == meta.max) {
                            return const SizedBox.shrink();
                          }
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            space: 4,
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
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (v) =>
                        const FlLine(color: AppColors.divider, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  maxY: maxVal * 1.2,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Legend(color: AppColors.issued, label: 'صادره', value: ''),
                const SizedBox(width: 20),
                _Legend(color: AppColors.received, label: 'دریافتی', value: ''),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCounterparties(List<Cheque> cheques) {
    final Map<String, double> totals = {};
    for (final c in cheques) {
      totals[c.counterpartyName] =
          (totals[c.counterpartyName] ?? 0) + c.amount;
    }

    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (sorted.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'بیشترین حجم معاملات',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            ...sorted.take(5).toList().asMap().entries.map((e) {
              final rank = e.key + 1;
              final entry = e.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$rank',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    Text(
                      CurrencyFormatter.formatCompact(entry.value),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textHint,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _Legend(
      {required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
        if (value.isNotEmpty) ...[
          const SizedBox(width: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ],
    );
  }
}

class _StatusBar extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const _StatusBar({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = total > 0 ? count / total : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                backgroundColor: AppColors.surfaceVariant,
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
