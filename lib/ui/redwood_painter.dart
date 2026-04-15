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
    // HACKABLE: visual turn strength only
    return _travelCurveAmount() * size.width * 0.11;
  }

  double _scrollLoop(double span) {
    if (span == 0) return 0;
    final value = worldZ % span;
    return value < 0 ? value + span : value;
  }

  void _paintBackground(Canvas canvas, Size size) {
    final sky = Rect.fromLTWH(0, 0, size.width, size.height);

    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF15251D),
          Color(0xFF24382D),
          Color(0xFF465A4B),
          Color(0xFF71806E),
          Color(0xFFB8B39D),
        ],
        stops: [0.0, 0.18, 0.42, 0.70, 1.0],
      ).createShader(sky);
    canvas.drawRect(sky, skyPaint);

    final horizonY = size.height * 0.395;
    final drift = math.sin(worldZ * 0.010) * size.width * 0.010;

    final distantGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFE5B6).withValues(alpha: 0.18),
          const Color(0xFFFFE5B6).withValues(alpha: 0.07),
          Colors.transparent,
        ],
        stops: const [0.0, 0.36, 1.0],
      ).createShader(
        Rect.fromCenter(
          center: Offset(size.width * 0.50 + drift, size.height * 0.49),
          width: size.width * 0.70,
          height: size.height * 0.28,
        ),
      );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.50 + drift, size.height * 0.49),
        width: size.width * 0.70,
        height: size.height * 0.28,
      ),
      distantGlow,
    );

    _paintFarForestBand(
      canvas,
      size,
      baselineY: horizonY * 1.00,
      trunkCount: 18,
      widthMin: 10,
      widthMax: 24,
      heightMin: size.height * 0.10,
      heightMax: size.height * 0.25,
      alpha: 0.10,
      fogMix: 0.72,
      xDrift: drift * 0.45,
    );

    _paintFarForestBand(
      canvas,
      size,
      baselineY: horizonY * 1.04,
      trunkCount: 14,
      widthMin: 18,
      widthMax: 42,
      heightMin: size.height * 0.12,
      heightMax: size.height * 0.31,
      alpha: 0.08,
      fogMix: 0.82,
      xDrift: -drift * 0.30,
    );

    _paintMistBand(
      canvas,
      center: Offset(size.width * 0.50 + drift, size.height * 0.48),
      width: size.width * 0.78,
      height: size.height * 0.16,
      alpha: 0.10,
    );
    _paintMistBand(
      canvas,
      center: Offset(size.width * 0.50 - drift * 0.3, size.height * 0.52),
      width: size.width * 0.56,
      height: size.height * 0.10,
      alpha: 0.06,
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
      final x = lerpDoubleValue(-25, size.width + 25, t) + xDrift;

      final widthWave = (math.sin(i * 1.61) + 1) * 0.5;
      final heightWave = (math.cos(i * 1.23 + 0.7) + 1) * 0.5;

      final trunkWidth = lerpDoubleValue(widthMin, widthMax, widthWave);
      final trunkHeight = lerpDoubleValue(heightMin, heightMax, heightWave);

      final rect = Rect.fromCenter(
        center: Offset(x, baselineY - trunkHeight * 0.46),
        width: trunkWidth,
        height: trunkHeight,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(trunkWidth * 0.18)),
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
    final horizonY = size.height * 0.402;
    final corridorBottom = size.height;

    // HACKABLE: composition squeeze
    final corridorHalfTop = size.width * 0.058;
    final corridorHalfBottom = size.width * 0.385;
    final shift = (-playerX * 22) + _travelShift(size);

    final leftForest = Path()
      ..moveTo(0, corridorBottom)
      ..lineTo(size.width / 2 - corridorHalfBottom + shift, corridorBottom)
      ..lineTo(size.width / 2 - corridorHalfTop + shift, horizonY)
      ..lineTo(0, horizonY * 0.93)
      ..close();

    final rightForest = Path()
      ..moveTo(size.width, corridorBottom)
      ..lineTo(size.width / 2 + corridorHalfBottom + shift, corridorBottom)
      ..lineTo(size.width / 2 + corridorHalfTop + shift, horizonY)
      ..lineTo(size.width, horizonY * 0.93)
      ..close();

    final forestPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF173723),
          Color(0xFF0F2818),
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
          Color(0xFF875632),
          Color(0xFF663F24),
          Color(0xFF422618),
          Color(0xFF231411),
        ],
        stops: [0.0, 0.34, 0.72, 1.0],
      ).createShader(
        Rect.fromLTWH(0, horizonY, size.width, size.height - horizonY),
      );

    canvas.drawPath(trail, trailPaint);

    _paintTrailBaseTexture(
      canvas,
      size,
      trail: trail,
      horizonY: horizonY,
      bottomY: corridorBottom,
      corridorHalfTop: corridorHalfTop,
      corridorHalfBottom: corridorHalfBottom,
      shift: shift,
    );

    _paintTrailLighting(
      canvas,
      size,
      horizonY: horizonY,
      bottomY: corridorBottom,
      corridorHalfTop: corridorHalfTop,
      corridorHalfBottom: corridorHalfBottom,
      shift: shift,
      trail: trail,
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

    _paintPathEdgeBlend(
      canvas,
      size,
      horizonY: horizonY,
      bottomY: corridorBottom,
      corridorHalfTop: corridorHalfTop,
      corridorHalfBottom: corridorHalfBottom,
      shift: shift,
    );

    _paintPathEdgeLeafLitter(
      canvas,
      size,
      horizonY: horizonY,
      bottomY: corridorBottom,
      corridorHalfTop: corridorHalfTop,
      corridorHalfBottom: corridorHalfBottom,
      shift: shift,
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
    final trunkPaint = Paint();
    final shadowPaint = Paint();
    final shrubPaint = Paint();
    final leafPaint = Paint();

    for (int i = 0; i < 8; i++) {
      final t = i / 7.0;

      final x = left
          ? lerpDoubleValue(size.width * 0.315 + shift, -22 + shift, t)
          : lerpDoubleValue(size.width * 0.685 + shift, size.width + 22 + shift, t);

      final trunkW = lerpDoubleValue(24, 64, t);
      final trunkH = lerpDoubleValue(90, 280, t);
      final y = lerpDoubleValue(horizonY + 18, bottomY + 16, t * t);

      trunkPaint.color = Color.lerp(
        GameConfig.forestDark,
        GameConfig.mist,
        (1.0 - t) * 0.26,
      )!
          .withValues(alpha: (0.08 + (1.0 - t) * 0.08).clamp(0.0, 1.0));

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
        trunkPaint,
      );

      shadowPaint.color = Colors.black.withValues(
        alpha: (0.05 + t * 0.05).clamp(0.0, 1.0),
      );

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(
            x + (left ? trunkW * 0.05 : -trunkW * 0.05),
            trunkRect.bottom - trunkH * 0.03,
          ),
          width: trunkW * 2.3,
          height: trunkH * 0.16,
        ),
        shadowPaint,
      );

      shrubPaint.color = const Color(0xFF112216).withValues(
        alpha: (0.08 + t * 0.10).clamp(0.0, 1.0),
      );

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(
            x + (left ? trunkW * 0.18 : -trunkW * 0.18),
            trunkRect.bottom - trunkH * 0.01,
          ),
          width: trunkW * 2.0,
          height: trunkH * 0.18,
        ),
        shrubPaint,
      );

      // HACKABLE: low leaf clusters / undergrowth accents
      leafPaint.color = const Color(0xFF6B5A2E).withValues(
        alpha: (0.10 + t * 0.12).clamp(0.0, 1.0),
      );
      for (int j = 0; j < 3; j++) {
        final xo = (j - 1) * trunkW * 0.22;
        final yo = trunkH * (0.01 + j * 0.012);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(
              x + xo + (left ? trunkW * 0.14 : -trunkW * 0.14),
              trunkRect.bottom - yo,
            ),
            width: trunkW * 0.24,
            height: trunkW * 0.11,
          ),
          leafPaint,
        );
      }
    }
  }

  void _paintTrailBaseTexture(
    Canvas canvas,
    Size size, {
    required Path trail,
    required double horizonY,
    required double bottomY,
    required double corridorHalfTop,
    required double corridorHalfBottom,
    required double shift,
  }) {
    canvas.save();
    canvas.clipPath(trail);

    // HACKABLE: center wear strip
    final centerWear = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFFFC67B).withValues(alpha: 0.03),
          const Color(0xFFFFC67B).withValues(alpha: 0.10),
          const Color(0xFFFFC67B).withValues(alpha: 0.06),
        ],
        stops: const [0.0, 0.65, 1.0],
      ).createShader(
        Rect.fromLTWH(
          size.width * 0.42 + shift * 0.06,
          horizonY,
          size.width * 0.16,
          bottomY - horizonY,
        ),
      );
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.42 + shift * 0.06,
        horizonY,
        size.width * 0.16,
        bottomY - horizonY,
      ),
      centerWear,
    );

    // HACKABLE: darker outer board edges
    final edgeShadeLeft = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.black.withValues(alpha: 0.10),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromLTWH(
          size.width / 2 - corridorHalfBottom + shift,
          horizonY,
          corridorHalfBottom * 0.34,
          bottomY - horizonY,
        ),
      );
    canvas.drawRect(
      Rect.fromLTWH(
        size.width / 2 - corridorHalfBottom + shift,
        horizonY,
        corridorHalfBottom * 0.34,
        bottomY - horizonY,
      ),
      edgeShadeLeft,
    );

    final edgeShadeRight = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerRight,
        end: Alignment.centerLeft,
        colors: [
          Colors.black.withValues(alpha: 0.10),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromLTWH(
          size.width / 2 + corridorHalfBottom + shift - corridorHalfBottom * 0.34,
          horizonY,
          corridorHalfBottom * 0.34,
          bottomY - horizonY,
        ),
      );
    canvas.drawRect(
      Rect.fromLTWH(
        size.width / 2 + corridorHalfBottom + shift - corridorHalfBottom * 0.34,
        horizonY,
        corridorHalfBottom * 0.34,
        bottomY - horizonY,
      ),
      edgeShadeRight,
    );

    // HACKABLE: plank variation bands
    for (int i = 0; i < 9; i++) {
      final t0 = i / 9;
      final t1 = (i + 1) / 9;
      final y0 = lerpDoubleValue(horizonY, bottomY, t0 * t0);
      final y1 = lerpDoubleValue(horizonY, bottomY, t1 * t1);

      final alpha = 0.018 + ((i % 2 == 0) ? 0.028 : 0.010);
      final paint = Paint()
        ..color = (i % 3 == 0
                ? const Color(0xFFFFC07A)
                : const Color(0xFF2A140E))
            .withValues(alpha: alpha);

      canvas.drawRect(
        Rect.fromLTWH(0, y0, size.width, math.max(0.0, y1 - y0)),
        paint,
      );
    }

    canvas.restore();
  }

  void _paintTrailLighting(
    Canvas canvas,
    Size size, {
    required double horizonY,
    required double bottomY,
    required double corridorHalfTop,
    required double corridorHalfBottom,
    required double shift,
    required Path trail,
  }) {
    final centerWarmth = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFC983).withValues(alpha: 0.17),
          const Color(0xFFFFC983).withValues(alpha: 0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 0.46, 1.0],
      ).createShader(
        Rect.fromCenter(
          center: Offset(size.width * 0.50 + shift * 0.10, size.height * 0.73),
          width: size.width * 0.72,
          height: size.height * 0.88,
        ),
      );

    final horizonPatch = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFE5BF).withValues(alpha: 0.13),
          const Color(0xFFFFE5BF).withValues(alpha: 0.04),
          Colors.transparent,
        ],
        stops: const [0.0, 0.32, 1.0],
      ).createShader(
        Rect.fromCenter(
          center: Offset(size.width * 0.50 + shift * 0.10, size.height * 0.54),
          width: size.width * 0.34,
          height: size.height * 0.14,
        ),
      );

    final edgeDarken = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.black.withValues(alpha: 0.22),
          Colors.transparent,
          Colors.transparent,
          Colors.black.withValues(alpha: 0.22),
        ],
        stops: const [0.0, 0.18, 0.82, 1.0],
      ).createShader(
        Rect.fromLTWH(
          size.width / 2 - corridorHalfBottom + shift,
          horizonY,
          corridorHalfBottom * 2,
          bottomY - horizonY,
        ),
      );

    canvas.save();
    canvas.clipPath(trail);
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
      ..color = Colors.black.withValues(alpha: 0.30)
      ..strokeWidth = 1.45;

    final seamHighlight = Paint()
      ..color = const Color(0xFFFFBE75).withValues(alpha: 0.09)
      ..strokeWidth = 0.85;

    final seamBleed = Paint()
      ..color = const Color(0xFF1C0F0C).withValues(alpha: 0.08)
      ..strokeWidth = 4.0;

    final seamScroll = _scrollLoop(1.0);

    for (int i = 1; i <= 11; i++) {
      final raw = ((i / 12) + seamScroll * 0.04) % 1.0;
      final t = raw <= 0.04 ? raw + 0.04 : raw;

      final y = lerpDoubleValue(horizonY, bottomY, t * t);
      final halfW = lerpDoubleValue(corridorHalfTop, corridorHalfBottom, t);

      canvas.drawLine(
        Offset(size.width / 2 - halfW + shift, y),
        Offset(size.width / 2 + halfW + shift, y),
        seamBleed,
      );
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

  void _paintPathEdgeBlend(
    Canvas canvas,
    Size size, {
    required double horizonY,
    required double bottomY,
    required double corridorHalfTop,
    required double corridorHalfBottom,
    required double shift,
  }) {
    final leftEdge = Path()
      ..moveTo(size.width / 2 - corridorHalfBottom + shift, bottomY)
      ..lineTo(size.width / 2 - corridorHalfBottom + shift + 18, bottomY)
      ..lineTo(size.width / 2 - corridorHalfTop + shift + 5, horizonY)
      ..lineTo(size.width / 2 - corridorHalfTop + shift, horizonY)
      ..close();

    final rightEdge = Path()
      ..moveTo(size.width / 2 + corridorHalfBottom + shift, bottomY)
      ..lineTo(size.width / 2 + corridorHalfBottom + shift - 18, bottomY)
      ..lineTo(size.width / 2 + corridorHalfTop + shift - 5, horizonY)
      ..lineTo(size.width / 2 + corridorHalfTop + shift, horizonY)
      ..close();

    final edgeLight = Paint()
      ..color = GameConfig.redwoodGlow.withValues(alpha: 0.14);
    final edgeShadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.10);

    canvas.drawPath(leftEdge, edgeLight);
    canvas.drawPath(rightEdge, edgeLight);

    canvas.drawLine(
      Offset(size.width / 2 - corridorHalfTop + shift, horizonY),
      Offset(size.width / 2 - corridorHalfBottom + shift, bottomY),
      edgeShadow,
    );
    canvas.drawLine(
      Offset(size.width / 2 + corridorHalfTop + shift, horizonY),
      Offset(size.width / 2 + corridorHalfBottom + shift, bottomY),
      edgeShadow,
    );
  }

  void _paintPathEdgeLeafLitter(
    Canvas canvas,
    Size size, {
    required double horizonY,
    required double bottomY,
    required double corridorHalfTop,
    required double corridorHalfBottom,
    required double shift,
  }) {
    final leafPaintA = Paint()
      ..color = const Color(0xFF6E562D).withValues(alpha: 0.24);
    final leafPaintB = Paint()
      ..color = const Color(0xFF8A6434).withValues(alpha: 0.18);
    final leafPaintC = Paint()
      ..color = const Color(0xFF41512D).withValues(alpha: 0.20);

    for (int i = 0; i < 18; i++) {
      final t = 0.22 + (i / 20);
      final y = lerpDoubleValue(horizonY, bottomY, t * t);
      final halfW = lerpDoubleValue(corridorHalfTop, corridorHalfBottom, t);

      final leftX = size.width / 2 - halfW + shift + 8 + (i % 3) * 6;
      final rightX = size.width / 2 + halfW + shift - 8 - (i % 3) * 6;
      final leafW = lerpDoubleValue(4, 18, t);
      final leafH = lerpDoubleValue(2, 8, t);

      final p = i % 3 == 0
          ? leafPaintA
          : (i % 3 == 1 ? leafPaintB : leafPaintC);

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(leftX, y + (i.isEven ? 2 : -1)),
          width: leafW,
          height: leafH,
        ),
        p,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(rightX, y + (i.isEven ? -1 : 2)),
          width: leafW,
          height: leafH,
        ),
        p,
      );

      // A few leaves spill onto the boardwalk, but stay near edges
      if (i % 4 == 0) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(leftX + leafW * 0.9, y + 1),
            width: leafW * 0.8,
            height: leafH * 0.8,
          ),
          leafPaintB,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(rightX - leafW * 0.9, y - 1),
            width: leafW * 0.8,
            height: leafH * 0.8,
          ),
          leafPaintA,
        );
      }
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

    // HACKABLE: manual stops to avoid robotic spacing
    const depthStops = [0.10, 0.18, 0.29, 0.45, 0.63, 0.80, 0.94];

    for (int i = 0; i < depthStops.length; i++) {
      final t = depthStops[i];
      final y = lerpDoubleValue(horizonY + 12, bottomY + 34, t * t);

      final trunkHeight = lerpDoubleValue(26, 330, t);
      final trunkWidth = lerpDoubleValue(8, 86, t);

      final edgeX = left
          ? lerpDoubleValue(size.width * 0.365 + shift, 16 + shift, t)
          : lerpDoubleValue(size.width * 0.635 + shift, size.width - 16 + shift, t);

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
          depthFog * 0.14,
        )!;

      final barkDark = Paint()
        ..color = Color.lerp(
          GameConfig.redwoodDark,
          GameConfig.mist,
          depthFog * 0.06,
        )!;

      final shadow = Paint()
        ..color = Colors.black.withValues(alpha: 0.14 + t * 0.05);

      final moss = Paint()
        ..color = mossBase.withValues(
          alpha: (0.12 + t * 0.20).clamp(0.0, 1.0),
        );

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(
            edgeX + (left ? trunkWidth * 0.06 : -trunkWidth * 0.06),
            trunkRect.bottom - trunkHeight * 0.02,
          ),
          width: trunkWidth * 2.1,
          height: trunkHeight * 0.14,
        ),
        shadow,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          trunkRect,
          Radius.circular(trunkWidth * 0.18),
        ),
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
        ..color = const Color(0xFFFFC07A).withValues(alpha: 0.04 + t * 0.09);

      canvas.drawRect(
        Rect.fromLTWH(
          left
              ? trunkRect.left + trunkWidth * 0.08
              : trunkRect.left + trunkWidth * 0.82,
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

    final sideDarkenLeft = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.black.withValues(alpha: 0.15),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width * 0.30, size.height));

    final sideDarkenRight = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerRight,
        end: Alignment.centerLeft,
        colors: [
          Colors.black.withValues(alpha: 0.15),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromLTWH(size.width * 0.70, 0, size.width * 0.30, size.height),
      );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width * 0.30, size.height),
      sideDarkenLeft,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.70, 0, size.width * 0.30, size.height),
      sideDarkenRight,
    );

    final lowHaze = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          GameConfig.mist.withValues(alpha: 0.02),
          GameConfig.mist.withValues(alpha: 0.05),
        ],
        stops: const [0.58, 0.82, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, lowHaze);

    final vignette = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          Colors.transparent,
          Colors.black.withValues(alpha: 0.22),
        ],
        stops: const [0.58, 0.84, 1.0],
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
