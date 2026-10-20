import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../features/ledger/ledger_store.dart';
import '../theme/app_colors.dart';

/// Shows why the last change or load did not reach the server, with Retry. Only appears when signed in and something failed.
class SyncBanner extends ConsumerWidget {
  const SyncBanner({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = ref.watch(ledgerProvider.select((s) => s.error));
    if (error == null) return child;
    final notifier = ref.read(ledgerProvider.notifier);
    return Column(children: [
      Semantics(
        liveRegion: true,
        child: Container(
          width: double.infinity,
          color: AppColors.expense.withValues(alpha: 0.12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            const Icon(LucideIcons.triangleAlert, size: 18, color: AppColors.expense),
            const SizedBox(width: 10),
            Expanded(child: Text(error, style: const TextStyle(fontWeight: FontWeight.w600))),
            TextButton(
              onPressed: () async {
                notifier.dismissError();
                await notifier.reload();
              },
              child: const Text('Retry'),
            ),
            IconButton(tooltip: 'Dismiss', onPressed: notifier.dismissError, icon: const Icon(LucideIcons.x, size: 18)),
          ]),
        ),
      ),
      Expanded(child: child),
    ]);
  }
}
