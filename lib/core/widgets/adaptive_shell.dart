import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../responsive/breakpoints.dart';
import '../theme/app_colors.dart';
import 'common.dart';
import 'sync_banner.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/settings/profile_card.dart';

class NavItem {
  const NavItem(this.label, this.icon, [String? short]) : short = short ?? label;
  final String label;
  /// Compact label for narrow bottom bars.
  final String short;
  final IconData icon;
}

const navItems = [
  NavItem('Dashboard', LucideIcons.layoutDashboard, 'Home'),
  NavItem('CashBooks', LucideIcons.bookOpen, 'Books'),
  NavItem('Transactions', LucideIcons.arrowLeftRight, 'Activity'),
  NavItem('Insights', LucideIcons.chartPie),
  NavItem('Settings', LucideIcons.settings),
];

/// Phone: bottom bar · Tablet: rail · Desktop/Web: full sidebar.
class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({super.key, required this.index, required this.onSelect, required this.child});
  final int index;
  final ValueChanged<int> onSelect;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    switch (Breakpoints.ofContext(context)) {
      case ScreenSize.phone:
        return Scaffold(
          body: SafeArea(child: Backdrop(child: SyncBanner(child: child))),
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: onSelect,
            destinations: [
              for (final n in navItems) NavigationDestination(icon: Icon(n.icon), label: n.short),
            ],
          ),
        );
      case ScreenSize.tablet:
        return Scaffold(
          body: SafeArea(
            child: Row(children: [
              NavigationRail(
                selectedIndex: index,
                onDestinationSelected: onSelect,
                labelType: NavigationRailLabelType.all,
                leading: const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: _Logo(compact: true)),
                destinations: [
                  for (final n in navItems)
                    NavigationRailDestination(icon: Icon(n.icon), label: Text(n.label)),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: Backdrop(child: SyncBanner(child: child))),
            ]),
          ),
        );
      case ScreenSize.desktop:
        return Scaffold(
          body: Row(children: [
            _Sidebar(index: index, onSelect: onSelect),
            Expanded(child: Backdrop(child: SyncBanner(child: child))),
          ]),
        );
    }
  }
}

class _Logo extends StatelessWidget {
  const _Logo({this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final mark = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset('assets/brand/logo.png', width: 40, height: 40),
    );
    if (compact) return mark;
    return Row(children: [
      mark,
      const SizedBox(width: 12),
      Flexible(
        child: Text('Ledgerly',
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      ),
    ]);
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.index, required this.onSelect});
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final auth = ref.watch(authProvider);
    return Container(
      width: 264,
      decoration: BoxDecoration(
        color: t.colorScheme.surface,
        border: Border(right: BorderSide(color: t.colorScheme.outline)),
      ),
      padding: const EdgeInsets.all(20),
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _Logo(),
          const SizedBox(height: 32),
          for (var i = 0; i < navItems.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _SidebarTile(item: navItems[i], selected: i == index, onTap: () => onSelect(i)),
            ),
          const Spacer(),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.go('/settings'),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: t.colorScheme.outline.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                Avatar(auth.displayName, size: 38),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(auth.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(auth.status == AuthStatus.demo ? 'Sample mode' : auth.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                  ]),
                ),
                Icon(LucideIcons.chevronRight, size: 16, color: t.colorScheme.onSurfaceVariant),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({required this.item, required this.selected, required this.onTap});
  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final color = selected ? Colors.white : c.onSurfaceVariant;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        gradient: selected ? AppColors.brandGradient : null,
        borderRadius: BorderRadius.circular(14),
        boxShadow: selected ? [BoxShadow(color: AppColors.expense.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))] : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(children: [
              Icon(item.icon, size: 20, color: color),
              const SizedBox(width: 12),
              Flexible(
                child: Text(item.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: color, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
