import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/ui_kit.dart';
import '../home/home_screen.dart';
import '../invoices/invoice_screens.dart' show monthLabel;

/// Read-only view of the ERP balance and ledger. Nothing here computes or changes points.
class PointsScreen extends ConsumerWidget {
  const PointsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final history = ref.watch(historyProvider);
    final balance = ref.watch(pointsProvider).value;
    final items = history.items;

    return Scaffold(
      appBar: AppBar(title: Text(t.pointsBalanceTitle)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(pointsProvider);
          await ref.read(historyProvider.notifier).reload();
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.pixels > n.metrics.maxScrollExtent - 300) ref.read(historyProvider.notifier).loadMore();
            return false;
          },
          child: ListView(padding: const EdgeInsets.fromLTRB(ZaadSpace.page, 4, ZaadSpace.page, ZaadSpace.xl), children: [
            const FadeSlideIn(child: PointsCard()),
            if (balance != null && balance.points <= 0) ...[
              const SizedBox(height: 12),
              Text(t.noPoints, textAlign: TextAlign.center, style: const TextStyle(color: ZaadColors.textMuted)),
            ],
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.info_outline_rounded, size: 16, color: ZaadColors.textMuted),
              const SizedBox(width: 6),
              Expanded(child: Text(t.onlineStoreNote, style: const TextStyle(color: ZaadColors.textMuted, fontSize: 12))),
            ]),
            const SizedBox(height: ZaadSpace.lg),
            SectionHeader(t.pointsHistory),
            if (items.isEmpty && history.loading)
              const Column(children: [SkeletonCard(), SizedBox(height: 10), SkeletonCard(), SizedBox(height: 10), SkeletonCard()])
            else if (items.isEmpty && history.error != null)
              ErrorView(error: history.error!, onRetry: () => ref.read(historyProvider.notifier).reload())
            else if (items.isEmpty)
              EmptyView(icon: Icons.history_rounded, text: t.noHistory)
            else
              ..._grouped(context, items),
            if (items.isNotEmpty && history.loading) const Padding(padding: EdgeInsets.only(top: 10), child: SkeletonCard()),
            if (items.isNotEmpty && history.error != null) ErrorView(error: history.error!, onRetry: () => ref.read(historyProvider.notifier).loadMore()),
          ]),
        ),
      ),
    );
  }

  /// One card per month, entries in ERP order.
  List<Widget> _grouped(BuildContext context, List<PointsEntry> items) {
    final out = <Widget>[];
    var start = 0;
    for (var i = 1; i <= items.length; i++) {
      final boundary = i == items.length || items[i].occurredAt.month != items[start].occurredAt.month || items[i].occurredAt.year != items[start].occurredAt.year;
      if (!boundary) continue;
      final group = items.sublist(start, i);
      out.add(Padding(
        padding: EdgeInsets.only(top: out.isEmpty ? 0 : 16, bottom: 10),
        child: Text(monthLabel(context, group.first.occurredAt), style: const TextStyle(color: ZaadColors.textMuted, fontWeight: FontWeight.w600, fontSize: 13)),
      ));
      out.add(FadeSlideIn(index: out.length ~/ 2, child: SurfaceCard(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(children: [
          for (var j = 0; j < group.length; j++) ...[
            if (j > 0) const Divider(indent: 68, endIndent: 16),
            PointsEntryTile(group[j]),
          ],
        ]),
      )));
      start = i;
    }
    return out;
  }
}

class PointsEntryTile extends StatelessWidget {
  final PointsEntry e;
  const PointsEntryTile(this.e, {super.key});
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final f = context.fmt;
    final (label, icon) = switch (e.type) {
      PointsEntryType.earned => (t.txEarned, Icons.add_rounded),
      PointsEntryType.redeemed => (t.txRedeemed, Icons.redeem_rounded),
      PointsEntryType.refundAdjustment => (t.txRefund, Icons.assignment_return_outlined),
      PointsEntryType.manualAdjustment => (t.txManual, Icons.tune_rounded),
    };
    final positive = e.pointsDelta > 0;
    final color = positive ? ZaadColors.success : ZaadColors.danger;
    final sub = [
      if (e.invoiceNumber != null) t.invoiceRef(e.invoiceNumber!),
      ?e.branchName,
      f.date(e.occurredAt),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        IconTile(icon, size: 40, bg: positive ? ZaadColors.successSoft : ZaadColors.dangerSoft, fg: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(fontSize: 12, color: ZaadColors.textMuted, height: 1.4)),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          // Exactly as the ERP reports it — never recomputed (spec §9).
          Text(f.signed(e.pointsDelta), textDirection: TextDirection.ltr, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: color)),
          if (e.balanceAfter != null) Text(t.balanceAfter(f.number(e.balanceAfter!)), style: const TextStyle(fontSize: 11, color: ZaadColors.textMuted)),
        ]),
      ]),
    );
  }
}
