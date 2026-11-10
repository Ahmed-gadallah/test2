import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Decorative artwork drawn in code (no image assets, so it stays sharp and light).
/// Everything here is decoration only: it never shows data.

/// A gold coin with a rim and a soft highlight.
class GoldCoin extends StatelessWidget {
  final double size;
  const GoldCoin({super.key, this.size = 26});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: ZaadGradients.gold,
      border: Border.all(color: const Color(0xFFFFE39A), width: size * 0.07),
      boxShadow: [BoxShadow(color: const Color(0x66B87800), blurRadius: size * 0.5, offset: Offset(0, size * 0.18))],
    ),
    child: Center(
      child: Container(
        width: size * 0.5,
        height: size * 0.5,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0x99B87800), width: size * 0.05),
        ),
      ),
    ),
  );
}

/// Gentle, endless up-down float for small decorative elements (one cheap controller).
/// Stops automatically when the screen is off-stage (TickerMode) and under "reduce motion".
class Floating extends StatefulWidget {
  final Widget child;
  final double amplitude;
  final Duration period;
  final double phase; // 0..1, so siblings don't move in lockstep
  const Floating({
    super.key,
    required this.child,
    this.amplitude = 5,
    this.period = const Duration(milliseconds: 3200),
    this.phase = 0,
  });
  @override
  State<Floating> createState() => _FloatingState();
}

class _FloatingState extends State<Floating> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.period);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.of(context).disableAnimations;
    if (reduce) {
      _c.stop();
    } else if (!_started) {
      _started = true;
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, c) {
      final t = (_c.value + widget.phase) * 2 * math.pi;
      return Transform.translate(offset: Offset(0, math.sin(t) * widget.amplitude), child: c);
    },
    child: widget.child,
  );
}

/// A soft diagonal light that sweeps across its child now and then (light reflection on the card).
class LightSweep extends StatefulWidget {
  final Widget child;
  final BorderRadius borderRadius;
  const LightSweep({super.key, required this.child, required this.borderRadius});
  @override
  State<LightSweep> createState() => _LightSweepState();
}

class _LightSweepState extends State<LightSweep> with SingleTickerProviderStateMixin {
  // 1.4 s sweep followed by a long rest: the controller runs 7 s, the light moves in the first 20%.
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 7));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.stop();
    } else if (!_started) {
      _started = true;
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      widget.child,
      Positioned.fill(
        child: IgnorePointer(
          child: ClipRRect(
            borderRadius: widget.borderRadius,
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, _) {
                final p = (_c.value / 0.2).clamp(0.0, 1.0);
                if (p == 0 || p == 1) return const SizedBox.shrink();
                final x = -1.6 + Curves.easeInOut.transform(p) * 3.2;
                return DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(x - 0.5, -1),
                      end: Alignment(x + 0.5, 1),
                      colors: [
                        Colors.white.withValues(alpha: 0),
                        Colors.white.withValues(alpha: 0.16),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ],
  );
}

/// Loyalty art for the points card: the official logo on a tilted card, resting on a glowing
/// pedestal, with gold coins floating around it.
class LoyaltyArt extends StatelessWidget {
  final double size;
  const LoyaltyArt({super.key, this.size = 150});
  @override
  Widget build(BuildContext context) {
    final s = size;
    return SizedBox(
      width: s,
      height: s,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Pedestal: three stacked ellipses with a cool glow.
          Positioned(
            bottom: s * 0.04,
            child: Container(
              width: s * 0.92,
              height: s * 0.2,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.elliptical(s * 0.46, s * 0.1)),
                gradient: const LinearGradient(
                  colors: [Color(0xFF2B37D9), Color(0xFF1A1FA8)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6F8BFF).withValues(alpha: 0.55),
                    blurRadius: s * 0.18,
                    spreadRadius: -s * 0.02,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: s * 0.13,
            child: Container(
              width: s * 0.7,
              height: s * 0.14,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.elliptical(s * 0.35, s * 0.07)),
                gradient: const LinearGradient(
                  colors: [Color(0xFF5D6BFF), Color(0xFF2A33C8)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1),
              ),
            ),
          ),
          // The card with the official logo.
          Positioned(
            bottom: s * 0.2,
            child: Floating(
              amplitude: s * 0.025,
              child: Transform.rotate(
                angle: -0.22,
                child: Container(
                  width: s * 0.58,
                  height: s * 0.46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(s * 0.08),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4554FF), Color(0xFF1B21B8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: s * 0.12,
                        offset: Offset(0, s * 0.06),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    padding: EdgeInsets.all(s * 0.012),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: ClipOval(
                      child: Image.asset('assets/brand/zaad_logo.png', width: s * 0.27, height: s * 0.27),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Floating coins.
          PositionedDirectional(
            top: s * 0.08,
            start: s * 0.02,
            child: Floating(phase: 0.3, amplitude: 4, child: GoldCoin(size: s * 0.16)),
          ),
          PositionedDirectional(
            top: s * 0.36,
            end: -s * 0.02,
            child: Floating(phase: 0.65, amplitude: 5, child: GoldCoin(size: s * 0.13)),
          ),
          PositionedDirectional(
            top: s * 0.02,
            end: s * 0.2,
            child: Floating(phase: 0.1, amplitude: 3, child: _Bubble(size: s * 0.07)),
          ),
          PositionedDirectional(
            bottom: s * 0.42,
            start: s * 0.0,
            child: Floating(phase: 0.8, amplitude: 3, child: _Bubble(size: s * 0.05)),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final double size;
  const _Bubble({required this.size});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.22)),
  );
}

/// Shopping bag with the official logo and a gold % tag (promotional banner fallback art when an
/// offer has no image of its own).
class ShoppingBagArt extends StatelessWidget {
  final double size;
  const ShoppingBagArt({super.key, this.size = 120});
  @override
  Widget build(BuildContext context) {
    final s = size;
    return SizedBox(
      width: s,
      height: s,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // Handle: a thin arc behind the bag's top edge.
          Positioned(
            top: s * 0.06,
            child: Container(
              width: s * 0.4,
              height: s * 0.4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: s * 0.03),
              ),
            ),
          ),
          // Bag body.
          Positioned(
            bottom: s * 0.04,
            child: Container(
              width: s * 0.66,
              height: s * 0.66,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(s * 0.08),
                gradient: const LinearGradient(
                  colors: [Color(0xFF4A58FF), ZaadColors.primary, Color(0xFF15199E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: ZaadColors.primary.withValues(alpha: 0.45),
                    blurRadius: s * 0.16,
                    offset: Offset(0, s * 0.08),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Top fold and a darker side panel suggest depth.
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: s * 0.09,
                    child: ColoredBox(color: Colors.white.withValues(alpha: 0.16)),
                  ),
                  PositionedDirectional(
                    top: 0,
                    bottom: 0,
                    end: 0,
                    width: s * 0.14,
                    child: ColoredBox(color: Colors.black.withValues(alpha: 0.14)),
                  ),
                  // Handle rivets.
                  PositionedDirectional(
                    top: s * 0.13,
                    start: s * 0.14,
                    child: _Rivet(size: s * 0.04),
                  ),
                  PositionedDirectional(
                    top: s * 0.13,
                    end: s * 0.14,
                    child: _Rivet(size: s * 0.04),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: s * 0.06),
                    child: Container(
                      padding: EdgeInsets.all(s * 0.012),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: ClipOval(
                        child: Image.asset('assets/brand/zaad_logo.png', width: s * 0.3, height: s * 0.3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Gold % tag.
          PositionedDirectional(
            top: s * 0.2,
            start: -s * 0.02,
            child: Floating(
              amplitude: 3,
              phase: 0.4,
              child: Transform.rotate(
                angle: 0.25,
                child: Container(
                  width: s * 0.26,
                  height: s * 0.26,
                  decoration: BoxDecoration(
                    gradient: ZaadGradients.gold,
                    borderRadius: BorderRadius.circular(s * 0.06),
                    boxShadow: [
                      BoxShadow(color: const Color(0x55B87800), blurRadius: s * 0.08, offset: Offset(0, s * 0.03)),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '%',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: s * 0.16, height: 1),
                  ),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            top: s * 0.1,
            end: s * 0.04,
            child: Floating(amplitude: 3, phase: 0.1, child: GoldCoin(size: s * 0.12)),
          ),
        ],
      ),
    );
  }
}

class _Rivet extends StatelessWidget {
  final double size;
  const _Rivet({required this.size});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.85)),
  );
}
