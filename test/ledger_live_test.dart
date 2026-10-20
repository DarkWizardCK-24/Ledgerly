import 'dart:convert';

import 'package:cashbook/app/providers.dart';
import 'package:cashbook/core/api/api_client.dart';
import 'package:cashbook/features/auth/auth_controller.dart';
import 'package:cashbook/features/auth/auth_service.dart';
import 'package:cashbook/features/ledger/ledger_repository.dart';
import 'package:cashbook/main.dart';
import 'package:cashbook/features/ledger/ledger_store.dart';
import 'package:cashbook/features/ledger/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A tiny in-memory stand-in for the FastAPI backend (same routes, same JSON shapes, same error envelope).
class FakeServer {
  final books = <Map<String, dynamic>>[];
  final txns = <Map<String, dynamic>>[];
  final cats = <Map<String, dynamic>>[
    {'id': 'cat-food', 'name': 'Food & groceries', 'kind': 'expense', 'icon_key': 'utensils', 'color': '#F97316', 'archived': false, 'is_builtin': true},
    {'id': 'cat-other', 'name': 'Other', 'kind': 'expense', 'icon_key': 'ellipsis', 'color': '#94A3B8', 'archived': false, 'is_builtin': true},
    {'id': 'cat-salary', 'name': 'Salary', 'kind': 'income', 'icon_key': 'banknote', 'color': '#12B76A', 'archived': false, 'is_builtin': true},
  ];
  final seen = <String>[];
  final reject = <String, ({int status, String code, String message})>{}; // "METHOD /path" -> error
  bool offline = false;
  int _n = 0;

  Map<String, dynamic> addBook(String name, {int opening = 0}) {
    final b = <String, dynamic>{
      'id': 'bk-${_n++}', 'name': name, 'description': '', 'currency': 'INR', 'opening_minor': opening, 'color': '#E8590C', 'icon_key': 'wallet',
      'archived': false, 'created_at': '2026-09-01T00:00:00Z', 'updated_at': '2026-09-01T00:00:00Z',
    };
    books.add(b);
    return b;
  }

  Map<String, dynamic> addTxn(String bookId, int amount, {String type = 'expense', String source = 'manual', String occurred = '2026-09-10T10:00:00Z'}) {
    final t = <String, dynamic>{
      'id': 'tx-${_n++}', 'book_id': bookId, 'type': type, 'amount_minor': amount, 'title': 'Row $_n', 'note': '', 'category_id': 'cat-food',
      'occurred_at': occurred, 'payment_method': 'UPI', 'merchant': '', 'tags': <String>[], 'created_source': source,
    };
    txns.add(t);
    return t;
  }

  http.Response _json(Object? body, [int status = 200]) => http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

  Future<http.Response> handle(http.Request r) async {
    if (offline) throw http.ClientException('offline');
    final path = r.url.path.replaceFirst('/api/v1', '');
    final key = '${r.method} $path';
    seen.add(key);
    final rej = reject[key];
    if (rej != null) return _json({'error': {'code': rej.code, 'message': rej.message}}, rej.status);
    final body = r.body.isEmpty ? <String, dynamic>{} : jsonDecode(r.body) as Map<String, dynamic>;
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();

    if (r.method == 'GET' && path == '/cashbooks') return _json(books);
    if (r.method == 'GET' && path == '/categories') return _json(cats);
    if (r.method == 'GET' && path == '/transactions') {
      final limit = int.parse(r.url.queryParameters['limit'] ?? '50');
      final offset = int.parse(r.url.queryParameters['offset'] ?? '0');
      return _json({'items': txns.skip(offset).take(limit).toList(), 'total': txns.length, 'limit': limit, 'offset': offset});
    }
    if (r.method == 'POST' && path == '/cashbooks') {
      final b = addBook(body['name'] as String, opening: body['opening_minor'] as int);
      b['color'] = body['color'];
      return _json(b, 201);
    }
    if (r.method == 'POST' && path == '/transactions') {
      if (!books.any((b) => b['id'] == body['book_id'])) return _json({'error': {'code': 'not_found', 'message': 'Not found.'}}, 404);
      final t = addTxn(body['book_id'] as String, body['amount_minor'] as int, type: body['type'] as String);
      t.addAll({'title': body['title'], 'category_id': body['category_id'], 'tags': body['tags'], 'payment_method': body['payment_method']});
      return _json(t, 201);
    }
    if (parts.length == 2 && parts[0] == 'transactions') {
      final i = txns.indexWhere((t) => t['id'] == parts[1]);
      if (i < 0) return _json({'error': {'code': 'not_found', 'message': 'Not found.'}}, 404);
      if (r.method == 'DELETE') {
        txns.removeAt(i);
        return http.Response('', 204);
      }
      if (r.method == 'PATCH') {
        txns[i] = {...txns[i], ...body};
        return _json(txns[i]);
      }
    }
    if (parts.length == 2 && parts[0] == 'cashbooks') {
      final i = books.indexWhere((b) => b['id'] == parts[1]);
      if (i < 0) return _json({'error': {'code': 'not_found', 'message': 'Not found.'}}, 404);
      if (r.method == 'DELETE') {
        if (txns.any((t) => t['book_id'] == parts[1])) return _json({'error': {'code': 'book_has_transactions', 'message': 'This CashBook has transactions. Archive it instead.'}}, 409);
        books.removeAt(i);
        return http.Response('', 204);
      }
      if (r.method == 'PATCH') {
        books[i] = {...books[i], ...body};
        return _json(books[i]);
      }
    }
    if (r.method == 'PATCH' && parts.length == 2 && parts[0] == 'categories') {
      final i = cats.indexWhere((c) => c['id'] == parts[1]);
      cats[i] = {...cats[i], ...body};
      return _json(cats[i]);
    }
    if (r.method == 'POST' && path == '/categories') {
      final c = <String, dynamic>{'id': 'cat-${_n++}', 'name': body['name'], 'kind': body['kind'], 'icon_key': body['icon_key'], 'color': body['color'], 'archived': false, 'is_builtin': false};
      cats.add(c);
      return _json(c, 201);
    }
    return _json({'error': {'code': 'not_found', 'message': 'No such route $key'}}, 404);
  }
}

class _SignedIn extends AuthController {
  @override
  AuthState build() => AuthState(
        status: AuthStatus.signedIn,
        session: Session(accessToken: 't', refreshToken: 'r', expiresAt: DateTime.now().add(const Duration(hours: 1)), userId: 'u-1', email: 'asha@example.com', displayName: 'Asha'),
      );
}

ProviderContainer containerFor(FakeServer s, {Future<String?> Function()? token}) {
  final repo = LedgerRepository(baseUrl: 'http://api.test', token: token ?? () async => 'tok', client: MockClient(s.handle));
  return ProviderContainer(overrides: [ledgerRepositoryProvider.overrideWithValue(repo)]);
}

Future<LedgerNotifier> ready(ProviderContainer c) async {
  final n = c.read(ledgerProvider.notifier);
  await n.loaded;
  return n;
}

void main() {
  test('signed in: books, categories and every page of transactions load from the API', () async {
    final s = FakeServer();
    final b = s.addBook('Personal', opening: 100000);
    for (var i = 0; i < 230; i++) {
      s.addTxn(b['id'] as String, 1000, occurred: '2026-09-${(i % 28 + 1).toString().padLeft(2, '0')}T10:00:00Z');
    }
    final c = containerFor(s);
    addTearDown(c.dispose);
    await ready(c);
    final st = c.read(ledgerProvider);
    expect(st.live, isTrue);
    expect(st.loading, isFalse);
    expect(st.txns.length, 230);
    expect(s.seen.where((k) => k == 'GET /transactions').length, 3); // 100 + 100 + 30
    expect(st.cats.length, 3);
    expect(categoryOf('cat-salary').income, isTrue);
    expect(st.balanceOf(st.books.single), 100000 - 230 * 1000, reason: 'balance is derived from opening + transactions');
  });

  test('a new book and a transaction added straight away both end up on the server with real ids', () async {
    final s = FakeServer();
    final c = containerFor(s);
    addTearDown(c.dispose);
    final n = await ready(c);
    String? tempBook;
    n.addBook((id) {
      tempBook = id;
      return Book(id: id, name: 'Trip', currency: 'INR', color: bookColors[0], createdAt: DateTime(2026, 9, 1));
    });
    n.addTxn((id) => Txn(id: id, bookId: tempBook!, type: TxnType.expense, amountMinor: 25000, title: 'Taxi', categoryId: 'cat-food', date: DateTime(2026, 9, 2, 9)));
    expect(c.read(ledgerProvider).txns.single.bookId, tempBook, reason: 'the screen updates instantly, before the server answers');
    await n.flush();
    expect(s.books.length, 1);
    expect(s.txns.single['book_id'], s.books.single['id']);
    expect(s.txns.single['amount_minor'], 25000);
    final st = c.read(ledgerProvider);
    expect(st.books.single.id, s.books.single['id']);
    expect(st.txns.single.bookId, s.books.single['id']);
    expect(st.txns.single.id, s.txns.single['id']);
    expect(st.error, isNull);
  });

  test('the amount is sent as integer paise and the time as UTC', () async {
    final s = FakeServer();
    final b = s.addBook('Personal');
    Map<String, dynamic>? sent;
    final repo = LedgerRepository(
      baseUrl: 'http://api.test',
      token: () async => 'tok',
      client: MockClient((r) async {
        if (r.method == 'POST') sent = jsonDecode(r.body) as Map<String, dynamic>;
        return s.handle(r);
      }),
    );
    final created = await repo.createTxn(Txn(id: 'x', bookId: b['id'] as String, type: TxnType.income, amountMinor: 1234567, title: 'Pay', categoryId: 'cat-salary', date: DateTime.utc(2026, 9, 1, 4, 30)));
    expect(sent!['amount_minor'], 1234567);
    expect(sent!['amount_minor'], isA<int>());
    expect(sent!['occurred_at'], '2026-09-01T04:30:00.000Z');
    expect(sent!['type'], 'income');
    expect(created.amountMinor, 1234567);
  });

  test('when the server refuses a change, the screen goes back to the server state and says why', () async {
    final s = FakeServer();
    final b = s.addBook('Personal');
    s.addTxn(b['id'] as String, 500);
    final c = containerFor(s);
    addTearDown(c.dispose);
    final n = await ready(c);
    n.deleteBook(b['id'] as String);
    expect(c.read(ledgerProvider).books, isEmpty, reason: 'optimistic');
    await n.flush();
    final st = c.read(ledgerProvider);
    expect(st.books.length, 1, reason: 'restored from the server');
    expect(st.error, contains('Archive it instead'));
    n.dismissError();
    expect(c.read(ledgerProvider).error, isNull);
  });

  test('an unreachable server surfaces an error and never pretends the change was saved', () async {
    final s = FakeServer();
    final b = s.addBook('Personal');
    final c = containerFor(s);
    addTearDown(c.dispose);
    final n = await ready(c);
    s.offline = true;
    n.addTxn((id) => Txn(id: id, bookId: b['id'] as String, type: TxnType.expense, amountMinor: 100, title: 'Tea', categoryId: 'cat-food', date: DateTime(2026, 9, 3)));
    await n.flush();
    expect(c.read(ledgerProvider).error, contains("Can't reach the server"));
    s.offline = false;
    await n.reload();
    expect(c.read(ledgerProvider).txns, isEmpty, reason: 'it was never saved, so it is not shown');
  });

  test('delete then undo recreates the transaction on the server', () async {
    final s = FakeServer();
    final b = s.addBook('Personal');
    s.addTxn(b['id'] as String, 700);
    final c = containerFor(s);
    addTearDown(c.dispose);
    final n = await ready(c);
    final t = c.read(ledgerProvider).txns.single;
    n.deleteTxn(t.id);
    n.restoreTxn(t);
    await n.flush();
    expect(s.txns.length, 1);
    expect(c.read(ledgerProvider).txns.single.amountMinor, 700);
    expect(c.read(ledgerProvider).error, isNull);
  });

  test('imported transactions are recognisable', () async {
    final s = FakeServer();
    final b = s.addBook('Personal');
    s.addTxn(b['id'] as String, 31300, source: 'import');
    s.addTxn(b['id'] as String, 500);
    final c = containerFor(s);
    addTearDown(c.dispose);
    await ready(c);
    final st = c.read(ledgerProvider);
    expect(st.txns.where((t) => t.imported).length, 1);
    expect(st.txns.firstWhere((t) => t.imported).amountMinor, 31300);
  });

  test('deleting a custom category archives it on the server (history stays intact)', () async {
    final s = FakeServer();
    final c = containerFor(s);
    addTearDown(c.dispose);
    final n = await ready(c);
    expect(n.addCategory(name: 'Pets', income: false, icon: categoryIcons[18], color: Colors.teal), isTrue);
    await n.flush();
    final id = s.cats.last['id'] as String;
    expect(s.cats.last['name'], 'Pets');
    expect(s.cats.last['icon_key'], 'pawPrint');
    expect(n.deleteCategory(c.read(ledgerProvider).cats.last.id), isTrue);
    await n.flush();
    expect(s.cats.firstWhere((x) => x['id'] == id)['archived'], isTrue);
  });

  test('no token means no request is made', () async {
    final s = FakeServer();
    final repo = LedgerRepository(baseUrl: 'http://api.test', token: () async => null, client: MockClient(s.handle));
    await expectLater(repo.loadAll(), throwsA(isA<LedgerApiException>().having((e) => e.code, 'code', 'unauthorized')));
    expect(s.seen, isEmpty);
  });

  test('sample mode (not signed in) never calls the API', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(ledgerProvider.notifier);
    await n.loaded;
    expect(c.read(ledgerProvider).live, isFalse);
    expect(c.read(ledgerProvider).txns, isNotEmpty);
    n.deleteTxn(c.read(ledgerProvider).txns.first.id);
    await n.flush();
    expect(c.read(ledgerProvider).error, isNull);
  });

  group('signed-in UI', () {
    Future<void> pump(WidgetTester tester, FakeServer s) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = LedgerRepository(baseUrl: 'http://api.test', token: () async => 'tok', client: MockClient(s.handle));
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authProvider.overrideWith(() => _SignedIn()),
          ledgerRepositoryProvider.overrideWithValue(repo),
          apiStatusProvider.overrideWith((_) async => const ApiStatus(apiUp: true, databaseReady: true)),
        ],
        child: const CashBookApp(),
      ));
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
    }

    testWidgets('the dashboard shows the signed-in user data, not the sample books', (tester) async {
      final s = FakeServer();
      final b = s.addBook('Household', opening: 2500000);
      s.addTxn(b['id'] as String, 150000, type: 'income');
      await pump(tester, s);
      expect(find.text('Total balance'), findsOneWidget);
      expect(find.textContaining('26,500'), findsWidgets, reason: 'opening 25,000 + income 1,500');
      expect(find.text('Goa Trip'), findsNothing, reason: 'sample data must not appear for a signed-in user');
    });

    testWidgets('a failed load explains itself and offers Retry, which recovers', (tester) async {
      final s = FakeServer()..offline = true;
      await pump(tester, s);
      expect(find.textContaining("Can't reach the server"), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      s.offline = false;
      s.addBook('Household');
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      expect(find.textContaining("Can't reach the server"), findsNothing);
    });
  });
}
