import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../core/error_text.dart';
import '../../core/theme.dart';
import '../../data/api.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/ui_kit.dart';

/// Carries state between auth steps.
class AuthFlow {
  final String mobile;
  final String purpose; // register | reset_password
  final String? verificationToken;
  final int resendAfter;
  const AuthFlow(this.mobile, this.purpose, {this.verificationToken, this.resendAfter = 60});
}

class _AuthScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  const _AuthScaffold({required this.title, this.subtitle, required this.children});
  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: AppBar(backgroundColor: Colors.transparent),
    body: DecoratedBox(
      decoration: const BoxDecoration(gradient: ZaadGradients.wash),
      child: SafeArea(
        child: Column(
          children: [
            const DemoBanner(),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: [
                      FadeSlideIn(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: ZaadShadows.card),
                            child: const BrandMark(size: 72),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      FadeSlideIn(
                        index: 1,
                        child: Column(
                          children: [
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                subtitle!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: ZaadColors.textMuted, fontSize: 15, height: 1.5),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      FadeSlideIn(
                        index: 2,
                        child: SurfaceCard(
                          radius: 24,
                          padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ErrorBox extends StatelessWidget {
  final String? text;
  const _ErrorBox(this.text);
  @override
  Widget build(BuildContext context) => text == null
      ? const SizedBox.shrink()
      : ShakeIn(
          key: ValueKey(text),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: ZaadColors.dangerSoft, borderRadius: BorderRadius.circular(12)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline_rounded, color: ZaadColors.danger, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(text!, style: const TextStyle(color: ZaadColors.danger, height: 1.5)),
                ),
              ],
            ),
          ),
        );
}

class _Busy extends StatelessWidget {
  final bool busy;
  final String label;
  final VoidCallback? onPressed;
  const _Busy({required this.busy, required this.label, required this.onPressed});
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy ? null : onPressed,
    child: busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : Text(label),
  );
}

Widget _mobileField(BuildContext context, TextEditingController c, {bool autofocus = true}) => TextField(
  controller: c,
  autofocus: autofocus,
  keyboardType: TextInputType.phone,
  textDirection: TextDirection.ltr,
  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+٠-٩ ]')), LengthLimitingTextInputFormatter(16)],
  decoration: InputDecoration(labelText: context.t.mobileNumber, hintText: context.t.mobileHint, prefixIcon: const Icon(Icons.phone_iphone_rounded)),
);

// ── Register: mobile + consent ─────────────────────────────────────────────
class RegisterMobileScreen extends ConsumerStatefulWidget {
  final String purpose;
  const RegisterMobileScreen({super.key, this.purpose = 'register'});
  @override
  ConsumerState<RegisterMobileScreen> createState() => _RegisterMobileState();
}

class _RegisterMobileState extends ConsumerState<RegisterMobileScreen> {
  final _mobile = TextEditingController(text: AppConfig.isDemo ? '0500000001' : '');
  bool _consent = false, _busy = false;
  String? _error;
  bool get _reset => widget.purpose == 'reset_password';

  Future<void> _submit() async {
    final t = context.t;
    if (!_reset && !_consent) return setState(() => _error = t.privacyRequired);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final info = await ref.read(apiProvider).sendOtp(_mobile.text, widget.purpose);
      if (mounted) context.push('/otp', extra: AuthFlow(_mobile.text, widget.purpose, resendAfter: info.resendAfterSeconds));
    } catch (e) {
      setState(() => _error = errorText(t, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return _AuthScaffold(
      title: _reset ? t.resetPasswordTitle : t.registerTitle,
      subtitle: t.registerSubtitle,
      children: [
        _ErrorBox(_error),
        _mobileField(context, _mobile),
        if (!_reset) ...[
          const SizedBox(height: 16),
          CheckboxListTile(
            value: _consent,
            onChanged: (v) => setState(() => _consent = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: Text(t.privacyConsent, style: const TextStyle(fontSize: 13, height: 1.5)),
          ),
        ],
        const SizedBox(height: 20),
        _Busy(busy: _busy, label: t.continueLabel, onPressed: _submit),
        if (AppConfig.isDemo) ...[
          const SizedBox(height: 16),
          const Text(
            '0500000001 · 0500000002 · 0500000003 · 0500000004 · 0599999999',
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            style: TextStyle(color: ZaadColors.textMuted, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

// ── OTP ────────────────────────────────────────────────────────────────────
class OtpScreen extends ConsumerStatefulWidget {
  final AuthFlow flow;
  const OtpScreen({super.key, required this.flow});
  @override
  ConsumerState<OtpScreen> createState() => _OtpState();
}

class _OtpState extends ConsumerState<OtpScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;
  late int _left = widget.flow.resendAfter;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (tm) {
      if (_left <= 0) return tm.cancel();
      setState(() => _left--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.text.length != 6) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final token = await ref.read(apiProvider).verifyOtp(widget.flow.mobile, widget.flow.purpose, _code.text);
      if (mounted) context.pushReplacement('/password', extra: AuthFlow(widget.flow.mobile, widget.flow.purpose, verificationToken: token));
    } catch (e) {
      setState(() => _error = errorText(context.t, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    try {
      final info = await ref.read(apiProvider).sendOtp(widget.flow.mobile, widget.flow.purpose);
      setState(() {
        _left = info.resendAfterSeconds;
        _error = null;
      });
      _startTimer();
    } catch (e) {
      setState(() => _error = errorText(context.t, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return _AuthScaffold(
      title: t.otpTitle,
      subtitle: t.otpSubtitle(widget.flow.mobile),
      children: [
        _ErrorBox(_error),
        TextField(
          controller: _code,
          autofocus: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          maxLength: 6,
          style: const TextStyle(fontSize: 28, letterSpacing: 12, fontWeight: FontWeight.w600),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (v) => v.length == 6 ? _verify() : null,
          decoration: const InputDecoration(counterText: '', hintText: '••••••'),
        ),
        if (AppConfig.isDemo)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              t.otpDemoHint,
              textAlign: TextAlign.center,
              style: const TextStyle(color: ZaadColors.textMuted),
            ),
          ),
        const SizedBox(height: 20),
        _Busy(busy: _busy, label: t.verify, onPressed: _verify),
        const SizedBox(height: 8),
        TextButton(onPressed: _left > 0 ? null : _resend, child: Text(_left > 0 ? t.resendIn(_left) : t.resendCode)),
      ],
    );
  }
}

// ── Create / reset password ────────────────────────────────────────────────
class PasswordScreen extends ConsumerStatefulWidget {
  final AuthFlow flow;
  const PasswordScreen({super.key, required this.flow});
  @override
  ConsumerState<PasswordScreen> createState() => _PasswordState();
}

class _PasswordState extends ConsumerState<PasswordScreen> {
  final _p1 = TextEditingController(), _p2 = TextEditingController();
  bool _busy = false, _obscure = true;
  String? _error;
  static final _rule = RegExp(r'^(?=.*[A-Za-z؀-ۿ])(?=.*\d).{8,128}$');

  Future<void> _submit() async {
    final t = context.t;
    if (!_rule.hasMatch(_p1.text)) return setState(() => _error = t.passwordRule);
    if (_p1.text != _p2.text) return setState(() => _error = t.passwordsDontMatch);
    setState(() {
      _busy = true;
      _error = null;
    });
    final api = ref.read(apiProvider);
    try {
      if (widget.flow.purpose == 'register') {
        final tokens = await api.register(widget.flow.verificationToken!, _p1.text, ref.read(localeProvider).languageCode);
        await ref.read(sessionProvider.notifier).signedIn(tokens, widget.flow.mobile);
        if (mounted) context.go('/home');
      } else {
        await api.resetPassword(widget.flow.verificationToken!, _p1.text);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.passwordUpdated)));
        context.go('/login');
      }
    } catch (e) {
      setState(() => _error = errorText(t, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final eye = IconButton(icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => _obscure = !_obscure));
    return _AuthScaffold(
      title: widget.flow.purpose == 'register' ? t.createPasswordTitle : t.resetPasswordTitle,
      subtitle: t.createPasswordSubtitle,
      children: [
        _ErrorBox(_error),
        TextField(
          controller: _p1,
          obscureText: _obscure,
          autofocus: true,
          decoration: InputDecoration(labelText: widget.flow.purpose == 'register' ? t.password : t.newPassword, suffixIcon: eye),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _p2,
          obscureText: _obscure,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(labelText: t.confirmPassword),
        ),
        const SizedBox(height: 24),
        _Busy(busy: _busy, label: t.continueLabel, onPressed: _submit),
      ],
    );
  }
}

// ── Login ──────────────────────────────────────────────────────────────────
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginState();
}

class _LoginState extends ConsumerState<LoginScreen> {
  final _mobile = TextEditingController(text: AppConfig.isDemo ? '0500000001' : '');
  final _password = TextEditingController(text: AppConfig.isDemo ? 'zaad1234' : '');
  bool _busy = false, _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (!AppConfig.isDemo) ref.read(tokenStoreProvider).lastMobile().then((m) => m != null && mounted ? _mobile.text = m : null);
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final tokens = await ref.read(apiProvider).login(_mobile.text, _password.text);
      await ref.read(sessionProvider.notifier).signedIn(tokens, _mobile.text);
      if (mounted) context.go('/home');
    } on ApiFailure catch (e) {
      setState(() => _error = errorText(context.t, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return _AuthScaffold(
      title: t.login,
      children: [
        _ErrorBox(_error),
        _mobileField(context, _mobile, autofocus: false),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: _obscure,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: t.password,
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => _obscure = !_obscure)),
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(onPressed: () => context.push('/forgot'), child: Text(t.forgotPassword)),
        ),
        const SizedBox(height: 8),
        _Busy(busy: _busy, label: t.login, onPressed: _submit),
        const SizedBox(height: 12),
        TextButton(onPressed: () => context.push('/register'), child: Text(t.createAccount)),
      ],
    );
  }
}

// ── Biometric unlock of an existing session ────────────────────────────────
class UnlockScreen extends ConsumerStatefulWidget {
  const UnlockScreen({super.key});
  @override
  ConsumerState<UnlockScreen> createState() => _UnlockState();
}

class _UnlockState extends ConsumerState<UnlockScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() => ref.read(sessionProvider.notifier).unlock(context.t.unlockTitle);

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DecoratedBox(
      decoration: const BoxDecoration(gradient: ZaadGradients.wash),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FadeSlideIn(
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: ZaadShadows.card),
                    child: const BrandMark(size: 96),
                  ),
                ),
                const SizedBox(height: 32),
                const Icon(Icons.fingerprint_rounded, size: 72, color: ZaadColors.primary),
                const SizedBox(height: 24),
                FilledButton(onPressed: _unlock, child: Text(context.t.unlockAction)),
                TextButton(onPressed: () => ref.read(sessionProvider.notifier).logout(), child: Text(context.t.logout)),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
