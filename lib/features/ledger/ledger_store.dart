import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../auth/auth_controller.dart';
import 'ledger_repository.dart';
import 'models.dart';

/// Signed in: the API is the source of truth (null elsewhere). Sample mode keeps the in-memory sample data below.
final ledgerRepositoryProvider = Provider<LedgerRepository?>((ref) {
  final user = ref.watch(authProvider.select((a) => a.status == AuthStatus.signedIn ? a.session?.userId : null));
  if (user == null) return null;
  return LedgerRepository(baseUrl: AppConfig.apiBaseUrl, token: () => ref.read(authProvider.notifier).accessToken());
});

class LedgerState {
  const LedgerState({required this.books, required this.txns, required this.cats, this.loading = false, this.error, this.live = false});
  final List<Book> books;
  final List<Txn> txns;
  final List<Category> cats;
  final bool loading; // first load from the server in progress
  final String? error; // last sync problem, shown once with a retry
  final bool live; // backed by the API (false = sample data)

  LedgerState copyWith({List<Book>? books, List<Txn>? txns, List<Category>? cats, bool? loading, String? error, bool clearError = false}) => LedgerState(
        books: books ?? this.books,
        txns: txns ?? this.txns,
        cats: cats ?? this.cats,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        live: live,
      );

  Book? bookById(String id) {
    for (final b in books) {
      if (b.id == id) return b;
    }
    return null;
  }

  List<Txn> txnsOf(String bookId) => txns.where((t) => t.bookId == bookId).toList();

  /// Balance is always derived from the opening balance and transactions.
  int balanceOf(Book b) => b.openingMinor + txnsOf(b.id).fold(0, (s, t) => s + t.signed);

  DateTime? lastActivity(Book b) {
    DateTime? last;
    for (final t in txnsOf(b.id)) {
      if (last == null || t.date.isAfter(last)) last = t.date;
    }
    return last;
  }

  int categoryUsage(String categoryId) => txns.where((t) => t.categoryId == categoryId).length;

  /// Tag -> number of transactions using it.
  Map<String, int> get tagCounts {
    final m = <String, int>{};
    for (final t in txns) {
      for (final g in t.tags) {
        m[g] = (m[g] ?? 0) + 1;
      }
    }
    return m;
  }
}

/// Screens call these synchronously and see the change immediately. When signed in, each change is also sent to the API,
/// one at a time and in order; if the server refuses (or can't be reached) the screen is put back to what the server has
/// and an [LedgerState.error] explains why. Nothing is ever shown as saved that the server rejected.
class LedgerNotifier extends Notifier<LedgerState> {
  int _seq = 1000;
  String _id(String p) => '$p${_seq++}';
  LedgerRepository? _repo;
  Future<void> _queue = Future.value();
  final _realIds = <String, String>{}; // temporary id -> server id, for rows created while offline-ish/in flight
  Completer<void> _loaded = Completer<void>();

  /// Completes after the first load (or failure), so screens can show a skeleton until then.
  Future<void> get loaded => _loaded.future;
  String _real(String id) => _realIds[id] ?? id;

  @override
  LedgerState build() {
    _repo = ref.watch(ledgerRepositoryProvider);
    _realIds.clear();
    _queue = Future.value();
    _loaded = Completer<void>();
    if (_repo != null) {
      categories = [];
      Future.microtask(reload);
      return const LedgerState(books: [], txns: [], cats: [], loading: true, live: true);
    }
    categories = List.of(defaultCategories);
    _loaded.complete();
    return _seed();
  }

  void _set(LedgerState s) {
    categories = s.cats; // keep the global lookup in sync
    state = s;
  }

  /// Reads everything from the server (live mode only).
  Future<void> reload() async {
    final r = _repo;
    if (r == null) return;
    try {
      final d = await r.loadAll();
      _realIds.clear();
      _set(LedgerState(books: d.books, txns: d.txns, cats: d.cats, live: true));
    } on LedgerApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    } catch (_) {
      state = state.copyWith(loading: false, error: 'Something went wrong while loading your data.');
    }
    if (!_loaded.isCompleted) _loaded.complete();
  }

  void dismissError() => state = state.copyWith(clearError: true);

  void _sync(Future<void> Function(LedgerRepository r) job) {
    final r = _repo;
    if (r == null) return;
    _queue = _queue.then((_) async {
      String? problem;
      try {
        await job(r);
      } on LedgerApiException catch (e) {
        problem = e.message;
      } catch (_) {
        problem = 'Something went wrong. Please try again.';
      }
      if (problem != null) {
        await reload(); // show what the server really has
        state = state.copyWith(error: problem);
      }
    });
  }

  /// Resolves once every queued change has been sent (used by tests).
  Future<void> flush() => _queue;

  Txn _wire(Txn t) => t.copyWith(id: _real(t.id), bookId: _real(t.bookId), categoryId: _real(t.categoryId));

  void _swapBook(String from, Book real) {
    _realIds[from] = real.id;
    _set(state.copyWith(
      books: [for (final b in state.books) b.id == from ? real : b],
      txns: [for (final t in state.txns) t.bookId == from ? t.copyWith(bookId: real.id) : t],
    ));
  }

  void _swapTxn(String from, Txn real) {
    _realIds[from] = real.id;
    _set(state.copyWith(txns: [for (final t in state.txns) t.id == from ? real : t]));
  }

  // ---- books
  void addBook(Book Function(String id) make) {
    final b = make(_id('b'));
    _set(state.copyWith(books: [...state.books, b]));
    _sync((r) async => _swapBook(b.id, await r.createBook(b)));
  }

  void updateBook(Book b) {
    _set(state.copyWith(books: [for (final x in state.books) x.id == b.id ? b : x]));
    _sync((r) async => await r.updateBook(b.copyWith(id: _real(b.id))));
  }

  void deleteBook(String id) {
    _set(state.copyWith(books: state.books.where((b) => b.id != id).toList()));
    _sync((r) => r.deleteBook(_real(id)));
  }

  // ---- transactions
  void addTxn(Txn Function(String id) make) => _insertTxn(make(_id('t')));

  void _insertTxn(Txn t) {
    _set(state.copyWith(txns: [t, ...state.txns]));
    _sync((r) async => _swapTxn(t.id, await r.createTxn(_wire(t))));
  }

  void restoreTxn(Txn t) => _insertTxn(t.copyWith(source: 'manual'));

  void updateTxn(Txn t) {
    _set(state.copyWith(txns: [for (final x in state.txns) x.id == t.id ? t : x]));
    _sync((r) async => await r.updateTxn(_wire(t)));
  }

  void deleteTxn(String id) {
    _set(state.copyWith(txns: state.txns.where((t) => t.id != id).toList()));
    _sync((r) => r.deleteTxn(_real(id)));
  }

  void duplicateTxn(Txn t) => addTxn((id) => t.copyWith(id: id, date: DateTime.now(), source: 'manual'));

  // ---- categories
  /// Returns false when the name already exists for that kind.
  bool addCategory({required String name, required bool income, required IconData icon, required Color color}) {
    final n = name.trim();
    if (state.cats.any((c) => c.income == income && c.name.toLowerCase() == n.toLowerCase())) return false;
    final c = Category(_id('c'), n, icon, color, income: income, builtin: false);
    _set(state.copyWith(cats: [...state.cats, c]));
    _sync((r) async {
      final real = await r.createCategory(c);
      _realIds[c.id] = real.id;
      _set(state.copyWith(
        cats: [for (final x in state.cats) x.id == c.id ? real : x],
        txns: [for (final t in state.txns) t.categoryId == c.id ? t.copyWith(categoryId: real.id) : t],
      ));
    });
    return true;
  }

  bool updateCategory(Category c) {
    final dup = state.cats.any((x) => x.id != c.id && x.income == c.income && x.name.toLowerCase() == c.name.trim().toLowerCase());
    if (dup) return false;
    _set(state.copyWith(cats: [for (final x in state.cats) x.id == c.id ? c : x]));
    _sync((r) async => await r.updateCategory(c.copyWith(id: _real(c.id))));
    return true;
  }

  /// Only custom, unused categories can be deleted; otherwise archive (history stays intact).
  bool deleteCategory(String id) {
    final c = categoryOf(id);
    if (c.builtin || state.categoryUsage(id) > 0) return false;
    _set(state.copyWith(cats: state.cats.where((x) => x.id != id).toList()));
    _sync((r) async => await r.updateCategory(c.copyWith(id: _real(id), archived: true))); // the API archives; history stays intact
    return true;
  }

  // ---- tags
  void renameTag(String from, String to) {
    final t = to.trim();
    if (t.isEmpty) return;
    _retag((x) => x.tags.contains(from) ? x.copyWith(tags: {for (final g in x.tags) g == from ? t : g}.toList()) : x);
  }

  void deleteTag(String tag) => _retag((x) => x.tags.contains(tag) ? x.copyWith(tags: x.tags.where((g) => g != tag).toList()) : x);

  void _retag(Txn Function(Txn) f) {
    final before = {for (final t in state.txns) t.id: t};
    final next = [for (final t in state.txns) f(t)];
    _set(state.copyWith(txns: next));
    for (final t in next) {
      if (!identical(before[t.id], t)) _sync((r) async => await r.updateTxn(_wire(t)));
    }
  }

  LedgerState _seed() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final rnd = Random(7);
    final books = <Book>[
      Book(id: 'b1', name: 'Personal', description: 'Everyday spending and income', currency: 'INR',
          openingMinor: 4500000, color: bookColors[0], iconKey: 'wallet', createdAt: today.subtract(const Duration(days: 200))),
      Book(id: 'b2', name: 'Household', description: 'Rent, bills and groceries', currency: 'INR',
          openingMinor: 25000000, color: bookColors[2], iconKey: 'house', createdAt: today.subtract(const Duration(days: 195))),
      Book(id: 'b3', name: 'Freelance', description: 'Client invoices and expenses', currency: 'INR',
          openingMinor: 0, color: bookColors[1], iconKey: 'briefcase', createdAt: today.subtract(const Duration(days: 190))),
      Book(id: 'b4', name: 'Goa Trip', description: 'Weekend getaway budget', currency: 'INR',
          openingMinor: 5000000, color: bookColors[3], iconKey: 'plane', createdAt: today.subtract(const Duration(days: 60))),
    ];

    final txns = <Txn>[];
    var n = 0;
    // amounts are rounded to whole rupees
    void add(String book, TxnType type, int minor, String title, String cat, DateTime d, String method,
        {String merchant = '', List<String> tags = const []}) {
      txns.add(Txn(id: 't${n++}', bookId: book, type: type, amountMinor: minor - minor % 100, title: title, categoryId: cat,
          date: d, method: method, merchant: merchant, tags: tags));
    }

    for (var m = 0; m < 6; m++) {
      final first = DateTime(now.year, now.month - m, 1, 9, 30);
      if (first.isAfter(now)) continue;
      add('b1', TxnType.income, 8500000, 'Salary', 'salary', first, 'Bank transfer', merchant: 'Acme Corp');
      add('b2', TxnType.expense, 2200000, 'House rent', 'housing', first.add(const Duration(days: 1)), 'Bank transfer', tags: ['fixed']);
      add('b1', TxnType.expense, 49900, 'Streaming plan', 'subs', first.add(const Duration(days: 4)), 'Credit card', merchant: 'StreamFlix', tags: ['subscription']);
      add('b1', TxnType.expense, 19900, 'Music subscription', 'subs', first.add(const Duration(days: 6)), 'UPI', merchant: 'TuneBox', tags: ['subscription']);
      add('b3', TxnType.income, 4200000 + rnd.nextInt(800000), 'Client invoice', 'freelance', first.add(const Duration(days: 9)), 'Bank transfer', merchant: 'Northwind Studio', tags: ['invoice']);
      add('b1', TxnType.income, 1200000 + rnd.nextInt(300000), 'Mutual fund returns', 'invest', first.add(const Duration(days: 12)), 'Bank transfer', merchant: 'Groww');
    }

    const personal = [
      ('Lunch', 'food', 18000, 52000, 'UPI', 'Cafe Aroma'),
      ('Groceries', 'food', 120000, 340000, 'Debit card', 'FreshMart'),
      ('Cab ride', 'transport', 15000, 60000, 'UPI', 'RideNow'),
      ('Fuel', 'transport', 150000, 280000, 'Debit card', 'Indian Oil'),
      ('Online order', 'shopping', 40000, 350000, 'Credit card', 'ShopKart'),
      ('Movie night', 'fun', 40000, 120000, 'UPI', 'CineMax'),
      ('Pharmacy', 'health', 20000, 90000, 'Cash', 'CareChem'),
      ('Haircut', 'personal', 25000, 60000, 'Cash', 'Style Studio'),
      ('Bank charges', 'fees', 5000, 20000, 'Bank transfer', ''),
    ];
    for (var d = 0; d < 180; d++) {
      final day = today.subtract(Duration(days: d));
      final count = rnd.nextInt(3);
      for (var i = 0; i < count; i++) {
        final t = personal[rnd.nextInt(personal.length)];
        final amt = t.$3 + rnd.nextInt(t.$4 - t.$3);
        add('b1', TxnType.expense, amt - amt % 100, t.$1, t.$2, day.add(Duration(hours: 8 + rnd.nextInt(13), minutes: rnd.nextInt(60))), t.$5,
            merchant: t.$6, tags: t.$2 == 'food' && rnd.nextInt(3) == 0 ? ['eating-out'] : const []);
      }
      if (d % 6 == 0) {
        add('b2', TxnType.expense, 80000 + rnd.nextInt(180000), 'Electricity & utilities', 'utilities',
            day.add(const Duration(hours: 11)), 'UPI', merchant: 'City Power', tags: const ['bills']);
      }
    }
    for (var d = 0; d < 40; d += 5) {
      final fun = d % 10 == 0;
      add('b4', TxnType.expense, 40000 + rnd.nextInt(380000), fun ? 'Water sports' : 'Beach shack dinner', fun ? 'fun' : 'food',
          today.subtract(Duration(days: d)).add(const Duration(hours: 14)), 'UPI', tags: const ['trip']);
    }
    add('b3', TxnType.expense, 350000, 'Design software yearly', 'subs', today.subtract(const Duration(days: 12)), 'Credit card', merchant: 'Pixelcraft', tags: const ['work']);

    txns.sort((a, b) => b.date.compareTo(a.date));
    return LedgerState(books: books, txns: txns.where((t) => !t.date.isAfter(now)).toList(), cats: List.of(defaultCategories));
  }
}

final ledgerProvider = NotifierProvider<LedgerNotifier, LedgerState>(LedgerNotifier.new);

/// Skeletons show until the first load: the real one when signed in, a short simulated one for sample data.
final bootProvider = FutureProvider<void>((ref) {
  final notifier = ref.read(ledgerProvider.notifier);
  return ref.watch(ledgerRepositoryProvider) != null ? notifier.loaded : Future.delayed(const Duration(milliseconds: 700));
});
