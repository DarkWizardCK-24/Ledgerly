import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/widgets/common.dart';
import '../ledger/ledger_store.dart';
import 'timeline.dart';
import 'txn_form.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  String? _bookId;

  @override
  Widget build(BuildContext context) {
    final books = ref.watch(ledgerProvider).books.where((b) => !b.archived).toList();
    return PageScaffold(
      title: 'Transactions',
      subtitle: 'Everything across your CashBooks',
      actions: [
        OutlinedButton.icon(onPressed: () => context.go('/settings/categories'), icon: const Icon(LucideIcons.tags, size: 16), label: const Text('Categories')),
        FilledButton.icon(
          onPressed: books.isEmpty ? null : () => showTxnForm(context, bookId: _bookId ?? books.first.id),
          icon: const Icon(LucideIcons.plus, size: 18),
          label: const Text('Add transaction'),
        ),
      ],
      children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          ChoiceChip(label: const Text('All books'), selected: _bookId == null, onSelected: (_) => setState(() => _bookId = null)),
          for (final b in books)
            ChoiceChip(
              avatar: Icon(b.icon, size: 16, color: b.color),
              label: Text(b.name),
              selected: _bookId == b.id,
              onSelected: (_) => setState(() => _bookId = b.id),
            ),
        ]),
        const SizedBox(height: 16),
        TransactionTimeline(key: ValueKey(_bookId), bookId: _bookId),
      ],
    );
  }
}
