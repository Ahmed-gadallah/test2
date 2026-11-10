import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/ui_kit.dart';

/// Offer image from the admin dashboard when present; otherwise a plain brand panel.
/// No invented imagery or promotional copy — content always comes from the offers API.
class OfferImage extends StatelessWidget {
  final Offer o;
  final double height;
  final double radius;
  const OfferImage(this.o, {super.key, required this.height, this.radius = 0});
  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      height: height,
      decoration: BoxDecoration(
        gradient: ZaadGradients.hero,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: const Center(
        child: Icon(Icons.local_offer_rounded, color: Colors.white54, size: 40),
      ),
    );
    if (o.imageUrl == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        o.imageUrl!,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

/// Promotional banner (home carousel + offers list).
class OfferBanner extends StatelessWidget {
  final Offer o;
  const OfferBanner(this.o, {super.key});
  @override
  Widget build(BuildContext context) {
    final ar = context.ar;
    final hasImage = o.imageUrl != null;
    return Pressable(
      onTap: () => context.push('/offers/${o.id}'),
      borderRadius: BorderRadius.circular(24),
      decoration: BoxDecoration(
        gradient: ZaadGradients.hero,
        borderRadius: BorderRadius.circular(24),
        boxShadow: ZaadShadows.card,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            PositionedDirectional(
              end: -40,
              top: -40,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          o.title(ar),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          o.description(ar),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xCCFFFFFF),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    context.t.viewDetails,
                                    style: const TextStyle(
                                      color: ZaadColors.primary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: ZaadColors.primary,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                context.t.validUntil(context.fmt.date(o.endAt)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xB3FFFFFF),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (hasImage) ...[
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 104,
                      child: OfferImage(o, height: 104, radius: 18),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontally paged banners with dot indicators (home screen).
class OffersCarousel extends ConsumerStatefulWidget {
  const OffersCarousel({super.key});
  @override
  ConsumerState<OffersCarousel> createState() => _OffersCarouselState();
}

class _OffersCarouselState extends ConsumerState<OffersCarousel> {
  final _page = PageController(viewportFraction: 0.92);
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
      loading: const Skeleton(height: 168, radius: 24),
      builder: (list) {
        if (list.isEmpty) {
          return SurfaceCard(
            child: EmptyView(
              icon: Icons.local_offer_outlined,
              text: context.t.noOffers,
            ),
          );
        }
        return Column(
          children: [
            SizedBox(
              height: 168,
              child: PageView.builder(
                controller: _page,
                itemCount: list.length,
                onPageChanged: (i) => setState(() => _index = i),
                // The next offer peeks in; cards away from the centre ease down slightly.
                itemBuilder: (_, i) => AnimatedBuilder(
                  animation: _page,
                  builder: (context, child) {
                    double page = _index.toDouble();
                    if (_page.hasClients && _page.position.haveDimensions) page = _page.page ?? page;
                    final d = (page - i).abs().clamp(0.0, 1.0);
                    return Transform.scale(scale: 1 - 0.05 * d, child: Opacity(opacity: 1 - 0.25 * d, child: child));
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: OfferBanner(list[i]),
                  ),
                ),
              ),
            ),
            if (list.length > 1) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < list.length; i++)
                    AnimatedContainer(
                      duration: ZaadMotion.base,
                      curve: ZaadMotion.curve,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _index ? 20 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: i == _index
                            ? ZaadColors.primary
                            : const Color(0xFFD5D7EA),
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

class OffersScreen extends ConsumerWidget {
  const OffersScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    return Scaffold(
      appBar: PageHeader(t.offersTitle, icon: Icons.local_offer_rounded),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(offersProvider),
        child: AsyncBody(
          value: ref.watch(offersProvider),
          onRetry: () => ref.invalidate(offersProvider),
          loading: ListView(
            padding: const EdgeInsets.all(ZaadSpace.page),
            children: const [
              Skeleton(height: 168, radius: 24),
              SizedBox(height: 14),
              Skeleton(height: 168, radius: 24),
            ],
          ),
          builder: (list) => list.isEmpty
              ? ListView(
                  children: [
                    const SizedBox(height: 60),
                    EmptyView(
                      icon: Icons.local_offer_outlined,
                      text: t.noOffers,
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    ZaadSpace.page,
                    ZaadSpace.sm,
                    ZaadSpace.page,
                    ZaadSpace.xl,
                  ),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (_, i) => FadeSlideIn(
                    index: i,
                    child: SizedBox(height: 168, child: OfferBanner(list[i])),
                  ),
                ),
        ),
      ),
    );
  }
}

class OfferDetailScreen extends ConsumerWidget {
  final String id;
  const OfferDetailScreen({super.key, required this.id});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final ar = context.ar;
    final f = context.fmt;
    return Scaffold(
      appBar: AppBar(title: Text(t.offersTitle)),
      body: AsyncBody(
        value: ref.watch(offerProvider(id)),
        onRetry: () => ref.invalidate(offerProvider(id)),
        builder: (o) => ListView(
          padding: const EdgeInsets.fromLTRB(
            ZaadSpace.page,
            0,
            ZaadSpace.page,
            ZaadSpace.xl,
          ),
          children: [
            FadeSlideIn(
              child: OfferImage(o, height: 200, radius: ZaadSpace.radius),
            ),
            const SizedBox(height: ZaadSpace.lg),
            FadeSlideIn(
              index: 1,
              child: SurfaceCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (o.ended)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: StatusChip(
                          t.offerEnded,
                          fg: ZaadColors.textMuted,
                          bg: ZaadColors.border,
                        ),
                      ),
                    Text(
                      o.title(ar),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: ZaadColors.primarySoft,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.event_rounded,
                            size: 16,
                            color: ZaadColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            t.validFromTo(f.date(o.startAt), f.date(o.endAt)),
                            style: const TextStyle(
                              color: ZaadColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      o.description(ar),
                      style: const TextStyle(fontSize: 15, height: 1.75),
                    ),
                  ],
                ),
              ),
            ),
            if (o.destinationUrl != null && !o.ended) ...[
              const SizedBox(height: ZaadSpace.lg),
              ExternalLink(
                uri: Uri.parse(o.destinationUrl!),
                builder: (open) => FilledButton.icon(
                  onPressed: open,
                  icon: const Icon(Icons.open_in_new_rounded, size: 20),
                  label: Text(o.ctaLabel(ar) ?? t.viewDetails),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
