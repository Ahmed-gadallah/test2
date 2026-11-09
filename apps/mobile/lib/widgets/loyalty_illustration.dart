import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Soft-3D loyalty scene: phone with a loyalty card, gift box, receipt and a points coin.
///
/// Built entirely from Flutter shapes (gradients + shadows): no image file, crisp at any size,
/// works offline. Everything is laid out in a 340×230 design box and scaled to [width].
/// Direction-neutral on purpose: the scene is artwork, so it is not mirrored in RTL.
class LoyaltyIllustration extends StatelessWidget {
  final double width;
  const LoyaltyIllustration({super.key, required this.width});

  static const _w = 340.0, _h = 230.0;

  @override
  Widget build(BuildContext context) {
    final scale = width / _w;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: width,
        height: _h * scale,
        child: FittedBox(
          child: SizedBox(
            width: _w,
            height: _h,
            child: Stack(clipBehavior: Clip.none, children: const [
              // Contact shadow on the "floor".
              Positioned(left: 40, right: 30, bottom: 2, child: _FloorShadow()),
              Positioned(left: 112, top: 0, child: _Phone()),
              Positioned(left: 238, top: 66, child: _Receipt()),
              Positioned(left: 26, top: 100, child: _GiftBox()),
              Positioned(left: 192, top: 140, child: _Coin()),
              Positioned(left: 70, top: 66, child: _Confetti(angle: -0.5, size: 16)),
              Positioned(left: 88, top: 50, child: _Confetti(angle: 0.35, size: 11)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _FloorShadow extends StatelessWidget {
  const _FloorShadow();
  @override
  Widget build(BuildContext context) => Container(
        height: 26,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          gradient: RadialGradient(colors: [ZaadColors.welcomeDeep.withValues(alpha: 0.28), ZaadColors.welcomeDeep.withValues(alpha: 0)]),
        ),
      );
}

/// Tilted smartphone showing a loyalty card with a star.
class _Phone extends StatelessWidget {
  const _Phone();
  @override
  Widget build(BuildContext context) {
    Widget bar(double w, {double h = 7, double a = 0.55}) =>
        Container(width: w, height: h, decoration: BoxDecoration(color: ZaadColors.welcomeBright.withValues(alpha: a), borderRadius: BorderRadius.circular(6)));
    return Transform.rotate(
      angle: 0.12,
      child: Container(
        width: 118,
        height: 206,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(colors: [ZaadColors.welcomeBright, ZaadColors.welcomeDeep], begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: [BoxShadow(color: ZaadColors.welcomeDeep.withValues(alpha: 0.45), blurRadius: 22, offset: const Offset(6, 14))],
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(21),
            gradient: const LinearGradient(colors: [Colors.white, ZaadColors.welcomeLight], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          ),
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 34, height: 7, decoration: BoxDecoration(color: ZaadColors.welcomeDeep, borderRadius: BorderRadius.circular(6)))),
            const SizedBox(height: 12),
            // Loyalty card on screen
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: const Color(0xFFDCE0FF),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: ZaadColors.welcomeDeep.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [ZaadColors.welcomeBright, ZaadColors.primary]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.star_rounded, color: Colors.white, size: 21),
                  ),
                ),
                const SizedBox(height: 8),
                bar(76),
                const SizedBox(height: 5),
                bar(58, a: 0.35),
              ]),
            ),
            const SizedBox(height: 12),
            bar(64, a: 0.4),
            const SizedBox(height: 7),
            bar(84, a: 0.22),
            const SizedBox(height: 7),
            bar(50, a: 0.22),
          ]),
        ),
      ),
    );
  }
}

/// Gift box with a blue ribbon and bow.
class _GiftBox extends StatelessWidget {
  const _GiftBox();
  @override
  Widget build(BuildContext context) {
    const white = LinearGradient(colors: [Colors.white, Color(0xFFDDE1FA)], begin: Alignment.topLeft, end: Alignment.bottomRight);
    const ribbon = LinearGradient(colors: [ZaadColors.welcomeBright, ZaadColors.primary], begin: Alignment.topCenter, end: Alignment.bottomCenter);
    return SizedBox(
      width: 112,
      height: 110,
      child: Stack(clipBehavior: Clip.none, children: [
        // body
        Positioned(
          left: 6,
          top: 38,
          child: Container(
            width: 100,
            height: 70,
            decoration: BoxDecoration(
              gradient: white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: ZaadColors.welcomeDeep.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(4, 10))],
            ),
            child: Center(child: Container(width: 18, decoration: const BoxDecoration(gradient: ribbon))),
          ),
        ),
        // lid
        Positioned(
          left: 0,
          top: 24,
          child: Container(
            width: 112,
            height: 22,
            decoration: BoxDecoration(
              gradient: white,
              borderRadius: BorderRadius.circular(7),
              boxShadow: [BoxShadow(color: ZaadColors.welcomeDeep.withValues(alpha: 0.18), blurRadius: 6, offset: const Offset(0, 3))],
            ),
            child: Center(child: Container(width: 20, decoration: const BoxDecoration(gradient: ribbon))),
          ),
        ),
        // bow
        const Positioned(left: 20, top: 4, child: _BowLoop(angle: -0.42)),
        const Positioned(left: 58, top: 4, child: _BowLoop(angle: 0.42)),
        Positioned(
          left: 48,
          top: 18,
          child: Container(width: 16, height: 14, decoration: BoxDecoration(gradient: ribbon, borderRadius: BorderRadius.circular(5))),
        ),
      ]),
    );
  }
}

class _BowLoop extends StatelessWidget {
  final double angle;
  const _BowLoop({required this.angle});
  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: angle,
        // Solid ribbon loop with a lighter fold highlight.
        child: Container(
          width: 34,
          height: 22,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.elliptical(20, 12)),
            gradient: const LinearGradient(colors: [ZaadColors.welcomeBright, ZaadColors.primary], begin: Alignment.topCenter, end: Alignment.bottomCenter),
            boxShadow: [BoxShadow(color: ZaadColors.welcomeDeep.withValues(alpha: 0.25), blurRadius: 5, offset: const Offset(0, 3))],
          ),
          alignment: Alignment.center,
          child: Container(
            width: 16,
            height: 6,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.28), borderRadius: BorderRadius.circular(6)),
          ),
        ),
      );
}

/// Paper receipt with a zig-zag bottom edge.
class _Receipt extends StatelessWidget {
  const _Receipt();
  @override
  Widget build(BuildContext context) {
    Widget line(double w, {double a = 0.3}) =>
        Container(width: w, height: 5, margin: const EdgeInsets.only(bottom: 7), decoration: BoxDecoration(color: ZaadColors.welcomeBright.withValues(alpha: a), borderRadius: BorderRadius.circular(4)));
    return Transform.rotate(
      angle: 0.16,
      child: PhysicalShape(
        clipper: const _ReceiptClipper(),
        color: Colors.white,
        elevation: 8,
        shadowColor: ZaadColors.welcomeDeep.withValues(alpha: 0.5),
        child: Container(
          width: 74,
          height: 118,
          padding: const EdgeInsets.fromLTRB(11, 14, 11, 0),
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.white, Color(0xFFEFF1FF)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            line(36, a: 0.5),
            line(52),
            line(44),
            line(52),
            line(30),
            line(48),
          ]),
        ),
      ),
    );
  }
}

class _ReceiptClipper extends CustomClipper<Path> {
  const _ReceiptClipper();
  @override
  Path getClip(Size s) {
    const tooth = 8.0;
    final p = Path()..moveTo(0, 0)..lineTo(s.width, 0)..lineTo(s.width, s.height - tooth);
    final teeth = (s.width / tooth).floor();
    final step = s.width / teeth;
    for (var i = teeth; i > 0; i--) {
      final x = i * step;
      p.lineTo(x - step / 2, s.height);
      p.lineTo(x - step, s.height - tooth);
    }
    return p..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> old) => false;
}

/// Points coin with a star, with a darker rim for depth.
class _Coin extends StatelessWidget {
  const _Coin();
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 74,
        height: 78,
        child: Stack(children: [
          // rim (thickness)
          Positioned(
            top: 6,
            child: Container(
              width: 74,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ZaadColors.welcomeDeep,
                boxShadow: [BoxShadow(color: ZaadColors.welcomeDeep.withValues(alpha: 0.45), blurRadius: 14, offset: const Offset(3, 8))],
              ),
            ),
          ),
          // face
          Container(
            width: 74,
            height: 72,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [ZaadColors.welcomeBright, ZaadColors.primary], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: Center(
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2)),
                child: const Icon(Icons.star_rounded, color: Colors.white, size: 36),
              ),
            ),
          ),
        ]),
      );
}

/// Small paper-confetti triangle.
class _Confetti extends StatelessWidget {
  final double angle;
  final double size;
  const _Confetti({required this.angle, required this.size});
  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: angle,
        child: CustomPaint(size: Size(size, size), painter: _TrianglePainter()),
      );
}

class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final path = Path()..moveTo(0, 0)..lineTo(s.width, s.height / 2)..lineTo(0, s.height)..close();
    canvas.drawPath(path, Paint()..shader = const LinearGradient(colors: [Colors.white, ZaadColors.welcomeLight]).createShader(Offset.zero & s));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Exposed for tests: the illustration's aspect ratio.
const double loyaltyIllustrationAspect = LoyaltyIllustration._w / LoyaltyIllustration._h;

