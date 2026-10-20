import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/common.dart';
import '../books/book_form.dart';
import '../ledger/analytics.dart';
import '../ledger/chart_cards.dart';
import '../ledger/ledger_store.dart';
import '../ledger/models.dart';
import '../transactions/txn_details.dart';
import '../transactions/txn_form.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Period _period = Period.month;
  String? _currency;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final boot = ref.watch(bootProvider);
    final ledger = ref.watch(ledgerProvider);
    final active = ledger.books.where((b) => !b.archived).toList();
    final curs = {for (final b in active) b.currency}.toList()..sort();
    final cur = curs.contains(_currency) ? _currency! : (curs.contains('INR') ? 'INR' : (curs.isEmpty ? 'INR' : curs.first));

    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');

    final actions = [
      OutlinedButton.icon(onPressed: () => showBookForm(context), icon: const Icon(LucideIcons.bookPlus, size: 16), label: const Text('New CashBook')),
      FilledButton.icon(
        onPressed: active.isEmpty ? null : () => showTxnForm(context, bookId: active.first.id),
        icon: const Icon(LucideIcons.plus, size: 18),
        label: const Text('New transaction'),
      ),
    ];

    if (boot.isLoading) {
      return PageScaffold(title: '$greeting 👋', subtitle: 'Loading your finances…', children: const [
        Skeleton(height: 190, radius: 28),
        SizedBox(height: 16),
        Row(children: [Expanded(child: Skeleton(height: 110, radius: 20)), SizedBox(width: 16), Expanded(child: Skeleton(height: 110, radius: 20)), SizedBox(width: 16), Expanded(child: Skeleton(height: 110, radius: 20))]),
        SizedBox(height: 16),
        Skeleton(height: 280, radius: 20),
      ]);
    }

    if (active.isEmpty) {
      return PageScaffold(title: '$greeting 👋', subtitle: 'Let\'s set up your first CashBook', children: [
        AppCard(
          child: EmptyState(
            icon: LucideIcons.bookOpen,
            title: 'Welcome to Ledgerly',
            message: 'Create a CashBook such as Personal or Household, then add your first transaction.',
            action: FilledButton.icon(onPressed: () => showBookForm(context), icon: const Icon(LucideIcons.plus, size: 18), label: const Text('Create CashBook')),
          ),
        ),
      ]);
    }

    final ids = {for (final b in active.where((b) => b.currency == cur)) b.id};
    final now = DateTime.now();
    final range = _period.range(now);
    final prev = _period.previous(now);
    List<Txn> within(DateTimeRange r) => ledger.txns.where((x) => ids.contains(x.bookId) && !x.date.isBefore(r.start) && x.date.isBefore(r.end)).toList();

    final cur_ = within(range);
    final prev_ = within(prev);
    final income = sumOf(cur_, TxnType.income);
    final expense = sumOf(cur_, TxnType.expense);

    final totals = <String, int>{};
    for (final b in active) {
      totals[b.currency] = (totals[b.currency] ?? 0) + ledger.balanceOf(b);
    }
    final grand = (totals[cur] ?? 0).abs();
    final recent = ledger.txns.where((x) => active.any((b) => b.id == x.bookId)).take(5).toList();
    final key = '${_period.name}-$cur';

    return PageScaffold(
      title: '$greeting 👋',
      subtitle: DateFormat('EEEE, d MMMM y').format(now),
      actions: actions,
      children: [
        Reveal(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(LucideIcons.flaskConical, size: 16, color: AppColors.warning),
              const SizedBox(width: 8),
              Flexible(child: Text('Sample data in ₹ — real data arrives with the backend in Phase 3.', style: t.textTheme.bodySmall)),
            ]),
          ),
        ),
        const SizedBox(height: 20),
        Reveal(
          index: 1,
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final p in Period.values) ChoiceChip(label: Text(p.label), selected: _period == p, onSelected: (_) => setState(() => _period = p)),
          ]),
        ),
        const SizedBox(height: 16),
        Reveal(index: 2, child: _BalanceHero(totals: totals, selected: cur)),
        const SizedBox(height: 16),
        Reveal(
          index: 3,
          child: Wrap(spacing: 12, runSpacing: 12, children: [
            _QuickAction(label: 'Add income', icon: LucideIcons.arrowDownLeft, gradient: AppColors.incomeGradient, onTap: () => showTxnForm(context, bookId: active.first.id, type: TxnType.income)),
            _QuickAction(label: 'Add expense', icon: LucideIcons.arrowUpRight, gradient: AppColors.expenseGradient, onTap: () => showTxnForm(context, bookId: active.first.id, type: TxnType.expense)),
            _QuickAction(label: 'New CashBook', icon: LucideIcons.bookPlus, gradient: AppColors.goldGradient, onTap: () => showBookForm(context)),
            _QuickAction(label: 'Insights', icon: LucideIcons.chartPie, gradient: AppColors.brandGradient, onTap: () => context.go('/insights')),
          ]),
        ),
        if (curs.length > 1) ...[
          const SizedBox(height: 16),
          Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('Showing', style: TextStyle(color: t.colorScheme.onSurfaceVariant)),
            for (final c in curs) ChoiceChip(label: Text(c), selected: cur == c, onSelected: (_) => setState(() => _currency = c)),
          ]),
        ],
        const SizedBox(height: 16),
        Reveal(
          index: 4,
          child: LayoutBuilder(builder: (context, c) {
            final cards = [
              _StatCard(key: ValueKey('i$key'), label: 'Income', icon: LucideIcons.arrowDownLeft, color: AppColors.income, minor: income, prev: sumOf(prev_, TxnType.income), cur: cur, goodWhenUp: true),
              _StatCard(key: ValueKey('e$key'), label: 'Expenses', icon: LucideIcons.arrowUpRight, color: AppColors.expense, minor: expense, prev: sumOf(prev_, TxnType.expense), cur: cur, goodWhenUp: false),
              _StatCard(key: ValueKey('n$key'), label: 'Net cash flow', icon: LucideIcons.activity, color: t.colorScheme.primary, minor: income - expense, prev: sumOf(prev_, TxnType.income) - sumOf(prev_, TxnType.expense), cur: cur, goodWhenUp: true, signed: true),
            ];
            if (c.maxWidth < 640) {
              return Column(children: [for (final x in cards) Padding(padding: const EdgeInsets.only(bottom: 12), child: x)]);
            }
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (var i = 0; i < cards.length; i++) ...[if (i > 0) const SizedBox(width: 16), Expanded(child: cards[i])],
            ]);
          }),
        ),
        const SizedBox(height: 16),
        Reveal(
          index: 5,
          child: _TwoUp(
            a: CategoryBreakdownCard(key: ValueKey('cat$key'), txns: cur_, currency: cur, subtitle: _period.label),
            b: TrendCard(key: ValueKey('trend$cur'), txns: ledger.txns.where((x) => ids.contains(x.bookId)).toList(), currency: cur),
          ),
        ),
        const SizedBox(height: 16),
        Reveal(
          index: 6,
          child: _TwoUp(
            a: SavingsCard(key: ValueKey('sv$key'), income: income, expense: expense, currency: cur, periodLabel: _period.label),
            b: _TopMerchants(key: ValueKey('tm$key'), txns: cur_, currency: cur),
          ),
        ),
        const SizedBox(height: 28),
        Reveal(
          index: 7,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionTitle('Recent transactions', trailing: TextButton(onPressed: () => context.go('/transactions'), child: const Text('View all'))),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (var i = 0; i < recent.length; i++) ...[
                  if (i > 0) const Divider(indent: 72),
                  _RecentRow(txn: recent[i], ledger: ledger),
                ],
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 28),
        Reveal(
          index: 8,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionTitle('Your CashBooks', trailing: TextButton(onPressed: () => context.go('/books'), child: const Text('Manage'))),
            SizedBox(
              height: 176,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: active.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, i) {
                  final b = active[i];
                  final bal = ledger.balanceOf(b);
                  return SizedBox(
                    width: 230,
                    child: AppCard(
                      accent: b.color,
                      onTap: () => context.go('/books/${b.id}'),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                        Row(children: [GradientIcon(b.icon, color: b.color, size: 34), const SizedBox(width: 10), Expanded(child: Text(b.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)))]),
                        const SizedBox(height: 12),
                        Text(formatMoney(bal, b.currency), style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        AnimatedProgress(value: grand == 0 || b.currency != cur ? 0 : bal.abs() / grand, color: b.color, height: 5),
                        const SizedBox(height: 4),
                        Text(b.currency == cur && grand != 0 ? '${(bal.abs() / grand * 100).round()}% of total' : '', style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

class _TwoUp extends StatelessWidget {
  const _TwoUp({required this.a, required this.b});
  final Widget a;
  final Widget b;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        if (c.maxWidth < 800) return Column(children: [a, const SizedBox(height: 16), b]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 16), Expanded(child: b)]);
      });
}

class _BalanceHero extends StatelessWidget {
  const _BalanceHero({required this.totals, required this.selected});
  final Map<String, int> totals;
  final String selected;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final others = totals.entries.where((e) => e.key != selected).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFB02E), Color(0xFFFF6B35), Color(0xFFE8384F)], begin: Alignment.topLeft, end: Alignment.bottomRight, stops: [0, 0.5, 1]),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: AppColors.expense.withValues(alpha: 0.28), blurRadius: 32, offset: const Offset(0, 16))],
      ),
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(right: -50, top: -60, child: Container(width: 220, height: 220, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.12)))),
        Positioned(right: 60, bottom: -90, child: Container(width: 180, height: 180, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08)))),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(LucideIcons.wallet, color: Colors.white70, size: 16), SizedBox(width: 8), Text('Total balance', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600))]),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: AnimatedMoney(totals[selected] ?? 0, selected, style: t.textTheme.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 4),
          const Text('Across all active CashBooks', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
          if (others.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final e in others)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
                  child: Text(formatMoney(e.value, e.key), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
            ]),
            const SizedBox(height: 10),
            const Text('Currencies are shown separately — no conversion rates are available yet.', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ]),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({super.key, required this.label, required this.icon, required this.color, required this.minor, required this.prev, required this.cur, required this.goodWhenUp, this.signed = false});
  final String label;
  final IconData icon;
  final Color color;
  final int minor;
  final int prev;
  final String cur;
  final bool goodWhenUp;
  final bool signed;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    String? delta;
    Color? dColor;
    IconData? dIcon;
    if (prev != 0) {
      final pct = ((minor - prev) / prev.abs() * 100);
      final up = pct >= 0;
      delta = '${pct.abs().toStringAsFixed(0)}% vs previous period';
      dIcon = up ? LucideIcons.trendingUp : LucideIcons.trendingDown;
      dColor = (up == goodWhenUp) ? AppColors.income : AppColors.expense;
    }
    return AppCard(
      accent: color,
      gradient: LinearGradient(colors: [color.withValues(alpha: 0.13), t.colorScheme.surface], begin: Alignment.topLeft, end: Alignment.bottomRight),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          GradientIcon(icon, color: color, size: 38),
          const SizedBox(width: 10),
          Text(label, style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 14),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: AnimatedMoney(minor, cur, signed: signed, style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800))),
        const SizedBox(height: 8),
        Row(children: [
          if (dIcon != null) ...[Icon(dIcon, size: 15, color: dColor), const SizedBox(width: 4)],
          Expanded(child: Text(delta ?? 'No data in previous period', style: t.textTheme.bodySmall?.copyWith(color: dColor ?? t.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600))),
        ]),
      ]),
    );
  }
}

class _TopMerchants extends StatelessWidget {
  const _TopMerchants({super.key, required this.txns, required this.currency});
  final List<Txn> txns;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final merchants = topMerchants(txns);
    final maxV = merchants.isEmpty ? 1 : merchants.first.value;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Top merchants', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        Text('Where most of your money went', style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 14),
        if (merchants.isEmpty)
          const SizedBox(height: 140, child: EmptyState(icon: LucideIcons.store, title: 'No merchants', message: 'Add a merchant to your expenses to see them here.'))
        else
          for (var i = 0; i < merchants.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(children: [
                Row(children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(gradient: AppColors.goldGradient, borderRadius: BorderRadius.circular(7)),
                    child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(merchants[i].key, overflow: TextOverflow.ellipsis, style: t.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                  Text(formatMoney(merchants[i].value, currency, compact: true), style: t.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 6),
                AnimatedProgress(value: merchants[i].value / maxV, gradient: AppColors.goldGradient, height: 6),
              ]),
            ),
      ]),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.label, required this.icon, required this.gradient, required this.onTap});
  final String label;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
          decoration: BoxDecoration(color: t.colorScheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.colorScheme.outline)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: Colors.white, size: 18)),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.txn, required this.ledger});
  final Txn txn;
  final LedgerState ledger;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cat = categoryOf(txn.categoryId);
    final book = ledger.bookById(txn.bookId);
    final income = txn.type == TxnType.income;
    return InkWell(
      onTap: () => showTxnDetails(context, txn),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          GradientIcon(cat.icon, color: cat.color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(txn.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              Text('${cat.name} · ${DateFormat('d MMM').format(txn.date)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
            ]),
          ),
          Text(formatMoney(txn.signed, book?.currency ?? 'INR', signed: true), style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: income ? AppColors.income : AppColors.expense)),
        ]),
      ),
    );
  }
}
