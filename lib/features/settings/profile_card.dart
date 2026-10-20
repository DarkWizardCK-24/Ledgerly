import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/common.dart';
import '../auth/auth_controller.dart';

String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
}

class Avatar extends StatelessWidget {
  const Avatar(this.name, {super.key, this.size = 56});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(gradient: AppColors.brandGradient, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.expense.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 6))]),
        child: Text(initialsOf(name), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.36)),
      );
}

/// Account details: who is signed in, the shared profile (synced with the Statement Analyzer), sign out.
class ProfileCard extends ConsumerWidget {
  const ProfileCard({super.key});

  Future<void> _editName(BuildContext context, WidgetRef ref, String current) async {
    final c = TextEditingController(text: current);
    final key = GlobalKey<FormState>();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit your name'),
        content: Form(
          key: key,
          child: TextFormField(controller: c, autofocus: true, decoration: const InputDecoration(labelText: 'Display name'), validator: (v) => (v == null || v.trim().length < 2) ? 'Enter at least 2 characters' : (v.trim().length > 80 ? 'Keep it under 80 characters' : null)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => key.currentState!.validate() ? Navigator.pop(ctx, c.text.trim()) : null, child: const Text('Save')),
        ],
      ),
    );
    c.dispose();
    if (name == null || !context.mounted) return;
    final err = await ref.read(authProvider.notifier).updateName(name);
    if (!context.mounted) return;
    ref.invalidate(profileProvider);
    toast(context, err ?? 'Name updated and synced');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final auth = ref.watch(authProvider);
    final profile = ref.watch(profileProvider);
    final demo = auth.status == AuthStatus.demo;

    return AppCard(
      padding: const EdgeInsets.all(22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Avatar(auth.displayName, size: 64),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(auth.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              Text(auth.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              _Pill(icon: demo ? LucideIcons.flaskConical : LucideIcons.badgeCheck, color: demo ? AppColors.warning : AppColors.income, label: demo ? 'Sample mode · not linked to an account' : 'Signed in'),
            ]),
          ),
        ]),
        const SizedBox(height: 18),
        if (!demo) ...[
          const Divider(),
          const SizedBox(height: 8),
          Text('Shared profile', style: t.textTheme.labelLarge?.copyWith(color: t.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          profile.when(
            loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Skeleton(height: 16, width: 220)),
            error: (_, _) => const _SyncNote(ok: false),
            data: (p) => p == null
                ? const _SyncNote(ok: false)
                : Column(children: [
                    _Row(LucideIcons.user, 'Display name', p.displayName ?? auth.displayName),
                    _Row(LucideIcons.indianRupee, 'Default currency', p.defaultCurrency),
                    _Row(LucideIcons.globe, 'Time zone', p.timezone),
                    const SizedBox(height: 6),
                    const _SyncNote(ok: true),
                  ]),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: [
          if (!demo) OutlinedButton.icon(onPressed: () => _editName(context, ref, auth.displayName), icon: const Icon(LucideIcons.pencil, size: 16), label: const Text('Edit name')),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: t.colorScheme.error),
            onPressed: () async {
              final ok = await confirmDialog(context, title: demo ? 'Leave sample mode?' : 'Sign out?', message: demo ? 'Sample data will be discarded.' : 'You will need to sign in again to see your CashBooks.', confirmLabel: demo ? 'Leave' : 'Sign out', destructive: true);
              if (ok) await ref.read(authProvider.notifier).signOut();
            },
            icon: const Icon(LucideIcons.logOut, size: 16),
            label: Text(demo ? 'Create an account' : 'Sign out'),
          ),
        ]),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.color, required this.label});
  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color))),
        ]),
      );
}

class _Row extends StatelessWidget {
  const _Row(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        Icon(icon, size: 17, color: t.colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: TextStyle(color: t.colorScheme.onSurfaceVariant))),
        Flexible(child: Text(value, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
      ]),
    );
  }
}

class _SyncNote extends StatelessWidget {
  const _SyncNote({required this.ok});
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppColors.income : AppColors.warning;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(children: [
        Icon(ok ? LucideIcons.refreshCw : LucideIcons.cloudOff, size: 15, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(ok ? 'Synced — the Statement Analyzer shows the same profile.' : 'Profile service unreachable. Your sign-in still works; profile details will sync when it\'s back.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}
