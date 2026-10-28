import 'dart:math';

import 'package:flutter/material.dart';

import 'pip_face.dart';

/// Full-screen "DICE ZEE!" moment. A glowing stage rises over the table, the
/// five winning dice pop in, the title drops in letter by letter, and
/// fireworks and confetti play behind it. Touch-transparent; calls [onDone]
/// once when the show ends so the owner can remove it.
class DiceZeeCelebration extends StatefulWidget {
  const DiceZeeCelebration({
    super.key,
    required this.face,
    required this.accent,
    required this.name,
    required this.points,
    required this.onDone,
    this.random,
  });

  /// The face all five dice show (1..6).
  final int face;

  /// The rolling player's seat colour; tints the stage and the dice pips.
  final Color accent;

  /// The rolling player's display name.
  final String name;

  /// What the roll is worth in the Dice Zee category.
  final int points;

  final VoidCallback onDone;

  /// Seed source for the bursts, confetti and cheer; injected in tests.
  final Random? random;

  static const duration = Duration(milliseconds: 3800);

  @override
  State<DiceZeeCelebration> createState() => _DiceZeeCelebrationState();
}

const _gold = Color(0xFFFFC83D);
const _night = Color(0xFF110A2B);

const _cheers = [
  'Unreal. Absolutely unreal.',
  'Luck? Skill? Who cares.',
  'The dice bow to you.',
  'Legendary roll.',
  'Frame this moment.',
  'Five of a kind. Chef\'s kiss.',
];

class _DiceZeeCelebrationState extends State<DiceZeeCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: DiceZeeCelebration.duration)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) widget.onDone();
        })
        ..forward();

  late final Random _rng = widget.random ?? Random();
  late final List<_Burst> _bursts = _Burst.generate(_rng, widget.accent);
  late final List<_Confetto> _confetti = _Confetto.generate(
    _rng,
    widget.accent,
  );
  late final String _cheer = _cheers[_rng.nextInt(_cheers.length)];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Progress of the [begin]..[end] slice of the show, clamped to 0..1.
  static double _slice(double t, double begin, double end) =>
      ((t - begin) / (end - begin)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final stageColor = Color.lerp(_night, widget.accent, 0.28)!;
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            final fadeIn = Curves.easeOut.transform(_slice(t, 0, 0.08));
            final fadeOut = 1 - _slice(t, 0.88, 1);
            final stage = fadeIn * fadeOut;
            return Opacity(
              opacity: fadeOut,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.1),
                        radius: 1.05,
                        colors: [
                          stageColor.withValues(alpha: 0.96 * fadeIn),
                          _night.withValues(alpha: 0.98 * fadeIn),
                        ],
                      ),
                    ),
                  ),
                  CustomPaint(painter: _RaysPainter(t, stage)),
                  CustomPaint(painter: _FireworksPainter(_bursts, t)),
                  CustomPaint(painter: _ConfettiPainter(_confetti, t)),
                  _Hero(
                    t: t,
                    face: widget.face,
                    accent: widget.accent,
                    name: widget.name,
                    points: widget.points,
                    cheer: _cheer,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.t,
    required this.face,
    required this.accent,
    required this.name,
    required this.points,
    required this.cheer,
  });

  final double t;
  final int face;
  final Color accent;
  final String name;
  final int points;
  final String cheer;

  static const _title = 'DICE ZEE';

  double _pop(double begin, double end) => Curves.elasticOut.transform(
    _DiceZeeCelebrationState._slice(t, begin, end),
  );

  double _fade(double begin, double end) =>
      Curves.easeOut.transform(_DiceZeeCelebrationState._slice(t, begin, end));

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final dieSize = ((width - 64) / 5.6).clamp(40.0, 72.0);
    final titleSize = (width / 5.2).clamp(48.0, 96.0);

    return Semantics(
      label: 'Dice Zee! $name rolled five ${face}s for $points points',
      child: ExcludeSemantics(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(
                  opacity: _fade(0.06, 0.18),
                  child: Text(
                    '${name.toUpperCase()} ROLLED',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 5; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Transform.scale(
                          scale: _pop(0.06 + i * 0.035, 0.30 + i * 0.035),
                          child: Transform.rotate(
                            angle: (i.isEven ? -1 : 1) * 0.06,
                            child: _DieTile(
                              face: face,
                              size: dieSize,
                              pip: accent,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 28),
                _GoldText(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < _title.length; i++)
                        _Letter(
                          char: _title[i],
                          size: titleSize,
                          progress: _DiceZeeCelebrationState._slice(
                            t,
                            0.18 + i * 0.030,
                            0.42 + i * 0.030,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Transform.scale(
                  scale: _pop(0.46, 0.62),
                  child: _PointsPill(points: points),
                ),
                const SizedBox(height: 22),
                Opacity(
                  opacity: _fade(0.54, 0.68),
                  child: Text(
                    cheer,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fills its child with a warm white-to-gold gradient.
class _GoldText extends StatelessWidget {
  const _GoldText({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, Color(0xFFFFE08A), _gold],
      ).createShader(rect),
      child: child,
    );
  }
}

/// One title letter, dropping in from above with a bounce.
class _Letter extends StatelessWidget {
  const _Letter({
    required this.char,
    required this.size,
    required this.progress,
  });

  final String char;
  final double size;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final drop = Curves.bounceOut.transform(progress);
    return Opacity(
      opacity: Curves.easeOut.transform((progress * 3).clamp(0.0, 1.0)),
      child: Transform.translate(
        offset: Offset(0, -size * 1.2 * (1 - drop)),
        child: Text(
          char == ' ' ? ' ' : char,
          style: TextStyle(
            color: Colors.white,
            fontSize: size,
            fontWeight: FontWeight.w900,
            height: 1,
            letterSpacing: size * 0.02,
            shadows: [
              Shadow(
                color: _gold.withValues(alpha: 0.55),
                blurRadius: size * 0.35,
              ),
              const Shadow(
                color: Color(0x66000000),
                blurRadius: 6,
                offset: Offset(0, 4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DieTile extends StatelessWidget {
  const _DieTile({required this.face, required this.size, required this.pip});

  final int face;
  final double size;
  final Color pip;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.24),
        boxShadow: [
          BoxShadow(
            color: _gold.withValues(alpha: 0.6),
            blurRadius: 22,
            spreadRadius: 1,
          ),
        ],
      ),
      child: PipFace(value: face, color: pip, size: size),
    );
  }
}

class _PointsPill extends StatelessWidget {
  const _PointsPill({required this.points});

  final int points;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        gradient: const LinearGradient(colors: [Color(0xFFFFE08A), _gold]),
        boxShadow: [
          BoxShadow(color: _gold.withValues(alpha: 0.5), blurRadius: 20),
        ],
      ),
      child: Text(
        '+$points POINTS',
        style: const TextStyle(
          color: _night,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

/// Slowly turning sunburst behind the hero.
class _RaysPainter extends CustomPainter {
  _RaysPainter(this.t, this.stage);

  final double t;
  final double stage;

  static const _count = 14;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.45);
    final radius = size.longestSide;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          _gold.withValues(alpha: 0.30 * stage),
          _gold.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.7));
    final spin = t * pi * 0.6;
    const half = pi / _count / 2;
    for (var i = 0; i < _count; i++) {
      final a = spin + i * 2 * pi / _count;
      canvas.drawPath(
        Path()
          ..moveTo(center.dx, center.dy)
          ..lineTo(
            center.dx + cos(a - half) * radius,
            center.dy + sin(a - half) * radius,
          )
          ..lineTo(
            center.dx + cos(a + half) * radius,
            center.dy + sin(a + half) * radius,
          )
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RaysPainter old) => old.t != t || old.stage != stage;
}

class _Spark {
  const _Spark({required this.angle, required this.speed});

  final double angle;

  /// Travel distance as a fraction of the screen's shorter side.
  final double speed;
}

class _Burst {
  const _Burst({
    required this.start,
    required this.center,
    required this.color,
    required this.sparks,
  });

  /// When it launches, as a fraction of the whole show.
  final double start;

  /// Burst point as a fraction of the screen size.
  final Offset center;
  final Color color;
  final List<_Spark> sparks;

  static List<_Burst> generate(Random rng, Color accent) {
    final palette = [
      _gold,
      Colors.white,
      Color.lerp(accent, Colors.white, 0.45)!,
      const Color(0xFFFF5C8A),
      const Color(0xFF5CE1FF),
      const Color(0xFFB388FF),
    ];
    return [
      for (var i = 0; i < 9; i++)
        _Burst(
          start: 0.10 + i * 0.075 + rng.nextDouble() * 0.03,
          center: Offset(
            0.10 + rng.nextDouble() * 0.80,
            0.10 + rng.nextDouble() * 0.55,
          ),
          color: palette[i % palette.length],
          sparks: [
            for (var s = 0; s < 64; s++)
              _Spark(
                angle: s / 64 * 2 * pi + rng.nextDouble() * 0.08,
                // Two rings of sparks give each burst some depth.
                speed: (s.isEven ? 0.20 : 0.32) + rng.nextDouble() * 0.06,
              ),
          ],
        ),
    ];
  }
}

/// Glowing additive fireworks: a rocket climbs, then bursts into sparks that
/// leave fading trails and sag under gravity.
class _FireworksPainter extends CustomPainter {
  _FireworksPainter(this.bursts, this.t);

  final List<_Burst> bursts;
  final double t;

  /// Fraction of the show each burst lives for.
  static const _life = 0.30;

  /// Share of a burst's life spent as a rising rocket.
  static const _climb = 0.22;

  static const _trail = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final reach = size.shortestSide;
    final glow = Paint()
      ..blendMode = BlendMode.plus
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final core = Paint()..blendMode = BlendMode.plus;

    for (final burst in bursts) {
      final age = (t - burst.start) / _life;
      if (age < 0 || age > 1) continue;
      final target = Offset(
        burst.center.dx * size.width,
        burst.center.dy * size.height,
      );

      if (age < _climb) {
        final k = Curves.easeOut.transform(age / _climb);
        final at = Offset.lerp(Offset(target.dx, size.height), target, k)!;
        core.color = Colors.white.withValues(alpha: 0.9);
        canvas.drawCircle(at, 2.5, core);
        continue;
      }

      final a = (age - _climb) / (1 - _climb);
      for (final spark in burst.sparks) {
        final dir = Offset(cos(spark.angle), sin(spark.angle));
        for (var i = 0; i < _trail; i++) {
          final back = i / _trail * 0.16;
          final ta = (a - back).clamp(0.0, 1.0);
          final dist = spark.speed * reach * Curves.easeOutCubic.transform(ta);
          final p = target + dir * dist + Offset(0, 0.10 * reach * ta * ta);
          final fade = (1 - a) * (1 - i / _trail);
          final radius = (1 - a * 0.6) * 4.2 * (1 - i / _trail * 0.6);
          glow.color = burst.color.withValues(alpha: 0.55 * fade);
          core.color = Color.lerp(
            burst.color,
            Colors.white,
            0.5,
          )!.withValues(alpha: fade);
          if (i == 0) canvas.drawCircle(p, radius * 2.2, glow);
          canvas.drawCircle(p, radius, core);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_FireworksPainter old) => old.t != t;
}

class _Confetto {
  const _Confetto({
    required this.x,
    required this.start,
    required this.fall,
    required this.sway,
    required this.spin,
    required this.color,
    required this.size,
  });

  final double x;
  final double start;
  final double fall;
  final double sway;
  final double spin;
  final Color color;
  final double size;

  static List<_Confetto> generate(Random rng, Color accent) {
    final palette = [
      _gold,
      Colors.white,
      Color.lerp(accent, Colors.white, 0.4)!,
      const Color(0xFFFF5C8A),
      const Color(0xFF5CE1FF),
    ];
    return [
      for (var i = 0; i < 70; i++)
        _Confetto(
          x: rng.nextDouble(),
          start: 0.22 + rng.nextDouble() * 0.30,
          fall: 0.45 + rng.nextDouble() * 0.35,
          sway: 0.02 + rng.nextDouble() * 0.04,
          spin: (rng.nextDouble() * 6 + 2) * (rng.nextBool() ? 1 : -1),
          color: palette[rng.nextInt(palette.length)],
          size: 6 + rng.nextDouble() * 6,
        ),
    ];
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.confetti, this.t);

  final List<_Confetto> confetti;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final c in confetti) {
      final age = t - c.start;
      if (age < 0) continue;
      final k = (age / (1 - c.start)).clamp(0.0, 1.0);
      final y = -20 + (size.height + 40) * k * c.fall * 1.6;
      if (y > size.height + 20) continue;
      final x = c.x * size.width + sin(age * 14) * c.sway * size.width;
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(age * c.spin * 3)
        // Flip the width over time so each piece flutters edge-on.
        ..scale(cos(age * c.spin * 5).abs().clamp(0.15, 1.0), 1);
      paint.color = c.color;
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: c.size,
          height: c.size * 0.6,
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
