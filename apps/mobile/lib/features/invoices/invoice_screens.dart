import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

StatusChip invoiceStatusChip(BuildContext context, InvoiceStatus s) {
  final t = context.t;
  return switch (s) {
    InvoiceStatus.finished => StatusChip(t.statusFinished, fg: ZaadColors.success, bg: ZaadColors.successSoft),
    InvoiceStatus.refunded => StatusChip(t.statusRefunded, fg: ZaadColors.danger, bg: ZaadColors.dangerSoft),
    InvoiceStatus.partiallyRefunded => StatusChip(t.statusPartiallyRefunded, fg: ZaadColors.warning, bg: ZaadColors.warningSoft),
    InvoiceStatus.cancelled => StatusChip(t.statusCancelled, fg: ZaadColors.textMuted, bg: ZaadColors.background),
  };
}

class InvoicesScreen extends ConsumerWidget {
  const InvoicesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final s = ref.watch(invoicesProvider);
    final n = ref.read(invoicesProvider.notifier);
    Widget body;
    if (s.items.isEmpty && s.loading) {
      body = const LoadingView();
    } else if (s.items.isEmpty && s.error != null) {
      body = ErrorView(error: s.error!, onRetry: n.reload);
    } else if (s.items.isEmpty) {
      body = ListView(children: [const SizedBox(height: 80), EmptyView(icon: Icons.receipt_long_outlined, text: t.noInvoices)]);
    } else {
      body = NotificationListener<ScrollNotification>(
        onNotification: (x) {
          if (x.metrics.pixels > x.metrics.maxScrollExtent - 300) n.loadMore();
          return false;
        },
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: s.items.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            if (i == s.items.length) {
              if (s.error != null) return ErrorView(error: s.error!, onRetry: n.loadMore);
              return s.done ? const SizedBox(height: 8) : const LoadingView();
            }
            return _InvoiceTile(s.items[i]);
          },
        ),
      );
    }
    return Scaffold(appBar: AppBar(title: Text(t.invoicesTitle), automaticallyImplyLeading: false), body: RefreshIndicator(onRefresh: n.reload, child: body));
  }
}

class _InvoiceTile extends StatelessWidget {
  final InvoiceSummary inv;
  const _InvoiceTile(this.inv);
  @override
  Widget build(BuildContext context) {
    final f = context.fmt;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/invoices/${inv.invoiceId}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: ZaadColors.primarySoft, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.receipt_long_rounded, color: ZaadColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('#${inv.invoiceNumber}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  invoiceStatusChip(context, inv.status),
                ]),
                const SizedBox(height: 4),
                Text(inv.branchName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ZaadColors.textMuted, fontSize: 13)),
                Text(f.dateTime(inv.issuedAt), style: const TextStyle(color: ZaadColors.textMuted, fontSize: 12)),
              ]),
            ),
            Text(f.sar(inv.total), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ]),
        ),
      ),
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
    return Scaffold(
      appBar: AppBar(title: Text(t.invoiceNumber)),
      body: AsyncBody(
        value: ref.watch(invoiceProvider(id)),
        onRetry: () => ref.invalidate(invoiceProvider(id)),
        builder: (inv) => ListView(padding: const EdgeInsets.all(16), children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Row(children: [
                  Expanded(child: Text('#${inv.invoiceNumber}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
                  invoiceStatusChip(context, inv.status),
                ]),
                const SizedBox(height: 8),
                KeyValueRow(t.branch, inv.branchName),
                KeyValueRow(t.date, f.dateTime(inv.issuedAt)),
                if (inv.paymentMethod != null)
                  KeyValueRow(t.paymentMethod, switch (inv.paymentMethod!) { PaymentMethod.cash => t.payCash, PaymentMethod.card => t.payCard, PaymentMethod.cashAndCard => t.payMixed }),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          SectionTitle(t.items),
          Card(
            child: Column(children: [
              for (var i = 0; i < inv.lines.length; i++) ...[
                if (i > 0) const Divider(indent: 16, endIndent: 16),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        // Product names come from the ERP as-is (often English only).
                        Text(inv.lines[i].name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('${t.qty(inv.lines[i].quantity)} × ${f.sar(inv.lines[i].unitPrice)}', style: const TextStyle(color: ZaadColors.textMuted, fontSize: 13)),
                        if (inv.lines[i].discount != null)
                          Text('${t.discounts}: -${f.sar(inv.lines[i].discount!)}', style: const TextStyle(color: ZaadColors.success, fontSize: 12)),
                      ]),
                    ),
                    Text(f.sar(inv.lines[i].lineTotal), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ]),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                // Each row only appears when the ERP provides the value (spec §11.2).
                if (inv.subTotal != null) KeyValueRow(t.subtotal, f.sar(inv.subTotal!)),
                if (inv.discountTotal != null) KeyValueRow(t.discounts, '-${f.sar(inv.discountTotal!)}', valueColor: ZaadColors.success),
                if (inv.voucherDiscount != null) KeyValueRow(t.voucherDiscount, '-${f.sar(inv.voucherDiscount!)}', valueColor: ZaadColors.success),
                if (inv.pointsValue != null) KeyValueRow(t.pointsDiscount, '-${f.sar(inv.pointsValue!)}', valueColor: ZaadColors.success),
                if (inv.taxTotal != null) KeyValueRow(t.tax, f.sar(inv.taxTotal!)),
                const Divider(height: 20),
                KeyValueRow(t.total, f.sar(inv.total), bold: true),
                if (inv.pointsEarned != null) KeyValueRow(t.pointsEarned, '+${f.number(inv.pointsEarned!)}', valueColor: ZaadColors.primary, bold: true, ltr: true),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
