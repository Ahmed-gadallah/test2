import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/error_text.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../home/home_screen.dart';

/// Read-only profile (spec §7). No editing in the MVP.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileState();
}

class _ProfileState extends ConsumerState<ProfileScreen> {
  bool _outage = false;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final f = context.fmt;
    final lang = ref.watch(localeProvider).languageCode;
    final bioAvailable = ref.watch(biometricAvailableProvider).value ?? false;
    final bio = ref.watch(biometricProvider);
    final api = ref.read(apiProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.profileTitle), automaticallyImplyLeading: false),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        AsyncBody(
          value: ref.watch(profileProvider),
          onRetry: () => ref.invalidate(profileProvider),
          builder: (p) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                const CircleAvatar(radius: 32, backgroundColor: ZaadColors.primarySoft, child: Icon(Icons.person_rounded, size: 36, color: ZaadColors.primary)),
                const SizedBox(height: 12),
                KeyValueRow(t.fullName, p.name?.trim().isNotEmpty == true ? p.name!.trim() : '—'),
                KeyValueRow(t.mobileNumber, f.mobile(p.mobileNumber), ltr: true),
                KeyValueRow(t.customerId, p.customerId),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: ZaadColors.textMuted),
                  const SizedBox(width: 6),
                  Expanded(child: Text(t.profileReadOnly, style: const TextStyle(color: ZaadColors.textMuted, fontSize: 12))),
                ]),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SectionTitle(t.settings),
        Card(
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.language_rounded),
              title: Text(t.language),
              trailing: SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [ButtonSegment(value: 'ar', label: Text('العربية')), ButtonSegment(value: 'en', label: Text('English'))],
                selected: {lang},
                onSelectionChanged: (s) => ref.read(localeProvider.notifier).set(s.first),
              ),
            ),
            const Divider(indent: 16, endIndent: 16),
            SwitchListTile(
              secondary: const Icon(Icons.fingerprint_rounded),
              title: Text(t.biometricUnlock),
              subtitle: bioAvailable ? null : Text(t.biometricUnavailable, style: const TextStyle(fontSize: 12)),
              value: bio && bioAvailable,
              onChanged: bioAvailable ? (v) => ref.read(biometricProvider.notifier).set(v) : null,
            ),
            const Divider(indent: 16, endIndent: 16),
            ListTile(leading: const Icon(Icons.shopping_bag_outlined), title: Text(t.shopOnline), trailing: const Icon(Icons.open_in_new_rounded, size: 18), onTap: openOnlineStore),
            const Divider(indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: ZaadColors.danger),
              title: Text(t.logout, style: const TextStyle(color: ZaadColors.danger)),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(content: Text(t.logoutConfirm), actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t.cancel)),
                    TextButton(onPressed: () => Navigator.pop(c, true), child: Text(t.logout)),
                  ]),
                );
                if (ok == true) await ref.read(sessionProvider.notifier).logout();
              },
            ),
          ]),
        ),
        if (AppConfig.demoTools) ...[
          const SizedBox(height: 16),
          SectionTitle(t.demoTools),
          Card(
            color: ZaadColors.warningSoft,
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.point_of_sale_rounded, color: ZaadColors.warning),
                title: Text(t.simulateCashier),
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
              SwitchListTile(
                secondary: const Icon(Icons.cloud_off_rounded, color: ZaadColors.warning),
                title: Text(t.simulateOutage),
                value: _outage,
                onChanged: (v) async {
                  await api.simulateErpOutage(v);
                  setState(() => _outage = v);
                  ref.invalidate(pointsProvider);
                },
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}
