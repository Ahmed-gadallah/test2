import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../offers/offers_screens.dart';

const onlineStoreUrl = 'https://zaadonline.com';

Future<void> openOnlineStore() => launchUrl(Uri.parse(onlineStoreUrl), mode: LaunchMode.externalApplication);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final profile = ref.watch(profileProvider);
    final pending = ref.watch(pendingRedemptionsProvider).value ?? const <Redemption>[];
    final name = profile.value?.name;

    Future<void> refresh() async {
      ref.invalidate(pointsProvider);
      ref.invalidate(offersProvider);
      ref.invalidate(notificationsProvider);
      ref.invalidate(profileProvider);
      // Wait for the refresh to settle; errors are rendered by the card itself.
      await ref.read(pointsProvider.future).then((_) {}, onError: (_) {});
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: refresh,
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: ZaadColors.primary,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 8, 24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const BrandMark(color: Colors.white, size: 18),
                      const Spacer(),
                      NotificationBell(onTap: () => context.push('/notifications')),
                      IconButton(onPressed: () => context.go('/profile'), icon: const Icon(Icons.settings_outlined, color: Colors.white), tooltip: t.settings),
                    ]),
                    const SizedBox(height: 12),
                    Text(
                      // ERP names are cashier-entered; greet neutrally if missing (assessment G4).
                      name == null || name.trim().isEmpty ? t.helloNoName : t.hello(name.trim()),
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 16),
                    const Padding(padding: EdgeInsetsDirectional.only(end: 12), child: PointsCard()), // end inset mirrors the icon-button gutter
                  ]),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            sliver: SliverList.list(children: [
              for (final r in pending.where((r) => r.isActionable)) ...[PendingRedemptionBanner(r), const SizedBox(height: 16)],
              SectionTitle(t.quickActions),
              const _QuickActions(),
              const SizedBox(height: 20),
              SectionTitle(t.latestOffers, trailing: TextButton(onPressed: () => context.go('/offers'), child: Text(t.seeAll))),
              const _OffersStrip(),
            ]),
          ),
        ]),
      ),
    );
  }
}

class PointsCard extends ConsumerWidget {
  final bool compact;
  const PointsCard({super.key, this.compact = false});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final f = context.fmt;
    final points = ref.watch(pointsProvider);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF3436D9), ZaadColors.primaryDark], begin: AlignmentDirectional.topStart, end: AlignmentDirectional.bottomEnd),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: switch (points) {
        AsyncData(:final value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.availablePoints, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 6),
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text(f.number(value.points), style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w700, height: 1.1)),
              const SizedBox(width: 6),
              Text(t.pointsUnit, style: const TextStyle(color: Colors.white70, fontSize: 15)),
            ]),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
              child: Text(t.equivalentValue(f.sar(value.equivalentSar)), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Text(t.rateExplanation(value.pointsPerSar), style: const TextStyle(color: Colors.white70, fontSize: 12))),
              Text(t.updatedAt(f.time(value.asOf)), style: const TextStyle(color: Colors.white60, fontSize: 11)),
            ]),
          ]),
        AsyncError() => Row(children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.white70),
            const SizedBox(width: 10),
            // Never show a stale/fake balance as current (spec §21).
            Expanded(child: Text(t.errErpUnavailable, style: const TextStyle(color: Colors.white, height: 1.4))),
            TextButton(onPressed: () => ref.invalidate(pointsProvider), child: Text(t.retry, style: const TextStyle(color: Colors.white))),
          ]),
        _ => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))),
      },
    );
  }
}

class PendingRedemptionBanner extends StatelessWidget {
  final Redemption r;
  const PendingRedemptionBanner(this.r, {super.key});
  @override
  Widget build(BuildContext context) {
    final f = context.fmt;
    return Material(
      color: ZaadColors.warningSoft,
      borderRadius: BorderRadius.circular(ZaadSpace.radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(ZaadSpace.radius),
        onTap: () => context.push('/redemption/${r.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            const Icon(Icons.point_of_sale_rounded, color: ZaadColors.warning, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.t.pendingRedemptionBanner, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('${f.number(r.points)} ${context.t.pointsUnit} · ${f.sar(r.discountAmount)} · ${r.branchName}',
                    style: const TextStyle(color: ZaadColors.textMuted, fontSize: 13)),
              ]),
            ),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 16)),
              onPressed: () => context.push('/redemption/${r.id}'),
              child: Text(context.t.pendingRedemptionAction),
            ),
          ]),
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
    return Column(children: [
      Row(children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: items[i].$3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                  child: Column(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: ZaadColors.primarySoft, borderRadius: BorderRadius.circular(12)),
                      child: Icon(items[i].$1, color: ZaadColors.primary),
                    ),
                    const SizedBox(height: 8),
                    Text(items[i].$2, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
          ),
        ],
      ]),
      const SizedBox(height: 10),
      // Prominent external link to the existing store (spec §14). No loyalty claims.
      Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: openOnlineStore,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: ZaadColors.primary, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.shopping_bag_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.shopOnline, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const Text('zaadonline.com', textDirection: TextDirection.ltr, style: TextStyle(color: ZaadColors.textMuted, fontSize: 12)),
                ]),
              ),
              const Icon(Icons.open_in_new_rounded, size: 18, color: ZaadColors.textMuted),
            ]),
          ),
        ),
      ),
    ]);
  }
}

class _OffersStrip extends ConsumerWidget {
  const _OffersStrip();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offers = ref.watch(offersProvider);
    return AsyncBody(
      value: offers,
      onRetry: () => ref.invalidate(offersProvider),
      builder: (list) => list.isEmpty
          ? EmptyView(icon: Icons.local_offer_outlined, text: context.t.noOffers)
          : SizedBox(
              height: 178,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, i) => SizedBox(width: 280, child: OfferCard(list[i], compact: true)),
              ),
            ),
    );
  }
}
