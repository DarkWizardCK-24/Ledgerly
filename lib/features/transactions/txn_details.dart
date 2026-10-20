import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/common.dart';
import '../ledger/ledger_store.dart';
import '../ledger/models.dart';
import 'txn_form.dart';

/// Read-only detail view with edit / duplicate / delete actions.
Future<void> showTxnDetails(BuildContext context, Txn txn) =>
    showAdaptiveSheet<void>(context, builder: (_) => TxnDetails(txnId: txn.id));

class TxnDetails extends ConsumerWidget {
  const TxnDetails({super.key, required this.txnId});
  final String txnId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(ledgerProvider);
    final txn = ledger.txns.where((x) => x.id == txnId).firstOrNull;
    if (txn == null) return const Padding(padding: EdgeInsets.all(32), child: Text('This transaction no longer exists.'));

    final t = Theme.of(context);
    final cat = categoryOf(txn.categoryId);
    final book = ledger.bookById(txn.bookId);
    final income = txn.type == TxnType.income;

    Widget row(IconData icon, String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 18, color: t.colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            SizedBox(width: 110, child: Text(label, style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant))),
            Expanded(child: Text(value, style: t.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
          ]),
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: income ? AppColors.incomeGradient : AppColors.expenseGradient,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(cat.icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(income ? 'Income · ${cat.name}' : 'Expense · ${cat.name}', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(formatMoney(txn.signed, book?.currency ?? 'INR', signed: true), style: t.textTheme.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 4),
            Text(txn.title, style: t.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(height: 12),
        row(LucideIcons.bookOpen, 'CashBook', book?.name ?? '—'),
        row(LucideIcons.calendar, 'Date & time', DateFormat('EEE, d MMM y · h:mm a').format(txn.date)),
        row(LucideIcons.creditCard, 'Payment', txn.method),
        if (txn.imported) row(LucideIcons.fileText, 'Source', 'Imported from a reviewed bank statement'),
        if (txn.merchant.isNotEmpty) row(LucideIcons.store, 'Merchant', txn.merchant),
        if (txn.note.isNotEmpty) row(LucideIcons.stickyNote, 'Notes', txn.note),
        if (txn.tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(LucideIcons.tag, size: 18, color: t.colorScheme.onSurfaceVariant),
              const SizedBox(width: 12),
              SizedBox(width: 110, child: Text('Tags', style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant))),
              Expanded(child: Wrap(spacing: 6, runSpacing: 6, children: [for (final g in txn.tags) Chip(label: Text('#$g'), visualDensity: VisualDensity.compact)])),
            ]),
          ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ref.read(ledgerProvider.notifier).duplicateTxn(txn);
                toast(context, 'Transaction duplicated');
              },
              icon: const Icon(LucideIcons.copy, size: 16),
              label: const Text('Duplicate'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: t.colorScheme.error),
              onPressed: () async {
                final ok = await confirmDialog(context, title: 'Delete transaction?', message: '"${txn.title}" will be removed and the balance updated.', confirmLabel: 'Delete', destructive: true);
                if (!ok || !context.mounted) return;
                Navigator.pop(context);
                ref.read(ledgerProvider.notifier).deleteTxn(txn.id);
                toast(context, 'Transaction deleted', actionLabel: 'Undo', onAction: () => ref.read(ledgerProvider.notifier).restoreTxn(txn));
              },
              icon: const Icon(LucideIcons.trash2, size: 16),
              label: const Text('Delete'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                showTxnForm(context, edit: txn);
              },
              icon: const Icon(LucideIcons.pencil, size: 16),
              label: const Text('Edit'),
            ),
          ),
        ]),
      ]),
    );
  }
}
