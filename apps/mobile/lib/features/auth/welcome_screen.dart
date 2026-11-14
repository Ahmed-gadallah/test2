import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/illustrations.dart';
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
        backgroundColor: ZaadColors.welcomeNavy,
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
                  final logo = tiny ? 92.0 : (compact ? 124.0 : 156.0);
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
                              child: _Entrance(delay: 0, child: _LanguagePill()),
                            ),
                          ),
                          SizedBox(height: tiny ? 0 : 8),
                          _Entrance(delay: 60, scaleFrom: 0.85, child: _LogoBadge(size: logo)),
                          SizedBox(height: tiny ? 10 : 18),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 26),
                            child: _Headline(
                              title: t.welcomeTitle,
                              subtitle: t.welcomeSubtitle,
                              tiny: tiny,
                              compact: compact,
                            ),
                          ),
                          // Illustration takes whatever height is left, never overlapping the buttons.
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, box) {
                                final w = (box.maxHeight * loyaltyIllustrationAspect)
                                    .clamp(0.0, width - 40)
                                    .toDouble();
                                if (w < 110) return const SizedBox.shrink(); // only on extremely short screens
                                return Center(
                                  child: _Entrance(
                                    delay: 380,
                                    child: Floating(
                                      amplitude: 5,
                                      period: const Duration(milliseconds: 4200),
                                      child: LoyaltyIllustration(width: w),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          _Entrance(
                            delay: 460,
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(22, tiny ? 4 : 12, 22, tiny ? 8 : 14),
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

/// Headline in two tones: the first sentence in white, the closing phrase ("all in one place!" /
/// "كلها في مكان واحد!") in the accent yellow with a hand-drawn underline. The copy itself is the
/// existing localized string; it is only split at its ".." for presentation.
class _Headline extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool tiny;
  final bool compact;
  const _Headline({required this.title, required this.subtitle, required this.tiny, required this.compact});

  @override
  Widget build(BuildContext context) {
    final i = title.indexOf('..');
    final first = i < 0 ? title : title.substring(0, i + 2).trim();
    final second = i < 0 ? '' : title.substring(i + 2).trim();
    final size = tiny ? 21.0 : (compact ? 25.0 : 29.0);
    final base = TextStyle(color: Colors.white, fontSize: size, fontWeight: FontWeight.w800, height: 1.35);
    return Column(
      children: [
        _Entrance(delay: 160, child: Text(first, textAlign: TextAlign.center, style: base)),
        if (second.isNotEmpty)
          _Entrance(
            delay: 240,
            child: Padding(
              padding: EdgeInsets.only(top: tiny ? 0 : 2),
              child: CustomPaint(
                // Yellow swoosh under the highlighted phrase.
                foregroundPainter: _SwooshPainter(),
                child: Padding(
                  padding: EdgeInsets.only(bottom: tiny ? 9 : 14),
                  child: Text(
                    second,
                    textAlign: TextAlign.center,
                    style: base.copyWith(
                      color: ZaadColors.welcomeYellow,
                      fontSize: size + 3,
                      shadows: [Shadow(color: ZaadColors.welcomeNavy.withValues(alpha: 0.35), blurRadius: 12)],
                    ),
                  ),
                ),
              ),
            ),
          ),
        SizedBox(height: tiny ? 4 : 10),
        _Entrance(
          delay: 320,
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: tiny ? 13.5 : 15.5, height: 1.6),
          ),
        ),
      ],
    );
  }
}

class _SwooshPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(w * 0.22, h - 2)
      ..quadraticBezierTo(w * 0.5, h - 10, w * 0.8, h - 5);
    canvas.drawPath(
      path,
      Paint()
        ..color = ZaadColors.welcomeYellow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Layered background: navy → royal gradient, flowing translucent waves, dot patterns, a yellow
/// crescent at the top corner, and a light floor with a yellow edge behind the illustration and
/// buttons, so the screen never reads as one flat blue block.
class _Backdrop extends StatelessWidget {
  const _Backdrop();
  @override
  Widget build(BuildContext context) {
    // Decorations sit on the end side (opposite the language pill), so mirror them in RTL.
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth, h = c.maxHeight;
        final stack = Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [ZaadColors.welcomeRoyal, Color(0xFF0D2A9E), ZaadColors.welcomeNavy],
                    stops: [0, 0.5, 1],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                ),
              ),
            ),
            // Soft electric light from the upper start and a glow behind the logo.
            Positioned(
              top: -w * 0.35,
              left: -w * 0.35,
              child: _Glow(size: w * 1.1, color: ZaadColors.welcomeElectric, alpha: 0.35),
            ),
            Positioned(
              top: h * 0.02,
              left: w * 0.15,
              child: _Glow(size: w * 0.7, color: ZaadColors.welcomeSky, alpha: 0.18),
            ),
            // Flowing waves (one drifts very slowly).
            Positioned.fill(child: CustomPaint(painter: _WavesPainter())),
            Positioned.fill(
              child: Floating(
                amplitude: 6,
                period: const Duration(seconds: 9),
                child: CustomPaint(painter: _DriftWavePainter()),
              ),
            ),
            // Dot patterns.
            Positioned(top: h * 0.14, right: w * 0.05, child: const _Dots(rows: 3, cols: 5)),
            Positioned(top: h * 0.5, left: w * 0.05, child: const _Dots(rows: 3, cols: 4, alpha: 0.18)),
            // Light floor with a yellow accent edge.
            Positioned.fill(child: CustomPaint(painter: _FloorPainter())),
          ],
        );
        return rtl ? Transform.flip(flipX: true, child: stack) : stack;
      },
    );
  }
}

class _Glow extends StatelessWidget {
  final double size;
  final Color color;
  final double alpha;
  const _Glow({required this.size, required this.color, required this.alpha});
  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0)]),
          ),
        ),
      );
}

class _Dots extends StatelessWidget {
  final int rows, cols;
  final double alpha;
  const _Dots({required this.rows, required this.cols, this.alpha = 0.28});
  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Column(children: [
          for (var r = 0; r < rows; r++)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                for (var c = 0; c < cols; c++)
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.only(right: 9),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: ZaadColors.welcomeSky.withValues(alpha: alpha * 1.8)),
                  ),
              ]),
            ),
        ]),
      );
}

/// Large translucent curves across the blue area and the yellow crescent in the top corner.
class _WavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    // Upper wave band (lighter royal).
    canvas.drawPath(
      Path()
        ..moveTo(0, h * 0.2)
        ..cubicTo(w * 0.3, h * 0.12, w * 0.55, h * 0.3, w, h * 0.22)
        ..lineTo(w, h * 0.42)
        ..cubicTo(w * 0.62, h * 0.5, w * 0.35, h * 0.34, 0, h * 0.44)
        ..close(),
      Paint()
        ..shader = LinearGradient(
          colors: [ZaadColors.welcomeElectric.withValues(alpha: 0.20), ZaadColors.welcomeRoyal.withValues(alpha: 0.05)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Offset.zero & s),
    );
    // Yellow crescent at the top corner (accent that breaks the blue).
    final c = Offset(w * 1.02, -h * 0.03);
    final r = w * 0.36;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      1.55,
      1.35,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.035
        ..strokeCap = StrokeCap.round
        ..shader = const LinearGradient(colors: [Color(0xFFFFE07A), ZaadColors.welcomeYellow, Color(0xFFF2A900)])
            .createShader(Rect.fromCircle(center: c, radius: r)),
    );
    // A thin second ring inside it.
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.8),
      1.6,
      1.25,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.25),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A soft bright-blue wave on the end side that drifts slowly (Floating wrapper).
class _DriftWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    canvas.drawPath(
      Path()
        ..moveTo(w, h * 0.38)
        ..cubicTo(w * 0.75, h * 0.42, w * 0.7, h * 0.58, w * 0.42, h * 0.6)
        ..lineTo(w, h * 0.72)
        ..close(),
      Paint()..color = ZaadColors.welcomeSky.withValues(alpha: 0.16),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The light floor: a wave-topped white → soft-gray area in the lower part, with a yellow accent
/// curve running along its start side and a soft shadow above its edge.
class _FloorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final top = h * 0.66;
    Path edge() => Path()
      ..moveTo(-10, top + h * 0.04)
      ..cubicTo(w * 0.25, top - h * 0.05, w * 0.6, top + h * 0.05, w + 10, top - h * 0.04);
    final floor = edge()
      ..lineTo(w + 10, h)
      ..lineTo(-10, h)
      ..close();
    // Depth: a soft navy shadow along the edge.
    canvas.drawPath(floor.shift(const Offset(0, -6)), Paint()
      ..color = ZaadColors.welcomeNavy.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
    canvas.drawPath(
      floor,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFDDE6FF), ZaadColors.welcomeFloor, Colors.white],
          stops: [0, 0.3, 1],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, top - h * 0.05, w, h - top + h * 0.05)),
    );
    // Yellow accent curve just above the floor on the start (left) side.
    canvas.drawPath(
      Path()
        ..moveTo(-10, top + h * 0.02)
        ..cubicTo(w * 0.12, top - h * 0.035, w * 0.28, top - h * 0.03, w * 0.42, top - h * 0.012),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..color = ZaadColors.welcomeYellow,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
                    style: TextStyle(fontWeight: e.key == lang ? FontWeight.w700 : FontWeight.w500),
                  ),
                ),
                if (e.key == lang) const Icon(Icons.check_rounded, color: ZaadColors.primary, size: 20),
              ],
            ),
          ),
      ],
      // Glass pill: translucent fill, light top edge, soft shadow.
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white.withValues(alpha: 0.22), Colors.white.withValues(alpha: 0.08)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: 0.38)),
          boxShadow: [BoxShadow(color: ZaadColors.welcomeNavy.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              names[lang] ?? lang,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Official logo (unchanged asset) on a deep disc with two faint rings and a soft electric glow.
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
            border: Border.all(color: Colors.white.withValues(alpha: a), width: 1.2),
          ),
        );
    return SizedBox(
      width: size * 1.34,
      height: size * 1.34,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _Glow(size: size * 1.6, color: ZaadColors.welcomeSky, alpha: 0.35),
          ring(size * 1.34, 0.10),
          ring(size * 1.17, 0.18),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ZaadColors.welcomeNavy,
              border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
              boxShadow: [
                BoxShadow(color: ZaadColors.welcomeElectric.withValues(alpha: 0.55), blurRadius: 34, spreadRadius: 2),
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

class _WelcomeButton extends StatelessWidget {
  final String label;
  final bool primary;
  final VoidCallback onTap;
  const _WelcomeButton({required this.label, required this.primary, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(22);
    // "Create account": white with royal text. "Log in": royal → navy gradient with a blue glow.
    final deco = BoxDecoration(
      borderRadius: r,
      color: primary ? Colors.white : null,
      gradient: primary
          ? null
          : const LinearGradient(
              colors: [ZaadColors.welcomeElectric, ZaadColors.welcomeRoyal, ZaadColors.welcomeNavy],
              stops: [0, 0.45, 1],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
      border: primary ? Border.all(color: const Color(0xFFE3E9FF)) : Border.all(color: Colors.white.withValues(alpha: 0.18)),
      boxShadow: [
        BoxShadow(
          color: primary ? ZaadColors.welcomeNavy.withValues(alpha: 0.12) : ZaadColors.welcomeElectric.withValues(alpha: 0.45),
          blurRadius: primary ? 18 : 22,
          offset: const Offset(0, 8),
        ),
      ],
    );
    return Pressable(
      onTap: onTap,
      borderRadius: r,
      semanticLabel: label,
      decoration: deco,
      // Pressed: shadow tightens as the button scales down (Pressable).
      pressedDecoration: deco.copyWith(
        boxShadow: [
          BoxShadow(
            color: primary ? ZaadColors.welcomeNavy.withValues(alpha: 0.10) : ZaadColors.welcomeElectric.withValues(alpha: 0.30),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SizedBox(
        height: 58,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: primary ? ZaadColors.welcomeRoyal : Colors.white,
              fontSize: 17.5,
              fontWeight: FontWeight.w800,
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
  final double scaleFrom;
  const _Entrance({required this.child, required this.delay, this.scaleFrom = 0.96});
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    final total = 560 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, (1 - v) * 18),
          child: Transform.scale(scale: scaleFrom + (1 - scaleFrom) * v, child: c),
        ),
      ),
      child: child,
    );
  }
}
