import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/error_text.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/ui_kit.dart';
import '../home/home_screen.dart';

/// Read-only profile (spec §7). No editing in the MVP.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileState();
}

class _ProfileState extends ConsumerState<ProfileScreen> {
  bool _outage = false;

  String _initials(String? name) {
    final parts = (name ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty && !RegExp(r'^\d+$').hasMatch(p)).toList();
    if (parts.isEmpty) return '';
    // One letter: two joined Arabic letters read as a word (e.g. "مع").
    return parts.first.characters.first.toUpperCase();
  }

  Future<void> _logout() async {
    final t = context.t;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(content: Text(t.logoutConfirm), actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t.cancel)),
        TextButton(onPressed: () => Navigator.pop(c, true), style: TextButton.styleFrom(foregroundColor: ZaadColors.danger), child: Text(t.logout)),
      ]),
    );
    if (ok == true) await ref.read(sessionProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final f = context.fmt;
    final lang = ref.watch(localeProvider).languageCode;
    final bioAvailable = ref.watch(biometricAvailableProvider).value ?? false;
    final bio = ref.watch(biometricProvider);
    final api = ref.read(apiProvider);

    return Scaffold(
      appBar: PageHeader(t.profileTitle),
      body: ListView(padding: const EdgeInsets.fromLTRB(ZaadSpace.page, 4, ZaadSpace.page, ZaadSpace.xl), children: [
        FadeSlideIn(
          child: AsyncBody(
            value: ref.watch(profileProvider),
            onRetry: () => ref.invalidate(profileProvider),
            loading: const SkeletonCard(),
            builder: (p) {
              final initials = _initials(p.name);
              return Column(children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(gradient: ZaadGradients.hero, borderRadius: BorderRadius.circular(ZaadSpace.radiusXl), boxShadow: ZaadShadows.raised),
                  child: Row(children: [
                    Container(
                      width: 60,
                      height: 60,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle, border: Border.all(color: Colors.white38)),
                      child: initials.isEmpty
                          ? const Icon(Icons.person_rounded, color: Colors.white, size: 32)
                          : Text(initials, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.name?.trim().isNotEmpty == true ? p.name!.trim() : '—',
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(f.mobile(p.mobileNumber), textDirection: TextDirection.ltr, style: const TextStyle(color: Color(0xCCFFFFFF))),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: ZaadSpace.md),
                InfoGroup(children: [
                  InfoRow(icon: Icons.badge_outlined, title: t.customerId, value: p.customerId, ltrValue: true),
                  InfoRow(icon: Icons.phone_iphone_rounded, title: t.mobileNumber, value: f.mobile(p.mobileNumber), ltrValue: true),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: ZaadColors.textMuted),
                  const SizedBox(width: 6),
                  Expanded(child: Text(t.profileReadOnly, style: const TextStyle(color: ZaadColors.textMuted, fontSize: 12))),
                ]),
              ]);
            },
          ),
        ),
        const SizedBox(height: ZaadSpace.lg),
        FadeSlideIn(index: 1, child: SectionHeader(t.settings)),
        FadeSlideIn(
          index: 2,
          child: InfoGroup(children: [
            InfoRow(
              icon: Icons.language_rounded,
              title: t.language,
              trailing: SegmentedButton<String>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: const [ButtonSegment(value: 'ar', label: Text('العربية')), ButtonSegment(value: 'en', label: Text('English'))],
                selected: {lang},
                onSelectionChanged: (s) => ref.read(localeProvider.notifier).set(s.first),
              ),
            ),
            InfoRow(
              icon: Icons.fingerprint_rounded,
              title: t.biometricUnlock,
              subtitle: bioAvailable ? null : t.biometricUnavailable,
              trailing: Switch(value: bio && bioAvailable, onChanged: bioAvailable ? (v) => ref.read(biometricProvider.notifier).set(v) : null),
            ),
            InfoRow(icon: Icons.shopping_bag_outlined, title: t.shopOnline, trailing: const Icon(Icons.open_in_new_rounded, size: 20, color: ZaadColors.textMuted), onTap: openOnlineStore),
            InfoRow(icon: Icons.logout_rounded, title: t.logout, color: ZaadColors.danger, trailing: const SizedBox.shrink(), onTap: _logout),
          ]),
        ),
        if (AppConfig.demoTools) ...[
          const SizedBox(height: ZaadSpace.lg),
          SectionHeader(t.demoTools),
          InfoGroup(children: [
            InfoRow(
              icon: Icons.point_of_sale_rounded,
              title: t.simulateCashier,
              color: ZaadColors.warning,
              trailing: const SizedBox.shrink(),
              onTap: () async {
                final m = ScaffoldMessenger.of(context);
                try {
                  final p = await ref.read(profileProvider.future);
                  await api.simulateCashierRedemption(p.mobileNumber, 1000);
                  ref.invalidate(pendingRedemptionsProvider);
                  ref.invalidate(notificationsProvider);
                  m.showSnackBar(const SnackBar(content: Text('✓')));
                } catch (e) {
                  if (context.mounted) m.showSnackBar(SnackBar(content: Text(errorText(t, e))));
                }
              },
            ),
            InfoRow(
              icon: Icons.cloud_off_rounded,
              title: t.simulateOutage,
              color: ZaadColors.warning,
              trailing: Switch(
                value: _outage,
                onChanged: (v) async {
                  await api.simulateErpOutage(v);
                  setState(() => _outage = v);
                  ref.invalidate(pointsProvider);
                },
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}
