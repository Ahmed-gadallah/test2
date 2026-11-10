import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/error_text.dart';
import '../../core/theme.dart';
import '../../data/api.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/ui_kit.dart';

/// Approval screen for a cashier-initiated redemption (spec §10.1). The app
/// sends the decision; the ERP validates the live balance and finalizes.
class RedemptionScreen extends ConsumerStatefulWidget {
  final String id;
  const RedemptionScreen({super.key, required this.id});
  @override
  ConsumerState<RedemptionScreen> createState() => _RedemptionState();
}

class _RedemptionState extends ConsumerState<RedemptionScreen> {
  Timer? _tick;
  bool _busy = false;
  Redemption? _result;
  String? _message;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// Extra confirmation with the device lock (biometric or passcode) before approving (spec §10.3).
  /// Only "this device has no lock at all" falls back to in-app approval; every other failure
  /// (cancel, lockout, timeout, error) means NOT approved.
  Future<bool> _confirmWithDevice() async {
    if (kIsWeb) return true;
    final reason = context.t.confirmRedemptionReason;
    final la = LocalAuthentication();
    try {
      if (!await la.isDeviceSupported()) return true;
      return await la.authenticate(localizedReason: reason);
    } on LocalAuthException catch (e) {
      return switch (e.code) {
        LocalAuthExceptionCode.noCredentialsSet || LocalAuthExceptionCode.noBiometricHardware => true,
        _ => false,
      };
    } catch (_) {
      return false;
    }
  }

  Future<void> _decide(bool approve) async {
    final t = context.t;
    if (!approve) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(t.rejectConfirmTitle),
          content: Text(t.rejectConfirmBody),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t.cancel)),
            TextButton(onPressed: () => Navigator.pop(c, true), style: TextButton.styleFrom(foregroundColor: ZaadColors.danger), child: Text(t.rejectRequest)),
          ],
        ),
      );
      if (ok != true) return;
    } else if (!await _confirmWithDevice()) {
      return;
    }
    setState(() { _busy = true; _message = null; });
    try {
      final r = await ref.read(apiProvider).decideRedemption(widget.id, approve);
      setState(() => _result = r);
      ref.invalidate(pointsProvider);
      ref.invalidate(notificationsProvider);
      ref.invalidate(pendingRedemptionsProvider);
    } on ApiFailure catch (e) {
      setState(() => _message = errorText(t, e));
      ref.invalidate(redemptionProvider(widget.id));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final async = ref.watch(redemptionProvider(widget.id));
    return Scaffold(
      appBar: AppBar(title: Text(t.redemptionTitle)),
      body: Column(children: [
        const DemoBanner(),
        Expanded(
          child: AsyncBody(
            value: async,
            onRetry: () => ref.invalidate(redemptionProvider(widget.id)),
            builder: (fetched) {
              final r = _result ?? fetched;
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: ListView(padding: const EdgeInsets.all(20), children: [
                    if (r.status != RedemptionStatus.pending || r.customerDecision != null || !r.expiresAt.isAfter(DateTime.now()))
                      _Outcome(r)
                    else
                      _RequestCard(r),
                    if (_message != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: ZaadColors.warningSoft, borderRadius: BorderRadius.circular(12)),
                        child: Text(_message!, style: const TextStyle(height: 1.5)),
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (r.isActionable && _result == null) ...[
                      FilledButton.icon(
                        onPressed: _busy ? null : () => _decide(true),
                        icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_rounded),
                        label: Text(t.confirmRedemption),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : () => _decide(false),
                        style: OutlinedButton.styleFrom(foregroundColor: ZaadColors.danger),
                        icon: const Icon(Icons.close_rounded),
                        label: Text(t.rejectRequest),
                      ),
                    ] else
                      FilledButton(onPressed: () => context.canPop() ? context.pop() : context.go('/home'), child: Text(t.done)),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final Redemption r;
  const _RequestCard(this.r);
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final f = context.fmt;
    final left = r.expiresAt.difference(DateTime.now());
    final urgent = left.inSeconds <= 30;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(color: ZaadColors.primarySoft, shape: BoxShape.circle),
            child: const Icon(Icons.point_of_sale_rounded, color: ZaadColors.primary, size: 32),
          ),
          const SizedBox(height: 16),
          Text(f.sar(r.discountAmount), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: ZaadColors.primary)),
          Text(t.discountValue, style: const TextStyle(color: ZaadColors.textMuted)),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 8),
          KeyValueRow(t.branch, r.branchName),
          KeyValueRow(t.pointsToRedeem, f.number(r.points), bold: true),
          KeyValueRow(t.reference, r.reference),
          KeyValueRow(t.expiresIn, f.countdown(left), bold: true, valueColor: urgent ? ZaadColors.danger : null),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (left.inSeconds / 120).clamp(0, 1).toDouble(),
              minHeight: 4,
              color: urgent ? ZaadColors.danger : ZaadColors.primary,
              backgroundColor: ZaadColors.border,
            ),
          ),
        ]),
      ),
    );
  }
}

class _Outcome extends StatelessWidget {
  final Redemption r;
  const _Outcome(this.r);
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final f = context.fmt;
    final expired = r.status == RedemptionStatus.expired || (r.status == RedemptionStatus.pending && r.customerDecision == null);
    final (icon, color, bg, title, body) = switch (r.status) {
      RedemptionStatus.completed => (Icons.check_circle_rounded, ZaadColors.success, ZaadColors.successSoft, t.redemptionCompleted, t.redemptionCompletedBody(f.number(r.points), f.sar(r.discountAmount))),
      RedemptionStatus.rejected => (Icons.cancel_rounded, ZaadColors.textMuted, ZaadColors.background, t.redemptionRejected, t.redemptionRejectedBody),
      RedemptionStatus.failed => (Icons.error_rounded, ZaadColors.danger, ZaadColors.dangerSoft, t.redemptionRejected, t.redemptionFailed),
      _ when expired => (Icons.timer_off_rounded, ZaadColors.warning, ZaadColors.warningSoft, t.redemptionExpired, t.redemptionRejectedBody),
      _ => (Icons.hourglass_top_rounded, ZaadColors.warning, ZaadColors.warningSoft, t.redemptionPending, ''),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          StatusBadge(icon: icon, color: color, background: bg),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          if (body.isNotEmpty) ...[const SizedBox(height: 8), Text(body, textAlign: TextAlign.center, style: const TextStyle(color: ZaadColors.textMuted, height: 1.5))],
          const SizedBox(height: 16),
          const Divider(),
          KeyValueRow(t.branch, r.branchName),
          KeyValueRow(t.reference, r.reference),
        ]),
      ),
    );
  }
}
