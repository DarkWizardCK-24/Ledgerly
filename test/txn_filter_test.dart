import 'package:cashbook/features/ledger/ledger_store.dart';
import 'package:cashbook/features/ledger/models.dart';
import 'package:cashbook/features/transactions/txn_filter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Txn _t(String id, {TxnType type = TxnType.expense, int minor = 10000, String title = 'Lunch', String cat = 'food', String method = 'UPI', DateTime? date, String note = '', String merchant = ''}) =>
    Txn(id: id, bookId: 'b1', type: type, amountMinor: minor, title: title, categoryId: cat, date: date ?? DateTime(2026, 3, 10, 12), method: method, note: note, merchant: merchant);

void main() {
  final book = Book(id: 'b1', name: 'Personal', currency: 'INR', color: Colors.red, createdAt: DateTime(2026));
  final ledger = LedgerState(books: [book], txns: const [], cats: defaultCategories);

  test('method and type filters combine', () {
    final f = const TxnFilter(method: 'UPI', type: TypeFilter.expense);
    expect(f.matches(_t('1')), isTrue);
    expect(f.matches(_t('2', method: 'Cash')), isFalse);
    expect(f.matches(_t('3', type: TxnType.income)), isFalse);
  });

  test('date range includes both end days in full and excludes the days around it', () {
    final f = TxnFilter(range: DateTimeRange(start: DateTime(2026, 3, 10), end: DateTime(2026, 3, 12)));
    expect(f.matches(_t('a', date: DateTime(2026, 3, 10, 0, 0))), isTrue);
    expect(f.matches(_t('b', date: DateTime(2026, 3, 12, 23, 59))), isTrue);
    expect(f.matches(_t('c', date: DateTime(2026, 3, 9, 23, 59))), isFalse);
    expect(f.matches(_t('d', date: DateTime(2026, 3, 13, 0, 0))), isFalse);
  });

  test('clear flags remove a single filter', () {
    final f = const TxnFilter(method: 'UPI', categoryId: 'food').copyWith(clearMethod: true);
    expect(f.method, isNull);
    expect(f.categoryId, 'food');
    expect(const TxnFilter().active, isFalse);
  });

  test('csv: signed plain-number amounts, quoting, and formula-injection guard', () {
    final csv = transactionsCsv([
      _t('1', minor: 12345, title: 'Dinner, "late"', merchant: '=HYPERLINK("x")'),
      _t('2', type: TxnType.income, minor: 500, title: 'Refund', cat: 'otherIn'),
    ], ledger);
    final lines = csv.split('\r\n');
    expect(lines.first, startsWith('Date,Time,CashBook,Type,Title'));
    expect(lines[1], contains('"Dinner, ""late"""'));
    expect(lines[1], contains(',-123.45,INR,')); // negative number stays a number, not escaped
    expect(lines[1], contains("\"'=HYPERLINK(\"\"x\"\")\"")); // formula neutralised
    expect(lines[2], contains(',5.00,INR,'));
  });
}
