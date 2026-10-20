import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/money.dart';
import '../../core/widgets/common.dart';
import '../ledger/ledger_store.dart';
import '../ledger/models.dart';

Future<void> showBookForm(BuildContext context, {Book? edit}) =>
    showAdaptiveSheet<void>(context, builder: (_) => BookForm(edit: edit));

class BookForm extends ConsumerStatefulWidget {
  const BookForm({super.key, this.edit});
  final Book? edit;

  @override
  ConsumerState<BookForm> createState() => _BookFormState();
}

class _BookFormState extends ConsumerState<BookForm> {
  final _key = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.edit?.name ?? '');
  late final _desc = TextEditingController(text: widget.edit?.description ?? '');
  late final _opening = TextEditingController(
      text: widget.edit == null || widget.edit!.openingMinor == 0 ? '' : (widget.edit!.openingMinor / 100).toStringAsFixed(2));
  late String _currency = widget.edit?.currency ?? 'INR';
  late String _iconKey = widget.edit?.iconKey ?? 'wallet';
  late Color _color = widget.edit?.color ?? bookColors.first;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _opening.dispose();
    super.dispose();
  }

  void _save() {
    if (!_key.currentState!.validate()) return;
    final store = ref.read(ledgerProvider.notifier);
    final opening = _opening.text.trim().isEmpty ? 0 : parseMinor(_opening.text)!;
    if (widget.edit == null) {
      store.addBook((id) => Book(
          id: id, name: _name.text.trim(), description: _desc.text.trim(), currency: _currency,
          openingMinor: opening, color: _color, iconKey: _iconKey, createdAt: DateTime.now()));
    } else {
      store.updateBook(widget.edit!.copyWith(
          name: _name.text.trim(), description: _desc.text.trim(), currency: _currency,
          openingMinor: opening, color: _color, iconKey: _iconKey));
    }
    Navigator.pop(context);
    toast(context, widget.edit == null ? 'CashBook created' : 'CashBook updated');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final editing = widget.edit != null;
    final hasTxns = editing && ref.read(ledgerProvider).txnsOf(widget.edit!.id).isNotEmpty;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Form(
        key: _key,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(editing ? 'Edit CashBook' : 'New CashBook', style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          if (!editing) ...[
            const SizedBox(height: 16),
            Text('Start from a suggestion', style: t.textTheme.labelLarge?.copyWith(color: t.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final s in bookTemplates)
                ActionChip(
                  avatar: Icon(bookIcons[s.iconKey], size: 16),
                  label: Text(s.name),
                  onPressed: () => setState(() {
                    _name.text = s.name;
                    _desc.text = s.description;
                    _iconKey = s.iconKey;
                  }),
                ),
            ]),
          ],
          const SizedBox(height: 16),
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Name your CashBook' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(controller: _desc, decoration: const InputDecoration(labelText: 'Description (optional)')),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _currency,
                decoration: InputDecoration(labelText: 'Currency', helperText: hasTxns ? 'Locked: has transactions' : null),
                items: [for (final c in currencies) DropdownMenuItem(value: c, child: Text('${currencySymbol(c)}  $c'))],
                onChanged: hasTxns ? null : (v) => setState(() => _currency = v!),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _opening,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Opening balance'),
                validator: (v) => (v == null || v.trim().isEmpty || parseMinor(v) != null) ? null : 'Invalid amount',
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Text('Icon', style: t.textTheme.labelLarge?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in bookIcons.entries)
              ChoiceChip(
                label: Icon(e.value, size: 18),
                selected: _iconKey == e.key,
                showCheckmark: false,
                onSelected: (_) => setState(() => _iconKey = e.key),
              ),
          ]),
          const SizedBox(height: 16),
          Text('Color', style: t.textTheme.labelLarge?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 8, children: [
            for (final c in bookColors)
              Semantics(
                button: true,
                selected: _color == c,
                label: 'Color',
                child: GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(color: _color == c ? t.colorScheme.onSurface : Colors.transparent, width: 3),
                    ),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: FilledButton(onPressed: _save, child: Text(editing ? 'Save changes' : 'Create CashBook'))),
          ]),
        ]),
      ),
    );
  }
}
