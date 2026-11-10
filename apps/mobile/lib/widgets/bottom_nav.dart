import 'package:flutter/material.dart';

import '../core/theme.dart';

class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const NavItem(this.icon, this.activeIcon, this.label);
}

/// Floating bottom navigation. A soft pill indicator glides to the active tab; the active icon
/// switches to its filled form and lifts slightly. Destinations and behaviour are unchanged.
class ZaadBottomNav extends StatelessWidget {
  final List<NavItem> items;
  final int index;
  final ValueChanged<int> onTap;
  const ZaadBottomNav({super.key, required this.items, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 10),
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 4, 14, 0),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: ZaadColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: ZaadColors.border.withValues(alpha: 0.6)),
          boxShadow: ZaadShadows.nav,
        ),
        child: LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth / items.length;
          // Visual position follows reading direction (first tab on the right in Arabic).
          final x = (rtl ? items.length - 1 - index : index) * w;
          return Stack(children: [
            AnimatedPositioned(
              duration: reduce ? Duration.zero : ZaadMotion.base,
              curve: ZaadMotion.curve,
              left: x,
              top: 0,
              bottom: 0,
              width: w,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: DecoratedBox(decoration: BoxDecoration(color: ZaadColors.primarySoft, borderRadius: BorderRadius.circular(22))),
              ),
            ),
            Row(children: [
              for (var i = 0; i < items.length; i++) Expanded(child: _Item(item: items[i], active: i == index, onTap: () => onTap(i))),
            ]),
          ]);
        }),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final NavItem item;
  final bool active;
  final VoidCallback onTap;
  const _Item({required this.item, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final color = active ? ZaadColors.primary : ZaadColors.textMuted;
    final reduce = MediaQuery.of(context).disableAnimations;
    return Semantics(
      selected: active,
      button: true,
      label: item.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedSlide(
              offset: active && !reduce ? const Offset(0, -0.06) : Offset.zero,
              duration: ZaadMotion.base,
              curve: ZaadMotion.curve,
              child: AnimatedSwitcher(
                duration: reduce ? Duration.zero : ZaadMotion.fast,
                transitionBuilder: (c, a) => ScaleTransition(scale: Tween(begin: 0.8, end: 1.0).animate(a), child: FadeTransition(opacity: a, child: c)),
                child: Icon(active ? item.activeIcon : item.icon, key: ValueKey(active), color: color, size: 25),
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: ZaadMotion.fast,
              style: TextStyle(fontFamily: 'IBMPlexSansArabic', fontSize: 12, color: color, fontWeight: active ? FontWeight.w700 : FontWeight.w500),
              child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ]),
        ),
      ),
    );
  }
}
