import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../home/home_screen.dart';

class PointsScreen extends ConsumerWidget {
  const PointsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final history = ref.watch(historyProvider);
    final balance = ref.watch(pointsProvider).value;
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
          child: ListView(padding: const EdgeInsets.all(16), children: [
            const PointsCard(),
            if (balance != null && balance.points <= 0) ...[const SizedBox(height: 12), Text(t.noPoints, textAlign: TextAlign.center, style: const TextStyle(color: ZaadColors.textMuted))],
            const SizedBox(height: 8),
            Text(t.onlineStoreNote, textAlign: TextAlign.center, style: const TextStyle(color: ZaadColors.textMuted, fontSize: 12)),
            const SizedBox(height: 16),
            SectionTitle(t.pointsHistory),
            if (history.items.isEmpty && history.loading)
              const LoadingView()
            else if (history.items.isEmpty && history.error != null)
              ErrorView(error: history.error!, onRetry: () => ref.read(historyProvider.notifier).reload())
            else if (history.items.isEmpty)
              EmptyView(icon: Icons.history_rounded, text: t.noHistory)
            else
              Card(
                child: Column(children: [
                  for (var i = 0; i < history.items.length; i++) ...[
                    if (i > 0) const Divider(indent: 16, endIndent: 16),
                    _EntryTile(history.items[i]),
                  ],
                ]),
              ),
            if (history.items.isNotEmpty && history.loading) const LoadingView(),
            if (history.items.isNotEmpty && history.error != null) ErrorView(error: history.error!, onRetry: () => ref.read(historyProvider.notifier).loadMore()),
          ]),
        ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  final PointsEntry e;
  const _EntryTile(this.e);
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final f = context.fmt;
    final (label, icon) = switch (e.type) {
      PointsEntryType.earned => (t.txEarned, Icons.add_circle_outline_rounded),
      PointsEntryType.redeemed => (t.txRedeemed, Icons.redeem_rounded),
      PointsEntryType.refundAdjustment => (t.txRefund, Icons.assignment_return_outlined),
      PointsEntryType.manualAdjustment => (t.txManual, Icons.tune_rounded),
    };
    final positive = e.pointsDelta > 0;
    final sub = [
      if (e.invoiceNumber != null) t.invoiceRef(e.invoiceNumber!),
      ?e.branchName,
      f.date(e.occurredAt),
    ].join(' · ');
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: positive ? ZaadColors.successSoft : ZaadColors.dangerSoft,
        child: Icon(icon, color: positive ? ZaadColors.success : ZaadColors.danger, size: 22),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(sub, style: const TextStyle(fontSize: 12, color: ZaadColors.textMuted)),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        // Shown exactly as the ERP reports it — never recomputed (spec §9).
        Text(f.signed(e.pointsDelta), textDirection: TextDirection.ltr, style: TextStyle(fontWeight: FontWeight.w700, color: positive ? ZaadColors.success : ZaadColors.danger)),
        if (e.balanceAfter != null) Text(t.balanceAfter(f.number(e.balanceAfter!)), style: const TextStyle(fontSize: 11, color: ZaadColors.textMuted)),
      ]),
    );
  }
}
