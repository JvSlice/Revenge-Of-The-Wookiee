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

  // ============================================================
  // HACKABLE: travel camera shaping
  // Keeps the world feeling like it bends during travel segments.
  // ============================================================
  double _travelCurveAmount() {
    if (!isTraveling) return 0.0;

    final t = travelProgress.clamp(0.0, 1.0);
    double phase;
    if (t < 0.25) {
      phase = t / 0.25;
    } else if (t < 0.75) {
      phase = 1.0;
    } else {
      phase = 1.0 - ((t - 0.75) / 0.25);
    }

    return travelTurn * phase;
  }

  double _travelShift(Size size) {
    final turn = _travelCurveAmount();
    return turn * size.width * 0.18; // HACKABLE: turn visual strength
  }

  double _travelRoll() {
    final turn = _travelCurveAmount();
    return turn * 0.05; // HACKABLE: tiny camera roll in radians
  }

  // ============================================================
  // HACKABLE: normalized world scroll for path boards / haze motion
  // ============================================================
  double _scrollLoop(double span) {
    if (span == 0) return 0;
    final value = worldZ % span;
    return value < 0 ? value + span : value;
  }

  void _paintBackground(Canvas canvas, Size size) {
    final skyRect = Rect.fromLTWH(0, 0, size.width, size.height);

    final skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0xFF1D281F),
          Color(0xFF314637),
          Color(0xFF6E7D67),
          Color(0xFFC8C3AE),
        ],
        stops: const [0.0, 0.28, 0.62, 1.0],
      ).createShader(skyRect);

    canvas.drawRect(skyRect, skyPaint);

    // Soft center light bloom to pull the eye down the corridor.
    final centerGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFE7B8).withValues(alpha: 0.18),
          const Color(0xFFFFE7B8).withValues(alpha: 0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 0.42, 1.0],
      ).createShader(
        Rect.fromCenter(
          center: Offset(size.width * 0.5, size.height * 0.50),
          width: size.width * 0.95,
          height: size.height * 0.65,
        ),
      );
    canvas.drawRect(skyRect, centerGlow);

    // Far distance fog wall with no hard edge.
    final farFog = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          const Color(0xFFD6D0BD).withValues(alpha: 0.10),
          const Color(0xFFDAD4C1).withValues(alpha: 0.22),
          const Color(0xFFE0DAC8).withValues(alpha: 0.30),
        ],
        stops: const [0.26, 0.44, 0.62, 1.0],
      ).createShader(skyRect);
    canvas.drawRect(skyRect, farFog);

    // Low drifting haze replacing the old hard oval mist.
    final hazeDrift = math.sin(worldZ * 0.018) * size.width * 0.02;
    final hazePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFF0E6D0).withValues(alpha: 0.16),
          const Color(0xFFF0E6D0).withValues(alpha: 0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 0.58, 1.0],
      ).createShader(
        Rect.fromCenter(
          center: Offset(size.width * 0.5 + hazeDrift, size.height * 0.60),
          width: size.width * 1.15,
          height: size.height * 0.34,
        ),
      );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5 + hazeDrift, size.height * 0.60),
        width: size.width * 1.15,
        height: size.height * 0.34,
      ),
      hazePaint,
    );
  }

  void _paintRedwoodHallway(Canvas canvas, Size size) {
    final horizonY = size.height * 0.40;
    final corridorBottom = size.height;
    final corridorHalfTop = size.width * 0.105;
    final corridorHalfBottom = size.width * 0.425;

    final turnShift = _travelShift(size);
    final shift = (-playerX * 22) + turnShift;

    final leftForest = Path()
      ..moveTo(0, corridorBottom)
      ..lineTo(size.width / 2 - corridorHalfBottom + shift, corridorBottom)
      ..lineTo(size.width / 2 - corridorHalfTop + shift, horizonY)
      ..lineTo(0, horizonY * 0.84)
      ..close();

    final rightForest = Path()
      ..moveTo(size.width, corridorBottom)
      ..lineTo(size.width / 2 + corridorHalfBottom + shift, corridorBottom)
      ..lineTo(size.width / 2 + corridorHalfTop + shift, horizonY)
      ..lineTo(size.width, horizonY * 0.84)
      ..close();

    final forestPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF2E3C2F),
          GameConfig.forestMid,
          GameConfig.forestDark,
        ],
        stops: const [0.0, 0.26, 1.0],
      ).createShader(
        Rect.fromLTWH(0, horizonY, size.width, size.height - horizonY),
      );

    canvas.drawPath(leftForest, forestPaint);
    canvas.drawPath(rightForest, forestPaint);

    _paintDeepForestSilhouettes(
      canvas,
      size,
      horizonY: horizonY,
      bottomY: corridorBottom,
      shift: shift,
      left: true,
    );
    _paintDeepForestSilhouettes(
      canvas,
      size,
      horizonY: horizonY,
      bottomY: corridorBottom,
      shift: shift,
      left: false,
    );

    final trail = Path()
      ..moveTo(size.width / 2 - corridorHalfBottom + shift, corridorBottom)
      ..lineTo(size.width / 2 + corridorHalfBottom + shift, corridorBottom)
      ..lineTo(size.width / 2 + corridorHalfTop + shift, horizonY)
      ..lineTo(size.width / 2 - corridorHalfTop + shift, horizonY)
      ..close();

    final trailPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0xFF8A5D35),
          Color(0xFF6A4327),
          Color(0xFF4C2E1B),
          Color(0xFF2E1B11),
        ],
        stops: [0.0, 0.32, 0.72, 1.0],
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

    _paintPlankSeams(
      canvas,
      size,
      horizonY: horizonY,
      bottomY: corridorBottom,
      corridorHalfTop: corridorHalfTop,
      corridorHalfBottom: corridorHalfBottom,
      shift: shift,
    );

    final edgeGlow = Paint()
      ..color = const Color(0xFFFFB36B).withValues(alpha: 0.16)
      ..strokeWidth = 3.0;

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

  void _paintDeepForestSilhouettes(
    Canvas canvas,
    Size size, {
    required double horizonY,
    required double bottomY,
    required double shift,
    required bool left,
  }) {
    final silhouettePaint = Paint()
      ..color = const Color(0xFF213024).withValues(alpha: 0.18);

    for (int i = 0; i < 10; i++) {
      final t = i / 9;
      final depth = 1.0 - t;
      final x = left
          ? lerpDoubleValue(size.width * 0.38 + shift, -20 + shift, t)
          : lerpDoubleValue(size.width * 0.62 + shift, size.width + 20 + shift, t);

      final trunkW = lerpDoubleValue(10, 42, t);
      final trunkH = lerpDoubleValue(70, 260, t);
      final y = lerpDoubleValue(horizonY + 6, bottomY + 10, t * t);

      final alpha = 0.08 + (depth * 0.10);
      silhouettePaint.color =
          const Color(0xFF213024).withValues(alpha: alpha.clamp(0.0, 1.0));

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, y - trunkH * 0.44),
            width: trunkW,
            height: trunkH,
          ),
          Radius.circular(trunkW * 0.16),
        ),
        silhouettePaint,
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
    final centerWarmth = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFD79A).withValues(alpha: 0.16),
          const Color(0xFFFFD79A).withValues(alpha: 0.06),
          Colors.transparent,
        ],
        stops: const [0.0, 0.48, 1.0],
      ).createShader(
        Rect.fromCenter(
          center: Offset(size.width * 0.5 + shift * 0.15, size.height * 0.58),
          width: size.width * 0.66,
          height: size.height * 0.72,
        ),
      );

    final pathLight = Path()
      ..moveTo(size.width / 2 - corridorHalfBottom + shift, bottomY)
      ..lineTo(size.width / 2 + corridorHalfBottom + shift, bottomY)
      ..lineTo(size.width / 2 + corridorHalfTop + shift, horizonY)
      ..lineTo(size.width / 2 - corridorHalfTop + shift, horizonY)
      ..close();

    canvas.save();
    canvas.clipPath(pathLight);
    canvas.drawRect(Rect.fromLTWH(0, horizonY, size.width, bottomY - horizonY), centerWarmth);
    canvas.restore();

    final vignette = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.black.withValues(alpha: 0.14),
          Colors.transparent,
          Colors.transparent,
          Colors.black.withValues(alpha: 0.14),
        ],
        stops: const [0.0, 0.22, 0.78, 1.0],
      ).createShader(
        Rect.fromLTWH(
          size.width / 2 - corridorHalfBottom + shift,
          horizonY,
          corridorHalfBottom * 2,
          bottomY - horizonY,
        ),
      );

    canvas.save();
    canvas.clipPath(pathLight);
    canvas.drawRect(
      Rect.fromLTWH(
        size.width / 2 - corridorHalfBottom + shift,
        horizonY,
        corridorHalfBottom * 2,
        bottomY - horizonY,
      ),
      vignette,
    );
    canvas.restore();
  }

  void _paintPlankSeams(
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
      ..strokeWidth = 1.4;

    final highlightPaint = Paint()
      ..color = const Color(0xFFFFC07A).withValues(alpha: 0.10)
      ..strokeWidth = 0.8;

    final plankCount = 10;
    final scroll = _scrollLoop(1.0);

    for (int i = 0; i < plankCount; i++) {
      final tBase = (i / plankCount + scroll / plankCount) % 1.0;
      final t = tBase == 0 ? 1.0 : tBase;

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
        highlightPaint,
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
    final fogColor = const Color(0xFFD9D2BF);

    for (int i = 0; i < 7; i++) {
      final t = (i + 1) / 8;
      final y = lerpDoubleValue(horizonY + 10, bottomY + 30, t * t);
      final trunkHeight = lerpDoubleValue(24, 260, t);
      final trunkWidth = lerpDoubleValue(5, 68, t);

      final edgeX = left
          ? lerpDoubleValue(size.width * 0.40 + shift, 12 + shift, t)
          : lerpDoubleValue(size.width * 0.60 + shift, size.width - 12 + shift, t);

      final trunkRect = Rect.fromCenter(
        center: Offset(edgeX, y - trunkHeight * 0.45),
        width: trunkWidth,
        height: trunkHeight,
      );

      final fogMix = (1.0 - t).clamp(0.0, 1.0);
      final barkColor = Color.lerp(
        GameConfig.redwoodMid,
        fogColor,
        fogMix * 0.62, // HACKABLE: distance fog on posts
      )!;
      final barkDarkColor = Color.lerp(
        GameConfig.redwoodDark,
        fogColor,
        fogMix * 0.46,
      )!;
      final alpha = (0.48 + t * 0.52).clamp(0.0, 1.0);

      final bark = Paint()..color = barkColor.withValues(alpha: alpha);
      final barkDark = Paint()..color = barkDarkColor.withValues(alpha: alpha);
      final moss = Paint()
        ..color = mossBase.withValues(alpha: (0.10 + t * 0.26).clamp(0.0, 1.0));

      canvas.drawShadow(
        Path()
          ..addRRect(
            RRect.fromRectAndRadius(
              trunkRect,
              Radius.circular(trunkWidth * 0.18),
            ),
          ),
        Colors.black.withValues(alpha: 0.28),
        trunkWidth * 0.16,
        false,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(trunkRect, Radius.circular(trunkWidth * 0.18)),
        bark,
      );

      // Bark grooves
      canvas.drawRect(
        Rect.fromLTWH(
          trunkRect.left + trunkWidth * 0.16,
          trunkRect.top,
          trunkWidth * 0.11,
          trunkHeight,
        ),
        barkDark,
      );
      canvas.drawRect(
        Rect.fromLTWH(
          trunkRect.left + trunkWidth * 0.54,
          trunkRect.top,
          trunkWidth * 0.08,
          trunkHeight,
        ),
        barkDark,
      );

      // Warm edge highlight
      final highlight = Paint()
        ..color = const Color(0xFFFFC07A).withValues(alpha: 0.10 + t * 0.10);
      canvas.drawRect(
        Rect.fromLTWH(
          trunkRect.left + trunkWidth * 0.06,
          trunkRect.top + trunkHeight * 0.04,
          trunkWidth * 0.06,
          trunkHeight * 0.90,
        ),
        highlight,
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

    // Soft full-scene fog blend.
    final fogPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          const Color(0xFFD8D1BE).withValues(alpha: 0.06),
          const Color(0xFFDCD4C3).withValues(alpha: 0.14),
          const Color(0xFFE2DAC9).withValues(alpha: 0.18),
        ],
        stops: const [0.32, 0.50, 0.72, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, fogPaint);

    // Side forest haze to soften corridor walls.
    final sideHazeLeft = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          const Color(0xFFCAD4C1).withValues(alpha: 0.18),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width * 0.38, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width * 0.38, size.height), sideHazeLeft);

    final sideHazeRight = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerRight,
        end: Alignment.centerLeft,
        colors: [
          const Color(0xFFCAD4C1).withValues(alpha: 0.18),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromLTWH(size.width * 0.62, 0, size.width * 0.38, size.height),
      );
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.62, 0, size.width * 0.38, size.height),
      sideHazeRight,
    );

    // Subtle cinematic vignette.
    final vignette = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          Colors.transparent,
          Colors.black.withValues(alpha: 0.24),
        ],
        stops: const [0.54, 0.80, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, vignette);
  }

  void _paintEnemies(Canvas canvas, Size size) {
    final sorted = [...enemies]..sort((a, b) => b.distance.compareTo(a.distance));

    for (final enemy in sorted) {
      final x = worldXToScreen(enemy.x - playerX, enemy.distance, size);
      final y = enemyScreenY(enemy.distance, size);
      final r = enemyRadius(enemy.distance) * enemy.radiusScale;

      final depthFog = ((enemy.distance - 2.0) / 18.0).clamp(0.0, 1.0);
      final bodyColor = enemy.alive
          ? Color.lerp(enemy.tint, const Color(0xFFD8D1BE), depthFog * 0.55)!
          : Colors.white.withValues(alpha: enemy.flash.clamp(0.0, 1.0));

      final bodyPaint = Paint()
        ..color = bodyColor.withValues(
          alpha: enemy.alive ? (1.0 - depthFog * 0.35) : 1.0,
        );

      final darkPaint = Paint()
        ..color = Color.lerp(
          const Color(0xFF7A848D),
          const Color(0xFFD8D1BE),
          depthFog * 0.45,
        )!;
      final eyePaint = Paint()
        ..color = Colors.redAccent.withValues(alpha: 1.0 - depthFog * 0.25);
      final limbPaint = Paint()
        ..color = Color.lerp(
          const Color(0xFF8C979F),
          const Color(0xFFD8D1BE),
          depthFog * 0.45,
        )!
        ..strokeWidth = math.max(2.0, r * 0.10)
        ..strokeCap = StrokeCap.round;

      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: (0.22 - depthFog * 0.10).clamp(0.0, 1.0));
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y + r * 1.08),
          width: r * 1.4,
          height: r * 0.40,
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

  // ============================================================
  // HACKABLE: projectile visuals
  // IMPORTANT:
  // projectile.position.dx is WORLD SPACE, so render uses:
  // projectile.position.dx - playerX
  // ============================================================
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
          center: Offset(centerX, baseY - 2),
          width: 24,
          height: 46,
        ),
        const Radius.circular(8),
      ),
      energyGlow,
    );

    canvas.drawCircle(Offset(centerX, baseY - 14), 18, energyGlow);
  }

  void _paintBossHealthBar(Canvas canvas, Size size) {
    if (bossMaxHealth <= 0 || bossHealth <= 0) return;

    final barWidth = math.min(size.width * 0.58, 420.0);
    const barHeight = 16.0;
    final left = (size.width - barWidth) / 2;
    final top = 18.0;

    final bg = Paint()..color = Colors.black.withValues(alpha: 0.50);
    final fg = Paint()..color = Colors.redAccent;
    final frame = Paint()
      ..color = const Color(0xFFFFC36E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, barWidth, barHeight),
      const Radius.circular(8),
    );

    canvas.drawRRect(rect, bg);

    final fill = (bossHealth / bossMaxHealth).clamp(0.0, 1.0);
    final fillRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, barWidth * fill, barHeight),
      const Radius.circular(8),
    );
    canvas.drawRRect(fillRect, fg);
    canvas.drawRRect(rect, frame);

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'BOSS',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(canvas, Offset(left + 8, top - 1));
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
