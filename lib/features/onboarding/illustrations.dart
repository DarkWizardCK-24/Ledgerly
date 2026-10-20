import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';

/// Entrance: fade + rise. Skipped entirely when the user asked the OS for reduced motion.
Widget enter(
  BuildContext context,
  Widget child, {
  int ms = 0,
  Offset from = const Offset(0, 0.18),
  bool pop = false,
}) {
  if (MediaQuery.disableAnimationsOf(context)) return child;
  var a = child
      .animate(delay: ms.ms)
      .fadeIn(duration: 450.ms)
      .slide(
        begin: from,
        end: Offset.zero,
        duration: 600.ms,
        curve: Curves.easeOutCubic,
      );
  if (pop) {
    a = a.scale(
      begin: const Offset(0.8, 0.8),
      end: const Offset(1, 1),
      duration: 600.ms,
      curve: Curves.easeOutBack,
    );
  }
  return a;
}

/// Gentle endless bob.
Widget floaty(
  BuildContext context,
  Widget child, {
  double dy = 7,
  int ms = 2600,
  int phase = 0,
}) {
  if (MediaQuery.disableAnimationsOf(context)) return child;
  return child
      .animate(onPlay: (c) => c.repeat(reverse: true), delay: phase.ms)
      .moveY(begin: -dy, end: dy, duration: ms.ms, curve: Curves.easeInOut);
}

/// Soft expanding ring.
Widget pulse(BuildContext context, Widget child, {int phase = 0}) {
  if (MediaQuery.disableAnimationsOf(context)) return child;
  return child
      .animate(onPlay: (c) => c.repeat(reverse: true), delay: phase.ms)
      .scale(
        begin: const Offset(0.94, 0.94),
        end: const Offset(1.06, 1.06),
        duration: 2200.ms,
        curve: Curves.easeInOut,
      );
}

const _white = Colors.white;
Color _w(double a) => Colors.white.withValues(alpha: a);

class _Glass extends StatelessWidget {
  const _Glass({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 24,
  });
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: _w(0.16),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _w(0.32)),
    ),
    child: child,
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    this.icon,
    this.text,
    this.gradient = AppColors.goldGradient,
    this.size = 52,
  });
  final IconData? icon;
  final String? text;
  final Gradient gradient;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: gradient,
      shape: BoxShape.circle,
      border: Border.all(color: _w(0.7), width: 2),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    alignment: Alignment.center,
    child: icon != null
        ? Icon(icon, color: _white, size: size * 0.46)
        : Text(
            text ?? '',
            style: TextStyle(
              color: _white,
              fontWeight: FontWeight.w800,
              fontSize: size * 0.46,
            ),
          ),
  );
}

// ------------------------------------------------------------------ 1. welcome
class WelcomeArt extends StatelessWidget {
  const WelcomeArt({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var i = 0; i < 3; i++)
            pulse(
              context,
              Container(
                width: 150.0 + i * 58,
                height: 150.0 + i * 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _w(0.34 - i * 0.09), width: 2),
                  color: _w(0.04),
                ),
              ),
              phase: i * 450,
            ),
          enter(
            context,
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(34),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 36,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(34),
                child: Image.asset(
                  'assets/brand/logo.png',
                  width: 124,
                  height: 124,
                ),
              ),
            ),
            pop: true,
            from: Offset.zero,
          ),
          Positioned(
            left: 8,
            top: 52,
            child: enter(
              context,
              floaty(context, const _Bubble(text: '₹', size: 54), phase: 0),
              ms: 350,
              pop: true,
              from: Offset.zero,
            ),
          ),
          Positioned(
            right: 6,
            top: 74,
            child: enter(
              context,
              floaty(
                context,
                const _Bubble(
                  icon: LucideIcons.trendingUp,
                  gradient: AppColors.incomeGradient,
                  size: 50,
                ),
                phase: 500,
                ms: 3000,
              ),
              ms: 500,
              pop: true,
              from: Offset.zero,
            ),
          ),
          Positioned(
            left: 34,
            bottom: 36,
            child: enter(
              context,
              floaty(
                context,
                const _Bubble(
                  icon: LucideIcons.receipt,
                  gradient: AppColors.expenseGradient,
                  size: 46,
                ),
                phase: 900,
              ),
              ms: 650,
              pop: true,
              from: Offset.zero,
            ),
          ),
          Positioned(
            right: 30,
            bottom: 28,
            child: enter(
              context,
              floaty(
                context,
                const _Bubble(icon: LucideIcons.sparkles, size: 44),
                phase: 1300,
                ms: 2900,
              ),
              ms: 800,
              pop: true,
              from: Offset.zero,
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ 2. books
class BooksArt extends StatelessWidget {
  const BooksArt({super.key});

  @override
  Widget build(BuildContext context) {
    Widget card(
      int i,
      double angle,
      double dx,
      double dy,
      String name,
      String sub,
      IconData icon,
      Gradient g,
      String balance,
    ) {
      return Positioned(
        left: 40 + dx,
        top: 22 + dy,
        child: enter(
          context,
          Transform.rotate(
            angle: angle,
            child: _BookCard(
              name: name,
              sub: sub,
              icon: icon,
              gradient: g,
              balance: balance,
            ),
          ),
          ms: 150 + i * 170,
          from: const Offset(0, 0.5),
        ),
      );
    }

    return SizedBox(
      width: 300,
      height: 300,
      child: Stack(
        children: [
          card(
            0,
            -0.15,
            -24,
            -4,
            'Goa Trip',
            'Weekend getaway',
            LucideIcons.plane,
            const LinearGradient(
              colors: [Color(0xFF38BDF8), Color(0xFF2563EB)],
            ),
            '₹32,400',
          ),
          card(
            1,
            0.11,
            28,
            86,
            'Household',
            'Rent, bills, groceries',
            LucideIcons.house,
            AppColors.goldGradient,
            '₹2,48,000',
          ),
          card(
            2,
            -0.03,
            0,
            174,
            'Personal',
            'Everyday spending',
            LucideIcons.wallet,
            AppColors.brandGradient,
            '₹58,750',
          ),
          Positioned(
            right: 4,
            top: 6,
            child: enter(
              context,
              floaty(
                context,
                const _Bubble(icon: LucideIcons.bookPlus, size: 50),
                phase: 300,
              ),
              ms: 700,
              pop: true,
              from: Offset.zero,
            ),
          ),
        ],
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  const _BookCard({
    required this.name,
    required this.sub,
    required this.icon,
    required this.gradient,
    required this.balance,
  });
  final String name, sub, balance;
  final IconData icon;
  final Gradient gradient;
  @override
  Widget build(BuildContext context) => Container(
    width: 216,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.22),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: _white, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.lightText,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              Text(
                sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.lightMuted,
                  fontSize: 11.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                balance,
                style: const TextStyle(
                  color: AppColors.ember,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------- 3. add fast
class AddFastArt extends StatelessWidget {
  const AddFastArt({super.key});

  @override
  Widget build(BuildContext context) {
    final rows = <(IconData, Gradient, String, String, String, bool)>[
      (
        LucideIcons.banknote,
        AppColors.incomeGradient,
        'Salary',
        'Bank transfer · 9:30 AM',
        '+₹85,000',
        true,
      ),
      (
        LucideIcons.utensils,
        const LinearGradient(colors: [Color(0xFFFB923C), Color(0xFFEA580C)]),
        'Lunch with team',
        'UPI · 1:10 PM',
        '−₹520',
        false,
      ),
      (
        LucideIcons.car,
        const LinearGradient(colors: [Color(0xFF38BDF8), Color(0xFF0284C7)]),
        'Cab ride',
        'UPI · 6:45 PM',
        '−₹240',
        false,
      ),
    ];
    return SizedBox(
      width: 300,
      height: 300,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(top: 6, right: 4, bottom: 58),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < rows.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: enter(
                        context,
                        _TxnRow(
                          icon: rows[i].$1,
                          gradient: rows[i].$2,
                          title: rows[i].$3,
                          sub: rows[i].$4,
                          amount: rows[i].$5,
                          income: rows[i].$6,
                        ),
                        ms: 150 + i * 200,
                        from: const Offset(0.4, 0),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 6,
            child: enter(
              context,
              pulse(context, const _Bubble(icon: LucideIcons.plus, size: 62)),
              ms: 800,
              pop: true,
              from: Offset.zero,
            ),
          ),
          Positioned(
            right: 10,
            top: -8,
            child: enter(
              context,
              floaty(
                context,
                const _Bubble(
                  icon: LucideIcons.zap,
                  gradient: AppColors.brandGradient,
                  size: 44,
                ),
                phase: 400,
              ),
              ms: 900,
              pop: true,
              from: Offset.zero,
            ),
          ),
        ],
      ),
    );
  }
}

class _TxnRow extends StatelessWidget {
  const _TxnRow({
    required this.icon,
    required this.gradient,
    required this.title,
    required this.sub,
    required this.amount,
    required this.income,
  });
  final IconData icon;
  final Gradient gradient;
  final String title, sub, amount;
  final bool income;
  @override
  Widget build(BuildContext context) => Container(
    width: 280,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: _white, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.lightText,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              Text(
                sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.lightMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            color: income ? const Color(0xFF0A7040) : const Color(0xFFC0231A),
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------- 4. insights
class InsightsArt extends StatelessWidget {
  const InsightsArt({super.key});

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return SizedBox(
      width: 300,
      height: 300,
      child: Stack(
        children: [
          Positioned(
            left: 6,
            right: 6,
            top: 26,
            child: enter(
              context,
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.24),
                      blurRadius: 30,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: still
                              ? Duration.zero
                              : const Duration(milliseconds: 1400),
                          curve: Curves.easeOutCubic,
                          builder: (_, t, _) => SizedBox(
                            width: 112,
                            height: 112,
                            child: CustomPaint(painter: _DonutPainter(t)),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Legend(Color(0xFFE8590C), 'Housing', '42%'),
                              _Legend(Color(0xFFEC4899), 'Shopping', '21%'),
                              _Legend(Color(0xFFF97316), 'Food', '14%'),
                              _Legend(Color(0xFF0EA5E9), 'Travel', '23%'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 70,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: still
                            ? Duration.zero
                            : const Duration(milliseconds: 1200),
                        curve: Curves.easeOutBack,
                        builder: (_, t, _) => Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            for (final (i, v) in const [
                              0.45,
                              0.7,
                              0.55,
                              0.9,
                              0.62,
                              0.8,
                            ].indexed)
                              Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Container(
                                    width: 28,
                                    height: math.max(
                                      4.0,
                                      56 * v * t.clamp(0.0, 1.0),
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: i.isEven
                                          ? AppColors.brandGradient
                                          : AppColors.goldGradient,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ms: 100,
            ),
          ),
          Positioned(
            right: 0,
            bottom: 14,
            child: enter(
              context,
              floaty(
                context,
                _Glass(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  radius: 18,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.piggyBank, color: _white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Saved 32% this month',
                        style: TextStyle(
                          color: _white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                phase: 200,
              ),
              ms: 900,
              pop: true,
              from: Offset.zero,
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.color, this.label, this.value);
  final Color color;
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3.5),
    child: Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.lightText,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.lightMuted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.t);
  final double t; // 0..1 sweep progress
  static const _parts = [
    (0.42, Color(0xFFE8590C)),
    (0.21, Color(0xFFEC4899)),
    (0.14, Color(0xFFF97316)),
    (0.23, Color(0xFF0EA5E9)),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.17;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: (size.width - stroke) / 2,
    );
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppColors.lightOutline;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);
    var start = -math.pi / 2;
    const gap = 0.06;
    final total = math.pi * 2 * t;
    var drawn = 0.0;
    for (final (share, color) in _parts) {
      final full = math.pi * 2 * share;
      final remaining = total - drawn;
      if (remaining <= 0) break;
      final sweep = math.min(full, remaining) - gap;
      if (sweep > 0) {
        canvas.drawArc(
          rect,
          start,
          sweep,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.round
            ..color = color,
        );
      }
      start += full;
      drawn += full;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.t != t;
}

// ---------------------------------------------------------------- 5. private
class PrivateArt extends StatelessWidget {
  const PrivateArt({super.key});

  @override
  Widget build(BuildContext context) {
    Widget pill(IconData icon, String text) => _Glass(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      radius: 14,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _white, size: 15),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: _white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );

    // Scales down rather than overflowing when the system font is large.
    return SizedBox(
      width: 300,
      height: 300,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 150,
                height: 118,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    for (var i = 0; i < 2; i++)
                      pulse(
                        context,
                        Container(
                          width: 92.0 + i * 26,
                          height: 92.0 + i * 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _w(0.3 - i * 0.12),
                              width: 2,
                            ),
                          ),
                        ),
                        phase: i * 600,
                      ),
                    enter(
                      context,
                      const _Bubble(
                        icon: LucideIcons.shieldCheck,
                        size: 78,
                        gradient: AppColors.incomeGradient,
                      ),
                      pop: true,
                      from: Offset.zero,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              enter(
                context,
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _AppBadge(
                      label: 'Ledgerly',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/brand/logo.png',
                          width: 44,
                          height: 44,
                        ),
                      ),
                    ),
                    const _Link(),
                    const _AppBadge(
                      label: 'Lensly',
                      child: _Bubble(
                        icon: LucideIcons.scanSearch,
                        size: 44,
                        gradient: LinearGradient(
                          colors: [Color(0xFFFB7185), Color(0xFFBE123C)],
                        ),
                      ),
                    ),
                  ],
                ),
                ms: 350,
              ),
              const SizedBox(height: 10),
              enter(
                context,
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    pill(LucideIcons.lock, 'Secure sign-in'),
                    pill(LucideIcons.download, 'Export anytime'),
                    pill(LucideIcons.trash2, 'Delete anytime'),
                  ],
                ),
                ms: 600,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppBadge extends StatelessWidget {
  const _AppBadge({required this.label, required this.child});
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      child,
      const SizedBox(height: 6),
      Text(
        label,
        style: const TextStyle(
          color: _white,
          fontWeight: FontWeight.w800,
          fontSize: 12.5,
        ),
      ),
    ],
  );
}

class _Link extends StatelessWidget {
  const _Link();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 0, 10, 20),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            decoration: BoxDecoration(color: _w(0.8), shape: BoxShape.circle),
          ),
        const Icon(LucideIcons.refreshCw, color: _white, size: 16),
        for (var i = 0; i < 3; i++)
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            decoration: BoxDecoration(color: _w(0.8), shape: BoxShape.circle),
          ),
      ],
    ),
  );
}
