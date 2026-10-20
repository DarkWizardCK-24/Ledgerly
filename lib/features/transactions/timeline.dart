import 'dart:convert';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format/money.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/common.dart';
import '../ledger/ledger_store.dart';
import '../ledger/models.dart';
import 'txn_details.dart';
import 'txn_filter.dart';
import 'txn_form.dart';

/// Vertical-rail timeline of transactions grouped by day, with search, filters and paging.
/// Pass [bookId] to scope it to a single CashBook.
class TransactionTimeline extends ConsumerStatefulWidget {
  const TransactionTimeline({super.key, this.bookId});
  final String? bookId;

  @override
  ConsumerState<TransactionTimeline> createState() => _TransactionTimelineState();
}

class _TransactionTimelineState extends ConsumerState<TransactionTimeline> {
  static const _pageSize = 25;
  TxnFilter _filter = TxnFilter.none;
  int _visible = _pageSize;

  bool get _filtered => _filter.active;

  void _reset(TxnFilter f) => setState(() {
        _filter = f;
        _visible = _pageSize;
      });

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _filter.range,
    );
    if (picked != null) _reset(_filter.copyWith(range: picked));
  }

  Future<void> _export(List<Txn> rows, LedgerState ledger) async {
    try {
      final stamp = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await FileSaver.instance.saveFile(
        name: 'cashbook-transactions-$stamp',
        bytes: utf8.encode('﻿${transactionsCsv(rows, ledger)}'), // BOM so Excel reads UTF-8 (₹, accents)
        fileExtension: 'csv',
        mimeType: MimeType.csv,
      );
      if (mounted) toast(context, 'Exported ${rows.length} transaction${rows.length == 1 ? '' : 's'}');
    } catch (_) {
      if (mounted) toast(context, 'The export failed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final boot = ref.watch(bootProvider);
    final ledger = ref.watch(ledgerProvider);

    final all = ledger.txns.where((t) => (widget.bookId == null || t.bookId == widget.bookId) && _filter.matches(t)).toList();

    final shown = all.take(_visible).toList();
    final groups = <DateTime, List<Txn>>{};
    for (final t in shown) {
      groups.putIfAbsent(DateTime(t.date.year, t.date.month, t.date.day), () => []).add(t);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Filters(
        filter: _filter,
        onChanged: _reset,
        onPickRange: _pickRange,
        onExport: all.isEmpty ? null : () => _export(all, ledger),
        exportCount: all.length,
      ),
      const SizedBox(height: 20),
      if (boot.isLoading)
        const _TimelineSkeleton()
      else if (all.isEmpty)
        AppCard(
          child: EmptyState(
            icon: LucideIcons.inbox,
            title: _filtered ? 'No matches' : 'No transactions yet',
            message: _filtered ? 'Try a different search or clear the filters.' : 'Add your first income or expense to start the timeline.',
            action: FilledButton.icon(
              onPressed: () => showTxnForm(context, bookId: widget.bookId),
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text('Add transaction'),
            ),
          ),
        )
      else ...[
        for (final day in groups.keys) _DaySection(day: day, txns: groups[day]!, ledger: ledger, showBook: widget.bookId == null),
        if (all.length > shown.length)
          Center(
            child: OutlinedButton(
              onPressed: () => setState(() => _visible += _pageSize),
              child: Text('Show more (${all.length - shown.length} remaining)'),
            ),
          ),
      ],
    ]);
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.filter, required this.onChanged, required this.onPickRange, required this.onExport, required this.exportCount});
  final TxnFilter filter;
  final ValueChanged<TxnFilter> onChanged;
  final VoidCallback onPickRange;
  final VoidCallback? onExport;
  final int exportCount;

  static final _short = DateFormat('d MMM');

  @override
  Widget build(BuildContext context) {
    final r = filter.range;
    final rangeLabel = r == null ? 'Dates' : (r.start == r.end ? _short.format(r.start) : '${_short.format(r.start)} – ${_short.format(r.end)}');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        onChanged: (v) => onChanged(filter.copyWith(query: v)),
        decoration: const InputDecoration(hintText: 'Search title, merchant, tag…', prefixIcon: Icon(LucideIcons.search, size: 18)),
      ),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        for (final f in TypeFilter.values)
          ChoiceChip(
            label: Text(f.name[0].toUpperCase() + f.name.substring(1)),
            selected: filter.type == f,
            onSelected: (_) => onChanged(filter.copyWith(type: f)),
          ),
        PopupMenuButton<String?>(
          tooltip: 'Filter by category',
          onSelected: (v) => onChanged(v == null ? filter.copyWith(clearCategory: true) : filter.copyWith(categoryId: v)),
          itemBuilder: (_) => [
            const PopupMenuItem(value: null, child: Text('All categories')),
            for (final c in categories) PopupMenuItem(value: c.id, child: Text(c.archived ? '${c.name} (archived)' : c.name)),
          ],
          child: Chip(
            avatar: const Icon(LucideIcons.listFilter, size: 16),
            label: Text(filter.categoryId == null ? 'Category' : categoryOf(filter.categoryId!).name),
          ),
        ),
        PopupMenuButton<String?>(
          tooltip: 'Filter by payment method',
          onSelected: (v) => onChanged(v == null ? filter.copyWith(clearMethod: true) : filter.copyWith(method: v)),
          itemBuilder: (_) => [
            const PopupMenuItem(value: null, child: Text('All methods')),
            for (final m in paymentMethods) PopupMenuItem(value: m, child: Text(m)),
          ],
          child: Chip(avatar: const Icon(LucideIcons.creditCard, size: 16), label: Text(filter.method ?? 'Method')),
        ),
        InputChip(
          avatar: const Icon(LucideIcons.calendarRange, size: 16),
          label: Text(rangeLabel),
          selected: r != null,
          onPressed: onPickRange,
          onDeleted: r == null ? null : () => onChanged(filter.copyWith(clearRange: true)),
          deleteButtonTooltipMessage: 'Clear dates',
        ),
        if (filter.active)
          TextButton(onPressed: () => onChanged(TxnFilter.none), child: const Text('Clear all')),
        OutlinedButton.icon(
          onPressed: onExport,
          icon: const Icon(LucideIcons.download, size: 16),
          label: Text(filter.active ? 'Export $exportCount (CSV)' : 'Export CSV'),
        ),
      ]),
    ]);
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({required this.day, required this.txns, required this.ledger, required this.showBook});
  final DateTime day;
  final List<Txn> txns;
  final LedgerState ledger;
  final bool showBook;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final label = day == today
        ? 'Today'
        : day == today.subtract(const Duration(days: 1))
            ? 'Yesterday'
            : DateFormat('EEE, d MMM y').format(day);

    // Daily subtotal per currency (never mix currencies).
    final byCur = <String, int>{};
    for (final x in txns) {
      final cur = ledger.bookById(x.bookId)?.currency ?? 'INR';
      byCur[cur] = (byCur[cur] ?? 0) + x.signed;
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 6),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(20)),
            child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Container(height: 1, color: t.colorScheme.outline)),
          const SizedBox(width: 12),
          Text(
            byCur.entries.map((e) => formatMoney(e.value, e.key, signed: true, compact: true)).join('  ·  '),
            style: t.textTheme.labelLarge?.copyWith(color: t.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700),
          ),
        ]),
      ),
      for (var i = 0; i < txns.length; i++)
        _TimelineEntry(txn: txns[i], ledger: ledger, showBook: showBook, first: i == 0, last: i == txns.length - 1),
      const SizedBox(height: 8),
    ]);
  }
}

/// One rail segment (dot + connecting line) beside a transaction card.
class _TimelineEntry extends ConsumerWidget {
  const _TimelineEntry({required this.txn, required this.ledger, required this.showBook, required this.first, required this.last});
  final Txn txn;
  final LedgerState ledger;
  final bool showBook;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final income = txn.type == TxnType.income;
    final tone = income ? AppColors.income : AppColors.expense;
    final line = t.colorScheme.outline;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 28,
          child: Column(children: [
            Container(width: 2, height: 24, color: first ? Colors.transparent : line),
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                gradient: income ? AppColors.incomeGradient : AppColors.expenseGradient,
                shape: BoxShape.circle,
                border: Border.all(color: t.scaffoldBackgroundColor, width: 3),
                boxShadow: [BoxShadow(color: tone.withValues(alpha: 0.45), blurRadius: 8)],
              ),
            ),
            Expanded(child: Container(width: 2, color: line)),
          ]),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _TxnCard(txn: txn, ledger: ledger, showBook: showBook),
          ),
        ),
      ]),
    );
  }
}

class _TxnCard extends ConsumerWidget {
  const _TxnCard({required this.txn, required this.ledger, required this.showBook});
  final Txn txn;
  final LedgerState ledger;
  final bool showBook;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(context,
        title: 'Delete transaction?', message: '"${txn.title}" will be removed and the balance updated.', confirmLabel: 'Delete', destructive: true);
    if (!ok || !context.mounted) return;
    ref.read(ledgerProvider.notifier).deleteTxn(txn.id);
    toast(context, 'Transaction deleted', actionLabel: 'Undo', onAction: () => ref.read(ledgerProvider.notifier).restoreTxn(txn));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final cat = categoryOf(txn.categoryId);
    final book = ledger.bookById(txn.bookId);
    final income = txn.type == TxnType.income;
    final tone = income ? AppColors.income : AppColors.expense;
    final desktop = Breakpoints.ofContext(context) == ScreenSize.desktop;
    final parts = [cat.name, txn.method, DateFormat('h:mm a').format(txn.date), if (showBook && book != null) book.name];

    return AppCard(
      padding: EdgeInsets.zero,
      accent: tone,
      onTap: () => showTxnDetails(context, txn),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          GradientIcon(cat.icon, color: cat.color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(txn.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(parts.join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
              if (txn.tags.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(spacing: 6, children: [
                  for (final g in txn.tags.take(3))
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: t.colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text('#$g', style: TextStyle(fontSize: 11, color: t.colorScheme.primary, fontWeight: FontWeight.w600)),
                    ),
                ]),
              ],
            ]),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: tone.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Text(formatMoney(txn.signed, book?.currency ?? 'INR', signed: true),
                style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: tone)),
          ),
          if (desktop) ...[
            const SizedBox(width: 4),
            IconButton(tooltip: 'Edit', icon: const Icon(LucideIcons.pencil, size: 18), onPressed: () => showTxnForm(context, edit: txn)),
            IconButton(tooltip: 'Duplicate', icon: const Icon(LucideIcons.copy, size: 18), onPressed: () {
              ref.read(ledgerProvider.notifier).duplicateTxn(txn);
              toast(context, 'Transaction duplicated');
            }),
            IconButton(tooltip: 'Delete', icon: Icon(LucideIcons.trash2, size: 18, color: t.colorScheme.error), onPressed: () => _delete(context, ref)),
          ],
        ]),
      ),
    );
  }
}

class _TimelineSkeleton extends StatelessWidget {
  const _TimelineSkeleton();

  @override
  Widget build(BuildContext context) => Column(children: [
        for (var i = 0; i < 5; i++)
          const Padding(
            padding: EdgeInsets.only(bottom: 12, left: 28),
            child: Skeleton(height: 72, radius: 20),
          ),
      ]);
}
