import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Remembers whether the intro has been seen on this device. Nothing personal is stored.
abstract class OnboardingStore {
  Future<bool> seen();
  Future<void> markSeen();
}

class SecureOnboardingStore implements OnboardingStore {
  SecureOnboardingStore([FlutterSecureStorage? s]) : _s = s ?? const FlutterSecureStorage();
  final FlutterSecureStorage _s;
  static const _key = 'ledgerly_onboarding_seen';

  @override
  Future<bool> seen() async {
    try {
      return await _s.read(key: _key) == '1';
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> markSeen() async {
    try {
      await _s.write(key: _key, value: '1');
    } catch (_) {}
  }
}

class MemoryOnboardingStore implements OnboardingStore {
  // ignore: prefer_initializing_formals
  MemoryOnboardingStore({bool seen = false}) : _seen = seen;
  bool _seen;
  @override
  Future<bool> seen() async => _seen;
  @override
  Future<void> markSeen() async => _seen = true;
}

final onboardingStoreProvider = Provider<OnboardingStore>((_) => SecureOnboardingStore());

class OnboardingState {
  const OnboardingState({this.loaded = false, this.seen = false});
  final bool loaded;
  final bool seen;
}

class OnboardingController extends Notifier<OnboardingState> {
  @override
  OnboardingState build() {
    Future.microtask(() async {
      final seen = await ref.read(onboardingStoreProvider).seen();
      state = OnboardingState(loaded: true, seen: seen);
    });
    return const OnboardingState();
  }

  Future<void> complete() async {
    await ref.read(onboardingStoreProvider).markSeen();
    state = const OnboardingState(loaded: true, seen: true);
  }
}

final onboardingProvider = NotifierProvider<OnboardingController, OnboardingState>(OnboardingController.new);
