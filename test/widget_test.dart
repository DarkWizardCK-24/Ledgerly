import 'package:cashbook/app/providers.dart';
import 'package:cashbook/features/auth/auth_controller.dart';
import 'package:cashbook/features/auth/auth_screen.dart';
import 'package:cashbook/features/auth/auth_service.dart';
import 'package:cashbook/features/onboarding/onboarding_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';
import 'package:cashbook/core/api/api_client.dart';
import 'package:cashbook/core/format/money.dart';
import 'package:cashbook/features/ledger/ledger_store.dart';
import 'package:cashbook/features/ledger/models.dart';
import 'package:cashbook/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _DemoAuth extends AuthController {
  @override
  AuthState build() => const AuthState(status: AuthStatus.demo);
}

class _SignedOut extends AuthController {
  @override
  AuthState build() => const AuthState(status: AuthStatus.signedOut);
}

http.Response _json(Object body, [int status = 200]) => http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

void main() {
  group('password and email validation', () {
    test('strength rises with length and variety', () {
      expect(passwordStrength(''), 0);
      expect(passwordStrength('abc'), 1);
      expect(passwordStrength('abcdefgh'), 1);
      expect(passwordStrength('Abcdefgh1'), 3);
      expect(passwordStrength('Abcdefgh1!'), 4);
    });

    test('email validator', () {
      expect(validateEmail(''), isNotNull);
      expect(validateEmail('nope'), isNotNull);
      expect(validateEmail(' a@b.co '), isNull);
    });
  });

  group('AuthService (Supabase Auth REST)', () {
    final user = {'id': 'u-1', 'email': 'asha@example.com', 'user_metadata': {'display_name': 'Asha'}};

    test('signIn posts password grant with apikey and parses the session', () async {
      late http.Request seen;
      final svc = AuthService(baseUrl: 'https://x.supabase.co/', anonKey: 'anon', client: MockClient((r) async {
        seen = r;
        return _json({'access_token': 'at', 'refresh_token': 'rt', 'expires_in': 3600, 'user': user});
      }));
      final s = await svc.signIn(' asha@example.com ', 'Secret123!');
      expect(seen.url.toString(), 'https://x.supabase.co/auth/v1/token?grant_type=password');
      expect(seen.headers['apikey'], 'anon');
      expect(jsonDecode(seen.body)['email'], 'asha@example.com'); // trimmed
      expect(s.userId, 'u-1');
      expect(s.displayName, 'Asha');
      expect(s.isExpired, isFalse);
    });

    test('wrong password gives a friendly message that never echoes the password', () async {
      final svc = AuthService(baseUrl: 'https://x.supabase.co', anonKey: 'anon', client: MockClient((_) async => _json({'error_code': 'invalid_credentials', 'msg': 'Invalid login credentials'}, 400)));
      try {
        await svc.signIn('a@b.co', 'TopSecret!99');
        fail('should throw');
      } on AuthException catch (e) {
        expect(e.message, 'Incorrect email or password.');
        expect(e.message.contains('TopSecret'), isFalse);
      }
    });

    test('signUp without a session means email confirmation is required', () async {
      final svc = AuthService(baseUrl: 'https://x.supabase.co', anonKey: 'anon', client: MockClient((r) async {
        expect(jsonDecode(r.body)['data'], {'display_name': 'Asha'});
        return _json({'id': 'u-1', 'email': 'asha@example.com'});
      }));
      final r = await svc.signUp(email: 'asha@example.com', password: 'Secret123!', displayName: 'Asha');
      expect(r.session, isNull);
      expect(r.needsEmailConfirmation, isTrue);
    });

    test('network failure is reported without raw details', () async {
      final svc = AuthService(baseUrl: 'https://x.supabase.co', anonKey: 'anon', client: MockClient((_) async => throw Exception('socket secret detail')));
      expect(() => svc.signIn('a@b.co', 'pw'), throwsA(isA<AuthException>().having((e) => e.message, 'message', isNot(contains('secret')))));
    });
  });

  group('AuthController', () {
    test('sign in stores the session; sign out clears it', () async {
      final store = MemorySessionStore();
      final svc = AuthService(baseUrl: 'https://x.supabase.co', anonKey: 'anon', client: MockClient((r) async {
        if (r.url.path.endsWith('/logout')) return http.Response('', 204);
        return _json({'access_token': 'at', 'refresh_token': 'rt', 'expires_in': 3600, 'user': {'id': 'u-1', 'email': 'a@b.co'}});
      }));
      final c = ProviderContainer(overrides: [sessionStoreProvider.overrideWithValue(store), authServiceProvider.overrideWithValue(svc)]);
      addTearDown(c.dispose);
      await Future<void>.delayed(Duration.zero);
      final auth = c.read(authProvider.notifier);
      expect(await auth.signIn('a@b.co', 'pw'), isTrue);
      expect(c.read(authProvider).status, AuthStatus.signedIn);
      expect((await store.read())?.accessToken, 'at');
      await auth.signOut();
      expect(c.read(authProvider).status, AuthStatus.signedOut);
      expect(await store.read(), isNull);
    });
  });

  group('money', () {
    test('formats INR with Indian grouping and USD with western grouping', () {
      expect(formatMoney(12345678, 'INR'), '₹1,23,456.78');
      expect(formatMoney(12345678, 'USD'), r'$123,456.78');
      expect(formatMoney(-5000, 'INR', compact: true), '-₹50');
      expect(formatMoney(250, 'INR', signed: true), '+₹2.50');
    });

    test('parseMinor is exact and rejects bad input', () {
      expect(parseMinor('1,250.5'), 125050);
      expect(parseMinor('0.07'), 7);
      expect(parseMinor('12.345'), isNull);
      expect(parseMinor('abc'), isNull);
      expect(parseMinor('-3'), isNull);
    });
  });

  group('ledger store', () {
    test('balance is derived from opening balance and transactions', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final store = c.read(ledgerProvider.notifier);
      store.addBook((id) => Book(id: id, name: 'T', currency: 'INR', openingMinor: 10000, color: Colors.red, createdAt: DateTime.now()));
      final book = c.read(ledgerProvider).books.last;
      store.addTxn((id) => Txn(id: id, bookId: book.id, type: TxnType.income, amountMinor: 5000, title: 'a', categoryId: 'salary', date: DateTime.now()));
      store.addTxn((id) => Txn(id: id, bookId: book.id, type: TxnType.expense, amountMinor: 2000, title: 'b', categoryId: 'food', date: DateTime.now()));
      expect(c.read(ledgerProvider).balanceOf(book), 13000);
      final t = c.read(ledgerProvider).txnsOf(book.id).first;
      store.deleteTxn(t.id);
      expect(c.read(ledgerProvider).txnsOf(book.id).length, 1);
    });
  });

  group('categories, tags and INR', () {
    test('sample data is entirely INR', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(ledgerProvider).books.every((b) => b.currency == 'INR'), isTrue);
    });

    test('category CRUD rules', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final store = c.read(ledgerProvider.notifier);

      expect(store.addCategory(name: 'Pets', income: false, icon: Icons.pets, color: Colors.red), isTrue);
      expect(store.addCategory(name: 'pets', income: false, icon: Icons.pets, color: Colors.red), isFalse); // duplicate
      final pets = c.read(ledgerProvider).cats.firstWhere((x) => x.name == 'Pets');
      expect(categoryOf(pets.id).name, 'Pets'); // global lookup stays in sync

      expect(store.updateCategory(pets.copyWith(name: 'Pet care')), isTrue);
      expect(categoryOf(pets.id).name, 'Pet care');
      expect(store.deleteCategory('food'), isFalse); // built-in cannot be deleted

      final book = c.read(ledgerProvider).books.first;
      store.addTxn((id) => Txn(id: id, bookId: book.id, type: TxnType.expense, amountMinor: 100, title: 'x', categoryId: pets.id, date: DateTime.now()));
      expect(store.deleteCategory(pets.id), isFalse); // in use -> must archive instead
      expect(store.updateCategory(categoryOf(pets.id).copyWith(archived: true)), isTrue);
      expect(c.read(ledgerProvider).txns.first.categoryId, pets.id); // history untouched
    });

    test('tags can be renamed and removed across transactions', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final store = c.read(ledgerProvider.notifier);
      final before = c.read(ledgerProvider).tagCounts['bills']!;
      store.renameTag('bills', 'utilities-bill');
      expect(c.read(ledgerProvider).tagCounts['utilities-bill'], before);
      expect(c.read(ledgerProvider).tagCounts.containsKey('bills'), isFalse);
      store.deleteTag('utilities-bill');
      expect(c.read(ledgerProvider).tagCounts.containsKey('utilities-bill'), isFalse);
    });
  });

  group('responsive shell', () {
    Future<void> pumpAt(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authProvider.overrideWith(() => _DemoAuth()),
          apiStatusProvider.overrideWith((_) async => const ApiStatus(apiUp: true, databaseReady: false, detail: 'x')),
        ],
        child: const CashBookApp(),
      ));
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
    }

    testWidgets('phone: bottom bar and dashboard', (tester) async {
      await pumpAt(tester, const Size(390, 844));
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Total balance'), findsOneWidget);
    });

    testWidgets('desktop: insights shows charts', (tester) async {
      await pumpAt(tester, const Size(1400, 900));
      await tester.tap(find.text('Insights').first);
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      expect(find.text('Spending by category'), findsOneWidget);
      expect(find.text('Savings rate'), findsOneWidget);
      expect(find.text('Largest expenses'), findsOneWidget);
    });

    testWidgets('signed out: sign-in screen, then sample mode reaches the dashboard', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(() => _SignedOut()), onboardingStoreProvider.overrideWithValue(MemoryOnboardingStore(seen: true))],
        child: const CashBookApp(),
      ));
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.textContaining('isn\'t configured'), findsOneWidget); // honest notice without Supabase config

      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();
      expect(find.text('Create your account'), findsOneWidget);
      expect(find.text('Confirm password'), findsOneWidget);

      await tester.ensureVisible(find.text('Explore with sample data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Explore with sample data'));
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      expect(find.text('Total balance'), findsOneWidget);
    });

    testWidgets('CashBooks grid ends with an Add CashBook card that opens the form', (tester) async {
      await pumpAt(tester, const Size(1400, 900));
      await tester.tap(find.text('CashBooks').first);
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      expect(find.text('Personal, Household, Business, Travel…'), findsOneWidget);
      await tester.tap(find.text('Personal, Household, Business, Travel…'));
      await tester.pumpAndSettle();
      expect(find.text('Create CashBook'), findsOneWidget);
    });

    testWidgets('tablet: rail', (tester) async {
      await pumpAt(tester, const Size(800, 1000));
      expect(find.byType(NavigationRail), findsOneWidget);
    });

    testWidgets('desktop: sidebar, navigate to CashBooks and create one', (tester) async {
      await pumpAt(tester, const Size(1400, 900));
      expect(find.byType(NavigationBar), findsNothing);
      await tester.tap(find.text('CashBooks').first);
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      expect(find.text('Personal'), findsWidgets);

      await tester.tap(find.text('New CashBook').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create CashBook')); // empty name -> validation error
      await tester.pumpAndSettle();
      expect(find.text('Name your CashBook'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Side Hustle');
      await tester.tap(find.text('Create CashBook'));
      await tester.pumpAndSettle();
      expect(find.text('Side Hustle'), findsOneWidget);
    });
  });
}
