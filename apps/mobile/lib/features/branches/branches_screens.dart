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
      body: Column(
        children: [
          GradientHeader(
            bottomPadding: 44,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.branchesTitle, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700, height: 1.25)),
                      const SizedBox(height: 4),
                      Text(t.branchesHomeSubtitle, style: const TextStyle(color: ZaadColors.onBlueMuted, fontSize: 13)),
                    ],
                  ),
                ),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                  ),
                  child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 30),
                ),
              ],
            ),
          ),
          // Search floats over the header's lower edge.
          Transform.translate(
            offset: const Offset(0, -26),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: ZaadSpace.page),
              child: ZaadSearchField(
                fieldKey: const Key('branch-search'),
                controller: _search,
                hint: t.branchesSearchHint,
                onChanged: (v) => setState(() => _query = v),
                clearTooltip: t.clearSearch,
                onClear: _query.isEmpty
                    ? null
                    : () => setState(() {
                          _search.clear();
                          _query = '';
                        }),
              ),
            ),
          ),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -14),
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(branchesProvider),
                child: AsyncBody(
                  value: ref.watch(branchesProvider),
                  onRetry: () => ref.invalidate(branchesProvider),
                  loading: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: ZaadSpace.page),
                    children: const [SkeletonCard(), SizedBox(height: 12), SkeletonCard(), SizedBox(height: 12), SkeletonCard()],
                  ),
                  builder: (all) {
                    if (all.isEmpty) {
                      return ListView(children: [const SizedBox(height: 40), EmptyView(icon: Icons.storefront_outlined, text: t.branchesEmpty)]);
                    }
                    final list = _query.trim().isEmpty ? all : all.where((b) => b.matches(_query)).toList();
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(ZaadSpace.page, 0, ZaadSpace.page, ZaadSpace.xl),
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: list.length + 1,
                      separatorBuilder: (_, i) => SizedBox(height: i == 0 ? 6 : 14),
                      itemBuilder: (_, i) {
                        if (i == 0) {
                          return list.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 40),
                                  child: EmptyView(icon: Icons.search_off_rounded, text: t.branchesNoResults),
                                )
                              : Row(children: [
                                  const Icon(Icons.storefront_outlined, size: 16, color: ZaadColors.textMuted),
                                  const SizedBox(width: 6),
                                  Text(t.branchesCount(list.length), style: const TextStyle(color: ZaadColors.textMuted, fontSize: 13, fontWeight: FontWeight.w500)),
                                ]);
                        }
                        return FadeSlideIn(index: i - 1, child: BranchCard(list[i - 1]));
                      },
                    );
                  },
                ),
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
      radius: 24,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BrandThumb(width: 84, height: 84, iconSize: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(b.name(ar), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, height: 1.3))),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(color: ZaadColors.background, shape: BoxShape.circle),
                        child: const Icon(Icons.chevron_right_rounded, size: 20, color: ZaadColors.textMuted),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    _Line(icon: Icons.location_city_rounded, text: b.place(), muted: true),
                    if (extra != null) ...[
                      const SizedBox(height: 4),
                      _Line(icon: Icons.place_outlined, text: extra, muted: true),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: tel == null
                    ? _Pill(icon: Icons.phone_disabled_outlined, label: t.noPhoneShort, muted: true)
                    : PhoneAction(
                        b,
                        builder: (open) => _Pill(
                          key: Key('call-${b.id}'),
                          icon: Icons.call_rounded,
                          label: context.fmt.mobile(b.phone!),
                          ltr: true,
                          tooltip: t.callBranch,
                          onTap: open,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: maps == null
                    ? _Pill(icon: Icons.location_off_outlined, label: t.noLocationShort, muted: true)
                    : ExternalLink(
                        uri: maps,
                        builder: (open) => _Pill(
                          key: Key('view-location-${b.id}'),
                          icon: Icons.map_outlined,
                          label: t.viewLocation,
                          filled: true,
                          onTap: open,
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small rounded action used on branch cards (call / view location).
class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool filled;
  final bool muted;
  final bool ltr;
  final String? tooltip;
  const _Pill({super.key, required this.icon, required this.label, this.onTap, this.filled = false, this.muted = false, this.ltr = false, this.tooltip});
  @override
  Widget build(BuildContext context) {
    final fg = muted ? ZaadColors.textMuted : ZaadColors.primary;
    final body = Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: muted ? ZaadColors.background : (filled ? ZaadColors.primarySoft : Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: muted || filled ? Colors.transparent : ZaadColors.border),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 18, color: fg),
        const SizedBox(width: 6),
        Flexible(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection: ltr ? TextDirection.ltr : null,
              style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: muted ? 12 : 14)),
        ),
      ]),
    );
    if (onTap == null) return body;
    final pill = Pressable(onTap: onTap, borderRadius: BorderRadius.circular(14), child: body);
    return tooltip == null ? pill : Tooltip(message: tooltip!, child: pill);
  }
}

class _Line extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool muted;
  const _Line({required this.icon, required this.text, this.muted = false});
  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, size: 16, color: ZaadColors.textMuted)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, height: 1.4, color: muted ? ZaadColors.textMuted : ZaadColors.text),
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: AsyncBody(
        value: ref.watch(branchesProvider),
        onRetry: () => ref.invalidate(branchesProvider),
        builder: (all) {
          final b = all.where((x) => x.id == id).firstOrNull;
          if (b == null) return SafeArea(child: EmptyView(icon: Icons.storefront_outlined, text: t.errNotFound));
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
      padding: EdgeInsets.zero,
      children: [
        // Branded hero (no invented photography): gradient, light and the storefront mark.
        Container(
          height: 230,
          decoration: const BoxDecoration(
            gradient: ZaadGradients.hero,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(ZaadSpace.radiusXl + 4)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(alignment: Alignment.center, children: [
            const PositionedDirectional(top: -80, end: -60, child: SoftGlow(size: 260, alpha: 0.12)),
            const PositionedDirectional(bottom: -90, start: -60, child: SoftGlow(size: 220, alpha: 0.08)),
            PositionedDirectional(
              bottom: -30,
              end: -20,
              child: Opacity(opacity: 0.10, child: Image.asset('assets/brand/zaad_logo.png', width: 190, height: 190)),
            ),
            FadeSlideIn(
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                ),
                child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 44),
              ),
            ),
          ]),
        ),
        Transform.translate(
          offset: const Offset(0, -40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: ZaadSpace.page),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FadeSlideIn(
                  index: 1,
                  child: SurfaceCard(
                    radius: 24,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          const Icon(Icons.location_on_rounded, color: ZaadColors.primary, size: 24),
                          const SizedBox(width: 8),
                          Expanded(child: Text(b.name(ar), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20, height: 1.3))),
                        ]),
                        const SizedBox(height: 8),
                        _Line(icon: Icons.location_city_rounded, text: b.place(), muted: true),
                        const SizedBox(height: 4),
                        _Line(icon: Icons.place_outlined, text: b.address(ar), muted: true),
                        // Only the actions that exist are shown; what is missing is stated below.
                        if (tel != null) ...[
                          const SizedBox(height: 18),
                          PhoneAction(
                            b,
                            builder: (open) => FilledButton.icon(key: const Key('call-branch'), onPressed: open, icon: const Icon(Icons.call_rounded), label: Text(t.callBranch)),
                          ),
                        ],
                        if (maps != null) ...[
                          SizedBox(height: tel == null ? 18 : 10),
                          ExternalLink(
                            uri: maps,
                            builder: (open) => (tel == null ? FilledButton.icon : OutlinedButton.icon)(
                              key: const Key('get-directions'),
                              onPressed: open,
                              icon: const Icon(Icons.directions_rounded),
                              label: Text(t.getDirections),
                            ),
                          ),
                        ],
                      ],
                    ),
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
                if (maps != null) ...[
                  const SizedBox(height: ZaadSpace.lg),
                  // Illustration only (not the real surroundings); tapping opens the branch's own link.
                  FadeSlideIn(
                    index: 3,
                    child: ExternalLink(
                      uri: maps,
                      builder: (open) => SurfaceCard(
                        radius: 24,
                        padding: EdgeInsets.zero,
                        onTap: open,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Column(children: [
                            const MapIllustration(height: 150),
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(children: [
                                const Icon(Icons.open_in_new_rounded, size: 18, color: ZaadColors.primary),
                                const SizedBox(width: 8),
                                Expanded(child: Text(t.openInGoogleMaps, style: const TextStyle(color: ZaadColors.primary, fontWeight: FontWeight.w600))),
                              ]),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// "Call branch". In the app: opens the phone's dialer with the number filled in (tel:, never auto-calls).
/// In a browser, tel: is unreliable — mobile browsers block it from embedded pages such as the shared
/// demo link — so the web build opens a sheet with the number and a Copy button (no dead Call button).
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
    useRootNavigator: true, // so [linkGuard] sees it and disables the web links underneath
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
