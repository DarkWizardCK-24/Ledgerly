import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/config/app_config.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/charts.dart';
import 'auth_controller.dart';

enum AuthMode { login, register, forgot }

/// 0 (empty) .. 4 (strong). Length is required; variety raises the score.
int passwordStrength(String p) {
  if (p.length < 8) return p.isEmpty ? 0 : 1;
  var score = 1;
  if (RegExp(r'[a-z]').hasMatch(p) && RegExp(r'[A-Z]').hasMatch(p)) score++;
  if (RegExp(r'\d').hasMatch(p)) score++;
  if (RegExp(r'[^A-Za-z0-9]').hasMatch(p) || p.length >= 14) score++;
  return score;
}

String? validateEmail(String? v) {
  final s = (v ?? '').trim();
  if (s.isEmpty) return 'Enter your email';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$').hasMatch(s)) return 'Enter a valid email address';
  return null;
}

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _key = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  AuthMode _mode = AuthMode.login;
  bool _show = false;

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  void _setMode(AuthMode m) {
    ref.read(authProvider.notifier).clearMessages();
    setState(() {
      _mode = m;
      _password.clear();
      _confirm.clear();
    });
  }

  Future<void> _submit() async {
    if (!_key.currentState!.validate()) return;
    final auth = ref.read(authProvider.notifier);
    switch (_mode) {
      case AuthMode.login:
        await auth.signIn(_email.text, _password.text);
      case AuthMode.register:
        final ok = await auth.signUp(name: _name.text, email: _email.text, password: _password.text);
        if (ok && ref.read(authProvider).info != null && mounted) setState(() => _mode = AuthMode.login);
      case AuthMode.forgot:
        await auth.sendReset(_email.text);
    }
    _password.clear();
    _confirm.clear();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.desktop;
    final form = _FormCard(
      mode: _mode,
      formKey: _key,
      name: _name,
      email: _email,
      password: _password,
      confirm: _confirm,
      show: _show,
      onToggleShow: () => setState(() => _show = !_show),
      onMode: _setMode,
      onSubmit: _submit,
    );

    return Scaffold(
      body: wide
          ? Row(children: [
              const Expanded(flex: 5, child: _BrandPanel()),
              Expanded(flex: 4, child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(40), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: form)))),
            ])
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(children: [const _MobileHeader(), const SizedBox(height: 24), form]),
                  ),
                ),
              ),
            ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    const points = [
      (LucideIcons.bookOpen, 'Unlimited CashBooks', 'Separate ledgers for home, work, trips and more.'),
      (LucideIcons.chartPie, 'Clear insights', 'Donuts, trends and savings rate from your real numbers.'),
      (LucideIcons.refreshCw, 'One account, two apps', 'The same sign-in and profile power Lensly, the statement analyzer.'),
    ];
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFFFB02E), Color(0xFFFF6B35), Color(0xFFE8384F)], begin: Alignment.topLeft, end: Alignment.bottomRight, stops: [0, 0.5, 1])),
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(right: -120, top: -120, child: _circle(380, 0.12)),
        Positioned(left: -80, bottom: -140, child: _circle(340, 0.1)),
        Padding(
          padding: const EdgeInsets.all(56),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.asset('assets/brand/logo.png', width: 64, height: 64)),
            const SizedBox(height: 28),
            Text('Every book,\nevery rupee —\nbeautifully organised.',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, height: 1.15)),
            const SizedBox(height: 36),
            for (var i = 0; i < points.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(width: 42, height: 42, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(14)), child: Icon(points[i].$1, color: Colors.white, size: 20)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(points[i].$2, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(points[i].$3, style: const TextStyle(color: Colors.white70, height: 1.4)),
                    ]),
                  ),
                ]).animate(delay: (150 * i).ms).fadeIn(duration: 500.ms).slideX(begin: -0.05, end: 0),
              ),
          ]),
        ),
      ]),
    );
  }

  Widget _circle(double s, double a) => Container(width: s, height: s, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: a)));
}

class _MobileHeader extends StatelessWidget {
  const _MobileHeader();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFFB02E), Color(0xFFFF6B35), Color(0xFFE8384F)], begin: Alignment.topLeft, end: Alignment.bottomRight, stops: [0, 0.5, 1]),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: AppColors.expense.withValues(alpha: 0.28), blurRadius: 30, offset: const Offset(0, 14))],
        ),
        child: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.asset('assets/brand/logo.png', width: 56, height: 56)),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Ledgerly', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
              Text('Every book, every rupee.', style: TextStyle(color: Colors.white70)),
            ]),
          ),
        ]),
      ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05, end: 0);
}

class _FormCard extends ConsumerWidget {
  const _FormCard({
    required this.mode,
    required this.formKey,
    required this.name,
    required this.email,
    required this.password,
    required this.confirm,
    required this.show,
    required this.onToggleShow,
    required this.onMode,
    required this.onSubmit,
  });
  final AuthMode mode;
  final GlobalKey<FormState> formKey;
  final TextEditingController name;
  final TextEditingController email;
  final TextEditingController password;
  final TextEditingController confirm;
  final bool show;
  final VoidCallback onToggleShow;
  final ValueChanged<AuthMode> onMode;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final auth = ref.watch(authProvider);
    final configured = AppConfig.authConfigured;
    final title = switch (mode) { AuthMode.login => 'Welcome back', AuthMode.register => 'Create your account', AuthMode.forgot => 'Reset your password' };
    final sub = switch (mode) {
      AuthMode.login => 'Sign in to continue to your CashBooks.',
      AuthMode.register => 'One account works in Ledgerly and Lensly.',
      AuthMode.forgot => 'Enter your email and we\'ll send a reset link.',
    };
    final cta = switch (mode) { AuthMode.login => 'Sign in', AuthMode.register => 'Create account', AuthMode.forgot => 'Send reset link' };
    final canSubmit = configured && !auth.busy;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: t.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: t.colorScheme.outline),
        boxShadow: [BoxShadow(color: const Color(0xFFB45309).withValues(alpha: 0.08), blurRadius: 40, offset: const Offset(0, 16))],
      ),
      child: Form(
        key: formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (mode != AuthMode.login) TextButton.icon(onPressed: () => onMode(AuthMode.login), icon: const Icon(LucideIcons.arrowLeft, size: 16), label: const Text('Back to sign in')),
          Text(title, style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(sub, style: TextStyle(color: t.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 20),
          if (!configured) const _Banner(icon: LucideIcons.triangleAlert, color: AppColors.warning, text: 'Sign-in isn\'t configured in this build. Run with --dart-define=SUPABASE_URL=… and SUPABASE_ANON_KEY=… (see the setup guide). You can still explore with sample data.'),
          if (auth.error != null) _Banner(icon: LucideIcons.circleAlert, color: AppColors.expense, text: auth.error!),
          if (auth.info != null) _Banner(icon: LucideIcons.circleCheck, color: AppColors.income, text: auth.info!),
          if (mode == AuthMode.register) ...[
            TextFormField(
              controller: name,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(LucideIcons.user, size: 18)),
              validator: (v) => (v == null || v.trim().length < 2) ? 'Enter your name' : null,
            ),
            const SizedBox(height: 14),
          ],
          TextFormField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(LucideIcons.mail, size: 18)),
            validator: validateEmail,
          ),
          if (mode != AuthMode.forgot) ...[
            const SizedBox(height: 14),
            TextFormField(
              controller: password,
              obscureText: !show,
              autofillHints: [mode == AuthMode.login ? AutofillHints.password : AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(LucideIcons.lock, size: 18),
                suffixIcon: IconButton(tooltip: show ? 'Hide password' : 'Show password', icon: Icon(show ? LucideIcons.eyeOff : LucideIcons.eye, size: 18), onPressed: onToggleShow),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter your password';
                if (mode == AuthMode.register && v.length < 8) return 'Use at least 8 characters';
                return null;
              },
              onFieldSubmitted: (_) => canSubmit ? onSubmit() : null,
            ),
          ],
          if (mode == AuthMode.register) ...[
            const SizedBox(height: 10),
            _StrengthMeter(controller: password),
            const SizedBox(height: 14),
            TextFormField(
              controller: confirm,
              obscureText: !show,
              decoration: const InputDecoration(labelText: 'Confirm password', prefixIcon: Icon(LucideIcons.shieldCheck, size: 18)),
              validator: (v) => v != password.text ? 'Passwords don\'t match' : null,
            ),
          ],
          if (mode == AuthMode.login)
            Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => onMode(AuthMode.forgot), child: const Text('Forgot password?'))),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: canSubmit ? onSubmit : null,
              child: auth.busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : Text(cta),
            ),
          ),
          if (mode == AuthMode.login || mode == AuthMode.register) ...[
            const SizedBox(height: 14),
            Center(
              child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(mode == AuthMode.login ? 'New here?' : 'Already have an account?', style: TextStyle(color: t.colorScheme.onSurfaceVariant)),
                TextButton(onPressed: () => onMode(mode == AuthMode.login ? AuthMode.register : AuthMode.login), child: Text(mode == AuthMode.login ? 'Create an account' : 'Sign in')),
              ]),
            ),
            Row(children: [const Expanded(child: Divider()), Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('or', style: TextStyle(color: t.colorScheme.onSurfaceVariant))), const Expanded(child: Divider())]),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(onPressed: () => ref.read(authProvider.notifier).enterDemo(), icon: const Icon(LucideIcons.flaskConical, size: 16), label: const Text('Explore with sample data')),
            ),
            const SizedBox(height: 8),
            Text('Sample mode keeps everything on this device and isn\'t linked to an account.', textAlign: TextAlign.center, style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          ],
        ]),
      ),
    ).animate().fadeIn(duration: 450.ms).slideY(begin: 0.04, end: 0, curve: Curves.easeOutCubic);
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.3))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4))),
        ]),
      );
}

class _StrengthMeter extends StatelessWidget {
  const _StrengthMeter({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final s = passwordStrength(controller.text);
          final label = ['Enter a password', 'Too weak', 'Fair', 'Good', 'Strong'][s];
          final color = [AppColors.warning, AppColors.expense, AppColors.warning, const Color(0xFF84CC16), AppColors.income][s];
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AnimatedProgress(value: s / 4, color: color, height: 6),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
          ]);
        },
      );
}
