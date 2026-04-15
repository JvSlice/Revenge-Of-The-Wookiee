import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../config/game_config.dart';
import '../game/helpers.dart';
import '../models/enemy.dart';
import '../models/enemy_projectile.dart';
import '../models/game_types.dart';
import '../models/shot_trace.dart';

class RedwoodPainter extends CustomPainter {
  RedwoodPainter({
    required this.size,
    required this.enemies,
    required this.enemyProjectiles,
    required this.traces,
    required this.playerX,
    required this.bobTime,
    this.worldZ = 0.0,
    required this.state,
    required this.currentWave,
    required this.firePressed,
    required this.bossHealth,
    required this.bossMaxHealth,
    required this.worldXToScreen,
    required this.enemyScreenY,
    required this.enemyRadius,
    required this.crosshairPosition,
    this.isTraveling = false,
    this.travelProgress = 0.0,
    this.travelTurn = 0.0,
  });

  final Size size;
  final List<Enemy> enemies;
  final List<EnemyProjectile> enemyProjectiles;
  final List<ShotTrace> traces;
  final double playerX;
  final double bobTime;
  final double worldZ;
  final GameState state;
  final int currentWave;
  final bool firePressed;
  final int bossHealth;
  final int bossMaxHealth;
  final Offset crosshairPosition;
  final bool isTraveling;
  final double travelProgress;
  final double travelTurn;

  final double Function(double worldX, double distance, Size size)
      worldXToScreen;
  final double Function(double distance, Size size) enemyScreenY;
  final double Function(double distance) enemyRadius;

  @override
  void paint(Canvas canvas, Size size) {
    _paintBackground(canvas, size);
    _paintRedwoodHallway(canvas, size);
    _paintAtmosphere(canvas, size);
    _paintEnemies(canvas, size);
    _paintEnemyProjectiles(canvas, size);
    _paintTraces(canvas);
    _paintCrosshair(canvas);
    _paintWeapon(canvas, size);
    _paintBossHealthBar(canvas, size);
  }

  double _travelCurveAmount() {
    if (!isTraveling) return 0.0;
    final t = travelProgress.clamp(0.0, 1.0);
    if (t < 0.25) return travelTurn * (t / 0.25);
    if (t < 0.75) return travelTurn;
    return travelTurn * (1.0 - ((t - 0.75) / 0.25));
  }

  double _travelShift(Size size) {
    // HACKABLE: visual turn strength only, no gameplay impact
    return _travelCurveAmount() * size.width * 0.12;
  }

  double _scrollLoop(double span) {
    if (span == 0) return 0;
    final value = worldZ % span;
    return value < 0 ? value + span : value;
  }

  void _paintBackground(Canvas canvas, Size size) {
    final sky = Rect.fromLTWH(0, 0, size.width, size.height * 0.64);

    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF203126),
          Color(0xFF304739),
          Color(0xFF5D715E),
          Color(0xFF97A18F),
          Color(0xFFC6BEAB),
        ],
        stops: [0.0, 0.26, 0.52, 0.78, 1.0],
      ).createShader(sky);

    canvas.drawRect(sky, skyPaint);

    final horizonY = size.height * 0.385;
    final drift = math.sin(worldZ * 0.012) * size.width * 0.012;

    // HACKABLE: distant glow at vanishing point
    final farGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFE5B7).withValues(alpha: 0.14),
          const Color(0xFFFFE5B7).withValues(alpha: 0.05),
          Colors.transparent,
        ],
        stops: const [0.0, 0.42, 1.0],
      ).createShader(
        Rect.fromCenter(
          center: Offset(size.width * 0.5 + drift, size.height * 0.47),
          width: size.width * 0.80,
          height: size.height * 0.36,
        ),
      );

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5 + drift, size.height * 0.47),
        width: size.width * 0.80,
        height: size.height * 0.36,
      ),
      farGlow,
    );

    _paintFarForestBand(
      canvas,
      size,
      baselineY: horizonY * 1.00,
      trunkCount: 18,
      widthMin: 8,
      widthMax: 18,
      heightMin: size.height * 0.09,
      heightMax: size.height * 0.24,
      alpha: 0.12,
      fogMix: 0.62,
      xDrift: drift * 0.45,
    );

    _paintFarForestBand(
      canvas,
      size,
      baselineY: horizonY * 1.03,
      trunkCount: 14,
      widthMin: 16,
      widthMax: 34,
      heightMin: size.height * 0.11,
      heightMax: size.height * 0.30,
      alpha: 0.09,
      fogMix: 0.76,
      xDrift: -drift * 0.28,
    );

    _paintMistBand(
      canvas,
      center: Offset(size.width * 0.50 + drift, size.height * 0.47),
      width: size.width * 0.86,
      height: size.height * 0.18,
      alpha: 0.10,
    );

    _paintMistBand(
      canvas,
      center: Offset(size.width * 0.50 - drift * 0.4, size.height * 0.51),
      width: size.width * 0.62,
      height: size.height * 0.12,
      alpha: 0.07,
    );
  }

  void _paintFarForestBand(
    Canvas canvas,
    Size size, {
    required double baselineY,
    required int trunkCount,
    required double widthMin,
    required double widthMax,
    required double heightMin,
    required double heightMax,
    required double alpha,
    required double fogMix,
    required double xDrift,
  }) {
    final paint = Paint()
      ..color = Color.lerp(
        GameConfig.forestDark,
        GameConfig.mist,
        fogMix,
      )!
          .withValues(alpha: alpha);

    for (int i = 0; i < trunkCount; i++) {
      final t = i / math.max(1, trunkCount - 1);
      final x = lerpDoubleValue(-30, size.width + 30, t) + xDrift;

      final waveA = (math.sin(i * 1.73) + 1) * 0.5;
      final waveB = (math.cos(i * 1.19 + 0.7) + 1) * 0.5;

      final trunkWidth = lerpDoubleValue(widthMin, widthMax, waveA);
      final trunkHeight = lerpDoubleValue(heightMin, heightMax, waveB);

      final rect = Rect.fromCenter(
        center: Offset(x, baselineY - trunkHeight * 0.46),
        width: trunkWidth,
        height: trunkHeight,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(trunkWidth * 0.16)),
        paint,
      );
    }
  }

  void _paintMistBand(
    Canvas canvas, {
    required Offset center,
    required double width,
    required double height,
    required double alpha,
  }) {
    final mistPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          GameConfig.mist.withValues(alpha: alpha),
          GameConfig.mist.withValues(alpha: alpha * 0.55),
          Colors.transparent,
        ],
        stops: const [0.0, 0.58, 1.0],
      ).createShader(
        Rect.fromCenter(center: center, width: width, height: height),
      );

    canvas.drawOval(
      Rect.fromCenter(center: center, width: width, height: height),
      mistPaint,
    );
  }

  void _paintRedwoodHallway(Canvas canvas, Size size) {
    final horizonY = size.height * 0.40;
    final corridorBottom = size.height;

    // HACKABLE: tighter corridor proportions for stronger perspective
    final corridorHalfTop = size.width * 0.072;
    final corridorHalfBottom = size.width * 0.40;
    final shift = (-playerX * 22) + _travelShift(size);

    // HACKABLE: bring side walls inward a bit
    final leftForest = Path()
      ..moveTo(0, corridorBottom)
      ..lineTo(size.width / 2 - corridorHalfBottom + shift, corridorBottom)
      ..lineTo(size.width / 2 - corridorHalfTop + shift, horizonY)
      ..lineTo(0, horizonY * 0.91)
      ..close();

    final rightForest = Path()
      ..moveTo(size.width, corridorBottom)
      ..lineTo(size.width / 2 + corridorHalfBottom + shift, corridorBottom)
      ..lineTo(size.width / 2 + corridorHalfTop + shift, horizonY)
      ..lineTo(size.width, horizonY * 0.91)
      ..close();

    final forestPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          GameConfig.forestMid,
          GameConfig.forestDark,
        ],
      ).createShader(
        Rect.fromLTWH(0, horizonY, size.width, size.height - horizonY),
      );

    canvas.drawPath(leftForest, forestPaint);
    canvas.drawPath(rightForest, forestPaint);

    _paintMidForestMass(
      canvas,
      size,
      left: true,
      horizonY: horizonY,
      bottomY: corridorBottom,
      shift: shift,
    );
    _paintMidForestMass(
      canvas,
      size,
      left: false,
      horizonY: horizonY,
      bottomY: corridorBottom,
      shift: shift,
    );

    final trail = Path()
      ..moveTo(size.width / 2 - corridorHalfBottom + shift, corridorBottom)
      ..lineTo(size.width / 2 + corridorHalfBottom + shift, corridorBottom)
      ..lineTo(size.width / 2 + corridorHalfTop + shift, horizonY)
      ..lineTo(size.width / 2 - corridorHalfTop + shift, horizonY)
      ..close();

    final trailPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF865833),
          Color(0xFF603B22),
          Color(0xFF3D2417),
          Color(0xFF261611),
        ],
        stops: [0.0, 0.34, 0.74, 1.0],
      ).createShader(
        Rect.fromLTWH(0, horizonY, size.width, size.height - horizonY),
      );

    canvas.drawPath(trail, trailPaint);

    _paintTrailLighting(
      canvas,
      size,
      horizonY: horizonY,
      bottomY: corridorBottom,
      corridorHalfTop: corridorHalfTop,
      corridorHalfBottom: corridorHalfBottom,
      shift: shift,
    );

    _paintTrailSeams(
      canvas,
      size,
      horizonY: horizonY,
      bottomY: corridorBottom,
      corridorHalfTop: corridorHalfTop,
      corridorHalfBottom: corridorHalfBottom,
      shift: shift,
    );

    final edgeGlow = Paint()
      ..color = GameConfig.redwoodGlow.withValues(alpha: 0.18)
      ..strokeWidth = 2.7;

    canvas.drawLine(
      Offset(size.width / 2 - corridorHalfTop + shift, horizonY),
      Offset(size.width / 2 - corridorHalfBottom + shift, corridorBottom),
      edgeGlow,
    );
    canvas.drawLine(
      Offset(size.width / 2 + corridorHalfTop + shift, horizonY),
      Offset(size.width / 2 + corridorHalfBottom + shift, corridorBottom),
      edgeGlow,
    );

    _paintRedwoodColumns(canvas, size, true, horizonY, corridorBottom, shift);
    _paintRedwoodColumns(canvas, size, false, horizonY, corridorBottom, shift);
  }

  void _paintMidForestMass(
    Canvas canvas,
    Size size, {
    required bool left,
    required double horizonY,
    required double bottomY,
    required double shift,
  }) {
    final massPaint = Paint();
    final shrubPaint = Paint();

    for (int i = 0; i < 9; i++) {
      final t = i / 8.0;

      final x = left
          ? lerpDoubleValue(size.width * 0.34 + shift, -18 + shift, t)
          : lerpDoubleValue(size.width * 0.66 + shift, size.width + 18 + shift, t);

      final trunkW = lerpDoubleValue(18, 54, t);
      final trunkH = lerpDoubleValue(80, 260, t);
      final y = lerpDoubleValue(horizonY + 14, bottomY + 10, t * t);

      massPaint.color = Color.lerp(
        GameConfig.forestDark,
        GameConfig.mist,
        (1.0 - t) * 0.28,
      )!
          .withValues(alpha: (0.07 + (1.0 - t) * 0.08).clamp(0.0, 1.0));

      final trunkRect = Rect.fromCenter(
        center: Offset(x, y - trunkH * 0.46),
        width: trunkW,
        height: trunkH,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          trunkRect,
          Radius.circular(trunkW * 0.18),
        ),
        massPaint,
      );

      shrubPaint.color = const Color(0xFF1E2D20).withValues(
        alpha: (0.08 + t * 0.08).clamp(0.0, 1.0),
      );

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(
            x + (left ? trunkW * 0.10 : -trunkW * 0.10),
            trunkRect.bottom - trunkH * 0.08,
          ),
          width: trunkW * 1.8,
          height: trunkH * 0.18,
        ),
        shrubPaint,
      );
    }
  }

  void _paintTrailLighting(
    Canvas canvas,
    Size size, {
    required double horizonY,
    required double bottomY,
    required double corridorHalfTop,
    required double corridorHalfBottom,
    required double shift,
  }) {
    final path = Path()
      ..moveTo(size.width / 2 - corridorHalfBottom + shift, bottomY)
      ..lineTo(size.width / 2 + corridorHalfBottom + shift, bottomY)
      ..lineTo(size.width / 2 + corridorHalfTop + shift, horizonY)
      ..lineTo(size.width / 2 - corridorHalfTop + shift, horizonY)
      ..close();

    final centerWarmth = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFCF87).withValues(alpha: 0.15),
          const Color(0xFFFFCF87).withValues(alpha: 0.07),
          Colors.transparent,
        ],
        stops: const [0.0, 0.46, 1.0],
      ).createShader(
        Rect.fromCenter(
          center: Offset(size.width * 0.5 + shift * 0.12, size.height * 0.72),
          width: size.width * 0.80,
          height: size.height * 0.90,
        ),
      );

    final horizonPatch = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFE5BF).withValues(alpha: 0.10),
          const Color(0xFFFFE5BF).withValues(alpha: 0.04),
          Colors.transparent,
        ],
        stops: const [0.0, 0.36, 1.0],
      ).createShader(
        Rect.fromCenter(
          center: Offset(size.width * 0.5 + shift * 0.12, size.height * 0.53),
          width: size.width * 0.42,
          height: size.height * 0.18,
        ),
      );

    final edgeDarken = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.black.withValues(alpha: 0.16),
          Colors.transparent,
          Colors.transparent,
          Colors.black.withValues(alpha: 0.16),
        ],
        stops: const [0.0, 0.20, 0.80, 1.0],
      ).createShader(
        Rect.fromLTWH(
          size.width / 2 - corridorHalfBottom + shift,
          horizonY,
          corridorHalfBottom * 2,
          bottomY - horizonY,
        ),
      );

    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(
      Rect.fromLTWH(0, horizonY, size.width, bottomY - horizonY),
      centerWarmth,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, horizonY, size.width, bottomY - horizonY),
      horizonPatch,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        size.width / 2 - corridorHalfBottom + shift,
        horizonY,
        corridorHalfBottom * 2,
        bottomY - horizonY,
      ),
      edgeDarken,
    );
    canvas.restore();
  }

  void _paintTrailSeams(
    Canvas canvas,
    Size size, {
    required double horizonY,
    required double bottomY,
    required double corridorHalfTop,
    required double corridorHalfBottom,
    required double shift,
  }) {
    final seamPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.24)
      ..strokeWidth = 1.35;

    final seamHighlight = Paint()
      ..color = const Color(0xFFFFBE75).withValues(alpha: 0.10)
      ..strokeWidth = 0.85;

    final seamScroll = _scrollLoop(1.0);

    for (int i = 1; i <= 10; i++) {
      final raw = ((i / 11) + seamScroll * 0.045) % 1.0;
      final t = raw <= 0.04 ? raw + 0.04 : raw;

      final y = lerpDoubleValue(horizonY, bottomY, t * t);
      final halfW = lerpDoubleValue(corridorHalfTop, corridorHalfBottom, t);

      canvas.drawLine(
        Offset(size.width / 2 - halfW + shift, y),
        Offset(size.width / 2 + halfW + shift, y),
        seamPaint,
      );
      canvas.drawLine(
        Offset(size.width / 2 - halfW + shift, y - 1.0),
        Offset(size.width / 2 + halfW + shift, y - 1.0),
        seamHighlight,
      );
    }
  }

  void _paintRedwoodColumns(
    Canvas canvas,
    Size size,
    bool left,
    double horizonY,
    double bottomY,
    double shift,
  ) {
    final mossBase = const Color(0xFF28452B);

    // HACKABLE: hand-tuned spacing feels less robotic than evenly spaced values
    const depthStops = [0.11, 0.21, 0.34, 0.49, 0.67, 0.82, 0.94];

    for (int i = 0; i < depthStops.length; i++) {
      final t = depthStops[i];
      final y = lerpDoubleValue(horizonY + 12, bottomY + 30, t * t);

      // HACKABLE: slightly bigger foreground posts
      final trunkHeight = lerpDoubleValue(28, 290, t);
      final trunkWidth = lerpDoubleValue(7, 76, t);

      final edgeX = left
          ? lerpDoubleValue(size.width * 0.39 + shift, 18 + shift, t)
          : lerpDoubleValue(size.width * 0.61 + shift, size.width - 18 + shift, t);

      final trunkRect = Rect.fromCenter(
        center: Offset(edgeX, y - trunkHeight * 0.45),
        width: trunkWidth,
        height: trunkHeight,
      );

      final depthFog = (1.0 - t).clamp(0.0, 1.0);

      final bark = Paint()
        ..color = Color.lerp(
          GameConfig.redwoodMid,
          GameConfig.mist,
          depthFog * 0.16,
        )!;

      final barkDark = Paint()
        ..color = Color.lerp(
          GameConfig.redwoodDark,
          GameConfig.mist,
          depthFog * 0.07,
        )!;

      final moss = Paint()
        ..color = mossBase.withValues(
          alpha: (0.14 + t * 0.20).clamp(0.0, 1.0),
        );

      canvas.drawShadow(
        Path()
          ..addRRect(
            RRect.fromRectAndRadius(
              trunkRect,
              Radius.circular(trunkWidth * 0.18),
            ),
          ),
        Colors.black.withValues(alpha: 0.22),
        trunkWidth * 0.14,
        false,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(trunkRect, Radius.circular(trunkWidth * 0.18)),
        bark,
      );

      canvas.drawRect(
        Rect.fromLTWH(
          trunkRect.left + trunkWidth * 0.18,
          trunkRect.top,
          trunkWidth * 0.12,
          trunkHeight,
        ),
        barkDark,
      );
      canvas.drawRect(
        Rect.fromLTWH(
          trunkRect.left + trunkWidth * 0.58,
          trunkRect.top,
          trunkWidth * 0.10,
          trunkHeight,
        ),
        barkDark,
      );

      final warmHighlight = Paint()
        ..color = const Color(0xFFFFC07A).withValues(alpha: 0.05 + t * 0.08);

      canvas.drawRect(
        Rect.fromLTWH(
          trunkRect.left + trunkWidth * 0.08,
          trunkRect.top + trunkHeight * 0.04,
          trunkWidth * 0.05,
          trunkHeight * 0.88,
        ),
        warmHighlight,
      );

      if (i.isEven) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(edgeX, trunkRect.top + trunkHeight * 0.28),
            width: trunkWidth * 0.92,
            height: trunkHeight * 0.15,
          ),
          moss,
        );
      }
    }
  }

  void _paintAtmosphere(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    final sideMistLeft = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          GameConfig.mist.withValues(alpha: 0.06),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromLTWH(0, 0, size.width * 0.28, size.height),
      );

    final sideMistRight = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerRight,
        end: Alignment.centerLeft,
        colors: [
          GameConfig.mist.withValues(alpha: 0.06),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromLTWH(size.width * 0.72, 0, size.width * 0.28, size.height),
      );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width * 0.28, size.height),
      sideMistLeft,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.72, 0, size.width * 0.28, size.height),
      sideMistRight,
    );

    final lowHaze = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          GameConfig.mist.withValues(alpha: 0.02),
          GameConfig.mist.withValues(alpha: 0.06),
        ],
        stops: const [0.56, 0.80, 1.0],
      ).createShader(rect);

    canvas.drawRect(rect, lowHaze);

    final vignette = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          Colors.transparent,
          Colors.black.withValues(alpha: 0.18),
        ],
        stops: const [0.60, 0.84, 1.0],
      ).createShader(rect);

    canvas.drawRect(rect, vignette);
  }

  void _paintEnemies(Canvas canvas, Size size) {
    final sorted = [...enemies]..sort((a, b) => b.distance.compareTo(a.distance));

    for (final enemy in sorted) {
      final x = worldXToScreen(enemy.x - playerX, enemy.distance, size);
      final y = enemyScreenY(enemy.distance, size);
      final r = enemyRadius(enemy.distance) * enemy.radiusScale;

      final bodyPaint = Paint()
        ..color = enemy.alive
            ? enemy.tint
            : Colors.white.withValues(alpha: enemy.flash.clamp(0.0, 1.0));

      final darkPaint = Paint()..color = const Color(0xFF7A848D);
      final eyePaint = Paint()..color = Colors.redAccent;
      final limbPaint = Paint()
        ..color = const Color(0xFF8C979F)
        ..strokeWidth = math.max(2.0, r * 0.10)
        ..strokeCap = StrokeCap.round;

      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.16);

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y + r * 1.08),
          width: r * 1.35,
          height: r * 0.36,
        ),
        shadowPaint,
      );

      final headPath = Path()
        ..moveTo(x, y - r * 1.38)
        ..lineTo(x - r * 0.42, y - r * 0.74)
        ..lineTo(x + r * 0.42, y - r * 0.74)
        ..close();
      canvas.drawPath(headPath, bodyPaint);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, y - r * 0.92),
            width: r * 0.42,
            height: r * 0.10,
          ),
          Radius.circular(r * 0.03),
        ),
        darkPaint,
      );

      canvas.drawCircle(Offset(x - r * 0.10, y - r * 0.92), r * 0.04, eyePaint);
      canvas.drawCircle(Offset(x + r * 0.10, y - r * 0.92), r * 0.04, eyePaint);

      final torsoPath = Path()
        ..moveTo(x, y - r * 0.52)
        ..lineTo(x - r * 0.54, y - r * 0.10)
        ..lineTo(x - r * 0.36, y + r * 0.76)
        ..lineTo(x + r * 0.36, y + r * 0.76)
        ..lineTo(x + r * 0.54, y - r * 0.10)
        ..close();
      canvas.drawPath(torsoPath, bodyPaint);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, y + r * 0.10),
            width: r * 0.22,
            height: r * 0.58,
          ),
          Radius.circular(r * 0.05),
        ),
        darkPaint,
      );

      canvas.drawLine(
        Offset(x - r * 0.34, y - r * 0.04),
        Offset(x - r * 0.96, y + r * 0.28),
        limbPaint,
      );
      canvas.drawLine(
        Offset(x + r * 0.34, y - r * 0.04),
        Offset(x + r * 0.96, y + r * 0.28),
        limbPaint,
      );

      canvas.drawLine(
        Offset(x - r * 0.18, y + r * 0.70),
        Offset(x - r * 0.42, y + r * 1.34),
        limbPaint,
      );
      canvas.drawLine(
        Offset(x + r * 0.18, y + r * 0.70),
        Offset(x + r * 0.42, y + r * 1.34),
        limbPaint,
      );

      if (enemy.maxHealth > 1 && enemy.alive) {
        final bg = Paint()..color = Colors.black.withValues(alpha: 0.45);
        final fg = Paint()..color = Colors.redAccent;
        final width = r * 1.0;
        final left = x - width / 2;
        final top = y - r * 1.70;

        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left, top, width, 6),
            const Radius.circular(3),
          ),
          bg,
        );

        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left, top, width * (enemy.health / enemy.maxHealth), 6),
            const Radius.circular(3),
          ),
          fg,
        );
      }
    }
  }

  void _paintEnemyProjectiles(Canvas canvas, Size size) {
    for (final projectile in enemyProjectiles) {
      final screenX = worldXToScreen(
        projectile.position.dx - playerX,
        projectile.position.dy,
        size,
      );
      final screenY = enemyScreenY(projectile.position.dy, size);

      final glow = Paint()
        ..color = (projectile.isBossShot ? Colors.orangeAccent : Colors.redAccent)
            .withValues(alpha: 0.22)
        ..style = PaintingStyle.fill;

      final core = Paint()
        ..color = projectile.isBossShot
            ? const Color(0xFFFFC36E)
            : Colors.redAccent;

      final drawRadius = projectile.isBossShot ? 10.0 : 7.0;

      canvas.drawCircle(Offset(screenX, screenY), drawRadius * 1.9, glow);
      canvas.drawCircle(Offset(screenX, screenY), drawRadius, core);
    }
  }

  void _paintTraces(Canvas canvas) {
    for (final trace in traces) {
      final p = Paint()
        ..color = GameConfig.accent.withValues(
          alpha: (trace.life / 0.08).clamp(0.0, 1.0),
        )
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(trace.start, trace.end, p);
    }
  }

  void _paintCrosshair(Canvas canvas) {
    if (state == GameState.menu) return;

    final c = crosshairPosition;

    final glowPaint = Paint()
      ..color = GameConfig.accent.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(c, 24, glowPaint);

    final ringPaint = Paint()
      ..color = GameConfig.accent.withValues(alpha: 0.92)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(c, 14, ringPaint);
    canvas.drawLine(Offset(c.dx - 22, c.dy), Offset(c.dx - 8, c.dy), ringPaint);
    canvas.drawLine(Offset(c.dx + 8, c.dy), Offset(c.dx + 22, c.dy), ringPaint);
    canvas.drawLine(Offset(c.dx, c.dy - 22), Offset(c.dx, c.dy - 8), ringPaint);
    canvas.drawLine(Offset(c.dx, c.dy + 8), Offset(c.dx, c.dy + 22), ringPaint);

    final centerDot = Paint()
      ..color = GameConfig.accent.withValues(alpha: 0.98)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(c, 2.4, centerDot);
  }

  void _paintWeapon(Canvas canvas, Size size) {
    final bobX = math.sin(bobTime * 3.2) * 4;
    final bobY = math.sin(bobTime * 6.4) * 3;
    final centerX = size.width / 2 + bobX;
    final baseY = size.height * 0.885 + bobY + (firePressed ? 4 : 0);

    final wood = Paint()..color = const Color(0xFF5A3A24);
    final darkWood = Paint()..color = const Color(0xFF3A2417);
    final metal = Paint()..color = const Color(0xFFB8C2C9);
    final darkMetal = Paint()..color = const Color(0xFF7E8A92);
    final stringPaint = Paint()
      ..color = const Color(0xFFE7DEC8)
      ..strokeWidth = 2.4;
    final energyGlow = Paint()
      ..color = GameConfig.accent.withValues(alpha: firePressed ? 0.55 : 0.22);
    final nodePaint = Paint()..color = const Color(0xFFC9D3DA);
    final nodeGlow = Paint()
      ..color = GameConfig.accent.withValues(alpha: firePressed ? 0.45 : 0.18);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centerX, baseY),
          width: 70,
          height: 138,
        ),
        const Radius.circular(12),
      ),
      wood,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centerX - 12, baseY),
          width: 14,
          height: 138,
        ),
        const Radius.circular(8),
      ),
      darkWood,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centerX, baseY - 46),
          width: 126,
          height: 28,
        ),
        const Radius.circular(10),
      ),
      darkMetal,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centerX, baseY - 25),
          width: 20,
          height: 88,
        ),
        const Radius.circular(8),
      ),
      metal,
    );

    final leftArmBase = Offset(centerX - 96, baseY - 34);
    final rightArmBase = Offset(centerX + 96, baseY - 34);
    final leftArmTip = Offset(centerX - 128, baseY - 76);
    final rightArmTip = Offset(centerX + 128, baseY - 76);

    final armPaint = Paint()
      ..color = metal.color
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(centerX - 42, baseY - 34), leftArmBase, armPaint);
    canvas.drawLine(Offset(centerX + 42, baseY - 34), rightArmBase, armPaint);

    armPaint.strokeWidth = 6;
    canvas.drawLine(leftArmBase, leftArmTip, armPaint);
    canvas.drawLine(rightArmBase, rightArmTip, armPaint);

    canvas.drawCircle(leftArmTip, 12, nodeGlow);
    canvas.drawCircle(rightArmTip, 12, nodeGlow);
    canvas.drawCircle(leftArmTip, 9, nodePaint);
    canvas.drawCircle(rightArmTip, 9, nodePaint);

    canvas.drawLine(leftArmTip, Offset(centerX, baseY - 8), stringPaint);
    canvas.drawLine(rightArmTip, Offset(centerX, baseY - 8), stringPaint);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centerX, baseY - 57),
          width: 8,
          height: 36,
        ),
        const Radius.circular(4),
      ),
      energyGlow,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centerX, baseY + 36),
          width: 34,
          height: 58,
        ),
        const Radius.circular(8),
      ),
      darkMetal,
    );
  }

  void _paintBossHealthBar(Canvas canvas, Size size) {
    if (bossMaxHealth <= 0 || bossHealth <= 0) return;

    final bg = Paint()..color = Colors.black.withValues(alpha: 0.45);
    final fg = Paint()..color = Colors.redAccent;
    final frame = Paint()
      ..color = GameConfig.accent.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final rect = Rect.fromLTWH(size.width * 0.18, 24, size.width * 0.64, 14);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(7)),
      bg,
    );

    final fillWidth = rect.width * (bossHealth / bossMaxHealth);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left, rect.top, fillWidth, rect.height),
        const Radius.circular(7),
      ),
      fg,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(7)),
      frame,
    );

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'BOSS',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(size.width / 2 - textPainter.width / 2, rect.top - 16),
    );
  }

  @override
  bool shouldRepaint(covariant RedwoodPainter oldDelegate) {
    return oldDelegate.playerX != playerX ||
        oldDelegate.bobTime != bobTime ||
        oldDelegate.worldZ != worldZ ||
        oldDelegate.state != state ||
        oldDelegate.currentWave != currentWave ||
        oldDelegate.firePressed != firePressed ||
        oldDelegate.bossHealth != bossHealth ||
        oldDelegate.bossMaxHealth != bossMaxHealth ||
        oldDelegate.crosshairPosition != crosshairPosition ||
        oldDelegate.isTraveling != isTraveling ||
        oldDelegate.travelProgress != travelProgress ||
        oldDelegate.travelTurn != travelTurn ||
        oldDelegate.enemies != enemies ||
        oldDelegate.enemyProjectiles != enemyProjectiles ||
        oldDelegate.traces != traces ||
        oldDelegate.size != size;
  }
}
