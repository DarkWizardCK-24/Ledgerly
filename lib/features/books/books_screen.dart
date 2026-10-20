import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/responsive/breakpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/common.dart';
import '../ledger/ledger_store.dart';
import 'book_card.dart';
import 'book_form.dart';

enum _Sort { recent, name, balance }

class BooksScreen extends ConsumerStatefulWidget {
  const BooksScreen({super.key});

  @override
  ConsumerState<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends ConsumerState<BooksScreen> {
  String _query = '';
  _Sort _sort = _Sort.recent;
  bool _archived = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final boot = ref.watch(bootProvider);
    final ledger = ref.watch(ledgerProvider);
    final q = _query.trim().toLowerCase();

    final books = ledger.books.where((b) => b.archived == _archived && (q.isEmpty || b.name.toLowerCase().contains(q) || b.description.toLowerCase().contains(q))).toList()
      ..sort((a, b) => switch (_sort) {
            _Sort.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            _Sort.balance => ledger.balanceOf(b).compareTo(ledger.balanceOf(a)),
            _Sort.recent => (ledger.lastActivity(b) ?? b.createdAt).compareTo(ledger.lastActivity(a) ?? a.createdAt),
          });

    final active = ledger.books.where((b) => !b.archived).toList();
    final totalInr = active.where((b) => b.currency == 'INR').fold(0, (s, b) => s + ledger.balanceOf(b));
    final width = MediaQuery.sizeOf(context).width;
    final cols = Breakpoints.columns(width - (width >= Breakpoints.desktop ? 264 : 0)).clamp(1, 3);
    final showAdd = !_archived && q.isEmpty;

    return PageScaffold(
      title: 'CashBooks',
      subtitle: 'Separate ledgers for every part of your life',
      actions: [
        FilledButton.icon(onPressed: () => showBookForm(context), icon: const Icon(LucideIcons.plus, size: 18), label: const Text('New CashBook')),
      ],
      children: [
        if (!boot.isLoading)
          Reveal(
            child: LayoutBuilder(builder: (context, c) {
              final tiles = [
                _Summary(icon: LucideIcons.bookOpen, color: AppColors.warning, label: 'Active books', value: '${active.length}'),
                _Summary(icon: LucideIcons.wallet, color: AppColors.income, label: 'Combined balance', money: totalInr),
                _Summary(icon: LucideIcons.arrowLeftRight, color: AppColors.expense, label: 'Transactions', value: '${ledger.txns.length}'),
              ];
              if (c.maxWidth < 620) return Column(children: [for (final x in tiles) Padding(padding: const EdgeInsets.only(bottom: 10), child: x)]);
              return Row(children: [for (var i = 0; i < tiles.length; i++) ...[if (i > 0) const SizedBox(width: 14), Expanded(child: tiles[i])]]);
            }),
          ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: t.colorScheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: t.colorScheme.outline)),
          child: Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(
              width: width < Breakpoints.tablet ? double.infinity : 320,
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(hintText: 'Search CashBooks…', prefixIcon: Icon(LucideIcons.search, size: 18), isDense: true),
              ),
            ),
            ChoiceChip(label: Text('Active (${active.length})'), selected: !_archived, onSelected: (_) => setState(() => _archived = false)),
            ChoiceChip(label: Text('Archived (${ledger.books.length - active.length})'), selected: _archived, onSelected: (_) => setState(() => _archived = true)),
            PopupMenuButton<_Sort>(
              tooltip: 'Sort',
              onSelected: (s) => setState(() => _sort = s),
              itemBuilder: (_) => const [
                PopupMenuItem(value: _Sort.recent, child: Text('Recent activity')),
                PopupMenuItem(value: _Sort.name, child: Text('Name')),
                PopupMenuItem(value: _Sort.balance, child: Text('Balance')),
              ],
              child: Chip(avatar: const Icon(LucideIcons.arrowUpDown, size: 16), label: Text(switch (_sort) { _Sort.recent => 'Recent activity', _Sort.name => 'Name', _Sort.balance => 'Balance' })),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        if (boot.isLoading)
          _grid(cols, [for (var i = 0; i < 4; i++) const Skeleton(height: 190, radius: 20)])
        else if (books.isEmpty && !showAdd)
          EmptyState(
            icon: _archived ? LucideIcons.archive : LucideIcons.bookOpen,
            title: q.isNotEmpty ? 'No matching CashBooks' : 'Nothing archived',
            message: q.isNotEmpty ? 'Try a different search.' : 'Archived books appear here and can be restored.',
          )
        else
          _grid(cols, [
            for (var i = 0; i < books.length; i++) Reveal(index: i, child: BookCard(book: books[i])),
            if (showAdd) Reveal(index: books.length, child: AddBookCard(onTap: () => showBookForm(context))),
          ]),
      ],
    );
  }

  /// Rows of equal-height cards so the add card always matches the book cards.
  Widget _grid(int cols, List<Widget> children) {
    const gap = 16.0;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += cols) {
      final slice = children.sublist(i, (i + cols).clamp(0, children.length));
      rows.add(Padding(
        padding: EdgeInsets.only(bottom: i + cols < children.length ? gap : 0),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var j = 0; j < cols; j++) ...[
              if (j > 0) const SizedBox(width: gap),
              Expanded(child: j < slice.length ? slice[j] : const SizedBox.shrink()),
            ],
          ]),
        ),
      ));
    }
    return Column(children: rows);
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.icon, required this.color, required this.label, this.value, this.money});
  final IconData icon;
  final Color color;
  final String label;
  final String? value;
  final int? money;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final style = t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800);
    return AppCard(
      accent: color,
      gradient: LinearGradient(colors: [color.withValues(alpha: 0.12), t.colorScheme.surface], begin: Alignment.topLeft, end: Alignment.bottomRight),
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        GradientIcon(icon, color: color, size: 42),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            if (money != null) FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: AnimatedMoney(money!, 'INR', style: style)) else Text(value ?? '', style: style),
          ]),
        ),
      ]),
    );
  }
}

/// Same footprint as a [BookCard]: a dashed "add" tile that opens the create form.
class AddBookCard extends StatefulWidget {
  const AddBookCard({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  State<AddBookCard> createState() => _AddBookCardState();
}

class _AddBookCardState extends State<AddBookCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final color = t.colorScheme.primary;
    return Semantics(
      button: true,
      label: 'Add a new CashBook',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: SystemMouseCursors.click,
        child: AnimatedScale(
          scale: _hover ? 1.02 : 1,
          duration: const Duration(milliseconds: 160),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: widget.onTap,
            child: CustomPaint(
              painter: _DashedBorder(color: color.withValues(alpha: _hover ? 0.9 : 0.45), radius: 20),
              child: Container(
                constraints: const BoxConstraints(minHeight: 188),
                decoration: BoxDecoration(color: color.withValues(alpha: _hover ? 0.09 : 0.05), borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.all(20),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(gradient: AppColors.brandGradient, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.expense.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 8))]),
                    child: const Icon(LucideIcons.plus, color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 14),
                  Text('New CashBook', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('Personal, Household, Business, Travel…', textAlign: TextAlign.center, style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  _DashedBorder({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 9), paint);
        d += 15;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder o) => o.color != color;
}
