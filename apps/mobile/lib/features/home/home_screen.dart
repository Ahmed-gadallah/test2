import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/ui_kit.dart';
import '../offers/offers_screens.dart';

const onlineStoreUrl = 'https://zaadonline.com';

final onlineStoreUri = Uri.parse(onlineStoreUrl);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final pending =
        ref.watch(pendingRedemptionsProvider).value ?? const <Redemption>[];

    Future<void> refresh() async {
      ref.invalidate(pointsProvider);
      ref.invalidate(offersProvider);
      ref.invalidate(notificationsProvider);
      ref.invalidate(profileProvider);
      // Wait for the balance to settle; errors are rendered by the card itself.
      await ref.read(pointsProvider.future).then((_) {}, onError: (_) {});
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: refresh,
          edgeOffset: 80,
          child: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: _HeaderWithCard()),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  ZaadSpace.page,
                  ZaadSpace.lg,
                  ZaadSpace.page,
                  ZaadSpace.xl,
                ),
                sliver: SliverList.list(
                  children: [
                    for (final r in pending.where((r) => r.isActionable)) ...[
                      FadeSlideIn(child: PendingRedemptionBanner(r)),
                      const SizedBox(height: ZaadSpace.lg),
                    ],
                    FadeSlideIn(index: 1, child: SectionHeader(t.quickActions)),
                    const FadeSlideIn(index: 2, child: _QuickActions()),
                    const SizedBox(height: ZaadSpace.md),
                    const FadeSlideIn(index: 3, child: ShopOnlineCard()),
                    const SizedBox(height: ZaadSpace.md),
                    const FadeSlideIn(index: 3, child: BranchesEntryCard()),
                    const SizedBox(height: ZaadSpace.lg),
                    FadeSlideIn(
                      index: 4,
                      child: SectionHeader(
                        t.latestOffers,
                        actionLabel: t.seeAll,
                        onAction: () => context.go('/offers'),
                      ),
                    ),
                    const FadeSlideIn(index: 5, child: OffersCarousel()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Blue header (logo, notifications, settings, greeting) with the points card overlapping its lower edge.
class _HeaderWithCard extends ConsumerWidget {
  const _HeaderWithCard();
  static const _overlap = 72.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final name = ref.watch(profileProvider).value?.name?.trim();
    return Stack(
      children: [
        Positioned.fill(
          bottom: _overlap,
          child: Container(
            decoration: const BoxDecoration(
              gradient: ZaadGradients.header,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(ZaadSpace.radiusXl + 4),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            // Two soft circles give depth without decoration noise (matches the reference direction).
            child: Stack(
              children: [
                PositionedDirectional(
                  top: -90,
                  end: -70,
                  child: _Glow(size: 260, alpha: 0.07),
                ),
                PositionedDirectional(
                  bottom: -60,
                  start: -80,
                  child: _Glow(size: 200, alpha: 0.05),
                ),
              ],
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              ZaadSpace.page,
              ZaadSpace.sm,
              ZaadSpace.page,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const BrandMark(size: 52),
                    const Spacer(),
                    NotificationBell(
                      onTap: () => context.push('/notifications'),
                    ),
                    IconButton(
                      onPressed: () => context.go('/profile'),
                      tooltip: t.settings,
                      icon: const Icon(
                        Icons.settings_outlined,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ZaadSpace.md),
                Text(
                  // ERP names are cashier-typed; greet neutrally when empty (assessment G4).
                  name == null || name.isEmpty
                      ? '${t.helloNoName} 👋'
                      : '${t.hello(name)} 👋',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: ZaadSpace.lg + 2),
                const FadeSlideIn(child: PointsCard()),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  final double size;
  final double alpha;
  const _Glow({required this.size, required this.alpha});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: alpha),
    ),
  );
}

/// The hero loyalty card. Every number comes from the ERP via the API; the app only formats it.
class PointsCard extends ConsumerWidget {
  const PointsCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final f = context.fmt;
    final points = ref.watch(pointsProvider);
    const muted = TextStyle(color: Color(0xCCFFFFFF), fontSize: 13);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: ZaadGradients.hero,
        borderRadius: BorderRadius.circular(ZaadSpace.radiusXl),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        boxShadow: ZaadShadows.raised,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Logo watermark (official artwork, low opacity).
          PositionedDirectional(
            end: -18,
            top: 14,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.10,
                child: Image.asset(
                  'assets/brand/zaad_logo.png',
                  width: 170,
                  height: 170,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
            child: switch (points) {
              AsyncData(:final value) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.stars_rounded,
                          color: ZaadColors.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        t.availablePoints,
                        style: muted.copyWith(fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      // Animate between balances (e.g. after a redemption) — display only.
                      TweenAnimationBuilder<double>(
                        tween: Tween(end: value.points.toDouble()),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, _) => Text(
                          f.number(v.round()),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 44,
                            fontWeight: FontWeight.w700,
                            height: 1.05,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        t.pointsUnit,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      t.equivalentValue(f.sar(value.equivalentSar)),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Divider(
                    color: Colors.white.withValues(alpha: 0.16),
                    height: 1,
                  ),
                  const SizedBox(height: 12),
                  // Wraps onto two lines on narrow screens instead of truncating.
                  Wrap(
                    spacing: 16,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.sync_alt_rounded,
                            color: Color(0xCCFFFFFF),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            t.rateExplanation(value.pointsPerSar),
                            style: muted,
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            color: Color(0xCCFFFFFF),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(t.updatedAt(f.time(value.asOf)), style: muted),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              AsyncError() => SizedBox(
                height: 150,
                child: Row(
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      color: Colors.white70,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    // Never show a stale/fake balance as current (spec §21).
                    Expanded(
                      child: Text(
                        t.errErpUnavailable,
                        style: const TextStyle(
                          color: Colors.white,
                          height: 1.5,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => ref.invalidate(pointsProvider),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                      ),
                      child: Text(t.retry),
                    ),
                  ],
                ),
              ),
              _ => const _PointsCardSkeleton(),
            },
          ),
        ],
      ),
    );
  }
}

class _PointsCardSkeleton extends StatelessWidget {
  const _PointsCardSkeleton();
  @override
  Widget build(BuildContext context) {
    Widget bar(double w, double h) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        bar(130, 16),
        const SizedBox(height: 14),
        bar(180, 40),
        const SizedBox(height: 14),
        bar(150, 28),
        const SizedBox(height: 22),
        bar(double.infinity, 14),
      ],
    );
  }
}

class PendingRedemptionBanner extends StatelessWidget {
  final Redemption r;
  const PendingRedemptionBanner(this.r, {super.key});
  @override
  Widget build(BuildContext context) {
    final f = context.fmt;
    return Pressable(
      onTap: () => context.push('/redemption/${r.id}'),
      decoration: BoxDecoration(
        color: ZaadColors.warningSoft,
        borderRadius: BorderRadius.circular(ZaadSpace.radius),
        border: Border.all(color: const Color(0xFFF3D9A4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ZaadSpace.lg),
        child: Row(
          children: [
            const IconTile(
              Icons.point_of_sale_rounded,
              bg: Colors.white,
              fg: ZaadColors.warning,
            ),
            const SizedBox(width: ZaadSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t.pendingRedemptionBanner,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${f.number(r.points)} ${context.t.pointsUnit} · ${f.sar(r.discountAmount)}',
                    style: const TextStyle(
                      color: ZaadColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onPressed: () => context.push('/redemption/${r.id}'),
              child: Text(context.t.pendingRedemptionAction),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final items = [
      (Icons.receipt_long_rounded, t.myInvoices, () => context.go('/invoices')),
      (Icons.stars_rounded, t.myPoints, () => context.push('/points')),
      (Icons.local_offer_rounded, t.offers, () => context.go('/offers')),
      (Icons.person_rounded, t.myProfile, () => context.go('/profile')),
    ];
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: ZaadSpace.md - 2),
          Expanded(
            child: QuickActionCard(
              icon: items[i].$1,
              label: items[i].$2,
              onTap: items[i].$3,
            ),
          ),
        ],
      ],
    );
  }
}

class QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const QuickActionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => SurfaceCard(
    onTap: onTap,
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
    child: Column(
      children: [
        IconTile(icon, size: 50),
        const SizedBox(height: 10),
        // Scales down slightly rather than truncating long labels (e.g. "My invoices" on small phones).
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Entry to the Branch Locator (فروع زاد).
class BranchesEntryCard extends StatelessWidget {
  const BranchesEntryCard({super.key});
  @override
  Widget build(BuildContext context) => SurfaceCard(
    key: const Key('branches-entry'),
    onTap: () => context.push('/branches'),
    padding: const EdgeInsets.all(14),
    child: Row(
      children: [
        const IconTile(Icons.storefront_rounded, size: 56),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.t.branchesTitle, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 2),
              Text(context.t.branchesHomeSubtitle, style: const TextStyle(color: ZaadColors.textMuted, fontSize: 13)),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: ZaadColors.textMuted),
      ],
    ),
  );
}

/// External link to the existing store (spec §14). No loyalty claims.
class ShopOnlineCard extends StatelessWidget {
  const ShopOnlineCard({super.key});
  @override
  Widget build(BuildContext context) => ExternalLink(
    uri: onlineStoreUri,
    builder: (open) => SurfaceCard(
      onTap: open,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: ZaadGradients.hero,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.shopping_bag_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t.shopOnline,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'zaadonline.com',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(color: ZaadColors.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: ZaadColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.open_in_new_rounded,
              size: 20,
              color: ZaadColors.primary,
            ),
          ),
        ],
      ),
    ),
  );
}
