import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../auth/auth_controller.dart';
import 'illustrations.dart';
import 'onboarding_store.dart';

class _Slide {
  const _Slide(this.colors, this.title, this.body, this.art);
  final List<Color> colors; // three stops, top-left to bottom-right
  final String title;
  final String body;
  final Widget art;
}

const _slides = <_Slide>[
  _Slide([Color(0xFFFF9A2F), Color(0xFFE8384F), Color(0xFF7A1531)], 'Welcome to Ledgerly', 'Every book, every rupee. A calm, beautiful home for all of your money.', WelcomeArt()),
  _Slide([Color(0xFFFFC93C), Color(0xFFFF7A2F), Color(0xFFB4360A)], 'A book for every part of life', 'Keep separate CashBooks for home, work, trips and side projects, each with its own balance.', BooksArt()),
  _Slide([Color(0xFFFB7185), Color(0xFFE11D48), Color(0xFF6B0F2A)], 'Add it in seconds', 'Log income and expenses with categories, tags and payment methods. Search and filter whenever you like.', AddFastArt()),
  _Slide([Color(0xFFFFB02E), Color(0xFFE8590C), Color(0xFF6E2410)], 'See where it all goes', 'Charts and trends show your spending, savings rate and biggest expenses at a glance.', InsightsArt()),
  _Slide([Color(0xFFE8384F), Color(0xFF9F1239), Color(0xFF2E0817)], 'Yours, and only yours', 'One secure account across Ledgerly and Lensly, our statement analyzer. Export or delete your data any time.', PrivateArt()),
];

/// First-run intro (also reachable from Settings as "Replay intro").
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pc = PageController();
  int _i = 0;

  bool get _last => _i == _slides.length - 1;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  double get _page => _pc.hasClients && _pc.position.haveDimensions ? (_pc.page ?? _i.toDouble()) : _i.toDouble();

  Future<void> _finish() async {
    await ref.read(onboardingProvider.notifier).complete();
    if (!mounted) return;
    context.go(ref.read(authProvider).isIn ? '/' : '/login');
  }

  void _go(int to) {
    final target = to.clamp(0, _slides.length - 1);
    if (MediaQuery.disableAnimationsOf(context)) {
      _pc.jumpToPage(target);
    } else {
      _pc.animateToPage(target, duration: const Duration(milliseconds: 520), curve: Curves.easeOutCubic);
    }
  }

  void _next() => _last ? _finish() : _go(_i + 1);

  List<Color> _blend(double p) {
    final a = p.floor().clamp(0, _slides.length - 1);
    final b = (a + 1).clamp(0, _slides.length - 1);
    final t = p - a;
    return [for (var k = 0; k < 3; k++) Color.lerp(_slides[a].colors[k], _slides[b].colors[k], t)!];
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (_, e) {
        if (e is! KeyDownEvent) return KeyEventResult.ignored;
        if (e.logicalKey == LogicalKeyboardKey.arrowRight || e.logicalKey == LogicalKeyboardKey.enter) {
          _next();
          return KeyEventResult.handled;
        }
        if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
          _go(_i - 1);
          return KeyEventResult.handled;
        }
        if (e.logicalKey == LogicalKeyboardKey.escape) {
          _finish();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        body: AnimatedBuilder(
          animation: _pc,
          builder: (context, child) {
            final p = _page;
            final c = _blend(p);
            return Container(
              decoration: BoxDecoration(gradient: LinearGradient(colors: c, begin: Alignment.topLeft, end: Alignment.bottomRight, stops: const [0, 0.55, 1])),
              child: Stack(children: [
                // Soft light blobs that drift as you swipe.
                Positioned(left: -90 - p * 36, top: -70, child: _Blob(size: 300, alpha: 0.16)),
                Positioned(right: -110 + p * 30, bottom: 120, child: _Blob(size: 340, alpha: 0.10)),
                child!,
              ]),
            );
          },
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
                    child: Row(children: [
                      Semantics(
                        label: 'Step ${_i + 1} of ${_slides.length}',
                        child: Text('${_i + 1} / ${_slides.length}', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                      ),
                      const Spacer(),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 250),
                        opacity: _last ? 0 : 1,
                        child: TextButton(
                          onPressed: _last ? null : _finish,
                          style: TextButton.styleFrom(foregroundColor: Colors.white),
                          child: const Text('Skip', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ]),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pc,
                      itemCount: _slides.length,
                      onPageChanged: (v) => setState(() => _i = v),
                      itemBuilder: (context, i) => AnimatedBuilder(
                        animation: _pc,
                        builder: (context, _) {
                          final d = (_page - i).clamp(-1.0, 1.0); // -1 incoming from right .. 1 leaving to left
                          return Opacity(
                            opacity: (1 - d.abs() * 0.7).clamp(0.0, 1.0),
                            child: _SlideView(slide: _slides[i], artShift: d * -70),
                          );
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                    child: Column(children: [
                      _Dots(count: _slides.length, index: _i),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton(
                          onPressed: _next,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.ember,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            elevation: 0,
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: Row(
                              key: ValueKey(_last),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_last ? 'Get started' : 'Next', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                const SizedBox(width: 8),
                                Icon(_last ? LucideIcons.rocket : LucideIcons.arrowRight, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide, required this.artShift});
  final _Slide slide;
  final double artShift;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(children: [
        Expanded(
          child: Center(
            child: Transform.translate(
              offset: Offset(artShift, 0),
              child: FittedBox(fit: BoxFit.scaleDown, child: slide.art),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Semantics(
          header: true,
          child: Text(slide.title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -0.4)),
        ),
        const SizedBox(height: 12),
        Text(slide.body, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 15.5, height: 1.45)),
        const SizedBox(height: 18),
      ]),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});
  final int count, index;
  @override
  Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == index ? 28 : 8,
            height: 8,
            decoration: BoxDecoration(color: i == index ? Colors.white : Colors.white.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(8)),
          ),
      ]);
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.alpha});
  final double size, alpha;
  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Colors.white.withValues(alpha: alpha), Colors.white.withValues(alpha: 0)])),
        ),
      );
}
