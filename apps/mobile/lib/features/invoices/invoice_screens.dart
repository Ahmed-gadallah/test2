import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/privacy.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/ui_kit.dart';

StatusChip invoiceStatusChip(BuildContext context, InvoiceStatus s) {
  final t = context.t;
  return switch (s) {
    InvoiceStatus.finished => StatusChip(t.statusFinished, fg: ZaadColors.success, bg: ZaadColors.successSoft),
    InvoiceStatus.refunded => StatusChip(t.statusRefunded, fg: ZaadColors.danger, bg: ZaadColors.dangerSoft),
    InvoiceStatus.partiallyRefunded => StatusChip(t.statusPartiallyRefunded, fg: ZaadColors.warning, bg: ZaadColors.warningSoft),
    InvoiceStatus.cancelled => StatusChip(t.statusCancelled, fg: ZaadColors.textMuted, bg: ZaadColors.background),
  };
}

/// "November 2026" style group label; western digits like the rest of the app.
String monthLabel(BuildContext context, DateTime d) =>
    DateFormat('MMMM yyyy', Localizations.localeOf(context).languageCode).format(d).replaceAllMapped(RegExp('[٠-٩]'), (m) => '${m[0]!.codeUnitAt(0) - 0x0660}');

class InvoicesScreen extends ConsumerWidget {
  const InvoicesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final s = ref.watch(invoicesProvider);
    final n = ref.read(invoicesProvider.notifier);
    Widget body;
    if (s.items.isEmpty && s.loading) {
      body = const SkeletonList();
    } else if (s.items.isEmpty && s.error != null) {
      body = ErrorView(error: s.error!, onRetry: n.reload);
    } else if (s.items.isEmpty) {
      body = ListView(children: [const SizedBox(height: 60), EmptyView(icon: Icons.receipt_long_outlined, text: t.noInvoices)]);
    } else {
      body = NotificationListener<ScrollNotification>(
        onNotification: (x) {
          if (x.metrics.pixels > x.metrics.maxScrollExtent - 300) n.loadMore();
          return false;
        },
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(ZaadSpace.page, 0, ZaadSpace.page, ZaadSpace.xl),
          itemCount: s.items.length + 1,
          itemBuilder: (_, i) {
            if (i == s.items.length) {
              if (s.error != null) return ErrorView(error: s.error!, onRetry: n.loadMore);
              return s.done ? const SizedBox(height: 8) : const Padding(padding: EdgeInsets.only(top: 12), child: SkeletonCard());
            }
            final inv = s.items[i];
            final newMonth = i == 0 || s.items[i - 1].issuedAt.month != inv.issuedAt.month || s.items[i - 1].issuedAt.year != inv.issuedAt.year;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (newMonth)
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 4 : 18, bottom: 10),
                  child: Text(monthLabel(context, inv.issuedAt), style: const TextStyle(color: ZaadColors.textMuted, fontWeight: FontWeight.w600, fontSize: 13)),
                )
              else
                const SizedBox(height: 10),
              InvoiceCard(inv),
            ]);
          },
        ),
      );
    }
    return Scaffold(appBar: PageHeader(t.invoicesTitle), body: RefreshIndicator(onRefresh: n.reload, child: body));
  }
}

class InvoiceCard extends StatelessWidget {
  final InvoiceSummary inv;
  const InvoiceCard(this.inv, {super.key});
  @override
  Widget build(BuildContext context) {
    final f = context.fmt;
    return SurfaceCard(
      onTap: () => context.push('/invoices/${inv.invoiceId}'),
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        const IconTile(Icons.receipt_long_rounded),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text('#${inv.invoiceNumber}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
              const SizedBox(width: 8),
              invoiceStatusChip(context, inv.status),
            ]),
            const SizedBox(height: 4),
            Text(f.dateTime(inv.issuedAt), style: const TextStyle(color: ZaadColors.textMuted, fontSize: 12.5)),
            Text(inv.branchName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ZaadColors.textMuted, fontSize: 12.5)),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(f.sar(inv.total), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 6),
          const Icon(Icons.chevron_right_rounded, color: ZaadColors.textMuted, size: 20),
        ]),
      ]),
    );
  }
}

class InvoiceDetailScreen extends ConsumerWidget {
  final String id;
  const InvoiceDetailScreen({super.key, required this.id});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final f = context.fmt;
    // Invoice lines include medicine names (health data under PDPL): block screenshots/recording on Android.
    return SecureScreen(
      child: Scaffold(
        appBar: AppBar(title: Text(t.invoiceNumber)),
        body: AsyncBody(
          value: ref.watch(invoiceProvider(id)),
          onRetry: () => ref.invalidate(invoiceProvider(id)),
          loading: const SkeletonList(count: 4),
          builder: (inv) => ListView(padding: const EdgeInsets.fromLTRB(ZaadSpace.page, 4, ZaadSpace.page, ZaadSpace.xl), children: [
            FadeSlideIn(
              child: SurfaceCard(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  Row(children: [
                    const IconTile(Icons.receipt_long_rounded, size: 44),
                    const SizedBox(width: 12),
                    Expanded(child: Text('#${inv.invoiceNumber}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700))),
                    invoiceStatusChip(context, inv.status),
                  ]),
                  const SizedBox(height: 18),
                  Text(t.total, style: const TextStyle(color: ZaadColors.textMuted)),
                  const SizedBox(height: 2),
                  Text(f.sar(inv.total), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: ZaadColors.primary)),
                  if (inv.pointsEarned != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: ZaadColors.primarySoft, borderRadius: BorderRadius.circular(30)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.stars_rounded, color: ZaadColors.primary, size: 18),
                        const SizedBox(width: 6),
                        // Shown exactly as the ERP reports it.
                        Text(t.pointsEarned, style: const TextStyle(color: ZaadColors.primary, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 6),
                        Text('+${f.number(inv.pointsEarned!)}', textDirection: TextDirection.ltr, style: const TextStyle(color: ZaadColors.primary, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 6),
                  KeyValueRow(t.branch, inv.branchName),
                  KeyValueRow(t.date, f.dateTime(inv.issuedAt)),
                  if (inv.paymentMethod != null)
                    KeyValueRow(t.paymentMethod, switch (inv.paymentMethod!) {
                      PaymentMethod.cash => t.payCash,
                      PaymentMethod.card => t.payCard,
                      PaymentMethod.cashAndCard => t.payMixed,
                    }),
                ]),
              ),
            ),
            const SizedBox(height: ZaadSpace.lg),
            FadeSlideIn(index: 1, child: SectionHeader('${t.items} (${inv.lines.length})')),
            FadeSlideIn(
              index: 2,
              child: SurfaceCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  for (var i = 0; i < inv.lines.length; i++) ...[
                    if (i > 0) const Divider(indent: 16, endIndent: 16),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: ZaadColors.background, borderRadius: BorderRadius.circular(9)),
                          child: Text('${inv.lines[i].quantity}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ZaadColors.textMuted)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            // Product names come from the ERP as-is (often English only).
                            Text(inv.lines[i].name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text('${t.qty(inv.lines[i].quantity)} × ${f.sar(inv.lines[i].unitPrice)}', style: const TextStyle(color: ZaadColors.textMuted, fontSize: 12.5)),
                            if (inv.lines[i].discount != null)
                              Text('${t.discounts}: -${f.sar(inv.lines[i].discount!)}', style: const TextStyle(color: ZaadColors.success, fontSize: 12)),
                          ]),
                        ),
                        Text(f.sar(inv.lines[i].lineTotal), style: const TextStyle(fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ],
                ]),
              ),
            ),
            const SizedBox(height: ZaadSpace.lg),
            FadeSlideIn(
              index: 3,
              child: SurfaceCard(
                padding: const EdgeInsets.all(18),
                child: Column(children: [
                  // Each row only appears when the ERP provides the value (spec §11.2).
                  if (inv.subTotal != null) KeyValueRow(t.subtotal, f.sar(inv.subTotal!)),
                  if (inv.discountTotal != null) KeyValueRow(t.discounts, '-${f.sar(inv.discountTotal!)}', valueColor: ZaadColors.success),
                  if (inv.voucherDiscount != null) KeyValueRow(t.voucherDiscount, '-${f.sar(inv.voucherDiscount!)}', valueColor: ZaadColors.success),
                  if (inv.pointsValue != null) KeyValueRow(t.pointsDiscount, '-${f.sar(inv.pointsValue!)}', valueColor: ZaadColors.success),
                  if (inv.taxTotal != null) KeyValueRow(t.tax, f.sar(inv.taxTotal!)),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
                  KeyValueRow(t.total, f.sar(inv.total), bold: true),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
