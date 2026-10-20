import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'models.dart';

/// A failed API call with the server's stable error code (e.g. `book_has_transactions`).
class LedgerApiException implements Exception {
  LedgerApiException(this.code, this.message, {this.status = 0});
  final String code;
  final String message;
  final int status;
  @override
  String toString() => message;
}

class LedgerData {
  const LedgerData({required this.books, required this.txns, required this.cats});
  final List<Book> books;
  final List<Txn> txns;
  final List<Category> cats;
}

/// Server icon keys are the Lucide member names; this is the whole set the app can draw.
const iconsByKey = <String, IconData>{
  'utensils': LucideIcons.utensils, 'car': LucideIcons.car, 'house': LucideIcons.house, 'zap': LucideIcons.zap,
  'shoppingBag': LucideIcons.shoppingBag, 'heartPulse': LucideIcons.heartPulse, 'clapperboard': LucideIcons.clapperboard,
  'graduationCap': LucideIcons.graduationCap, 'repeat': LucideIcons.repeat, 'plane': LucideIcons.plane,
  'sparkles': LucideIcons.sparkles, 'receipt': LucideIcons.receipt, 'banknote': LucideIcons.banknote,
  'laptop': LucideIcons.laptop, 'trendingUp': LucideIcons.trendingUp, 'landmark': LucideIcons.landmark,
  'gift': LucideIcons.gift, 'dumbbell': LucideIcons.dumbbell, 'pawPrint': LucideIcons.pawPrint,
  'coffee': LucideIcons.coffee, 'baby': LucideIcons.baby, 'wrench': LucideIcons.wrench,
  'smartphone': LucideIcons.smartphone, 'ellipsis': LucideIcons.ellipsis,
};

String iconKeyOf(IconData icon) {
  for (final e in iconsByKey.entries) {
    if (e.value == icon) return e.key;
  }
  return 'ellipsis';
}

String hexOf(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
Color colorOf(String hex) => Color(0xFF000000 | int.parse(hex.replaceFirst('#', ''), radix: 16));

Book bookFromJson(Map<String, dynamic> j) => Book(
      id: j['id'] as String,
      name: j['name'] as String,
      description: (j['description'] as String?) ?? '',
      currency: j['currency'] as String,
      openingMinor: j['opening_minor'] as int,
      color: colorOf(j['color'] as String),
      iconKey: (j['icon_key'] as String?) ?? 'wallet',
      archived: (j['archived'] as bool?) ?? false,
      createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
    );

Category categoryFromJson(Map<String, dynamic> j) => Category(
      j['id'] as String,
      j['name'] as String,
      iconsByKey[j['icon_key']] ?? LucideIcons.ellipsis,
      colorOf(j['color'] as String),
      income: j['kind'] == 'income',
      archived: (j['archived'] as bool?) ?? false,
      builtin: (j['is_builtin'] as bool?) ?? false,
    );

Txn txnFromJson(Map<String, dynamic> j) => Txn(
      id: j['id'] as String,
      bookId: j['book_id'] as String,
      type: j['type'] == 'income' ? TxnType.income : TxnType.expense,
      amountMinor: j['amount_minor'] as int,
      title: j['title'] as String,
      note: (j['note'] as String?) ?? '',
      categoryId: (j['category_id'] as String?) ?? '',
      date: DateTime.parse(j['occurred_at'] as String).toLocal(),
      method: (j['payment_method'] as String?) ?? 'Other',
      merchant: (j['merchant'] as String?) ?? '',
      tags: [for (final t in (j['tags'] as List? ?? const [])) t as String],
      source: (j['created_source'] as String?) ?? 'manual',
    );

Map<String, dynamic> _txnBody(Txn t) => {
      'book_id': t.bookId,
      'type': t.type == TxnType.income ? 'income' : 'expense',
      'amount_minor': t.amountMinor,
      'title': t.title,
      'note': t.note,
      'category_id': t.categoryId.isEmpty ? null : t.categoryId,
      'occurred_at': t.date.toUtc().toIso8601String(),
      'payment_method': t.method,
      'merchant': t.merchant,
      'tags': t.tags,
    };

/// All CashBook data access goes through the FastAPI backend (never straight to the database).
class LedgerRepository {
  LedgerRepository({required this.baseUrl, required this.token, http.Client? client}) : _http = client ?? http.Client();
  final String baseUrl;
  final Future<String?> Function() token;
  final http.Client _http;

  Future<dynamic> _send(String method, String path, {Object? body, Map<String, String>? query}) async {
    final t = await token();
    if (t == null) throw LedgerApiException('unauthorized', 'Please sign in again.', status: 401);
    final uri = Uri.parse('$baseUrl/api/v1$path').replace(queryParameters: query);
    final req = http.Request(method, uri)
      ..headers['Authorization'] = 'Bearer $t'
      ..headers['Content-Type'] = 'application/json';
    if (body != null) req.body = jsonEncode(body);
    http.Response res;
    try {
      res = await http.Response.fromStream(await _http.send(req).timeout(const Duration(seconds: 20)));
    } on TimeoutException {
      throw LedgerApiException('unreachable', "Can't reach the server. Check your connection and try again.");
    } on http.ClientException {
      throw LedgerApiException('unreachable', "Can't reach the server. Check your connection and try again.");
    }
    if (res.statusCode == 204) return null;
    dynamic decoded;
    try {
      decoded = res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      decoded = null;
    }
    if (res.statusCode >= 400) {
      final e = decoded is Map ? decoded['error'] : null;
      throw LedgerApiException(e is Map ? (e['code'] as String? ?? 'error') : 'error', e is Map ? (e['message'] as String? ?? 'Something went wrong.') : 'Something went wrong.', status: res.statusCode);
    }
    return decoded;
  }

  Future<LedgerData> loadAll() async {
    final results = await Future.wait([_send('GET', '/cashbooks'), _send('GET', '/categories')]);
    final books = [for (final b in results[0] as List) bookFromJson(b as Map<String, dynamic>)];
    final cats = [for (final c in results[1] as List) categoryFromJson(c as Map<String, dynamic>)];
    final txns = <Txn>[];
    var offset = 0;
    while (true) {
      final page = await _send('GET', '/transactions', query: {'limit': '100', 'offset': '$offset'}) as Map<String, dynamic>;
      final items = page['items'] as List;
      txns.addAll([for (final t in items) txnFromJson(t as Map<String, dynamic>)]);
      offset += items.length;
      if (items.isEmpty || offset >= (page['total'] as int)) break;
    }
    txns.sort((a, b) => b.date.compareTo(a.date));
    return LedgerData(books: books, txns: txns, cats: cats);
  }

  // ---- books
  Map<String, dynamic> _bookBody(Book b) => {
        'name': b.name, 'description': b.description, 'currency': b.currency, 'opening_minor': b.openingMinor,
        'color': hexOf(b.color), 'icon_key': b.iconKey,
      };
  Future<Book> createBook(Book b) async => bookFromJson(await _send('POST', '/cashbooks', body: _bookBody(b)) as Map<String, dynamic>);
  Future<Book> updateBook(Book b) async =>
      bookFromJson(await _send('PATCH', '/cashbooks/${b.id}', body: {..._bookBody(b), 'archived': b.archived}) as Map<String, dynamic>);
  Future<void> deleteBook(String id) => _send('DELETE', '/cashbooks/$id');

  // ---- transactions
  Future<Txn> createTxn(Txn t) async => txnFromJson(await _send('POST', '/transactions', body: _txnBody(t)) as Map<String, dynamic>);
  Future<Txn> updateTxn(Txn t) async => txnFromJson(await _send('PATCH', '/transactions/${t.id}', body: _txnBody(t)) as Map<String, dynamic>);
  Future<void> deleteTxn(String id) => _send('DELETE', '/transactions/$id');

  // ---- categories (the API archives instead of deleting, so history stays intact)
  Future<Category> createCategory(Category c) async => categoryFromJson(await _send('POST', '/categories', body: {
        'name': c.name, 'kind': c.income ? 'income' : 'expense', 'icon_key': iconKeyOf(c.icon), 'color': hexOf(c.color),
      }) as Map<String, dynamic>);
  Future<Category> updateCategory(Category c) async => categoryFromJson(await _send('PATCH', '/categories/${c.id}', body: {
        'name': c.name, 'icon_key': iconKeyOf(c.icon), 'color': hexOf(c.color), 'archived': c.archived,
      }) as Map<String, dynamic>);

  // ---- data controls
  Future<Map<String, dynamic>> dataSummary() async => await _send('GET', '/me/data-summary') as Map<String, dynamic>;

  /// The full export as pretty JSON text.
  Future<String> exportAll() async {
    final data = await _send('GET', '/me/export');
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<void> deleteData(String scope) => _send('DELETE', '/me/data', query: {'scope': scope, 'confirm': 'DELETE'});
  Future<void> deleteAccount() => _send('DELETE', '/me/account', query: {'confirm': 'DELETE'});
}
