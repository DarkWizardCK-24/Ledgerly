@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:cashbook/features/ledger/ledger_repository.dart';
import 'package:cashbook/features/ledger/models.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// Runs the Flutter data layer against the REAL FastAPI backend on a real PostgreSQL.
/// Skipped unless E2E_API_URL and E2E_TOKEN are set (see docs/setup-guide.md):
///   python backend/scripts/dev_server.py --port 8010 --seed-user `uuid`
///   E2E_API_URL=http://localhost:8010 E2E_TOKEN=`an HS256 jwt for that user` flutter test test/live_backend_test.dart
const _csv = 'Sample Bank\nAccount No: XX4821\n\nDate,Description,Debit,Credit,Balance\n'
    ',Opening Balance,,,"10,000.00"\n'
    '01/09/2026,NEFT-ACME CORP-SALARY,,"85,000.00","95,000.00"\n'
    '02/09/2026,UPI-SWIGGY-ORDER 3770,313.00,,"94,687.00"\n'
    '05/09/2026,ACH D- NETFLIX.COM,499.00,,"94,188.00"\n'
    ',Closing Balance,,,"94,188.00"\n';

void main() {
  final api = Platform.environment['E2E_API_URL'];
  final token = Platform.environment['E2E_TOKEN'];
  final skip = (api == null || token == null) ? 'set E2E_API_URL and E2E_TOKEN to run against a real backend' : null;

  test('CashBook data layer against the real API and a real PostgreSQL', skip: skip, () async {
    HttpOverrides.global = null; // flutter_test blocks real network by default
    final client = http.Client();
    final repo = LedgerRepository(baseUrl: api!, token: () async => token, client: client);
    final h = {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};
    Future<dynamic> raw(String method, String path, [Object? body]) async {
      final r = http.Request(method, Uri.parse('$api/api/v1$path'))..headers.addAll(h);
      if (body != null) r.body = jsonEncode(body);
      final res = await http.Response.fromStream(await client.send(r));
      expect(res.statusCode, lessThan(300), reason: '$method $path -> ${res.body}');
      return res.body.isEmpty ? null : jsonDecode(res.body);
    }

    // built-in categories come from the server with real UUIDs
    var d = await repo.loadAll();
    expect(d.cats.where((c) => c.builtin).length, 17);
    final food = d.cats.firstWhere((c) => c.name == 'Food & groceries');
    final salary = d.cats.firstWhere((c) => c.name == 'Salary');
    expect(food.income, isFalse);
    expect(salary.income, isTrue);

    // books
    final book = await repo.createBook(Book(id: 'tmp', name: 'Personal', currency: 'INR', openingMinor: 100000, color: bookColors[2], iconKey: 'house', createdAt: DateTime.now()));
    expect(book.id, isNot('tmp'));
    expect(book.color, bookColors[2]);
    expect(book.iconKey, 'house');

    // transactions: exact integer paise, UTC round-trip, tags, update, delete
    final when = DateTime(2026, 9, 12, 18, 45);
    final t = await repo.createTxn(Txn(id: 'tmp', bookId: book.id, type: TxnType.expense, amountMinor: 123456, title: 'Groceries', categoryId: food.id, date: when, method: 'UPI', merchant: 'FreshMart', tags: ['weekly', 'home']));
    expect(t.amountMinor, 123456);
    expect(t.date.toUtc(), when.toUtc());
    expect(t.tags, ['weekly', 'home']);
    expect(t.categoryId, food.id);
    final edited = await repo.updateTxn(t.copyWith(amountMinor: 99999, title: 'Groceries (edited)'));
    expect(edited.amountMinor, 99999);
    expect(edited.title, 'Groceries (edited)');
    final income = await repo.createTxn(Txn(id: 'tmp', bookId: book.id, type: TxnType.income, amountMinor: 500000, title: 'Pay', categoryId: salary.id, date: when));

    d = await repo.loadAll();
    expect(d.txns.length, 2);
    final b = d.books.single;
    expect(b.openingMinor + d.txns.fold<int>(0, (s, x) => s + x.signed), 100000 + 500000 - 99999);

    // the server refuses to delete a book that has transactions; archiving works
    await expectLater(repo.deleteBook(book.id), throwsA(isA<LedgerApiException>().having((e) => e.code, 'code', 'book_has_transactions')));
    final archived = await repo.updateBook(b.copyWith(archived: true));
    expect(archived.archived, isTrue);
    await repo.updateBook(b.copyWith(archived: false));

    // custom category: create, rename, archive
    final cat = await repo.createCategory(Category('tmp', 'Pets', categoryIcons[18], const Color(0xFF0D9488), income: false, builtin: false));
    expect(cat.icon, categoryIcons[18]);
    expect((await repo.updateCategory(cat.copyWith(name: 'Pet care'))).name, 'Pet care');
    expect((await repo.updateCategory(cat.copyWith(archived: true))).archived, isTrue);

    // an Analyzer import shows up in CashBook as an imported, tagged row
    final req = http.MultipartRequest('POST', Uri.parse('$api/api/v1/statement-processing/process'))
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['report_book_id'] = (await raw('POST', '/report-books', {'name': 'Bank'}))['id'] as String
      ..files.add(http.MultipartFile.fromString('file', _csv, filename: 'statement.csv'));
    final processed = jsonDecode(await (await client.send(req)).stream.bytesToString()) as Map<String, dynamic>;
    final reportId = processed['report_id'] as String;
    final rows = await raw('GET', '/reports/$reportId/transactions') as List;
    await raw('PUT', '/reports/$reportId/reviews', {'items': [for (final r in rows) {'transaction_id': r['id'], 'reviewed': true}]});
    final imp = await raw('POST', '/imports/confirm', {'report_id': reportId, 'cashbook_id': book.id, 'idempotency_key': 'flutter-e2e-0001'});
    expect(imp['imported_count'], 3);
    d = await repo.loadAll();
    final imported = d.txns.where((x) => x.imported).toList();
    expect(imported.length, 3);
    expect(imported.every((x) => x.tags.contains('imported')), isTrue);
    expect(d.txns.length, 5, reason: '2 manual + 3 imported');

    // data controls
    final summary = await repo.dataSummary();
    expect(summary['transactions'], 5);
    final exported = jsonDecode(await repo.exportAll()) as Map<String, dynamic>;
    expect((exported['cashbook'] as Map)['transactions'], hasLength(5));
    final noConfirm = await client.send(http.Request('DELETE', Uri.parse('$api/api/v1/me/data?scope=all'))..headers.addAll(h));
    expect(noConfirm.statusCode, 422, reason: 'deleting without the DELETE confirmation is refused');
    await repo.deleteData('all');
    d = await repo.loadAll();
    expect(d.books, isEmpty);
    expect(d.txns, isEmpty);
    expect(d.cats.where((c) => !c.builtin), isEmpty);
    expect(income.id, isNotEmpty);
  });
}

