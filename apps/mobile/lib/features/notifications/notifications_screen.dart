import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/ui_kit.dart';

/// Maps `zaad://offers/{id}` → `/offers/{id}`, `zaad://redemptions/{id}` → `/redemption/{id}`.
String? routeForDeepLink(String link) {
  final u = Uri.tryParse(link);
  if (u == null || u.scheme != 'zaad') return null;
  final id = u.pathSegments.isNotEmpty ? u.pathSegments.first : null;
  return switch (u.host) {
    'offers' when id != null => '/offers/$id',
    'redemptions' when id != null => '/redemption/$id',
    'invoices' when id != null => '/invoices/$id',
    'points' => '/points',
    _ => null,
  };
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final api = ref.read(apiProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.notificationsTitle), actions: [
        IconButton(
          tooltip: t.markAllRead,
          icon: const Icon(Icons.done_all_rounded),
          onPressed: () async {
            await api.markAllNotificationsRead();
            ref.invalidate(notificationsProvider);
          },
        ),
      ]),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(notificationsProvider),
        child: AsyncBody(
          value: ref.watch(notificationsProvider),
          onRetry: () => ref.invalidate(notificationsProvider),
          loading: const SkeletonList(),
          builder: (r) {
            final list = r.$1;
            if (list.isEmpty) return ListView(children: [const SizedBox(height: 80), EmptyView(icon: Icons.notifications_none_rounded, text: t.noNotifications)]);
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(ZaadSpace.page, 4, ZaadSpace.page, ZaadSpace.xl),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _Tile(list[i], onTap: () async {
                await api.markNotificationRead(list[i].id);
                ref.invalidate(notificationsProvider);
                final route = routeForDeepLink(list[i].deepLink);
                if (route != null && context.mounted) context.push(route);
              }),
            );
          },
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final AppNotification n;
  final VoidCallback onTap;
  const _Tile(this.n, {required this.onTap});
  @override
  Widget build(BuildContext context) {
    final ar = context.ar;
    final icon = switch (n.type) {
      'offer' => Icons.local_offer_rounded,
      'redemption_request' => Icons.point_of_sale_rounded,
      'redemption_completed' => Icons.check_circle_rounded,
      'points_earned' => Icons.stars_rounded,
      _ => Icons.info_outline_rounded,
    };
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IconTile(icon, size: 44),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ar ? n.titleAr : n.titleEn, style: TextStyle(fontWeight: n.read ? FontWeight.w600 : FontWeight.w700)),
            const SizedBox(height: 3),
            Text(ar ? n.bodyAr : n.bodyEn, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ZaadColors.textMuted, fontSize: 13, height: 1.45)),
            const SizedBox(height: 6),
            Text(context.fmt.dateTime(n.createdAt), style: const TextStyle(fontSize: 11, color: ZaadColors.textMuted)),
          ]),
        ),
        if (!n.read) Container(margin: const EdgeInsets.only(top: 6), width: 9, height: 9, decoration: const BoxDecoration(color: ZaadColors.primary, shape: BoxShape.circle)),
      ]),
    );
  }
}
