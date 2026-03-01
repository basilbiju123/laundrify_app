import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:audioplayers/audioplayers.dart';

// ═══════════════════════════════════════════════════════════════════
// SPLASH PAGE — Animated logo + Sound effects
//
// SETUP:
//   1. Add to pubspec.yaml:
//        dependencies:
//          audioplayers: ^6.1.0
//
//   2. Create assets/sounds/ folder in your project root.
//
//   3. Add these lines to pubspec.yaml flutter section:
//        flutter:
//          assets:
//            - assets/sounds/
//
//   4. Drop these two sound files into assets/sounds/:
//        • splash_logo.wav  — short "whoosh + pop" (logo appears)   ~0.4s
//        • splash_drop.wav  — gentle water drop sound (arcs fan out) ~0.5s
//
//   Free sounds to use (search on freesound.org or mixkit.co):
//        • "Logo whoosh" / "magic appear" for splash_logo.wav
//        • "Water drop" / "drip" for splash_drop.wav
// ═══════════════════════════════════════════════════════════════════

class SplashPage extends StatefulWidget {
  final VoidCallback onFinished;
  const SplashPage({super.key, required this.onFinished});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with TickerProviderStateMixin {

  // ── Audio ──────────────────────────────────────────────────────
  final AudioPlayer _sfxLogo  = AudioPlayer();
  final AudioPlayer _sfxDrop  = AudioPlayer();

  // — Logo entry
  late AnimationController _logoCtrl;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _logoRotate;

  // — Text entry
  late AnimationController _textCtrl;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;
  late Animation<double> _tagFade;

  // — Water ripple / bubble ambient
  late AnimationController _rippleCtrl;
  late Animation<double> _ripple;

  // — Shirt bounce
  late AnimationController _shirtCtrl;
  late Animation<double> _shirtBounce;

  // — Water splash arcs
  late AnimationController _splashCtrl;
  late Animation<double> _splashArc;

  // — Bubbles float
  late AnimationController _bubblesCtrl;

  // — Progress / exit
  late AnimationController _exitCtrl;
  late Animation<double> _exitFade;

  @override
  void initState() {
    super.initState();

    // ── Configure audio players ──────────────────────────────────
    _sfxLogo.setVolume(0.85);
    _sfxDrop.setVolume(0.7);
    // Release mode: prevent audio from routing through earpiece on iOS
    _sfxLogo.setPlayerMode(PlayerMode.lowLatency);
    _sfxDrop.setPlayerMode(PlayerMode.lowLatency);

    // Logo entrance: scale+fade+slight rotation
    _logoCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _logoScale  = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));
    _logoFade   = CurvedAnimation(parent: _logoCtrl, curve: const Interval(0.0, 0.5, curve: Curves.easeOut));
    _logoRotate = Tween<double>(begin: -0.15, end: 0.0).animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutBack));

    // Text slides up after logo
    _textCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _textFade  = CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut);
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic));
    _tagFade = CurvedAnimation(parent: _textCtrl, curve: const Interval(0.4, 1.0, curve: Curves.easeOut));

    // Ripple: continuous pulsing glow
    _rippleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(reverse: true);
    _ripple = CurvedAnimation(parent: _rippleCtrl, curve: Curves.easeInOut);

    // Shirt gentle bounce
    _shirtCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
    _shirtBounce = Tween<double>(begin: -4.0, end: 4.0).animate(CurvedAnimation(parent: _shirtCtrl, curve: Curves.easeInOut));

    // Splash arc: fan out after logo appears
    _splashCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _splashArc  = CurvedAnimation(parent: _splashCtrl, curve: Curves.easeOutCubic);

    // Bubbles float up
    _bubblesCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat();

    // Exit fade
    _exitCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn));

    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    // 🔊 Sound 1: Logo whoosh as logo pops in
    _playSound(_sfxLogo, 'sounds/splash_logo.wav');

    // Logo pops in
    _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    // 🔊 Sound 2: Water drop as splash arcs fan out
    _playSound(_sfxDrop, 'sounds/splash_drop.wav');

    // Splash arcs fan out
    _splashCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    // Text slides up
    _textCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;

    // Exit
    _exitCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) widget.onFinished();
  }

  /// Plays an asset sound safely — if the file doesn't exist yet, silently ignores.
  Future<void> _playSound(AudioPlayer player, String assetPath) async {
    // Web: audioplayers AssetSource needs the file served with correct MIME type.
    // Use DeviceFileSource via a data URI instead — or skip if not supported.
    // For web we use a separate HTML audio approach; for mobile/desktop use AssetSource.
    if (kIsWeb) {
      try {
        await player.play(AssetSource(assetPath));
      } catch (_) {
        // Web audio may fail silently — animation continues regardless.
      }
      return;
    }
    try {
      await player.play(AssetSource(assetPath));
    } catch (_) {
      // Sound file not found or platform issue — fail silently.
    }
  }

  @override
  void dispose() {
    _sfxLogo.dispose();
    _sfxDrop.dispose();
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _rippleCtrl.dispose();
    _shirtCtrl.dispose();
    _splashCtrl.dispose();
    _bubblesCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _exitFade,
      builder: (_, child) => Opacity(opacity: _exitFade.value, child: child),
      child: Scaffold(
        backgroundColor: const Color(0xFF0A1628),
        body: Stack(
          children: [
            // ── Deep radial background gradient ──────────────
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -0.2),
                    radius: 1.2,
                    colors: [
                      Color(0xFF0D2145),
                      Color(0xFF080F1E),
                    ],
                  ),
                ),
              ),
            ),

            // ── Ambient floating bubbles ──────────────────────
            AnimatedBuilder(
              animation: _bubblesCtrl,
              builder: (_, __) => CustomPaint(
                painter: _BubblesPainter(_bubblesCtrl.value),
                size: Size.infinite,
              ),
            ),

            // ── Center content ────────────────────────────────
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  // ── Logo assembly ─────────────────────────
                  AnimatedBuilder(
                    animation: Listenable.merge([_logoCtrl, _ripple, _shirtBounce, _splashArc]),
                    builder: (_, __) => SizedBox(
                      width: 200,
                      height: 200,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [

                          // Outer pulsing glow ring
                          Opacity(
                            opacity: (_logoFade.value * 0.4 * (0.5 + 0.5 * _ripple.value)).clamp(0.0, 1.0),
                            child: Container(
                              width: 180 + 20 * _ripple.value,
                              height: 180 + 20 * _ripple.value,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    const Color(0xFF1B6EF3).withValues(alpha: 0.3),
                                    const Color(0xFF1B6EF3).withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Splash arcs (water splashes) — custom paint
                          Opacity(
                            opacity: _splashArc.value,
                            child: CustomPaint(
                              painter: _SplashArcPainter(_splashArc.value),
                              size: const Size(200, 200),
                            ),
                          ),

                          // Logo background circle
                          Transform.scale(
                            scale: _logoScale.value,
                            child: Container(
                              width: 130,
                              height: 130,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Color(0xFF1B6EF3), Color(0xFF0A3BAD)],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF1B6EF3).withValues(alpha: 0.5),
                                    blurRadius: 30 + 10 * _ripple.value,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Animated shirt icon (with bounce)
                          Opacity(
                            opacity: _logoFade.value,
                            child: Transform(
                              transform: Matrix4.identity()
                                ..translateByDouble(0.0, _shirtBounce.value, 0.0, 1.0)
                                ..rotateZ(_logoRotate.value),
                              alignment: Alignment.center,
                              child: _buildShirtLogo(),
                            ),
                          ),

                          // Water droplets orbiting (small circles)
                          ...List.generate(5, (i) {
                            final angle = (i / 5) * 2 * math.pi + _rippleCtrl.value * 0.4;
                            final radius = 74.0;
                            final x = radius * math.cos(angle);
                            final y = radius * math.sin(angle);
                            final sz = (i % 3 == 0) ? 6.0 : (i % 3 == 1) ? 4.0 : 3.0;
                            return Positioned(
                              left: 100 + x - sz / 2,
                              top: 100 + y - sz / 2,
                              child: Opacity(
                                opacity: _logoFade.value * 0.8,
                                child: Container(
                                  width: sz,
                                  height: sz,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── LAUNDRIFY text ─────────────────────────
                  FadeTransition(
                    opacity: _textFade,
                    child: SlideTransition(
                      position: _textSlide,
                      child: Column(
                        children: [
                          // Brand name — letter-spaced bold
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Colors.white, Color(0xFF7BB8FF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds),
                            child: const Text(
                              'LAUNDRIFY',
                              style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Tagline
                          FadeTransition(
                            opacity: _tagFade,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 24,
                                  height: 1.5,
                                  color: const Color(0xFF4A90D9).withValues(alpha: 0.6),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Clean clothes, delivered.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF7BB8FF),
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  width: 24,
                                  height: 1.5,
                                  color: const Color(0xFF4A90D9).withValues(alpha: 0.6),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 60),

                  // ── Loading bar ────────────────────────────
                  FadeTransition(
                    opacity: _textFade,
                    child: AnimatedBuilder(
                      animation: _rippleCtrl,
                      builder: (_, __) => Container(
                        width: 120,
                        height: 3,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B4FD8).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: AnimatedBuilder(
                            animation: _textCtrl,
                            builder: (_, __) => FractionallySizedBox(
                              widthFactor: _textCtrl.value,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF1B6EF3), Color(0xFF7BB8FF)],
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF1B6EF3).withValues(alpha: 0.6),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // — Draw a shirt icon using Canvas-style widgets ——————————————
  Widget _buildShirtLogo() {
    return SizedBox(
      width: 80,
      height: 80,
      child: CustomPaint(
        painter: _ShirtPainter(),
      ),
    );
  }
}

// ─── Custom Painters ──────────────────────────────────────────────

/// Draws a simplified shirt/tee icon with water effect
class _ShirtPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Shirt body
    final body = Path()
      ..moveTo(w * 0.25, h * 0.22)
      ..lineTo(w * 0.05, h * 0.42)
      ..lineTo(w * 0.18, h * 0.46)
      ..lineTo(w * 0.18, h * 0.90)
      ..lineTo(w * 0.82, h * 0.90)
      ..lineTo(w * 0.82, h * 0.46)
      ..lineTo(w * 0.95, h * 0.42)
      ..lineTo(w * 0.75, h * 0.22)
      // Collar right
      ..quadraticBezierTo(w * 0.70, h * 0.18, w * 0.60, h * 0.22)
      ..quadraticBezierTo(w * 0.50, h * 0.28, w * 0.40, h * 0.22)
      ..quadraticBezierTo(w * 0.30, h * 0.18, w * 0.25, h * 0.22)
      ..close();
    canvas.drawPath(body, paint);

    // Water drip detail
    final dropPaint = Paint()
      ..color = const Color(0xFF7BB8FF).withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.62, h * 0.55), w * 0.06, dropPaint);
    canvas.drawCircle(Offset(w * 0.72, h * 0.45), w * 0.04, dropPaint);
    canvas.drawCircle(Offset(w * 0.78, h * 0.60), w * 0.03, dropPaint);
  }

  @override
  bool shouldRepaint(_ShirtPainter old) => false;
}

/// Draws animated water splash arcs around the logo
class _SplashArcPainter extends CustomPainter {
  final double progress;
  _SplashArcPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Draw 4 splash arcs at different angles
    final splashAngles = [math.pi * 0.3, math.pi * 0.7, math.pi * 1.1, math.pi * 1.6];
    for (int i = 0; i < splashAngles.length; i++) {
      final angle = splashAngles[i];
      final delay = i * 0.15;
      final p = ((progress - delay) / (1.0 - delay)).clamp(0.0, 1.0);
      if (p <= 0) continue;

      final length = 28.0 * p;
      final startR = 70.0;
      final endR = startR + length;
      final width = (3.0 * (1 - p * 0.5)).clamp(1.0, 4.0);
      final opacity = (p * (1 - p * 0.3)).clamp(0.0, 0.85);

      final paint = Paint()
        ..color = const Color(0xFF4A9EFF).withValues(alpha: opacity)
        ..strokeWidth = width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      // Arc-like splash: curve outward
      final path = Path();
      final x1 = cx + startR * math.cos(angle);
      final y1 = cy + startR * math.sin(angle);
      final x2 = cx + endR * math.cos(angle - 0.2);
      final y2 = cy + endR * math.sin(angle - 0.2);
      final cpx = cx + (startR + length * 0.6) * math.cos(angle - 0.1);
      final cpy = cy + (startR + length * 0.6) * math.sin(angle - 0.1);
      path.moveTo(x1, y1);
      path.quadraticBezierTo(cpx, cpy, x2, y2);
      canvas.drawPath(path, paint);

      // Droplet at tip
      final dropPaint = Paint()
        ..color = const Color(0xFF7BB8FF).withValues(alpha: opacity * 0.7)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x2, y2), width * 0.8, dropPaint);
    }
  }

  @override
  bool shouldRepaint(_SplashArcPainter old) => old.progress != progress;
}

/// Floating ambient bubbles in background
class _BubblesPainter extends CustomPainter {
  final double t;
  _BubblesPainter(this.t);

  static final List<_Bubble> _bubbles = List.generate(18, (i) {
    final rng = math.Random(i * 31 + 7);
    return _Bubble(
      x: rng.nextDouble(),
      baseY: rng.nextDouble(),
      size: 2.0 + rng.nextDouble() * 5,
      speed: 0.15 + rng.nextDouble() * 0.35,
      opacity: 0.08 + rng.nextDouble() * 0.18,
      phase: rng.nextDouble(),
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final b in _bubbles) {
      final progress = ((t * b.speed + b.phase) % 1.0);
      final y = size.height * (1.0 - progress) - b.size;
      final x = size.width * b.x + math.sin(progress * math.pi * 3 + b.phase * 6) * 12;
      paint.color = const Color(0xFF4A90D9).withValues(alpha: b.opacity * (1 - (progress > 0.8 ? (progress - 0.8) * 5 : 0)));
      canvas.drawCircle(Offset(x, y), b.size / 2, paint);
    }
  }

  @override
  bool shouldRepaint(_BubblesPainter old) => old.t != t;
}

class _Bubble {
  final double x, baseY, size, speed, opacity, phase;
  const _Bubble({required this.x, required this.baseY, required this.size, required this.speed, required this.opacity, required this.phase});
}
