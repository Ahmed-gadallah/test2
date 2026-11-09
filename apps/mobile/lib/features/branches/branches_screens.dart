import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/clipboard/copy_text.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/ui_kit.dart';

/// Branch Locator — "فروع زاد | Our Branches".
/// All data comes from the backend branch directory (active branches only); nothing is hardcoded.
/// Calls open the dialer with the number filled in (tel:), they never place the call.
/// Locations open the exact Google Maps link supplied for the branch — never a derived location.
class BranchesScreen extends ConsumerStatefulWidget {
  const BranchesScreen({super.key});
  @override
  ConsumerState<BranchesScreen> createState() => _BranchesScreenState();
}

class _BranchesScreenState extends ConsumerState<BranchesScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Scaffold(
      appBar: PageHeader(t.branchesTitle),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(ZaadSpace.page, ZaadSpace.xs, ZaadSpace.page, ZaadSpace.sm),
            child: TextField(
              key: const Key('branch-search'),
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: t.branchesSearchHint,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: t.clearSearch,
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(() {
                          _search.clear();
                          _query = '';
                        }),
                      ),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(branchesProvider),
              child: AsyncBody(
                value: ref.watch(branchesProvider),
                onRetry: () => ref.invalidate(branchesProvider),
                loading: ListView(
                  padding: const EdgeInsets.all(ZaadSpace.page),
                  children: const [SkeletonCard(), SizedBox(height: 12), SkeletonCard(), SizedBox(height: 12), SkeletonCard()],
                ),
                builder: (all) {
                  if (all.isEmpty) {
                    return ListView(children: [const SizedBox(height: 60), EmptyView(icon: Icons.storefront_outlined, text: t.branchesEmpty)]);
                  }
                  final list = _query.trim().isEmpty ? all : all.where((b) => b.matches(_query)).toList();
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(ZaadSpace.page, 0, ZaadSpace.page, ZaadSpace.xl),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: list.length + 1,
                    separatorBuilder: (_, i) => SizedBox(height: i == 0 ? 4 : 12),
                    itemBuilder: (_, i) {
                      if (i == 0) {
                        return list.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.only(top: 48),
                                child: EmptyView(icon: Icons.search_off_rounded, text: t.branchesNoResults),
                              )
                            : Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(t.branchesCount(list.length), style: const TextStyle(color: ZaadColors.textMuted, fontSize: 13)),
                              );
                      }
                      return BranchCard(list[i - 1]);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BranchCard extends StatelessWidget {
  final Branch b;
  const BranchCard(this.b, {super.key});
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final ar = context.ar;
    final extra = b.extraAddress(ar);
    final maps = b.mapsUri;
    final tel = b.telUri;
    return SurfaceCard(
      key: Key('branch-${b.id}'),
      onTap: () => context.push('/branches/${b.id}'),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const IconTile(Icons.storefront_rounded, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.name(ar), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, height: 1.3)),
                    const SizedBox(height: 2),
                    Text(b.place(), style: const TextStyle(color: ZaadColors.textMuted, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          if (extra != null) ...[
            const SizedBox(height: 10),
            _Line(icon: Icons.place_outlined, text: extra),
          ],
          const SizedBox(height: 6),
          tel == null
              ? _Line(icon: Icons.phone_disabled_outlined, text: t.phoneUnavailable, muted: true)
              : _Line(icon: Icons.phone_outlined, text: context.fmt.mobile(b.phone!), ltr: true),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: maps == null
                    ? Container(
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: ZaadColors.border.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12)),
                        child: Text(t.locationUnavailable, style: const TextStyle(color: ZaadColors.textMuted, fontSize: 13)),
                      )
                    : ExternalLink(
                        uri: maps,
                        builder: (open) => OutlinedButton.icon(
                          key: Key('view-location-${b.id}'),
                          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                          onPressed: open,
                          icon: const Icon(Icons.map_outlined, size: 18),
                          label: Text(t.viewLocation),
                        ),
                      ),
              ),
              if (tel != null) ...[
                const SizedBox(width: 10),
                PhoneAction(
                  b,
                  builder: (open) => IconButton.filledTonal(
                    key: Key('call-${b.id}'),
                    tooltip: t.callBranch,
                    onPressed: open,
                    icon: const Icon(Icons.call_rounded),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool ltr;
  final bool muted;
  const _Line({required this.icon, required this.text, this.ltr = false, this.muted = false});
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 18, color: ZaadColors.textMuted),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              textDirection: ltr ? TextDirection.ltr : null,
              style: TextStyle(fontSize: 14, color: muted ? ZaadColors.textMuted : ZaadColors.text),
            ),
          ),
        ],
      );
}

class BranchDetailScreen extends ConsumerWidget {
  final int id;
  const BranchDetailScreen({super.key, required this.id});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    return Scaffold(
      appBar: AppBar(title: Text(t.branchesTitle)),
      body: AsyncBody(
        value: ref.watch(branchesProvider),
        onRetry: () => ref.invalidate(branchesProvider),
        builder: (all) {
          final b = all.where((x) => x.id == id).firstOrNull;
          if (b == null) return EmptyView(icon: Icons.storefront_outlined, text: t.errNotFound);
          return _BranchDetail(b);
        },
      ),
    );
  }
}

class _BranchDetail extends StatelessWidget {
  final Branch b;
  const _BranchDetail(this.b);
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final ar = context.ar;
    final tel = b.telUri;
    final maps = b.mapsUri;
    final hasDistinctDistrict = b.district != null && b.district != b.city;
    return ListView(
      padding: const EdgeInsets.fromLTRB(ZaadSpace.page, 0, ZaadSpace.page, ZaadSpace.xl),
      children: [
        FadeSlideIn(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: ZaadGradients.hero, borderRadius: BorderRadius.circular(ZaadSpace.radius), boxShadow: ZaadShadows.card),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.name(ar), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20, height: 1.3)),
                      const SizedBox(height: 4),
                      Text(b.place(), style: const TextStyle(color: ZaadColors.onBlueMuted, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: ZaadSpace.lg),
        // Only the actions that exist are shown; what is missing is stated in the details below.
        if (tel != null || maps != null)
          FadeSlideIn(
            index: 1,
            child: Row(
              children: [
                if (tel != null)
                  Expanded(
                    child: PhoneAction(
                      b,
                      builder: (open) => FilledButton.icon(key: const Key('call-branch'), onPressed: open, icon: const Icon(Icons.call_rounded), label: Text(t.callBranch)),
                    ),
                  ),
                if (tel != null && maps != null) const SizedBox(width: 12),
                if (maps != null)
                  Expanded(
                    child: ExternalLink(
                      uri: maps,
                      builder: (open) => (tel == null ? FilledButton.icon : OutlinedButton.icon)(
                        key: const Key('get-directions'),
                        onPressed: open,
                        icon: const Icon(Icons.directions_rounded),
                        label: Text(t.getDirections),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: ZaadSpace.lg),
        FadeSlideIn(
          index: 2,
          child: InfoGroup(children: [
            InfoRow(icon: Icons.place_outlined, title: t.branchAddress, subtitle: b.address(ar)),
            InfoRow(icon: Icons.location_city_rounded, title: t.branchCity, subtitle: b.city),
            if (hasDistinctDistrict) InfoRow(icon: Icons.map_outlined, title: t.branchDistrict, subtitle: b.district),
            tel == null
                ? InfoRow(icon: Icons.phone_disabled_outlined, title: t.branchPhone, subtitle: t.phoneUnavailable)
                : PhoneAction(
                    b,
                    builder: (open) => InfoRow(
                      icon: Icons.phone_outlined,
                      title: t.branchPhone,
                      subtitle: t.branchPhoneHint,
                      value: context.fmt.mobile(b.phone!),
                      ltrValue: true,
                      onTap: open,
                      trailing: CopyNumberButton(b.phone!),
                    ),
                  ),
            if (maps == null) InfoRow(icon: Icons.location_off_outlined, title: t.branchLocation, subtitle: t.locationUnavailable),
            if (b.notes != null) InfoRow(icon: Icons.info_outline_rounded, title: t.branchNotes, subtitle: b.notes),
          ]),
        ),
      ],
    );
  }
}

/// "Call branch". In the app: opens the phone's dialer with the number filled in (tel:, never auto-calls).
/// In a browser, tel: is unreliable — mobile browsers block it from embedded pages such as the shared
/// demo link — so the web build opens a sheet with the number, a Copy button and a call attempt.
class PhoneAction extends StatelessWidget {
  /// Overridable in tests; true for web builds.
  static bool useCallSheet = kIsWeb;
  final Branch b;
  final Widget Function(VoidCallback? open) builder;
  const PhoneAction(this.b, {super.key, required this.builder});
  @override
  Widget build(BuildContext context) {
    final tel = b.telUri;
    if (tel == null) return builder(null);
    if (!useCallSheet) return ExternalLink(uri: tel, builder: builder);
    return builder(() => showCallSheet(context, b));
  }
}

Future<void> showCallSheet(BuildContext context, Branch b) {
  final t = context.t;
  final number = context.fmt.mobile(b.phone!);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(ZaadSpace.page, 0, ZaadSpace.page, ZaadSpace.lg),
        child: Column(
          key: const Key('call-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(b.name(context.ar), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            SelectableText(number, textAlign: TextAlign.center, textDirection: TextDirection.ltr,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: ZaadColors.primary, letterSpacing: 1)),
            const SizedBox(height: 4),
            Text(t.callFromBrowserNote, textAlign: TextAlign.center, style: const TextStyle(color: ZaadColors.textMuted, fontSize: 13)),
            const SizedBox(height: ZaadSpace.lg),
            FilledButton.icon(
              key: const Key('copy-number'),
              onPressed: () => _copy(sheet, b.phone!, closeSheet: true),
              icon: const Icon(Icons.copy_rounded),
              label: Text(t.copyNumber),
            ),
            const SizedBox(height: 10),
            ExternalLink(
              uri: b.telUri!,
              builder: (open) => OutlinedButton.icon(onPressed: open, icon: const Icon(Icons.call_rounded), label: Text(t.callBranch)),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Copies the number as the dialer expects it (05XXXXXXXX for Saudi numbers).
Future<void> _copy(BuildContext context, String phone, {bool closeSheet = false}) async {
  final t = context.t;
  final messenger = ScaffoldMessenger.of(context);
  final local = phone.startsWith('+966') ? '0${phone.substring(4)}' : phone;
  final ok = await copyText(local);
  if (ok && closeSheet && context.mounted) Navigator.of(context).pop();
  messenger.showSnackBar(SnackBar(content: Text(ok ? t.numberCopied : t.copyFailed)));
}

class CopyNumberButton extends StatelessWidget {
  final String phone;
  const CopyNumberButton(this.phone, {super.key});
  @override
  Widget build(BuildContext context) => IconButton(
        key: const Key('copy-phone'),
        tooltip: context.t.copyNumber,
        visualDensity: VisualDensity.compact,
        onPressed: () => _copy(context, phone),
        icon: const Icon(Icons.copy_rounded, size: 20, color: ZaadColors.textMuted),
      );
}
