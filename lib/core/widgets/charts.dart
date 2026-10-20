import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../format/money.dart';
import '../theme/app_colors.dart';

bool _reduce(BuildContext c) => MediaQuery.disableAnimationsOf(c);
Duration _d(BuildContext c, int ms) => _reduce(c) ? Duration.zero : Duration(milliseconds: ms);

/// Fade + rise on first build, staggered by [index]. Does nothing when animations are disabled.
class Reveal extends StatelessWidget {
  const Reveal({super.key, required this.child, this.index = 0});
  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    if (_reduce(context)) return child;
    return child
        .animate(delay: (60 * index).ms)
        .fadeIn(duration: 450.ms, curve: Curves.easeOut)
        .slideY(begin: 0.06, end: 0, duration: 500.ms, curve: Curves.easeOutCubic);
  }
}

/// Money value that counts up on first show and re-animates whenever the value changes.
class AnimatedMoney extends StatelessWidget {
  const AnimatedMoney(this.minor, this.currency, {super.key, this.style, this.signed = false, this.compact = false});
  final int minor;
  final String currency;
  final TextStyle? style;
  final bool signed;
  final bool compact;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: minor.toDouble()),
        duration: _d(context, 900),
        curve: Curves.easeOutCubic,
        builder: (_, v, _) => Text(formatMoney(v.round(), currency, signed: signed, compact: compact), style: style),
      );
}

/// Horizontal progress bar with a rounded gradient fill that animates to [value] (0..1).
class AnimatedProgress extends StatelessWidget {
  const AnimatedProgress({super.key, required this.value, this.color = AppColors.warning, this.gradient, this.height = 8});
  final double value;
  final Color color;
  final Gradient? gradient;
  final double height;

  @override
  Widget build(BuildContext context) {
    final track = Theme.of(context).colorScheme.outline.withValues(alpha: 0.6);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Container(
        height: height,
        color: track,
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
          duration: _d(context, 800),
          curve: Curves.easeOutCubic,
          builder: (_, v, _) => FractionallySizedBox(
            widthFactor: v,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(height),
                gradient: gradient ?? LinearGradient(colors: [Color.lerp(color, Colors.white, 0.3)!, color]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular progress ring with centred [child].
class RingProgress extends StatelessWidget {
  const RingProgress({super.key, required this.value, this.size = 110, this.strokeWidth = 12, this.gradient = AppColors.goldGradient, this.child});
  final double value;
  final double size;
  final double strokeWidth;
  final Gradient gradient;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final track = Theme.of(context).colorScheme.outline.withValues(alpha: 0.6);
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
        duration: _d(context, 1000),
        curve: Curves.easeOutCubic,
        builder: (_, v, c) => CustomPaint(painter: _RingPainter(v, strokeWidth, gradient, track), child: Center(child: c)),
        child: child,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v, this.w, this.g, this.track);
  final double v;
  final double w;
  final Gradient g;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(w / 2, w / 2, size.width - w, size.height - w);
    final base = Paint()..style = PaintingStyle.stroke..strokeWidth = w..color = track;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(startAngle: -math.pi / 2, endAngle: math.pi * 1.5, colors: g.colors, transform: const GradientRotation(-math.pi / 2)).createShader(rect);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * v, false, p);
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.v != v || o.track != track;
}

/// Donut chart whose slices sweep in. [slices] are (value, colour).
class DonutChart extends StatelessWidget {
  const DonutChart({super.key, required this.slices, this.size = 150, this.strokeWidth = 20, this.child});
  final List<(double, Color)> slices;
  final double size;
  final double strokeWidth;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final track = Theme.of(context).colorScheme.outline.withValues(alpha: 0.6);
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: _d(context, 1100),
        curve: Curves.easeOutCubic,
        builder: (_, t, c) => CustomPaint(painter: _DonutPainter(slices, strokeWidth, track, t), child: Center(child: c)),
        child: child,
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.slices, this.w, this.track, this.t);
  final List<(double, Color)> slices;
  final double w;
  final Color track;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(w / 2, w / 2, size.width - w, size.height - w);
    final p = Paint()..style = PaintingStyle.stroke..strokeWidth = w;
    canvas.drawArc(rect, 0, math.pi * 2, false, p..color = track);
    final total = slices.fold(0.0, (s, e) => s + e.$1);
    if (total <= 0) return;
    var start = -math.pi / 2;
    final gap = slices.length > 1 ? 0.035 : 0.0;
    for (final s in slices) {
      final sweep = s.$1 / total * math.pi * 2 * t;
      canvas.drawArc(rect, start, math.max(sweep - gap, 0.001), false, p..color = s.$2..strokeCap = StrokeCap.butt);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter o) => o.t != t || o.slices != slices || o.track != track;
}

/// Grouped income/expense bars per month; bars grow on first show.
class IncomeExpenseBars extends StatelessWidget {
  const IncomeExpenseBars({super.key, required this.labels, required this.income, required this.expense, required this.currency, this.height = 170});
  final List<String> labels;
  final List<int> income;
  final List<int> expense;
  final String currency;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final maxV = [...income, ...expense, 1].reduce(math.max);
    return SizedBox(
      height: height,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Tooltip(
              message: '${labels[i]}\nIncome ${formatMoney(income[i], currency)}\nExpenses ${formatMoney(expense[i], currency)}',
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Expanded(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children: [
                    _Bar(fraction: income[i] / maxV, gradient: AppColors.incomeGradient, delay: i),
                    const SizedBox(width: 4),
                    _Bar(fraction: expense[i] / maxV, gradient: AppColors.expenseGradient, delay: i),
                  ]),
                ),
                const SizedBox(height: 8),
                Text(labels[i], style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
              ]),
            ),
          ),
      ]),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.fraction, required this.gradient, required this.delay});
  final double fraction;
  final Gradient gradient;
  final int delay;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: fraction.clamp(0.02, 1.0)),
        duration: _d(context, 700 + delay * 90),
        curve: Curves.easeOutCubic,
        builder: (_, v, _) => FractionallySizedBox(
          heightFactor: v,
          child: Container(width: 14, decoration: BoxDecoration(gradient: gradient, borderRadius: const BorderRadius.vertical(top: Radius.circular(7)))),
        ),
      );
}

class LegendDot extends StatelessWidget {
  const LegendDot(this.color, this.label, {super.key});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ]);
}
