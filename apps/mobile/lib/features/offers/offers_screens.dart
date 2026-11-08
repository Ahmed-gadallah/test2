import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

/// Offer artwork: uses the admin-uploaded banner when present; otherwise a
/// neutral brand-colour panel (no invented imagery).
class _OfferArt extends StatelessWidget {
  final Offer o;
  final double height;
  const _OfferArt(this.o, {required this.height});
  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      height: height,
      decoration: const BoxDecoration(gradient: LinearGradient(colors: [ZaadColors.primary, Color(0xFF4B4DE0)], begin: AlignmentDirectional.topStart, end: AlignmentDirectional.bottomEnd)),
      child: const Center(child: Icon(Icons.local_offer_rounded, color: Colors.white70, size: 36)),
    );
    if (o.imageUrl == null) return fallback;
    return Image.network(o.imageUrl!, height: height, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback);
  }
}

class OfferCard extends StatelessWidget {
  final Offer o;
  final bool compact;
  const OfferCard(this.o, {super.key, this.compact = false});
  @override
  Widget build(BuildContext context) {
    final ar = context.ar;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/offers/${o.id}'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _OfferArt(o, height: compact ? 72 : 140),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(o.title(ar), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(o.description(ar), maxLines: compact ? 1 : 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ZaadColors.textMuted, fontSize: 13)),
              const SizedBox(height: 6),
              Text(context.t.validUntil(context.fmt.date(o.endAt)), style: const TextStyle(color: ZaadColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class OffersScreen extends ConsumerWidget {
  const OffersScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    return Scaffold(
      appBar: AppBar(title: Text(t.offersTitle), automaticallyImplyLeading: false),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(offersProvider),
        child: AsyncBody(
          value: ref.watch(offersProvider),
          onRetry: () => ref.invalidate(offersProvider),
          builder: (list) => list.isEmpty
              ? ListView(children: [const SizedBox(height: 80), EmptyView(icon: Icons.local_offer_outlined, text: t.noOffers)])
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => OfferCard(list[i]),
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
        builder: (o) => ListView(children: [
          _OfferArt(o, height: 200),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (o.ended)
                Padding(padding: const EdgeInsets.only(bottom: 12), child: StatusChip(t.offerEnded, fg: ZaadColors.textMuted, bg: ZaadColors.border)),
              Text(o.title(ar), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.4)),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.event_rounded, size: 16, color: ZaadColors.primary),
                const SizedBox(width: 6),
                Text(t.validFromTo(f.date(o.startAt), f.date(o.endAt)), style: const TextStyle(color: ZaadColors.primary, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 16),
              Text(o.description(ar), style: const TextStyle(fontSize: 15, height: 1.7)),
              if (o.destinationUrl != null && !o.ended) ...[
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => launchUrl(Uri.parse(o.destinationUrl!), mode: LaunchMode.externalApplication),
                  child: Text(o.ctaLabel(ar) ?? t.viewDetails),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}
