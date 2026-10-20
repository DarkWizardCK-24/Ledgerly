import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/common.dart';
import 'data_controls.dart';
import 'profile_card.dart';

/// Live backend/database status (real calls). Profile and account settings arrive in Phase 3.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(apiStatusProvider);
    final api = status.value;
    return PageScaffold(
      title: 'Settings',
      subtitle: 'System status and preferences',
      actions: [
        OutlinedButton.icon(onPressed: () => ref.invalidate(apiStatusProvider), icon: const Icon(LucideIcons.refreshCw, size: 16), label: const Text('Re-check')),
      ],
      children: [
        const SectionTitle('Your account'),
        const Reveal(child: ProfileCard()),
        const SizedBox(height: 28),
        const SectionTitle('System status'),
        LayoutBuilder(builder: (context, c) {
          final cards = [
            _StatusCard(icon: LucideIcons.server, title: 'FastAPI backend', loading: status.isLoading, ok: api?.apiUp ?? false, okText: 'Online', badText: 'Unreachable'),
            _StatusCard(icon: LucideIcons.database, title: 'Supabase database', loading: status.isLoading, ok: api?.databaseReady ?? false, okText: 'Connected', badText: api?.detail ?? 'Not connected'),
          ];
          return c.maxWidth < 640
              ? Column(children: [cards[0], const SizedBox(height: 16), cards[1]])
              : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: cards[0]), const SizedBox(width: 16), Expanded(child: cards[1])]);
        }),
        const SizedBox(height: 28),
        const SectionTitle('Organise'),
        AppCard(
          onTap: () => context.go('/settings/categories'),
          child: Row(children: [
            const GradientIcon(LucideIcons.tags, color: Color(0xFFE8590C), size: 44),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Categories & tags', style: TextStyle(fontWeight: FontWeight.w700)),
                Text('Create, rename, recolour and archive'),
              ]),
            ),
            Icon(LucideIcons.chevronRight, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ]),
        ),
        const SizedBox(height: 12),
        AppCard(
          onTap: () => context.push('/welcome'),
          child: Row(children: [
            const GradientIcon(LucideIcons.sparkles, color: Color(0xFFE8384F), size: 44),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Replay intro', style: TextStyle(fontWeight: FontWeight.w700)),
                Text('A quick tour of what Ledgerly can do'),
              ]),
            ),
            Icon(LucideIcons.chevronRight, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ]),
        ),
        const SizedBox(height: 28),
        const SectionTitle('Data & privacy'),
        const DataControlsCard(),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.icon, required this.title, required this.loading, required this.ok, required this.okText, required this.badText});
  final IconData icon;
  final String title;
  final bool loading;
  final bool ok;
  final String okText;
  final String badText;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final color = loading ? t.colorScheme.onSurfaceVariant : (ok ? AppColors.income : AppColors.expense);
    return AppCard(
      child: Row(children: [
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: color)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(loading ? 'Checking…' : (ok ? okText : badText), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    );
  }
}
