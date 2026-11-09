import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config.dart';
import '../core/error_text.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../l10n/gen/app_localizations.dart';
import '../state/providers.dart';

extension Ctx on BuildContext {
  AppLocalizations get t => AppLocalizations.of(this);
  Fmt get fmt => Fmt(Localizations.localeOf(this).languageCode);
  bool get ar => Localizations.localeOf(this).languageCode == 'ar';
}

/// Official Zaad logo (assets/brand/zaad_logo.png, supplied by Zaad). Used as-is, never redrawn.
class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 40});
  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/brand/zaad_logo.png',
        width: size,
        height: size,
        filterQuality: FilterQuality.medium,
        semanticLabel: context.t.appName,
      );
}

class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key});

  /// Single source of truth for showing demo indicators (unchanged: demo builds only).
  static bool get visible => AppConfig.isDemo;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return SafeArea(
      bottom: false,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 22),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: const BoxDecoration(color: ZaadColors.warningSoft, borderRadius: BorderRadius.vertical(bottom: Radius.circular(14))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.science_outlined, size: 14, color: ZaadColors.warning),
            const SizedBox(width: 6),
            Flexible(
              child: Text(context.t.demoBanner,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: ZaadColors.warning, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(strokeWidth: 2.5)));
}

class EmptyView extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyView({super.key, required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(color: ZaadColors.primarySoft, borderRadius: BorderRadius.circular(28)),
              child: Icon(icon, size: 40, color: ZaadColors.primary),
            ),
            const SizedBox(height: 20),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: ZaadColors.textMuted, fontSize: 15, height: 1.6)),
          ]),
        ),
      );
}

class ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;
  const ErrorView({super.key, required this.error, this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(color: ZaadColors.dangerSoft, borderRadius: BorderRadius.circular(28)),
              child: const Icon(Icons.cloud_off_rounded, size: 40, color: ZaadColors.danger),
            ),
            const SizedBox(height: 20),
            Text(errorText(context.t, error), textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, height: 1.6)),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(minimumSize: const Size(160, 48), backgroundColor: ZaadColors.primarySoft, foregroundColor: ZaadColors.primary),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(context.t.retry),
              ),
            ],
          ]),
        ),
      );
}

/// Renders an AsyncValue with consistent loading (skeleton) / error+retry states.
class AsyncBody<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback onRetry;
  final Widget? loading;
  const AsyncBody({super.key, required this.value, required this.builder, required this.onRetry, this.loading});
  @override
  Widget build(BuildContext context) => switch (value) {
        AsyncData(:final value) => builder(value),
        AsyncError(:final error) => ErrorView(error: error, onRetry: onRetry),
        _ => loading ?? const LoadingView(),
      };
}

class KeyValueRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;
  /// Force left-to-right for phone numbers and signed amounts so RTL layout doesn't reorder them.
  final bool ltr;
  const KeyValueRow(this.label, this.value, {super.key, this.bold = false, this.valueColor, this.ltr = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(label, style: const TextStyle(color: ZaadColors.textMuted, fontSize: 14))),
          const SizedBox(width: 12),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.end, textDirection: ltr ? TextDirection.ltr : null, style: TextStyle(fontSize: bold ? 16 : 14, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: valueColor)),
          ),
        ]),
      );
}

class StatusChip extends StatelessWidget {
  final String label;
  final Color fg;
  final Color bg;
  const StatusChip(this.label, {super.key, required this.fg, required this.bg});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

/// Bell icon with unread badge.
class NotificationBell extends ConsumerWidget {
  final VoidCallback onTap;
  final Color color;
  const NotificationBell({super.key, required this.onTap, this.color = Colors.white});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(notificationsProvider).value?.$2 ?? 0;
    return IconButton(
      onPressed: onTap,
      tooltip: context.t.notificationsTitle,
      icon: Badge(
        isLabelVisible: unread > 0,
        backgroundColor: const Color(0xFFE5484D),
        label: Text(unread > 9 ? '9+' : '$unread'),
        child: Icon(Icons.notifications_none_rounded, color: color, size: 26),
      ),
    );
  }
}
