import 'package:flutter/material.dart';

import '../core/theme.dart';

class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const NavItem(this.icon, this.activeIcon, this.label);
}

/// Floating bottom navigation: line icons, filled + pill background when active, safe-area aware.
class ZaadBottomNav extends StatelessWidget {
  final List<NavItem> items;
  final int index;
  final ValueChanged<int> onTap;
  const ZaadBottomNav({super.key, required this.items, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 10),
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 4, 14, 0),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(color: ZaadColors.surface, borderRadius: BorderRadius.circular(26), boxShadow: ZaadShadows.nav),
        child: Row(children: [
          for (var i = 0; i < items.length; i++) Expanded(child: _Item(item: items[i], active: i == index, onTap: () => onTap(i))),
        ]),
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
    return Semantics(
      selected: active,
      button: true,
      label: item.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: active ? ZaadColors.primarySoft : Colors.transparent, borderRadius: BorderRadius.circular(20)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Icon(active ? item.activeIcon : item.icon, key: ValueKey(active), color: color, size: 25),
            ),
            const SizedBox(height: 3),
            Text(item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: color, fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
          ]),
        ),
      ),
    );
  }
}
