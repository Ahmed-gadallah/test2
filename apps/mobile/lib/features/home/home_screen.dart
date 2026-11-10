import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/illustrations.dart';
import '../../widgets/ui_kit.dart';
import '../offers/offers_screens.dart';

const onlineStoreUrl = 'https://zaadonline.com';

final onlineStoreUri = Uri.parse(onlineStoreUrl);

/// Home. Every value shown comes from the existing providers (ERP via the API); this screen only
/// arranges and animates it. Destinations are unchanged.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final pending = ref.watch(pendingRedemptionsProvider).value ?? const <Redemption>[];

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
        body: Stack(
          children: [
            // Light blue wash with one soft diagonal light band behind the header.
            const Positioned.fill(
              child: DecoratedBox(decoration: BoxDecoration(gradient: ZaadGradients.wash)),
            ),
            const PositionedDirectional(top: -140, start: -120, child: _BackdropLight()),
            RefreshIndicator(
              onRefresh: refresh,
              child: CustomScrollView(
                slivers: [
                  SliverSafeArea(
                    bottom: false,
                    sliver: SliverPadding(
                      padding: const EdgeInsets.fromLTRB(ZaadSpace.page, ZaadSpace.sm, ZaadSpace.page, ZaadSpace.xl),
                      sliver: SliverList.list(
                        children: [
                          const FadeSlideIn(offset: -14, child: _HomeHeader()),
                          const SizedBox(height: ZaadSpace.lg + 2),
                          FadeSlideIn(index: 1, offset: 24, child: PointsCard(onTap: () => context.push('/points'))),
                          const SizedBox(height: ZaadSpace.lg),
                          for (final r in pending.where((r) => r.isActionable)) ...[
                            FadeSlideIn(index: 2, child: PendingRedemptionBanner(r)),
                            const SizedBox(height: ZaadSpace.lg),
                          ],
                          FadeSlideIn(
                            index: 2,
                            child: SectionHeader(
                              t.quickActions,
                              leading: const Icon(Icons.bolt_rounded, color: ZaadColors.gold, size: 24),
                            ),
                          ),
                          const _QuickActions(),
                          const SizedBox(height: ZaadSpace.xl - 4),
                          const FadeSlideIn(index: 5, child: PromoCarousel()),
                          const SizedBox(height: ZaadSpace.lg),
                          FadeSlideIn(
                            index: 6,
                            child: SectionHeader(
                              t.latestOffers,
                              leading: const Icon(Icons.card_giftcard_rounded, color: ZaadColors.primary, size: 22),
                              actionLabel: t.seeAll,
                              onAction: () => context.go('/offers'),
                            ),
                          ),
                          const FadeSlideIn(index: 7, child: LatestOffersStrip()),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackdropLight extends StatelessWidget {
  const _BackdropLight();
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: 420,
      height: 420,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [ZaadColors.electric.withValues(alpha: 0.14), ZaadColors.electric.withValues(alpha: 0)],
        ),
      ),
    ),
  );
}

/// Header: official logo tile, greeting, notifications (live badge) and settings.
class _HomeHeader extends ConsumerWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final name = ref.watch(profileProvider).value?.name?.trim();
    return Row(
      children: [
        Container(
          width: 58,
          height: 58,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: ZaadShadows.card,
          ),
          child: const BrandMark(size: 50),
        ),
        const SizedBox(width: ZaadSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Shrinks to fit instead of cutting the name; very long names still end with "…".
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Text(
                    // ERP names are cashier-typed; greet neutrally when empty (assessment G4).
                    name == null || name.isEmpty ? '${t.helloNoName} 👋' : '${t.hello(name)} 👋',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: ZaadColors.navy,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
              Text(
                t.appName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: ZaadColors.textMuted),
              ),
            ],
          ),
        ),
        _CircleAction(
          child: NotificationBell(color: ZaadColors.primary, onTap: () => context.push('/notifications')),
        ),
        const SizedBox(width: ZaadSpace.sm),
        _CircleAction(
          child: IconButton(
            onPressed: () => context.go('/profile'),
            tooltip: t.settings,
            icon: const Icon(Icons.settings_outlined, color: ZaadColors.primary, size: 24),
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
    width: 48,
    height: 48,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const LinearGradient(
        colors: [Colors.white, Color(0xFFF1F3FF)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      border: Border.all(color: Colors.white),
      boxShadow: ZaadShadows.card,
    ),
    child: child,
  );
}

/// The hero loyalty card. Every number comes from the ERP via the API; the app only formats it.
class PointsCard extends ConsumerWidget {
  /// Home opens the points history ("More"); the points screen shows the card without it.
  final VoidCallback? onTap;
  const PointsCard({super.key, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final f = context.fmt;
    final points = ref.watch(pointsProvider);
    final radius = BorderRadius.circular(ZaadSpace.radiusXl + 4);
    const muted = TextStyle(color: Color(0xDDFFFFFF), fontSize: 13);

    final content = switch (points) {
      AsyncData(:final value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _GlassPill(
                      leading: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.star_rounded, color: ZaadColors.primary, size: 15),
                      ),
                      label: t.availablePoints,
                    ),
                    const SizedBox(height: 12),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          // Counts up on load and between balances — display only, value from the ERP.
                          AnimatedCount(
                            value.points,
                            format: f.number,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 48,
                              fontWeight: FontWeight.w800,
                              height: 1.05,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            t.pointsUnit,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _GlassPill(
                      leading: const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 18),
                      label: t.equivalentValue(f.sar(value.equivalentSar)),
                      bold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              LoyaltyArt(size: MediaQuery.sizeOf(context).width < 380 ? 108 : 128),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.18), height: 1),
          const SizedBox(height: 12),
          // Rate · last update · More — scales down on narrow phones instead of wrapping.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Row(
              children: [
                const Icon(Icons.hourglass_empty_rounded, color: Color(0xDDFFFFFF), size: 16),
                const SizedBox(width: 5),
                Text(t.rateExplanation(value.pointsPerSar), style: muted),
                const _VDivider(),
                const Icon(Icons.schedule_rounded, color: Color(0xDDFFFFFF), size: 16),
                const SizedBox(width: 5),
                Text(t.updatedAt(f.time(value.asOf)), style: muted),
                if (onTap != null) ...[
                  const _VDivider(),
                  Text(
                    t.more,
                    style: muted.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 18),
                ],
              ],
            ),
          ),
        ],
      ),
      AsyncError() => SizedBox(
        height: 150,
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.white70, size: 28),
            const SizedBox(width: 12),
            // Never show a stale/fake balance as current (spec §21).
            Expanded(
              child: Text(t.errErpUnavailable, style: const TextStyle(color: Colors.white, height: 1.5)),
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
    };

    final card = LightSweep(
      borderRadius: radius,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: ZaadGradients.loyalty,
          borderRadius: radius,
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          boxShadow: ZaadShadows.glow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Depth: glass sheen at the top, a cool glow behind the art, a darker floor.
            const PositionedDirectional(top: -110, start: -60, child: SoftGlow(size: 280, alpha: 0.12)),
            PositionedDirectional(
              bottom: -60,
              end: -40,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF7D8CFF).withValues(alpha: 0.35),
                      const Color(0xFF7D8CFF).withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 70,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.white.withValues(alpha: 0.10), Colors.white.withValues(alpha: 0)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 14), child: content),
          ],
        ),
      ),
    );
    if (onTap == null) return card;
    return Pressable(onTap: onTap, borderRadius: radius, child: card);
  }
}

/// Frosted pill on the blue card (label chips).
class _GlassPill extends StatelessWidget {
  final Widget leading;
  final String label;
  final bool bold;
  const _GlassPill({required this.leading, required this.label, this.bold = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.fromSTEB(6, 6, 14, 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        leading,
        const SizedBox(width: 8),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: bold ? FontWeight.w700 : FontWeight.w500),
            ),
          ),
        ),
      ],
    ),
  );
}

class _VDivider extends StatelessWidget {
  const _VDivider();
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 18,
    margin: const EdgeInsets.symmetric(horizontal: 12),
    color: Colors.white.withValues(alpha: 0.25),
  );
}

class _PointsCardSkeleton extends StatelessWidget {
  const _PointsCardSkeleton();
  @override
  Widget build(BuildContext context) {
    Widget bar(double w, double h) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
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
            const IconTile(Icons.point_of_sale_rounded, bg: Colors.white, fg: ZaadColors.warning),
            const SizedBox(width: ZaadSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.t.pendingRedemptionBanner, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    '${f.number(r.points)} ${context.t.pointsUnit} · ${f.sar(r.discountAmount)}',
                    style: const TextStyle(color: ZaadColors.textMuted, fontSize: 13),
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

/// Quick actions: the same six destinations as before, as premium cards in a 3×2 grid.
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
        builder: (open) => QuickActionCard(
          icon: Icons.shopping_bag_rounded,
          label: t.shopOnline,
          onTap: open ?? () {},
          external: true,
        ),
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
              // Staggered entrance, one card after another.
              SizedBox(
                width: w,
                child: FadeSlideIn(index: 2 + i, child: items[i]),
              ),
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

  static final _radius = BorderRadius.circular(24);
  static final _decoration = BoxDecoration(
    borderRadius: _radius,
    gradient: const LinearGradient(
      colors: [Colors.white, Color(0xFFF4F5FF)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    border: Border.all(color: Colors.white, width: 1.2),
    boxShadow: ZaadShadows.card,
  );
  // Pressed: the card scales down slightly while its shadow deepens (lift effect).
  static final _pressed = _decoration.copyWith(boxShadow: ZaadShadows.raised);

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    borderRadius: _radius,
    decoration: _decoration,
    pressedDecoration: _pressed,
    semanticLabel: label,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(10, 16, 10, 12),
      child: Column(
        children: [
          // Glossy icon bubble.
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    center: Alignment(-0.35, -0.45),
                    radius: 0.95,
                    colors: [Colors.white, Color(0xFFE4E7FF)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: ZaadColors.primary.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ShaderMask(
                  shaderCallback: (r) => ZaadGradients.active.createShader(r),
                  child: Icon(icon, color: Colors.white, size: 30),
                ),
              ),
              if (external)
                PositionedDirectional(
                  top: -2,
                  end: -4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: ZaadShadows.soft,
                    ),
                    child: const Icon(Icons.north_east_rounded, size: 11, color: ZaadColors.primary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ZaadColors.navy),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Small gold directional indicator.
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: ZaadColors.goldSoft),
                child: const Icon(Icons.chevron_right_rounded, size: 16, color: ZaadColors.goldDeep),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Promotional banners = the offers published from the admin dashboard (dynamic, never hardcoded).
/// Swipe between them; indicators appear only when there is more than one.
class PromoCarousel extends ConsumerStatefulWidget {
  const PromoCarousel({super.key});
  @override
  ConsumerState<PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends ConsumerState<PromoCarousel> {
  final _page = PageController();
  int _index = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AsyncBody(
      value: ref.watch(offersProvider),
      onRetry: () => ref.invalidate(offersProvider),
      loading: const Skeleton(height: 150, radius: 26),
      builder: (list) {
        if (list.isEmpty) return const SizedBox.shrink(); // the offers section below shows the empty state
        final banners = list.take(5).toList();
        return Column(
          children: [
            SizedBox(
              height: 156,
              child: PageView.builder(
                controller: _page,
                itemCount: banners.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => AnimatedBuilder(
                  animation: _page,
                  builder: (context, child) {
                    double page = _index.toDouble();
                    if (_page.hasClients && _page.position.haveDimensions) page = _page.page ?? page;
                    final d = (page - i).abs().clamp(0.0, 1.0);
                    return Opacity(
                      opacity: 1 - 0.35 * d,
                      child: Transform.scale(scale: 1 - 0.04 * d, child: child),
                    );
                  },
                  child: _PromoBanner(banners[i]),
                ),
              ),
            ),
            if (banners.length > 1) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < banners.length; i++)
                    AnimatedContainer(
                      duration: ZaadMotion.base,
                      curve: ZaadMotion.curve,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _index ? 22 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        gradient: i == _index ? ZaadGradients.active : null,
                        color: i == _index ? null : const Color(0xFFD3D6F0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _PromoBanner extends StatelessWidget {
  final Offer o;
  const _PromoBanner(this.o);
  @override
  Widget build(BuildContext context) {
    final ar = context.ar;
    final radius = BorderRadius.circular(26);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Pressable(
        onTap: () => context.push('/offers/${o.id}'),
        borderRadius: radius,
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: const LinearGradient(
            colors: [Color(0xFFFFFDF7), Color(0xFFFFF6E3)],
            begin: AlignmentDirectional.centerStart,
            end: AlignmentDirectional.centerEnd,
          ),
          border: Border.all(color: Colors.white, width: 1.2),
          boxShadow: ZaadShadows.card,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            children: [
              // Blue wave on the end side holding the art.
              Positioned.fill(
                child: CustomPaint(painter: _WavePainter(rtl: Directionality.of(context) == TextDirection.rtl)),
              ),
              PositionedDirectional(
                end: 10,
                top: 10,
                bottom: 10,
                child: SizedBox(
                  width: 130,
                  child: o.imageUrl == null
                      ? const Center(child: ShoppingBagArt(size: 124))
                      : Center(child: OfferImage(o, height: 120, radius: 18)),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(18, 16, 160, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      o.title(ar),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ZaadColors.navy,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      o.description(ar),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: ZaadColors.textMuted, fontSize: 12.5),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsetsDirectional.fromSTEB(14, 7, 8, 7),
                      decoration: BoxDecoration(
                        gradient: ZaadGradients.gold,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: ZaadColors.goldDeep.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              context.t.discoverNow,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: ZaadColors.navy, fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.chevron_right_rounded, color: ZaadColors.navy, size: 18),
                        ],
                      ),
                    ),
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

/// Royal-blue shape with a soft S-curve edge, on the end side of the promo banner.
class _WavePainter extends CustomPainter {
  final bool rtl;
  _WavePainter({required this.rtl});
  @override
  void paint(Canvas canvas, Size size) {
    if (rtl) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    final w = size.width, h = size.height;
    final x0 = w * 0.56;
    final path = Path()
      ..moveTo(x0 + 40, 0)
      ..cubicTo(x0 - 10, h * 0.3, x0 + 50, h * 0.65, x0 - 6, h)
      ..lineTo(w, h)
      ..lineTo(w, 0)
      ..close();
    final rect = Rect.fromLTWH(x0 - 10, 0, w - x0 + 10, h);
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          colors: [ZaadColors.electric, ZaadColors.primary, Color(0xFF12169A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect),
    );
    // A thin light edge along the curve.
    canvas.drawPath(
      Path()
        ..moveTo(x0 + 40, 0)
        ..cubicTo(x0 - 10, h * 0.3, x0 + 50, h * 0.65, x0 - 6, h),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) => old.rtl != rtl;
}

/// "Latest offers": horizontally scrolling offer cards (all offers from the API).
class LatestOffersStrip extends ConsumerWidget {
  const LatestOffersStrip({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncBody(
      value: ref.watch(offersProvider),
      onRetry: () => ref.invalidate(offersProvider),
      loading: const Skeleton(height: 200, radius: 22),
      builder: (list) {
        if (list.isEmpty) {
          return SurfaceCard(
            child: EmptyView(icon: Icons.local_offer_outlined, text: context.t.noOffers),
          );
        }
        return SizedBox(
          height: 214,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) => FadeSlideIn(index: i, child: _OfferCard(list[i])),
          ),
        );
      },
    );
  }
}

class _OfferCard extends StatelessWidget {
  final Offer o;
  const _OfferCard(this.o);
  @override
  Widget build(BuildContext context) {
    final ar = context.ar;
    final radius = BorderRadius.circular(22);
    final deco = BoxDecoration(
      color: Colors.white,
      borderRadius: radius,
      border: Border.all(color: Colors.white),
      boxShadow: ZaadShadows.card,
    );
    return SizedBox(
      width: 220,
      child: Pressable(
        onTap: () => context.push('/offers/${o.id}'),
        borderRadius: radius,
        decoration: deco,
        pressedDecoration: deco.copyWith(boxShadow: ZaadShadows.raised),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              child: SizedBox(
                height: 118,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    OfferImage(o, height: 118),
                    // Real label from the data: the offer's validity.
                    PositionedDirectional(
                      top: 10,
                      start: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: ZaadGradients.gold,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          context.t.validUntil(context.fmt.date(o.endAt)),
                          style: const TextStyle(color: ZaadColors.navy, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Text(
                o.title(ar),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, height: 1.35, color: ZaadColors.navy),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.t.viewDetails,
                      style: const TextStyle(color: ZaadColors.primary, fontWeight: FontWeight.w600, fontSize: 12.5),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: ZaadColors.primary, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
