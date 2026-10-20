import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format/money.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/common.dart';
import '../ledger/ledger_store.dart';
import '../ledger/models.dart';
import 'book_form.dart';

/// Archive / restore / delete with dependency checks, shared by card + detail page.
Future<void> deleteBookSafely(BuildContext context, WidgetRef ref, Book b) async {
  final ledger = ref.read(ledgerProvider);
  final count = ledger.txnsOf(b.id).length;
  if (count > 0) {
    final archive = await confirmDialog(
      context,
      title: 'Can\'t delete "${b.name}"',
      message: 'It still has $count transaction${count == 1 ? '' : 's'}. Deleting would erase your history. Archive it instead? You can restore it any time.',
      confirmLabel: 'Archive instead',
    );
    if (archive && context.mounted) {
      ref.read(ledgerProvider.notifier).updateBook(b.copyWith(archived: true));
      toast(context, '"${b.name}" archived');
    }
    return;
  }
  final ok = await confirmDialog(context,
      title: 'Delete "${b.name}"?', message: 'This empty CashBook will be permanently deleted.', confirmLabel: 'Delete', destructive: true);
  if (ok && context.mounted) {
    ref.read(ledgerProvider.notifier).deleteBook(b.id);
    toast(context, 'CashBook deleted');
  }
}

class BookCard extends ConsumerWidget {
  const BookCard({super.key, required this.book});
  final Book book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final ledger = ref.watch(ledgerProvider);
    final balance = ledger.balanceOf(book);
    final last = ledger.lastActivity(book);
    final count = ledger.txnsOf(book.id).length;

    final dark = Color.lerp(book.color, Colors.black, 0.38)!;
    return AppCard(
      padding: EdgeInsets.zero,
      accent: book.color,
      onTap: () => context.go('/books/${book.id}'),
      child: Opacity(
        opacity: book.archived ? 0.65 : 1,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Color.lerp(book.color, Colors.white, 0.12)!, dark], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: Stack(children: [
              Positioned(right: -10, bottom: -30, child: Icon(book.icon, size: 110, color: Colors.white.withValues(alpha: 0.1))),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(14)),
                    child: Icon(book.icon, color: Colors.white, size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(book.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: Colors.white)),
                      Text(book.archived ? 'Archived' : book.description.isEmpty ? book.currency : book.description,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.bodySmall?.copyWith(color: Colors.white70)),
                    ]),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Book actions',
                    iconColor: Colors.white,
                    onSelected: (v) {
                      switch (v) {
                        case 'edit':
                          showBookForm(context, edit: book);
                        case 'archive':
                          ref.read(ledgerProvider.notifier).updateBook(book.copyWith(archived: !book.archived));
                          toast(context, book.archived ? '"${book.name}" restored' : '"${book.name}" archived');
                        case 'delete':
                          deleteBookSafely(context, ref, book);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(LucideIcons.pencil, size: 18), title: Text('Edit'), dense: true)),
                      PopupMenuItem(
                          value: 'archive',
                          child: ListTile(
                              leading: Icon(book.archived ? LucideIcons.archiveRestore : LucideIcons.archive, size: 18),
                              title: Text(book.archived ? 'Restore' : 'Archive'),
                              dense: true)),
                      const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(LucideIcons.trash2, size: 18), title: Text('Delete'), dense: true)),
                    ],
                  ),
                ]),
                const SizedBox(height: 22),
                const Text('Balance', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(formatMoney(balance, book.currency), style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ]),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(children: [
              Icon(LucideIcons.activity, size: 15, color: book.color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  last == null ? 'No activity yet' : '$count transactions · last ${DateFormat('d MMM').format(last)}',
                  style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                ),
              ),
              Icon(LucideIcons.chevronRight, size: 16, color: t.colorScheme.onSurfaceVariant),
            ]),
          ),
        ]),
      ),
    );
  }
}
