import 'dart:convert';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/common.dart';
import '../auth/auth_controller.dart';
import '../ledger/ledger_repository.dart';
import '../ledger/ledger_store.dart';

final dataSummaryProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final repo = ref.watch(ledgerRepositoryProvider);
  if (repo == null) return null;
  try {
    return await repo.dataSummary();
  } catch (_) {
    return null;
  }
});

/// Export, retention and deletion. Deleting is never one tap: the word DELETE has to be typed.
class DataControlsCard extends ConsumerWidget {
  const DataControlsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(ledgerRepositoryProvider);
    final t = Theme.of(context);
    final summary = ref.watch(dataSummaryProvider).value;
    final danger = OutlinedButton.styleFrom(foregroundColor: AppColors.expense, side: BorderSide(color: AppColors.expense.withValues(alpha: 0.5)));

    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(LucideIcons.shieldCheck, size: 20),
          const SizedBox(width: 8),
          Text('Your data', style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 8),
        Text(
          repo == null
              ? "You're in sample mode: everything here is illustrative and lives only on this device."
              : 'Your sign-in token is kept in the device keystore and passwords are never stored. You can download everything we hold, or delete it.',
          style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant),
        ),
        if (summary != null) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _Fact('CashBooks', summary['cashbooks']),
            _Fact('Transactions', summary['transactions']),
            _Fact('Custom categories', summary['custom_categories']),
            _Fact('Statement reports', summary['reports']),
          ]),
        ],
        const SizedBox(height: 14),
        Wrap(spacing: 10, runSpacing: 10, children: [
          if (repo == null)
            OutlinedButton.icon(
              style: danger,
              onPressed: () {
                ref.invalidate(ledgerProvider);
                toast(context, 'Sample data reset');
              },
              icon: const Icon(LucideIcons.eraser, size: 16),
              label: const Text('Reset sample data'),
            )
          else ...[
            OutlinedButton.icon(onPressed: () => _export(context, repo), icon: const Icon(LucideIcons.download, size: 16), label: const Text('Download all my data')),
            OutlinedButton.icon(style: danger, onPressed: () => _confirmDelete(context, ref, repo, account: false), icon: const Icon(LucideIcons.trash2, size: 16), label: const Text('Delete my data…')),
            OutlinedButton.icon(style: danger, onPressed: () => _confirmDelete(context, ref, repo, account: true), icon: const Icon(LucideIcons.trash2, size: 16), label: const Text('Delete my account…')),
          ],
        ]),
      ]),
    );
  }

  Future<void> _export(BuildContext context, LedgerRepository repo) async {
    try {
      final text = await repo.exportAll();
      await FileSaver.instance.saveFile(name: 'my-finance-data', bytes: utf8.encode(text), fileExtension: 'json', mimeType: MimeType.json);
      if (context.mounted) toast(context, 'Your data was saved');
    } on LedgerApiException catch (e) {
      if (context.mounted) toast(context, e.message);
    } catch (_) {
      if (context.mounted) toast(context, 'The export failed.');
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, LedgerRepository repo, {required bool account}) async {
    final done = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteDialog(account: account, repo: repo),
    );
    if (done != true) return;
    if (account) {
      await ref.read(authProvider.notifier).signOut();
    } else {
      await ref.read(ledgerProvider.notifier).reload();
      ref.invalidate(dataSummaryProvider);
      if (context.mounted) toast(context, "Deleted. This can't be undone.");
    }
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);
  final String label;
  final Object? value;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: t.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
        Text('${value ?? 0}', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _DeleteDialog extends StatefulWidget {
  const _DeleteDialog({required this.account, required this.repo});
  final bool account;
  final LedgerRepository repo;
  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  final _ctl = TextEditingController();
  String _scope = 'cashbook';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.account) {
        await widget.repo.deleteAccount();
      } else {
        await widget.repo.deleteData(_scope);
      }
      if (mounted) Navigator.pop(context, true);
    } on LedgerApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = "That didn't work. Nothing was deleted.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final armed = _ctl.text == 'DELETE' && !_busy;
    return AlertDialog(
      title: Text(widget.account ? 'Delete your account?' : 'Delete your data?'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (widget.account)
            const Text('This permanently deletes your sign-in account and all of your data in both apps.')
          else
            RadioGroup<String>(
              groupValue: _scope,
              onChanged: (v) => setState(() => _scope = v ?? _scope),
              child: const Column(children: [
                RadioListTile<String>(value: 'cashbook', title: Text('CashBook data'), subtitle: Text('CashBooks, transactions and your custom categories.')),
                RadioListTile<String>(value: 'analyzer', title: Text('Lensly data'), subtitle: Text('Reports, corrections, versions, budgets and goals.')),
                RadioListTile<String>(value: 'all', title: Text('Everything'), subtitle: Text('Both of the above. Your sign-in stays.')),
              ]),
            ),
          const SizedBox(height: 10),
          const Text("This can't be undone. Consider downloading your data first.", style: TextStyle(color: AppColors.expense, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          TextField(
            controller: _ctl,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(labelText: 'Type DELETE to confirm', border: OutlineInputBorder()),
            onChanged: (_) => setState(() {}),
          ),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: const TextStyle(color: AppColors.expense, fontWeight: FontWeight.w600))),
        ]),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
          onPressed: armed ? _go : null,
          child: Text(_busy ? 'Deleting…' : (widget.account ? 'Delete account' : 'Delete data')),
        ),
      ],
    );
  }
}
