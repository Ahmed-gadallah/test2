import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/link.dart';

import '../core/open_url/open_stub.dart' if (dart.library.js_interop) '../core/open_url/open_web.dart';
import '../core/theme.dart';

/// Shrinks slightly while pressed — the app's single tap-feedback behaviour.
///
/// The scale listens to raw pointer events (Listener), so it never competes with the
/// InkWell for the tap. [decoration] (fill, gradient, border, shadow) is painted outside
/// the clipped ink layer, so shadows are never cut into a rectangle.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final Decoration? decoration;
  /// Optional decoration while pressed (e.g. a deeper shadow: the card "lifts" as it scales).
  final Decoration? pressedDecoration;
  final String? semanticLabel;
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(ZaadSpace.radius)),
    this.decoration,
    this.pressedDecoration,
    this.semanticLabel,
  });
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    final enabled = widget.onTap != null;
    return Semantics(
      button: enabled,
      label: widget.semanticLabel,
      child: Listener(
        onPointerDown: enabled ? (_) => _set(true) : null,
        onPointerUp: (_) => _set(false),
        onPointerCancel: (_) => _set(false),
        child: AnimatedScale(
          scale: _down && !reduce ? 0.97 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: ZaadMotion.fast,
            curve: Curves.easeOut,
            decoration: (_down && widget.pressedDecoration != null ? widget.pressedDecoration : widget.decoration) ?? const BoxDecoration(),
            child: Material(
              type: MaterialType.transparency,
              borderRadius: widget.borderRadius,
              clipBehavior: Clip.antiAlias,
              child: InkWell(onTap: widget.onTap, borderRadius: widget.borderRadius, child: widget.child),
            ),
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
    final deco = BoxDecoration(color: ZaadColors.surface, borderRadius: r, border: Border.all(color: ZaadColors.border), boxShadow: ZaadShadows.card);
    final body = Padding(padding: padding, child: child);
    return onTap == null ? DecoratedBox(decoration: deco, child: body) : Pressable(onTap: onTap, borderRadius: r, decoration: deco, child: body);
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
  /// Optional small icon before the title (e.g. a gold bolt for quick access).
  final Widget? leading;
  const SectionHeader(this.title, {super.key, this.actionLabel, this.onAction, this.leading});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: ZaadSpace.sm, bottom: ZaadSpace.md),
        child: Row(children: [
          if (leading != null) ...[leading!, const SizedBox(width: 6)],
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
  /// Optional brand icon tile shown at the end of the header (consistent across tab screens).
  final IconData? icon;
  const PageHeader(this.title, {super.key, this.subtitle, this.actions = const [], this.icon});
  @override
  Size get preferredSize => Size.fromHeight(subtitle == null ? 68 : 84);
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
            if (icon != null)
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(gradient: ZaadGradients.hero, borderRadius: BorderRadius.circular(15), boxShadow: ZaadShadows.soft),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
          ]),
        ),
      );
}

/// Draws attention to a newly shown error with one short horizontal shake (no looping).
class ShakeIn extends StatelessWidget {
  final Widget child;
  const ShakeIn({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOut,
      builder: (_, t, c) {
        // Damped sine: ±6px settling to 0.
        final dx = 6 * (1 - t) * math.sin(t * math.pi * 5);
        return Opacity(opacity: (t * 3).clamp(0, 1), child: Transform.translate(offset: Offset(dx, 0), child: c));
      },
      child: child,
    );
  }
}

/// Fades + slides its child in once. `index` staggers siblings. Respects reduced motion.
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final int index;
  /// Start offset in px; negative slides down from above (header).
  final double offset;
  const FadeSlideIn({super.key, required this.child, this.index = 0, this.offset = 16});
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    // Capped so long lists never wait on late items; scrolling is never blocked.
    final i = index.clamp(0, 8);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: ZaadMotion.slow + ZaadMotion.stagger * i,
      curve: ZaadMotion.curve,
      builder: (_, t, c) => Opacity(opacity: t, child: Transform.translate(offset: Offset(0, (1 - t) * offset), child: c)),
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

/// Opens an external URL (website, Google Maps link, tel:).
///
/// Phones (Android/iOS): url_launcher's Link hands the URL to the system (browser, Maps, dialer).
/// Web: a real link is created and clicked from the tap (see open_web.dart). url_launcher's web Link
/// places an invisible <a> over the widget, but this Flutter web build positions those elements at
/// the wrong horizontal offset (about 3× the real x), so taps missed narrow buttons and could hit a
/// neighbouring link (e.g. "Copy number" opening the map).
class ExternalLink extends StatelessWidget {
  /// True on web builds; tests set it to exercise the web path on the VM.
  static bool useDirectOpen = kIsWeb;
  final Uri uri;
  final Widget Function(VoidCallback? open) builder;
  const ExternalLink({super.key, required this.uri, required this.builder});
  @override
  Widget build(BuildContext context) {
    if (useDirectOpen) return builder(() => openInNewTab(uri.toString()));
    return Link(
      uri: uri,
      target: LinkTarget.blank,
      builder: (context, follow) => builder(follow == null ? null : () => follow()),
    );
  }
}


/// Counts up to [value] the first time it appears (from 0), then animates between later values.
/// Display only: the value itself always comes from the API (ERP).
class AnimatedCount extends StatelessWidget {
  final int value;
  final String Function(int) format;
  final TextStyle? style;
  const AnimatedCount(this.value, {super.key, required this.format, this.style});
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return Text(format(value), style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: ZaadMotion.count,
      curve: ZaadMotion.emphasized,
      builder: (_, v, _) => Text(format(v.round()), style: style),
    );
  }
}

/// Pill search field with a soft shadow (branches, and any future list search).
class ZaadSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  final String? clearTooltip;
  final Key? fieldKey;
  const ZaadSearchField({super.key, this.fieldKey, required this.controller, required this.hint, required this.onChanged, this.onClear, this.clearTooltip});
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), boxShadow: ZaadShadows.card),
        child: TextField(
          key: fieldKey,
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: ZaadColors.textMuted, fontSize: 14),
            prefixIcon: const Icon(Icons.search_rounded, color: ZaadColors.primary),
            suffixIcon: onClear == null ? null : IconButton(tooltip: clearTooltip, icon: const Icon(Icons.close_rounded), onPressed: onClear),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: Colors.white)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: ZaadColors.primary, width: 1.4)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          ),
        ),
      );
}

/// Curved royal-blue header with soft light (branches screen and other hero headers).
class GradientHeader extends StatelessWidget {
  final Widget child;
  final double bottomPadding;
  const GradientHeader({super.key, required this.child, this.bottomPadding = 40});
  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          gradient: ZaadGradients.hero,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(ZaadSpace.radiusXl + 4)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          const PositionedDirectional(top: -90, end: -60, child: SoftGlow(size: 240, alpha: 0.10)),
          const PositionedDirectional(bottom: -70, start: -70, child: SoftGlow(size: 180, alpha: 0.07)),
          SafeArea(bottom: false, child: Padding(padding: EdgeInsets.fromLTRB(ZaadSpace.page, ZaadSpace.sm, ZaadSpace.page, bottomPadding), child: child)),
        ]),
      );
}

/// A soft white light disc used for depth on blue surfaces.
class SoftGlow extends StatelessWidget {
  final double size;
  final double alpha;
  const SoftGlow({super.key, required this.size, this.alpha = 0.08});
  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [Colors.white.withValues(alpha: alpha * 1.6), Colors.white.withValues(alpha: 0)]),
          ),
        ),
      );
}

/// Branded placeholder used where a photo would go (e.g. branches). No photos of real branches are
/// invented: it is the brand gradient, a storefront glyph and the official logo, clearly not a photo.
class BrandThumb extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  final double iconSize;
  const BrandThumb({super.key, this.width = 92, this.height = 92, this.radius = 18, this.iconSize = 36});
  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(gradient: ZaadGradients.hero, borderRadius: BorderRadius.circular(radius)),
        clipBehavior: Clip.antiAlias,
        child: Stack(alignment: Alignment.center, children: [
          PositionedDirectional(top: -height * 0.35, end: -width * 0.3, child: SoftGlow(size: width * 1.1, alpha: 0.12)),
          PositionedDirectional(
            bottom: -height * 0.12,
            start: -width * 0.1,
            child: Opacity(opacity: 0.12, child: Image.asset('assets/brand/zaad_logo.png', width: width * 0.75, height: width * 0.75)),
          ),
          Icon(Icons.storefront_rounded, color: Colors.white, size: iconSize),
        ]),
      );
}

/// Decorative, generic street-map drawing (NOT the branch's real surroundings). Used only as an
/// illustration next to the button that opens the branch's own Google Maps link.
class MapIllustration extends StatelessWidget {
  final double height;
  const MapIllustration({super.key, this.height = 150});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _MapPainter(), child: const Center(child: _MapPin())),
      );
}

class _MapPin extends StatelessWidget {
  const _MapPin();
  @override
  Widget build(BuildContext context) {
    final pin = Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 52,
        height: 52,
        decoration: const BoxDecoration(color: ZaadColors.primary, shape: BoxShape.circle, boxShadow: ZaadShadows.glow),
        child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 26),
      ),
      Container(width: 4, height: 12, decoration: BoxDecoration(color: ZaadColors.primary, borderRadius: BorderRadius.circular(2))),
      Container(width: 18, height: 6, decoration: BoxDecoration(color: ZaadColors.primary.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(6))),
    ]);
    if (MediaQuery.of(context).disableAnimations) return pin;
    // Drops in once; no looping animation.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutBack,
      builder: (_, t, c) => Opacity(opacity: t.clamp(0, 1), child: Transform.translate(offset: Offset(0, -18 * (1 - t)), child: c)),
      child: pin,
    );
  }
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFFEEF0FC);
    canvas.drawRect(Offset.zero & size, bg);
    final block = Paint()..color = const Color(0xFFE2E5F8);
    const cell = 46.0;
    for (var x = 6.0; x < size.width; x += cell) {
      for (var y = 6.0; y < size.height; y += cell) {
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, cell - 12, cell - 12), const Radius.circular(6)), block);
      }
    }
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 9
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, size.height * 0.62), Offset(size.width, size.height * 0.38), road);
    canvas.drawLine(Offset(size.width * 0.3, 0), Offset(size.width * 0.42, size.height), road);
    final green = Paint()..color = const Color(0xFFDDEFE6);
    canvas.drawCircle(Offset(size.width * 0.82, size.height * 0.78), 18, green);
    canvas.drawCircle(Offset(size.width * 0.12, size.height * 0.2), 14, green);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Success / status badge that scales in once (redemption outcomes).
class StatusBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;
  const StatusBadge({super.key, required this.icon, required this.color, required this.background});
  @override
  Widget build(BuildContext context) {
    final badge = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: background, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 10))]),
      child: Icon(icon, color: color, size: 48),
    );
    if (MediaQuery.of(context).disableAnimations) return badge;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 560),
      curve: Curves.easeOutBack,
      builder: (_, t, c) => Opacity(opacity: t.clamp(0, 1), child: Transform.scale(scale: 0.6 + 0.4 * t, child: c)),
      child: badge,
    );
  }
}
