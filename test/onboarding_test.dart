import 'package:cashbook/features/auth/auth_controller.dart';
import 'package:cashbook/features/onboarding/onboarding_store.dart';
import 'package:cashbook/main.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SignedOut extends AuthController {
  @override
  AuthState build() => const AuthState(status: AuthStatus.signedOut);
}

class _Demo extends AuthController {
  @override
  AuthState build() => const AuthState(status: AuthStatus.demo);
}

Future<void> _pump(WidgetTester tester, AuthController Function() auth, MemoryOnboardingStore store, {Size size = const Size(420, 900)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  // Reduced motion: no endless animations, so the tester can settle.
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  await tester.pumpWidget(ProviderScope(
    overrides: [authProvider.overrideWith(auth), onboardingStoreProvider.overrideWithValue(store)],
    child: const CashBookApp(),
  ));
  await tester.pumpAndSettle(const Duration(milliseconds: 200));
}

void main() {
  testWidgets('first launch shows the intro before sign-in and walks through all five slides', (tester) async {
    final store = MemoryOnboardingStore();
    await _pump(tester, _SignedOut.new, store);
    expect(find.text('Welcome to Ledgerly'), findsOneWidget);
    expect(find.text('Welcome back'), findsNothing);
    expect(find.text('1 / 5'), findsOneWidget);

    const titles = ['A book for every part of life', 'Add it in seconds', 'See where it all goes', 'Yours, and only yours'];
    for (final t in titles) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.text('5 / 5'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget); // hidden (transparent) on the last slide, but not tappable
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('Next'), findsNothing);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    expect(find.text('Welcome back'), findsOneWidget); // sign-in
    expect(await store.seen(), isTrue);
  });

  testWidgets('Skip goes straight to sign-in and remembers it', (tester) async {
    final store = MemoryOnboardingStore();
    await _pump(tester, _SignedOut.new, store);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    expect(find.text('Welcome back'), findsOneWidget);
    expect(await store.seen(), isTrue);
  });

  testWidgets('arrow keys move between slides', (tester) async {
    await _pump(tester, _SignedOut.new, MemoryOnboardingStore(), size: const Size(1400, 900));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    expect(find.text('A book for every part of life'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    expect(find.text('Welcome to Ledgerly'), findsOneWidget);
  });

  testWidgets('returning users go straight to sign-in', (tester) async {
    await _pump(tester, _SignedOut.new, MemoryOnboardingStore(seen: true));
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Welcome to Ledgerly'), findsNothing);
  });

  testWidgets('signed-in / sample users are not interrupted, and can replay the intro from Settings', (tester) async {
    await _pump(tester, _Demo.new, MemoryOnboardingStore(), size: const Size(1400, 900));
    expect(find.text('Total balance'), findsOneWidget);
    expect(find.text('Welcome to Ledgerly'), findsNothing);

    await tester.tap(find.text('Settings').first);
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    await tester.ensureVisible(find.text('Replay intro'));
    await tester.tap(find.text('Replay intro'));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    expect(find.text('Welcome to Ledgerly'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    expect(find.text('Total balance'), findsOneWidget); // back in the app, not on sign-in
  });
}
