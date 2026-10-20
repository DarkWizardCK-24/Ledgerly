import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../responsive/breakpoints.dart';
import '../theme/app_colors.dart';

/// Scrollable page body with centred max width and responsive padding.
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    required this.children,
    this.leading,
  });
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final List<Widget> children;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final w = MediaQuery.sizeOf(context).width;
    final pad = w >= Breakpoints.desktop
        ? 40.0
        : (w >= Breakpoints.tablet ? 28.0 : 16.0);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        pad,
        w >= Breakpoints.tablet ? 32 : 20,
        pad,
        40,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 12,
                  spacing: 12,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (leading case final l?) ...[
                          l,
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: t.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (subtitle case final sub?)
                                Text(
                                  sub,
                                  style: TextStyle(
                                    color: t.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (actions.isNotEmpty)
                      Wrap(spacing: 8, runSpacing: 8, children: actions),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    // Small chart/list cards give this a short, fixed height: shrink to fit instead of overflowing.
    return LayoutBuilder(builder: (context, c) {
      final compact = c.hasBoundedHeight && c.maxHeight < 260;
      final body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(compact ? 12 : 20),
            decoration: BoxDecoration(
              color: t.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: compact ? 24 : 32, color: t.colorScheme.primary),
          ),
          SizedBox(height: compact ? 8 : 16),
          Text(
            title,
            style: t.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: t.colorScheme.onSurfaceVariant),
          ),
          if (action != null) ...[SizedBox(height: compact ? 8 : 16), action!],
        ],
      );
      return Center(
        child: Padding(
          padding: EdgeInsets.all(compact ? 8 : 32),
          child: compact
              ? FittedBox(fit: BoxFit.scaleDown, child: ConstrainedBox(constraints: BoxConstraints(maxWidth: c.maxWidth.isFinite ? c.maxWidth - 16 : 320), child: body))
              : body,
        ),
      );
    });
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: LucideIcons.circleAlert,
    title: 'Something went wrong',
    message: message,
    action: onRetry == null
        ? null
        : OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(LucideIcons.refreshCw, size: 16),
            label: const Text('Try again'),
          ),
  );
}

/// Pulsing placeholder block for loading states.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.height = 16, this.width, this.radius = 12});
  final double height;
  final double? width;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.outline;
    final reduce = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: base.withValues(alpha: reduce ? 0.6 : 0.4 + 0.4 * _c.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                )
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Bottom sheet on phones, centred dialog on larger screens.
Future<T?> showAdaptiveSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  if (Breakpoints.ofContext(context) == ScreenSize.phone) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: builder(ctx),
      ),
    );
  }
  return showDialog<T>(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.9,
        ),
        child: builder(ctx),
      ),
    ),
  );
}

void toast(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(
    SnackBar(
      content: Text(message),
      action: actionLabel == null
          ? null
          : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
    ),
  );
}

/// Rounded gradient tile holding an icon (category avatars, stat icons, quick actions).
class GradientIcon extends StatelessWidget {
  const GradientIcon(
    this.icon, {
    super.key,
    required this.color,
    this.size = 44,
    this.gradient,
  });
  final IconData icon;
  final Color color;
  final double size;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient:
          gradient ??
          LinearGradient(
            colors: [Color.lerp(color, Colors.white, 0.28)!, color],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
      borderRadius: BorderRadius.circular(size * 0.32),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.35),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Icon(icon, color: Colors.white, size: size * 0.46),
  );
}

/// Decorative colour glows behind page content.
class Backdrop extends StatelessWidget {
  const Backdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    Widget glow(Color c, double size) => IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              c.withValues(alpha: dark ? 0.16 : 0.2),
              c.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
    return Stack(
      children: [
        Positioned(top: -160, right: -120, child: glow(AppColors.warning, 520)),
        Positioned(
          bottom: -200,
          left: -140,
          child: glow(AppColors.expense, 520),
        ),
        child,
      ],
    );
  }
}

/// Two cards side by side on wide screens, stacked on narrow ones.
class TwoUp extends StatelessWidget {
  const TwoUp({
    super.key,
    required this.a,
    required this.b,
    this.breakpoint = 800,
  });
  final Widget a;
  final Widget b;
  final double breakpoint;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      if (c.maxWidth < breakpoint) {
        return Column(children: [a, const SizedBox(height: 16), b]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: a),
          const SizedBox(width: 16),
          Expanded(child: b),
        ],
      );
    },
  );
}
