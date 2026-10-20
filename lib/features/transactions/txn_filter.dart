import 'package:flutter/material.dart';

import '../ledger/ledger_store.dart';
import '../ledger/models.dart';

enum TypeFilter { all, income, expense }

/// Everything the timeline can narrow by. Pure data so it can be tested without widgets.
class TxnFilter {
  const TxnFilter({this.query = '', this.type = TypeFilter.all, this.categoryId, this.method, this.range});
  final String query;
  final TypeFilter type;
  final String? categoryId;
  final String? method;
  final DateTimeRange? range; // inclusive of both days

  static const none = TxnFilter();

  bool get active => query.trim().isNotEmpty || type != TypeFilter.all || categoryId != null || method != null || range != null;

  TxnFilter copyWith({String? query, TypeFilter? type, String? categoryId, String? method, DateTimeRange? range, bool clearCategory = false, bool clearMethod = false, bool clearRange = false}) => TxnFilter(
        query: query ?? this.query,
        type: type ?? this.type,
        categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
        method: clearMethod ? null : (method ?? this.method),
        range: clearRange ? null : (range ?? this.range),
      );

  bool matches(Txn t) {
    if (type == TypeFilter.income && t.type != TxnType.income) return false;
    if (type == TypeFilter.expense && t.type != TxnType.expense) return false;
    if (categoryId != null && t.categoryId != categoryId) return false;
    if (method != null && t.method != method) return false;
    final r = range;
    if (r != null) {
      final start = DateTime(r.start.year, r.start.month, r.start.day);
      final end = DateTime(r.end.year, r.end.month, r.end.day).add(const Duration(days: 1));
      if (t.date.isBefore(start) || !t.date.isBefore(end)) return false;
    }
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return t.title.toLowerCase().contains(q) ||
        t.merchant.toLowerCase().contains(q) ||
        t.note.toLowerCase().contains(q) ||
        t.tags.any((g) => g.toLowerCase().contains(q)) ||
        categoryOf(t.categoryId).name.toLowerCase().contains(q);
  }
}

String _two(int n) => n.toString().padLeft(2, '0');

/// A spreadsheet treats a cell starting with = + - @ (or a control character) as a formula; a leading quote defuses it.
String _cell(Object o) {
  if (o is int) return _decimal(o); // numbers are never formulas, so negatives stay plain
  final v = o as String;
  final safe = v.isNotEmpty && '=+-@\t\r'.contains(v[0]) ? "'$v" : v;
  return safe.contains(RegExp(r'[",\n\r]')) ? '"${safe.replaceAll('"', '""')}"' : safe;
}

/// Whole units with two decimals from minor units, e.g. -12345 -> "-123.45".
String _decimal(int minor) => '${minor < 0 ? '-' : ''}${minor.abs() ~/ 100}.${_two(minor.abs() % 100)}';

/// CSV of the given transactions (newest first as passed). Amounts are plain numbers, negative for expenses.
String transactionsCsv(Iterable<Txn> txns, LedgerState ledger) {
  final rows = <List<Object>>[
    ['Date', 'Time', 'CashBook', 'Type', 'Title', 'Category', 'Amount', 'Currency', 'Method', 'Merchant', 'Tags', 'Note'],
    for (final t in txns)
      [
        '${t.date.year}-${_two(t.date.month)}-${_two(t.date.day)}',
        '${_two(t.date.hour)}:${_two(t.date.minute)}',
        ledger.bookById(t.bookId)?.name ?? '',
        t.type == TxnType.income ? 'Income' : 'Expense',
        t.title,
        categoryOf(t.categoryId).name,
        t.signed,
        ledger.bookById(t.bookId)?.currency ?? '',
        t.method,
        t.merchant,
        t.tags.join(' '),
        t.note,
      ],
  ];
  return rows.map((r) => r.map(_cell).join(',')).join('\r\n');
}
