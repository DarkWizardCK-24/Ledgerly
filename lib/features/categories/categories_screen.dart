import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/widgets/app_card.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/common.dart';
import '../ledger/ledger_store.dart';
import '../ledger/models.dart';

enum _Tab { expense, income, tags }

/// Create / rename / recolour / archive / delete categories, and rename or delete tags.
class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  _Tab _tab = _Tab.expense;

  @override
  Widget build(BuildContext context) {
    final ledger = ref.watch(ledgerProvider);
    final t = Theme.of(context);

    return PageScaffold(
      title: 'Categories & tags',
      subtitle: 'Organise how your money is labelled',
      leading: IconButton(tooltip: 'Back', onPressed: () => context.go('/settings'), icon: const Icon(LucideIcons.arrowLeft)),
      actions: [
        if (_tab != _Tab.tags)
          FilledButton.icon(
            onPressed: () => _showCategoryForm(context, income: _tab == _Tab.income),
            icon: const Icon(LucideIcons.plus, size: 18),
            label: const Text('New category'),
          ),
      ],
      children: [
        Reveal(
          child: Wrap(spacing: 8, children: [
            ChoiceChip(label: const Text('Expense'), selected: _tab == _Tab.expense, onSelected: (_) => setState(() => _tab = _Tab.expense)),
            ChoiceChip(label: const Text('Income'), selected: _tab == _Tab.income, onSelected: (_) => setState(() => _tab = _Tab.income)),
            ChoiceChip(label: const Text('Tags'), selected: _tab == _Tab.tags, onSelected: (_) => setState(() => _tab = _Tab.tags)),
          ]),
        ),
        const SizedBox(height: 16),
        if (_tab == _Tab.tags)
          _TagList(counts: ledger.tagCounts)
        else
          Reveal(
            key: ValueKey(_tab),
            child: AppCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (final c in ledger.cats.where((c) => c.income == (_tab == _Tab.income)).toList()..sort((a, b) => a.archived == b.archived ? a.name.compareTo(b.name) : (a.archived ? 1 : -1))) ...[
                  _CategoryRow(cat: c, usage: ledger.categoryUsage(c.id)),
                  Divider(color: t.colorScheme.outline),
                ],
              ]),
            ),
          ),
      ],
    );
  }
}

class _CategoryRow extends ConsumerWidget {
  const _CategoryRow({required this.cat, required this.usage});
  final Category cat;
  final int usage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final store = ref.read(ledgerProvider.notifier);
    return Opacity(
      opacity: cat.archived ? 0.55 : 1,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: GradientIcon(cat.icon, color: cat.color, size: 42),
        title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text([cat.builtin ? 'Built-in' : 'Custom', '$usage transaction${usage == 1 ? '' : 's'}', if (cat.archived) 'Archived'].join(' · ')),
        trailing: cat.builtin
            ? Tooltip(message: 'Built-in categories are read-only', child: Icon(LucideIcons.lock, size: 16, color: t.colorScheme.onSurfaceVariant))
            : PopupMenuButton<String>(
                tooltip: 'Category actions',
                onSelected: (v) async {
                  switch (v) {
                    case 'edit':
                      _showCategoryForm(context, edit: cat);
                    case 'archive':
                      store.updateCategory(cat.copyWith(archived: !cat.archived));
                      toast(context, cat.archived ? '"${cat.name}" restored' : '"${cat.name}" archived — history is kept');
                    case 'delete':
                      if (usage > 0) {
                        toast(context, 'In use by $usage transaction${usage == 1 ? '' : 's'} — archive it instead');
                        return;
                      }
                      final ok = await confirmDialog(context, title: 'Delete "${cat.name}"?', message: 'This unused category will be permanently deleted.', confirmLabel: 'Delete', destructive: true);
                      if (ok && context.mounted) {
                        store.deleteCategory(cat.id);
                        toast(context, 'Category deleted');
                      }
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(LucideIcons.pencil, size: 18), title: Text('Edit'), dense: true)),
                  PopupMenuItem(value: 'archive', child: ListTile(leading: Icon(cat.archived ? LucideIcons.archiveRestore : LucideIcons.archive, size: 18), title: Text(cat.archived ? 'Restore' : 'Archive'), dense: true)),
                  const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(LucideIcons.trash2, size: 18), title: Text('Delete'), dense: true)),
                ],
              ),
      ),
    );
  }
}

void _showCategoryForm(BuildContext context, {Category? edit, bool income = false}) =>
    showAdaptiveSheet<void>(context, builder: (_) => _CategoryForm(edit: edit, income: edit?.income ?? income));

class _CategoryForm extends ConsumerStatefulWidget {
  const _CategoryForm({this.edit, required this.income});
  final Category? edit;
  final bool income;

  @override
  ConsumerState<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends ConsumerState<_CategoryForm> {
  final _key = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.edit?.name ?? '');
  late IconData _icon = widget.edit?.icon ?? categoryIcons.first;
  late Color _color = widget.edit?.color ?? bookColors.first;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    if (!_key.currentState!.validate()) return;
    final store = ref.read(ledgerProvider.notifier);
    final ok = widget.edit == null
        ? store.addCategory(name: _name.text, income: widget.income, icon: _icon, color: _color)
        : store.updateCategory(widget.edit!.copyWith(name: _name.text.trim(), icon: _icon, color: _color));
    if (!ok) {
      setState(() => _error = 'A ${widget.income ? 'income' : 'expense'} category with this name already exists.');
      return;
    }
    Navigator.pop(context);
    toast(context, widget.edit == null ? 'Category created' : 'Category updated');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Form(
        key: _key,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.edit == null ? 'New ${widget.income ? 'income' : 'expense'} category' : 'Edit category', style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Center(child: GradientIcon(_icon, color: _color, size: 64)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _name,
            autofocus: widget.edit == null,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: 'Name', errorText: _error),
            onChanged: (_) => setState(() => _error = null),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Name this category' : (v.trim().length > 60 ? 'Keep it under 60 characters' : null),
          ),
          const SizedBox(height: 16),
          Text('Icon', style: t.textTheme.labelLarge?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final i in categoryIcons)
              ChoiceChip(label: Icon(i, size: 18), selected: _icon == i, showCheckmark: false, onSelected: (_) => setState(() => _icon = i)),
          ]),
          const SizedBox(height: 16),
          Text('Color', style: t.textTheme.labelLarge?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 8, children: [
            for (final c in [...bookColors, const Color(0xFF12B76A), const Color(0xFFEC4899), const Color(0xFF64748B)])
              GestureDetector(
                onTap: () => setState(() => _color = c),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: _color == c ? t.colorScheme.onSurface : Colors.transparent, width: 3)),
                ),
              ),
          ]),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: FilledButton(onPressed: _save, child: Text(widget.edit == null ? 'Create category' : 'Save changes'))),
          ]),
        ]),
      ),
    );
  }
}

class _TagList extends ConsumerWidget {
  const _TagList({required this.counts});
  final Map<String, int> counts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final store = ref.read(ledgerProvider.notifier);
    final tags = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (tags.isEmpty) {
      return const AppCard(child: EmptyState(icon: LucideIcons.tag, title: 'No tags yet', message: 'Add tags like #bills or #trip when you create a transaction.'));
    }
    return Reveal(
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          for (final e in tags) ...[
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              leading: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: t.colorScheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(LucideIcons.hash, size: 18, color: t.colorScheme.primary),
              ),
              title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${e.value} transaction${e.value == 1 ? '' : 's'}'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(tooltip: 'Rename', icon: const Icon(LucideIcons.pencil, size: 18), onPressed: () => _rename(context, store, e.key)),
                IconButton(
                  tooltip: 'Delete',
                  icon: Icon(LucideIcons.trash2, size: 18, color: t.colorScheme.error),
                  onPressed: () async {
                    final ok = await confirmDialog(context, title: 'Remove tag "${e.key}"?', message: 'It will be removed from ${e.value} transaction${e.value == 1 ? '' : 's'}. The transactions themselves are kept.', confirmLabel: 'Remove', destructive: true);
                    if (ok && context.mounted) {
                      store.deleteTag(e.key);
                      toast(context, 'Tag removed');
                    }
                  },
                ),
              ]),
            ),
            Divider(color: t.colorScheme.outline),
          ],
        ]),
      ),
    );
  }

  Future<void> _rename(BuildContext context, LedgerNotifier store, String tag) async {
    final c = TextEditingController(text: tag);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Rename tag'),
        content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(labelText: 'Tag name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Rename')),
        ],
      ),
    );
    c.dispose();
    if (name != null && name.isNotEmpty && name != tag && context.mounted) {
      store.renameTag(tag, name);
      toast(context, 'Tag renamed');
    }
  }
}
