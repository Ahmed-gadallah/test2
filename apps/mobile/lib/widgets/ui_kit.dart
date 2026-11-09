import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Shrinks slightly while pressed — the app's single tap-feedback behaviour.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final String? semanticLabel;
  const Pressable({super.key, required this.child, this.onTap, this.borderRadius = const BorderRadius.all(Radius.circular(ZaadSpace.radius)), this.semanticLabel});
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    return Semantics(
      button: widget.onTap != null,
      label: widget.semanticLabel,
      child: GestureDetector(
        onTapDown: widget.onTap == null ? null : (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        child: AnimatedScale(
          scale: _down && !reduce ? 0.97 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(onTap: widget.onTap, borderRadius: widget.borderRadius, child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// White card with the brand-tinted soft shadow and hairline border.
class SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  const SurfaceCard({super.key, required this.child, this.padding = const EdgeInsets.all(ZaadSpace.lg), this.onTap, this.radius = ZaadSpace.radius});
  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    final body = Ink(
      decoration: BoxDecoration(color: ZaadColors.surface, borderRadius: r, border: Border.all(color: ZaadColors.border), boxShadow: ZaadShadows.card),
      child: Padding(padding: padding, child: child),
    );
    return onTap == null ? Material(type: MaterialType.transparency, child: body) : Pressable(onTap: onTap, borderRadius: r, child: body);
  }
}

/// Light-blue rounded square holding an icon (quick actions, list leading icons).
class IconTile extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color bg;
  final Color fg;
  const IconTile(this.icon, {super.key, this.size = 48, this.bg = ZaadColors.primarySoft, this.fg = ZaadColors.primary});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size * 0.3)),
        child: Icon(icon, color: fg, size: size * 0.5),
      );
}

/// Section title with an optional "See all ›" action.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const SectionHeader(this.title, {super.key, this.actionLabel, this.onAction});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: ZaadSpace.sm, bottom: ZaadSpace.md),
        child: Row(children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ZaadColors.text))),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 36)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(actionLabel!, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 2),
                const Icon(Icons.chevron_right_rounded, size: 20), // auto-mirrors in RTL
              ]),
            ),
        ]),
      );
}

/// Large left/right-aligned title for top-level tab screens (Invoices, Offers, Profile).
class PageHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  const PageHeader(this.title, {super.key, this.subtitle, this.actions = const []});
  @override
  Size get preferredSize => Size.fromHeight(subtitle == null ? 64 : 80);
  @override
  Widget build(BuildContext context) => SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(ZaadSpace.page, ZaadSpace.md, ZaadSpace.md, ZaadSpace.sm),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, height: 1.2)),
                if (subtitle != null) Text(subtitle!, style: const TextStyle(color: ZaadColors.textMuted, fontSize: 13)),
              ]),
            ),
            ...actions,
          ]),
        ),
      );
}

/// Fades + slides its child in once. `index` staggers siblings. Respects reduced motion.
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final int index;
  const FadeSlideIn({super.key, required this.child, this.index = 0});
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 360 + index * 70),
      curve: Curves.easeOutCubic,
      builder: (_, t, c) => Opacity(opacity: t, child: Transform.translate(offset: Offset(0, (1 - t) * 14), child: c)),
      child: child,
    );
  }
}

/// Shimmering placeholder block for loading states.
class Skeleton extends StatefulWidget {
  final double height;
  final double? width;
  final double radius;
  const Skeleton({super.key, this.height = 16, this.width, this.radius = 10});
  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              colors: const [Color(0xFFE9EAF5), Color(0xFFF4F5FB), Color(0xFFE9EAF5)],
              stops: const [0.1, 0.5, 0.9],
              begin: Alignment(-1.5 + _c.value * 3, 0),
              end: Alignment(-0.5 + _c.value * 3, 0),
            ),
          ),
        ),
      );
}

/// A list of skeleton rows shaped like list cards.
class SkeletonList extends StatelessWidget {
  final int count;
  const SkeletonList({super.key, this.count = 6});
  @override
  Widget build(BuildContext context) => ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        padding: const EdgeInsets.all(ZaadSpace.page),
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(height: ZaadSpace.md),
        itemBuilder: (_, _) => const SkeletonCard(),
      );
}

class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});
  @override
  Widget build(BuildContext context) => SurfaceCard(
        child: Row(children: const [
          Skeleton(height: 48, width: 48, radius: 14),
          SizedBox(width: ZaadSpace.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Skeleton(height: 14, width: 140),
              SizedBox(height: 8),
              Skeleton(height: 12, width: 200),
            ]),
          ),
          SizedBox(width: ZaadSpace.md),
          Skeleton(height: 16, width: 64),
        ]),
      );
}

/// Grouped settings/info rows inside one card.
class InfoGroup extends StatelessWidget {
  final List<Widget> children;
  const InfoGroup({super.key, required this.children});
  @override
  Widget build(BuildContext context) => SurfaceCard(
        padding: const EdgeInsets.symmetric(vertical: ZaadSpace.xs),
        child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(indent: 68, endIndent: ZaadSpace.lg),
            children[i],
          ],
        ]),
      );
}

class InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? color;
  final bool ltrValue;
  const InfoRow({super.key, required this.icon, required this.title, this.value, this.subtitle, this.trailing, this.onTap, this.color, this.ltrValue = false});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ZaadSpace.radius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: ZaadSpace.lg, vertical: ZaadSpace.md),
          child: Row(children: [
            IconTile(icon, size: 38, bg: color == null ? ZaadColors.primarySoft : color!.withValues(alpha: 0.1), fg: color ?? ZaadColors.primary),
            const SizedBox(width: ZaadSpace.md + 2),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: color ?? ZaadColors.text)),
                if (subtitle != null) Text(subtitle!, style: const TextStyle(color: ZaadColors.textMuted, fontSize: 12)),
              ]),
            ),
            if (value != null)
              Flexible(
                child: Text(value!,
                    textAlign: TextAlign.end,
                    textDirection: ltrValue ? TextDirection.ltr : null,
                    style: const TextStyle(color: ZaadColors.textMuted, fontWeight: FontWeight.w500)),
              ),
            ?trailing,
            if (onTap != null && trailing == null) const Icon(Icons.chevron_right_rounded, color: ZaadColors.textMuted),
          ]),
        ),
      );
}
