import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/common.dart';
import '../ledger/chart_cards.dart';
import '../ledger/ledger_store.dart';
import '../ledger/models.dart';
import '../transactions/timeline.dart';
import '../transactions/txn_form.dart';
import 'book_card.dart';
import 'book_form.dart';

class BookDetailScreen extends ConsumerWidget {
  const BookDetailScreen({super.key, required this.bookId});
  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(ledgerProvider);
    final book = ledger.bookById(bookId);
    if (book == null) {
      return PageScaffold(
        title: 'CashBook',
        leading: IconButton(onPressed: () => context.go('/books'), icon: const Icon(LucideIcons.arrowLeft)),
        children: [ErrorState(message: 'This CashBook no longer exists.', onRetry: () => context.go('/books'))],
      );
    }

    final t = Theme.of(context);
    final txns = ledger.txnsOf(book.id);
    final income = txns.where((x) => x.type == TxnType.income).fold(0, (s, x) => s + x.amountMinor);
    final expense = txns.where((x) => x.type == TxnType.expense).fold(0, (s, x) => s + x.amountMinor);

    return PageScaffold(
      title: book.name,
      subtitle: book.archived ? 'Archived · read only recommended' : (book.description.isEmpty ? book.currency : book.description),
      leading: IconButton(tooltip: 'Back to CashBooks', onPressed: () => context.go('/books'), icon: const Icon(LucideIcons.arrowLeft)),
      actions: [
        OutlinedButton.icon(onPressed: () => showBookForm(context, edit: book), icon: const Icon(LucideIcons.pencil, size: 16), label: const Text('Edit')),
        OutlinedButton.icon(
          onPressed: () {
            ref.read(ledgerProvider.notifier).updateBook(book.copyWith(archived: !book.archived));
            toast(context, book.archived ? 'Restored' : 'Archived');
          },
          icon: Icon(book.archived ? LucideIcons.archiveRestore : LucideIcons.archive, size: 16),
          label: Text(book.archived ? 'Restore' : 'Archive'),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            await deleteBookSafely(context, ref, book);
            if (context.mounted && ref.read(ledgerProvider).bookById(book.id) == null) context.go('/books');
          },
          icon: Icon(LucideIcons.trash2, size: 16, color: t.colorScheme.error),
          label: Text('Delete', style: TextStyle(color: t.colorScheme.error)),
        ),
        FilledButton.icon(onPressed: () => showTxnForm(context, bookId: book.id), icon: const Icon(LucideIcons.plus, size: 18), label: const Text('Add transaction')),
      ],
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [book.color, Color.lerp(book.color, Colors.black, 0.35)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(book.icon, color: Colors.white70, size: 18), const SizedBox(width: 8), const Text('Current balance', style: TextStyle(color: Colors.white70))]),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: AnimatedMoney(ledger.balanceOf(book), book.currency, style: t.textTheme.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 4),
            Text('Opening ${formatMoney(book.openingMinor, book.currency)}', style: const TextStyle(color: Colors.white70)),
          ]),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, c) {
          final cards = [
            _Stat(label: 'Total income', value: formatMoney(income, book.currency), color: AppColors.income, icon: LucideIcons.arrowDownLeft),
            _Stat(label: 'Total expenses', value: formatMoney(expense, book.currency), color: AppColors.expense, icon: LucideIcons.arrowUpRight),
          ];
          return c.maxWidth < 520
              ? Column(children: [cards[0], const SizedBox(height: 12), cards[1]])
              : Row(children: [Expanded(child: cards[0]), const SizedBox(width: 16), Expanded(child: cards[1])]);
        }),
        const SizedBox(height: 16),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('Income vs expenses', style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
              Text(income + expense == 0 ? '—' : '${(income / (income + expense) * 100).round()}% income', style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
            ]),
            const SizedBox(height: 12),
            AnimatedProgress(value: income + expense == 0 ? 0 : income / (income + expense), gradient: AppColors.incomeGradient, height: 12),
          ]),
        ),
        const SizedBox(height: 16),
        TwoUp(
          a: CategoryBreakdownCard(txns: txns, currency: book.currency, subtitle: 'All time'),
          b: TrendCard(txns: txns, currency: book.currency),
        ),
        const SizedBox(height: 28),
        const SectionTitle('Transactions'),
        TransactionTimeline(bookId: book.id),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color, required this.icon});
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return AppCard(
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          ]),
        ),
      ]),
    );
  }
}
