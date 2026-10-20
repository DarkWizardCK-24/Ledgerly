import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format/money.dart';
import '../../core/widgets/common.dart';
import '../ledger/ledger_store.dart';
import '../ledger/models.dart';

Future<void> showTxnForm(BuildContext context, {Txn? edit, String? bookId, TxnType? type}) {
  return showAdaptiveSheet<void>(context, builder: (_) => TxnForm(edit: edit, bookId: bookId, type: type));
}

class TxnForm extends ConsumerStatefulWidget {
  const TxnForm({super.key, this.edit, this.bookId, this.type});
  final Txn? edit;
  final String? bookId;
  final TxnType? type;

  @override
  ConsumerState<TxnForm> createState() => _TxnFormState();
}

class _TxnFormState extends ConsumerState<TxnForm> {
  final _key = GlobalKey<FormState>();
  late TxnType _type = widget.edit?.type ?? widget.type ?? TxnType.expense;
  late String? _bookId = widget.edit?.bookId ?? widget.bookId;
  late String _categoryId = widget.edit?.categoryId ?? defaultCategoryId(income: widget.type == TxnType.income);
  late String _method = widget.edit?.method ?? 'UPI';
  late DateTime _date = widget.edit?.date ?? DateTime.now();
  late final _amount = TextEditingController(
      text: widget.edit == null ? '' : (widget.edit!.amountMinor / 100).toStringAsFixed(2));
  late final _title = TextEditingController(text: widget.edit?.title ?? '');
  late final _merchant = TextEditingController(text: widget.edit?.merchant ?? '');
  late final _note = TextEditingController(text: widget.edit?.note ?? '');
  late final _tags = TextEditingController(text: widget.edit?.tags.join(', ') ?? '');

  @override
  void dispose() {
    for (final c in [_amount, _title, _merchant, _note, _tags]) {
      c.dispose();
    }
    super.dispose();
  }

  List<Category> get _cats => categories.where((c) => c.income == (_type == TxnType.income) && (!c.archived || c.id == widget.edit?.categoryId)).toList();

  void _setType(TxnType t) => setState(() {
        _type = t;
        if (!_cats.any((c) => c.id == _categoryId)) _categoryId = _cats.first.id;
      });

  Future<void> _pickDate() async {
    final d = await showDatePicker(
        context: context, initialDate: _date, firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_date));
    setState(() => _date = DateTime(d.year, d.month, d.day, t?.hour ?? _date.hour, t?.minute ?? _date.minute));
  }

  void _save() {
    if (!_key.currentState!.validate()) return;
    final store = ref.read(ledgerProvider.notifier);
    final tags = _tags.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final minor = parseMinor(_amount.text)!;
    if (widget.edit == null) {
      store.addTxn((id) => Txn(id: id, bookId: _bookId!, type: _type, amountMinor: minor, title: _title.text.trim(),
          note: _note.text.trim(), categoryId: _categoryId, date: _date, method: _method, merchant: _merchant.text.trim(), tags: tags));
    } else {
      store.updateTxn(widget.edit!.copyWith(bookId: _bookId, type: _type, amountMinor: minor, title: _title.text.trim(),
          note: _note.text.trim(), categoryId: _categoryId, date: _date, method: _method, merchant: _merchant.text.trim(), tags: tags));
    }
    Navigator.pop(context);
    toast(context, widget.edit == null ? 'Transaction added' : 'Transaction updated');
  }

  @override
  Widget build(BuildContext context) {
    final books = ref.watch(ledgerProvider).books.where((b) => !b.archived || b.id == _bookId).toList();
    final t = Theme.of(context);
    final book = books.where((b) => b.id == _bookId).firstOrNull;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Form(
        key: _key,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(widget.edit == null ? 'New transaction' : 'Edit transaction',
              style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          SegmentedButton<TxnType>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: TxnType.expense, label: Text('Expense')),
              ButtonSegment(value: TxnType.income, label: Text('Income')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => _setType(s.first),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _amount,
            autofocus: widget.edit == null,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            decoration: InputDecoration(labelText: 'Amount', prefixText: '${currencySymbol(book?.currency ?? 'INR')} '),
            validator: (v) {
              final m = parseMinor(v ?? '');
              if (m == null) return 'Enter a valid amount (up to 2 decimals)';
              if (m <= 0) return 'Amount must be greater than zero';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Title'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Give this transaction a title' : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _bookId,
            decoration: const InputDecoration(labelText: 'CashBook'),
            items: [for (final b in books) DropdownMenuItem(value: b.id, child: Text('${b.name} · ${b.currency}'))],
            onChanged: (v) => setState(() => _bookId = v),
            validator: (v) => v == null ? 'Choose a CashBook' : null,
          ),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey(_type),
                initialValue: _categoryId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [for (final c in _cats) DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))],
                onChanged: (v) => setState(() => _categoryId = v!),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _method,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Payment method'),
                items: [for (final m in paymentMethods) DropdownMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis))],
                onChanged: (v) => setState(() => _method = v!),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _pickDate,
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Date & time'),
              child: Text(DateFormat('EEE, d MMM y · h:mm a').format(_date)),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(controller: _merchant, decoration: const InputDecoration(labelText: 'Merchant / counterparty (optional)')),
          const SizedBox(height: 12),
          TextFormField(controller: _tags, decoration: const InputDecoration(labelText: 'Tags (comma separated, optional)')),
          const SizedBox(height: 12),
          TextFormField(controller: _note, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes (optional)')),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: FilledButton(onPressed: _save, child: Text(widget.edit == null ? 'Add transaction' : 'Save changes'))),
          ]),
        ]),
      ),
    );
  }
}
