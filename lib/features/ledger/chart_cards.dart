import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/common.dart';
import 'analytics.dart';
import 'models.dart';

/// Donut + ranked progress bars for expenses by category.
class CategoryBreakdownCard extends StatelessWidget {
  const CategoryBreakdownCard({super.key, required this.txns, required this.currency, required this.subtitle, this.rows = 5});
  final List<Txn> txns;
  final String currency;
  final String subtitle;
  final int rows;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final entries = expenseByCategory(txns);
    final total = entries.fold(0, (s, e) => s + e.value);
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Spending by category', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        Text(subtitle, style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 18),
        if (entries.isEmpty)
          const SizedBox(height: 160, child: EmptyState(icon: LucideIcons.chartPie, title: 'No expenses', message: 'Nothing spent in this period.'))
        else
          LayoutBuilder(builder: (context, c) {
            final donut = DonutChart(
              size: 150,
              slices: [for (final e in entries) (e.value.toDouble(), categoryOf(e.key).color)],
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Total', style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                AnimatedMoney(total, currency, compact: true, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              ]),
            );
            final list = Column(children: [
              for (final e in entries.take(rows))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(children: [
                    Row(children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: categoryOf(e.key).color, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(categoryOf(e.key).name, overflow: TextOverflow.ellipsis, style: t.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600))),
                      Text(formatMoney(e.value, currency, compact: true), style: t.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      SizedBox(width: 34, child: Text('${(e.value / total * 100).round()}%', textAlign: TextAlign.right, style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant))),
                    ]),
                    const SizedBox(height: 6),
                    AnimatedProgress(value: e.value / total, color: categoryOf(e.key).color, height: 6),
                  ]),
                ),
            ]);
            if (c.maxWidth < 430) {
              return Column(children: [Center(child: donut), const SizedBox(height: 16), list]);
            }
            return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [donut, const SizedBox(width: 20), Expanded(child: list)]);
          }),
      ]),
    );
  }
}

/// Six-month income vs expense bar chart.
class TrendCard extends StatelessWidget {
  const TrendCard({super.key, required this.txns, required this.currency});
  final List<Txn> txns;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final m = monthlySeries(txns, DateTime.now());
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Income vs expenses', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        Text('Last 6 months', style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 18),
        IncomeExpenseBars(labels: m.labels, income: m.income, expense: m.expense, currency: currency),
        const SizedBox(height: 14),
        const Row(children: [LegendDot(AppColors.income, 'Income'), SizedBox(width: 16), LegendDot(AppColors.expense, 'Expenses')]),
      ]),
    );
  }
}

/// Savings-rate ring: how much of the period's income was kept.
class SavingsCard extends StatelessWidget {
  const SavingsCard({super.key, required this.income, required this.expense, required this.currency, required this.periodLabel});
  final int income;
  final int expense;
  final String currency;
  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final rate = savingsRate(income, expense);
    final good = (rate ?? 0) >= 0;
    final value = (rate ?? 0).clamp(0.0, 1.0);
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Savings rate', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        Text(periodLabel, style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 18),
        Row(children: [
          RingProgress(
            value: value,
            size: 118,
            gradient: good ? AppColors.incomeGradient : AppColors.expenseGradient,
            child: Text(rate == null ? '—' : '${(rate * 100).round()}%', style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _Line('Income', income, currency, AppColors.income),
              const SizedBox(height: 8),
              _Line('Expenses', expense, currency, AppColors.expense),
              const Divider(height: 20),
              _Line(good ? 'Saved' : 'Overspent', (income - expense).abs(), currency, good ? AppColors.income : AppColors.expense),
              if (rate == null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('No income in this period to compare.', style: t.textTheme.bodySmall)),
            ]),
          ),
        ]),
      ]),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.minor, this.currency, this.color);
  final String label;
  final int minor;
  final String currency;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant))),
      const SizedBox(width: 8),
      Expanded(
        child: Align(
          alignment: Alignment.centerRight,
          child: FittedBox(fit: BoxFit.scaleDown, child: Text(formatMoney(minor, currency, compact: true), style: t.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800))),
        ),
      ),
    ]);
  }
}
