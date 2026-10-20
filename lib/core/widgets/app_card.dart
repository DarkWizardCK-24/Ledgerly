import 'package:flutter/material.dart';

/// Soft, elevated card. Optional [gradient] tints the surface; [accent] adds a coloured glow.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.gradient,
    this.accent,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(20);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: gradient == null ? c.surface : null,
        gradient: gradient,
        borderRadius: radius,
        border: Border.all(color: accent?.withValues(alpha: 0.28) ?? c.outline),
        boxShadow: [
          BoxShadow(
            color: (accent ?? const Color(0xFFB45309)).withValues(alpha: dark ? 0.0 : 0.07),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}
