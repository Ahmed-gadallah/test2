import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/loyalty_illustration.dart';
import '../../widgets/ui_kit.dart';

/// Onboarding / welcome screen. Presentation only: navigation (/register, /login),
/// language persistence (localeProvider) and demo-mode detection are unchanged.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: ZaadColors.welcomeDeep,
        body: Stack(
          children: [
            const Positioned.fill(child: _Backdrop()),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, c) {
                  // Short screens: shrink logo, illustration and gaps; keep the hierarchy.
                  final h = c.maxHeight;
                  final compact = h < 800;
                  final tiny = h < 700;
                  final logo = tiny ? 92.0 : (compact ? 132.0 : 168.0);
                  final width = c.maxWidth.clamp(0.0, 480.0);
                  return Center(
                    child: SizedBox(
                      width: width,
                      child: Column(
                        children: [
                          const DemoBanner(),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: _LanguagePill(),
                            ),
                          ),
                          SizedBox(height: tiny ? 0 : 12),
                          _Entrance(delay: 0, child: _LogoBadge(size: logo)),
                          SizedBox(height: tiny ? 12 : 22),
                          _Entrance(
                            delay: 120,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    // Break after ".." as in the design; the copy itself is unchanged.
                                    t.welcomeTitle.replaceFirst('.. ', '..\n'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: tiny ? 21 : (compact ? 25 : 29),
                                      fontWeight: FontWeight.w700,
                                      height: 1.45,
                                    ),
                                  ),
                                  SizedBox(height: tiny ? 6 : 10),
                                  Text(
                                    t.welcomeSubtitle,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: ZaadColors.onBlueMuted,
                                      fontSize: tiny ? 13.5 : 15,
                                      height: 1.6,
                                    ),
                                  ),
                                  SizedBox(height: tiny ? 6 : 16),
                                  if (!tiny) const _Divider(),
                                ],
                              ),
                            ),
                          ),
                          // Illustration takes whatever height is left, never overlapping the buttons.
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, box) {
                                final w =
                                    (box.maxHeight * loyaltyIllustrationAspect)
                                        .clamp(0.0, width - 40)
                                        .toDouble();
                                if (w < 110) return const SizedBox.shrink(); // only on extremely short screens
                                return Center(
                                  child: _Entrance(
                                    delay: 240,
                                    child: LoyaltyIllustration(width: w),
                                  ),
                                );
                              },
                            ),
                          ),
                          _Entrance(
                            delay: 320,
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                22,
                                tiny ? 4 : 14,
                                22,
                                tiny ? 8 : 12,
                              ),
                              child: Column(
                                children: [
                                  _WelcomeButton(
                                    label: t.createAccount,
                                    primary: true,
                                    onTap: () => context.push('/register'),
                                  ),
                                  const SizedBox(height: 14),
                                  _WelcomeButton(
                                    label: t.login,
                                    primary: false,
                                    onTap: () => context.push('/login'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Deep-blue gradient, soft edge circles, and a light "floor" curve behind the illustration base and buttons.
class _Backdrop extends StatelessWidget {
  const _Backdrop();
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth, h = c.maxHeight;
        Widget circle(
          double size,
          double alpha, {
          Color color = Colors.white,
        }) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: alpha),
          ),
        );
        return Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    ZaadColors.welcomeBright,
                    ZaadColors.primary,
                    ZaadColors.welcomeDeep,
                  ],
                  stops: [0, 0.45, 1],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned(
              top: -w * 0.32,
              right: -w * 0.30,
              child: circle(w * 0.85, 0.07),
            ),
            Positioned(
              top: h * 0.22,
              left: -w * 0.42,
              child: circle(w * 0.72, 0.05),
            ),
            Positioned(
              top: h * 0.50,
              right: -w * 0.38,
              child: circle(w * 0.7, 0.06, color: ZaadColors.welcomeBright),
            ),
            // Light floor: a very wide ellipse whose top edge forms the curve seen behind the illustration.
            Positioned(
              left: -w * 0.45,
              right: -w * 0.45,
              bottom: -h * 0.18,
              height: h * 0.52,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(
                    Radius.elliptical(w * 1.9, h * 0.52),
                  ),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFC9CFFF),
                      ZaadColors.welcomeLight,
                      Colors.white,
                    ],
                    stops: [0, 0.35, 1],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 🌐 Current language ⌄ — opens a menu; selection uses the existing localeProvider (persisted).
class _LanguagePill extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(localeProvider).languageCode;
    const names = {'ar': 'العربية', 'en': 'English'};
    return PopupMenuButton<String>(
      tooltip: context.t.language,
      initialValue: lang,
      onSelected: (v) => ref.read(localeProvider.notifier).set(v),
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (_) => [
        for (final e in names.entries)
          PopupMenuItem(
            value: e.key,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    e.value,
                    style: TextStyle(
                      fontWeight: e.key == lang
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
                if (e.key == lang)
                  const Icon(
                    Icons.check_rounded,
                    color: ZaadColors.primary,
                    size: 20,
                  ),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              names[lang] ?? lang,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// Official logo (unchanged asset) on a deep-blue disc with two faint rings and a soft glow.
class _LogoBadge extends StatelessWidget {
  final double size;
  const _LogoBadge({required this.size});
  @override
  Widget build(BuildContext context) {
    Widget ring(double d, double a) => Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: a),
          width: 1.2,
        ),
      ),
    );
    return SizedBox(
      width: size * 1.32,
      height: size * 1.32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ring(size * 1.32, 0.08),
          ring(size * 1.16, 0.14),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ZaadColors.welcomeDeep,
              boxShadow: [
                BoxShadow(
                  color: ZaadColors.welcomeBright.withValues(alpha: 0.55),
                  blurRadius: 36,
                  spreadRadius: 2,
                ),
              ],
            ),
            padding: EdgeInsets.all(size * 0.035),
            child: BrandMark(size: size * 0.93),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) {
    final line = Container(
      width: 64,
      height: 1.2,
      color: Colors.white.withValues(alpha: 0.3),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        line,
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: Colors.white70,
            shape: BoxShape.circle,
          ),
        ),
        line,
      ],
    );
  }
}

class _WelcomeButton extends StatelessWidget {
  final String label;
  final bool primary;
  final VoidCallback onTap;
  const _WelcomeButton({
    required this.label,
    required this.primary,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(20);
    return Pressable(
      onTap: onTap,
      borderRadius: r,
      semanticLabel: label,
      decoration: BoxDecoration(
        borderRadius: r,
        color: primary ? Colors.white : null,
        gradient: primary
            ? null
            : const LinearGradient(
                colors: [ZaadColors.welcomeBright, ZaadColors.primary],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
        border: primary ? null : Border.all(color: Colors.white, width: 1.6),
        boxShadow: [
          BoxShadow(
            color: ZaadColors.welcomeDeep.withValues(
              alpha: primary ? 0.18 : 0.32,
            ),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SizedBox(
        height: 58,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: primary ? ZaadColors.primary : Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// Fade + rise + slight scale on first build; respects reduced motion.
class _Entrance extends StatelessWidget {
  final Widget child;
  final int delay;
  const _Entrance({required this.child, required this.delay});
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    final total = 520 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, (1 - v) * 18),
          child: Transform.scale(scale: 0.96 + 0.04 * v, child: c),
        ),
      ),
      child: child,
    );
  }
}
