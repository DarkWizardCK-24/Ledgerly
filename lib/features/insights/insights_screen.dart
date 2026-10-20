import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/common.dart';
import '../ledger/analytics.dart';
import '../ledger/chart_cards.dart';
import '../ledger/ledger_store.dart';
import '../ledger/models.dart';
import '../transactions/txn_details.dart';

/// Reports derived entirely from the ledger: category donut, trends, savings rate,
/// payment methods and the largest expenses.
class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  Period _period = Period.month;
  String? _bookId;

  static const _methodColors = [Color(0xFFFF7A2F), Color(0xFFE8384F), Color(0xFFFFB703), Color(0xFF0EA5E9), Color(0xFF8B5CF6), Color(0xFF94A3B8)];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final boot = ref.watch(bootProvider);
    final ledger = ref.watch(ledgerProvider);
    final books = ledger.books.where((b) => !b.archived).toList();

    if (boot.isLoading) {
      return const PageScaffold(title: 'Insights', subtitle: 'Crunching your numbers…', children: [
        Skeleton(height: 300, radius: 20),
        SizedBox(height: 16),
        Skeleton(height: 260, radius: 20),
      ]);
    }
    if (books.isEmpty) {
      return PageScaffold(title: 'Insights', children: const [
        AppCard(child: EmptyState(icon: LucideIcons.chartPie, title: 'Nothing to analyse yet', message: 'Create a CashBook and add transactions to see insights.')),
      ]);
    }

    final selected = books.where((b) => b.id == _bookId).firstOrNull;
    final scope = selected == null ? books.where((b) => b.currency == 'INR').toList() : [selected];
    final cur = scope.isEmpty ? 'INR' : scope.first.currency;
    final ids = {for (final b in scope) b.id};
    final range = _period.range(DateTime.now());
    final all = ledger.txns.where((x) => ids.contains(x.bookId)).toList();
    final inPeriod = all.where((x) => !x.date.isBefore(range.start) && x.date.isBefore(range.end)).toList();
    final income = sumOf(inPeriod, TxnType.income);
    final expense = sumOf(inPeriod, TxnType.expense);
    final methods = expenseByMethod(inPeriod);
    final methodTotal = methods.fold(0, (s, e) => s + e.value);
    final biggest = largestExpenses(inPeriod);
    final key = '${_period.name}-${_bookId ?? 'all'}';

    return PageScaffold(
      title: 'Insights',
      subtitle: 'Reports built from your real transactions · all amounts in ${selected?.currency ?? '₹ INR'}',
      children: [
        Reveal(
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final p in Period.values) ChoiceChip(label: Text(p.label), selected: _period == p, onSelected: (_) => setState(() => _period = p)),
          ]),
        ),
        const SizedBox(height: 12),
        Reveal(
          index: 1,
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            ChoiceChip(label: const Text('All books'), selected: _bookId == null, onSelected: (_) => setState(() => _bookId = null)),
            for (final b in books) ChoiceChip(avatar: Icon(b.icon, size: 16, color: b.color), label: Text(b.name), selected: _bookId == b.id, onSelected: (_) => setState(() => _bookId = b.id)),
          ]),
        ),
        const SizedBox(height: 16),
        Reveal(index: 2, child: TwoUp(a: CategoryBreakdownCard(key: ValueKey('c$key'), txns: inPeriod, currency: cur, subtitle: _period.label, rows: 6), b: SavingsCard(key: ValueKey('s$key'), income: income, expense: expense, currency: cur, periodLabel: _period.label))),
        const SizedBox(height: 16),
        Reveal(
          index: 3,
          child: TwoUp(
            a: TrendCard(key: ValueKey('t$key'), txns: all, currency: cur),
            b: AppCard(
              key: ValueKey('m$key'),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Payment methods', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                Text('How you paid · ${_period.label}', style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 18),
                if (methods.isEmpty)
                  const SizedBox(height: 150, child: EmptyState(icon: LucideIcons.creditCard, title: 'No spending', message: 'No expenses in this period.'))
                else
                  Row(children: [
                    DonutChart(size: 130, strokeWidth: 16, slices: [for (var i = 0; i < methods.length; i++) (methods[i].value.toDouble(), _methodColors[i % _methodColors.length])]),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(children: [
                        for (var i = 0; i < methods.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(children: [
                              Container(width: 10, height: 10, decoration: BoxDecoration(color: _methodColors[i % _methodColors.length], shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              Expanded(child: Text(methods[i].key, overflow: TextOverflow.ellipsis, style: t.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600))),
                              Text('${(methods[i].value / methodTotal * 100).round()}%', style: t.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800)),
                            ]),
                          ),
                      ]),
                    ),
                  ]),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Reveal(
          index: 4,
          child: AppCard(
            key: ValueKey('l$key'),
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Largest expenses', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              Text(_period.label, style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              if (biggest.isEmpty)
                const SizedBox(height: 120, child: EmptyState(icon: LucideIcons.receipt, title: 'No expenses', message: 'Nothing to rank in this period.'))
              else
                for (final x in biggest)
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => showTxnDetails(context, x),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(children: [
                        GradientIcon(categoryOf(x.categoryId).icon, color: categoryOf(x.categoryId).color, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(child: Text(x.title, overflow: TextOverflow.ellipsis, style: t.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700))),
                              Text(formatMoney(x.amountMinor, cur), style: t.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800, color: AppColors.expense)),
                            ]),
                            const SizedBox(height: 2),
                            Text('${categoryOf(x.categoryId).name} · ${DateFormat('d MMM').format(x.date)}', style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                            const SizedBox(height: 6),
                            AnimatedProgress(value: x.amountMinor / biggest.first.amountMinor, gradient: AppColors.expenseGradient, height: 6),
                          ]),
                        ),
                      ]),
                    ),
                  ),
            ]),
          ),
        ),
      ],
    );
  }
}
