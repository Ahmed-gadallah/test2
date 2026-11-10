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
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: DecoratedBox(
          // Light blue wash behind the header fading into the page background.
          decoration: const BoxDecoration(gradient: ZaadGradients.wash),
          child: RefreshIndicator(
            onRefresh: refresh,
            child: CustomScrollView(
              slivers: [
                SliverSafeArea(
                  bottom: false,
                  sliver: SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      ZaadSpace.page,
                      ZaadSpace.sm,
                      ZaadSpace.page,
                      ZaadSpace.xl,
                    ),
                    sliver: SliverList.list(
                      children: [
                        const _HomeHeader(),
                        const SizedBox(height: ZaadSpace.lg + 2),
                        FadeSlideIn(
                          child: PointsCard(
                            onTap: () => context.push('/points'),
                          ),
                        ),
                        const SizedBox(height: ZaadSpace.lg),
                        for (final r in pending.where((r) => r.isActionable)) ...[
                          FadeSlideIn(index: 1, child: PendingRedemptionBanner(r)),
                          const SizedBox(height: ZaadSpace.lg),
                        ],
                        FadeSlideIn(index: 1, child: SectionHeader(t.quickActions)),
                        const _QuickActions(),
                        const SizedBox(height: ZaadSpace.lg),
                        FadeSlideIn(
                          index: 5,
                          child: SectionHeader(
                            t.latestOffers,
                            actionLabel: t.seeAll,
                            onAction: () => context.go('/offers'),
                          ),
                        ),
                        const FadeSlideIn(index: 6, child: OffersCarousel()),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Clean light header: official logo, greeting, notifications and settings.
class _HomeHeader extends ConsumerWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final name = ref.watch(profileProvider).value?.name?.trim();
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: ZaadShadows.soft,
          ),
          child: const BrandMark(size: 46),
        ),
        const SizedBox(width: ZaadSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                // ERP names are cashier-typed; greet neutrally when empty (assessment G4).
                name == null || name.isEmpty
                    ? '${t.helloNoName} 👋'
                    : '${t.hello(name)} 👋',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: ZaadColors.text,
                ),
              ),
              Text(
                t.appName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: ZaadColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        _CircleAction(
          child: NotificationBell(
            color: ZaadColors.text,
            onTap: () => context.push('/notifications'),
          ),
        ),
        const SizedBox(width: ZaadSpace.sm),
        _CircleAction(
          child: IconButton(
            onPressed: () => context.go('/profile'),
            tooltip: t.settings,
            icon: const Icon(
              Icons.settings_outlined,
              color: ZaadColors.text,
              size: 24,
            ),
          ),
        ),
      ],
    );
  }
}

class _CircleAction extends StatelessWidget {
  final Widget child;
  const _CircleAction({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    width: 46,
    height: 46,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      boxShadow: ZaadShadows.soft,
    ),
    child: child,
  );
}

/// The hero loyalty card. Every number comes from the ERP via the API; the app only formats it.
class PointsCard extends ConsumerWidget {
  /// Home opens the points history; the points screen shows the card without a tap action.
  final VoidCallback? onTap;
  const PointsCard({super.key, this.onTap});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final f = context.fmt;
    final points = ref.watch(pointsProvider);
    const muted = TextStyle(color: Color(0xCCFFFFFF), fontSize: 13);

    final radius = BorderRadius.circular(ZaadSpace.radiusXl);
    final card = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: ZaadGradients.hero,
        borderRadius: radius,
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        boxShadow: ZaadShadows.glow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Lighting: a soft highlight from the top corner and a low glow — depth without noise.
          const PositionedDirectional(top: -120, start: -80, child: SoftGlow(size: 300, alpha: 0.12)),
          const PositionedDirectional(bottom: -90, end: -40, child: SoftGlow(size: 200, alpha: 0.08)),
          // Logo watermark (official artwork, low opacity).
          PositionedDirectional(
            end: -18,
            bottom: -24,
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
                      // Counts up on load and between balances — display only, value from the ERP.
                      AnimatedCount(
                        value.points,
                        format: f.number,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 46,
                          fontWeight: FontWeight.w700,
                          height: 1.05,
                          letterSpacing: -0.5,
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
          if (onTap != null && points.hasValue)
            PositionedDirectional(
              top: 18,
              end: 18,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), shape: BoxShape.circle),
                child: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 20),
              ),
            ),
        ],
      ),
    );
    if (onTap == null) return card;
    return Pressable(onTap: onTap, borderRadius: radius, child: card);
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

/// Quick actions as a 3×2 grid of icon cards. Same destinations as before
/// (invoices, points, offers, profile, shop online, branches).
class _QuickActions extends StatelessWidget {
  const _QuickActions();
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final items = <Widget>[
      QuickActionCard(icon: Icons.receipt_long_rounded, label: t.myInvoices, onTap: () => context.go('/invoices')),
      QuickActionCard(icon: Icons.stars_rounded, label: t.myPoints, onTap: () => context.push('/points')),
      QuickActionCard(icon: Icons.local_offer_rounded, label: t.offers, onTap: () => context.go('/offers')),
      QuickActionCard(icon: Icons.storefront_rounded, label: t.branchesTitle, onTap: () => context.go('/branches')),
      ExternalLink(
        uri: onlineStoreUri,
        builder: (open) => QuickActionCard(icon: Icons.shopping_bag_rounded, label: t.shopOnline, onTap: open ?? () {}, external: true),
      ),
      QuickActionCard(icon: Icons.person_rounded, label: t.myProfile, onTap: () => context.go('/profile')),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        const gap = ZaadSpace.md;
        final w = (c.maxWidth - gap * 2) / 3;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < items.length; i++)
              SizedBox(width: w, child: FadeSlideIn(index: 2 + i ~/ 3, child: items[i])),
          ],
        );
      },
    );
  }
}

class QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool external;
  const QuickActionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.external = false,
  });
  @override
  Widget build(BuildContext context) => SurfaceCard(
    onTap: onTap,
    padding: const EdgeInsets.fromLTRB(6, 16, 6, 14),
    child: Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEEEFFF), ZaadColors.primarySoft],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: ZaadColors.primary, size: 27),
            ),
            if (external)
              const PositionedDirectional(
                top: -4,
                end: -6,
                child: CircleAvatar(
                  radius: 9,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.north_east_rounded, size: 12, color: ZaadColors.primary),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        // Scales down slightly rather than truncating long labels on small phones.
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
