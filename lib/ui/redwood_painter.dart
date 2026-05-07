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
    _paintEnvironmentLighting(canvas, size);
    _paintAtmosphere(canvas, size);
    _paintFloatingParticles(canvas, size);
    _paintNearMotionDrift(canvas, size);
    _paintForegroundPosts(canvas, size);
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
    return _travelCurveAmount() * size.width * 0.08;
  }

  void _paintEnvironmentLighting(Canvas canvas, Size size) {
    final driftX = math.sin(worldZ * 0.012) * size.width * 0.012;
    final centerX = size.width * 0.5 + driftX + _travelShift(size) * 0.25;
    final horizonY = size.height * 0.40;

    final canopyShade = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withValues(alpha: 0.30),
          Colors.black.withValues(alpha: 0.12),
          Colors.transparent,
        ],
        stops: const [0.0, 0.24, 1.0],
      ).createShader(
        Rect.fromLTWH(0, 0, size.width, size.height * 0.34),
      );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.34),
      canopyShade,
    );

    final vanishingGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFF0BE).withValues(alpha: 0.18),
          const Color(0xFFFFF0BE).withValues(alpha: 0.07),
          Colors.transparent,
        ],
        stops: const [0.0, 0.28, 1.0],
      ).createShader(
        Rect.fromCenter(
          center: Offset(centerX, size.height * 0.47),
          width: size.width * 0.68,
          height: size.height * 0.30,
        ),
      );

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX, size.height * 0.47),
        width: size.width * 0.68,
        height: size.height * 0.30,
      ),
      vanishingGlow,
    );

    final shaftPaintA = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFFFF4D2).withValues(alpha: 0.08),
          const Color(0xFFFFF4D2).withValues(alpha: 0.03),
          Colors.transparent,
        ],
        stops: const [0.0, 0.40, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final shaftPaintB = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFFFF8E1).withValues(alpha: 0.06),
          const Color(0xFFFFF8E1).withValues(alpha: 0.02),
          Colors.transparent,
        ],
        stops: const [0.0, 0.42, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final leftShaft = Path()
      ..moveTo(centerX - size.width * 0.18, 0)
      ..lineTo(centerX - size.width * 0.05, 0)
      ..lineTo(centerX + size.width * 0.02, horizonY + size.height * 0.22)
      ..lineTo(centerX - size.width * 0.08, horizonY + size.height * 0.22)
      ..close();

    final rightShaft = Path()
      ..moveTo(centerX + size.width * 0.04, 0)
      ..lineTo(centerX + size.width * 0.17, 0)
      ..lineTo(centerX + size.width * 0.08, horizonY + size.height * 0.24)
      ..lineTo(centerX - size.width * 0.01, horizonY + size.height * 0.24)
      ..close();

    canvas.drawPath(leftShaft, shaftPaintA);
    canvas.drawPath(rightShaft, shaftPaintB);
  }

  void _paintAtmosphere(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    final fog = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFF1E8C9).withValues(alpha: 0.14),
          const Color(0xFFE2DBC3).withValues(alpha: 0.07),
          Colors.transparent,
        ],
        stops: const [0.0, 0.42, 1.0],
      ).createShader(
        Rect.fromLTWH(0, size.height * 0.34, size.width, size.height * 0.22),
      );

    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.34, size.width, size.height * 0.22),
      fog,
    );

    // HACKABLE: slow lower haze drift for motion feel
    final hazeX = math.sin(worldZ * 0.020) * size.width * 0.02;
    final lowerHaze = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFF3CF).withValues(alpha: 0.07),
          const Color(0xFFFFF3CF).withValues(alpha: 0.03),
          Colors.transparent,
        ],
        stops: const [0.0, 0.52, 1.0],
      ).createShader(
        Rect.fromCenter(
          center: Offset(size.width * 0.5 + hazeX, size.height * 0.72),
          width: size.width * 0.72,
          height: size.height * 0.24,
        ),
      );

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5 + hazeX, size.height * 0.72),
        width: size.width * 0.72,
        height: size.height * 0.24,
      ),
      lowerHaze,
    );

    final sideDarkenLeft = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.black.withValues(alpha: 0.18),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromLTWH(0, 0, size.width * 0.28, size.height),
      );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width * 0.28, size.height),
      sideDarkenLeft,
    );

    final sideDarkenRight = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerRight,
        end: Alignment.centerLeft,
        colors: [
          Colors.black.withValues(alpha: 0.18),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromLTWH(size.width * 0.72, 0, size.width * 0.28, size.height),
      );

    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.72, 0, size.width * 0.28, size.height),
      sideDarkenRight,
    );

    final vignette = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          Colors.transparent,
          Colors.black.withValues(alpha: 0.22),
        ],
        stops: const [0.55, 0.83, 1.0],
      ).createShader(rect);

    canvas.drawRect(rect, vignette);
  }

  void _paintFloatingParticles(Canvas canvas, Size size) {
    final horizonY = size.height * 0.38;
    final lightCenter = Offset(
      size.width * 0.5 + math.sin(worldZ * 0.01) * size.width * 0.01,
      size.height * 0.46,
    );

    for (int i = 0; i < 40; i++) {
      final seed = i.toDouble();
      final layer = (i % 3) / 2.0;
      final xBase = ((math.sin(seed * 12.9898) * 43758.5453).abs() % 1.0);
      final yBase = ((math.cos(seed * 78.233) * 24634.6345).abs() % 1.0);

      final x =
          xBase * size.width +
          math.sin(worldZ * (0.40 + layer * 0.22) + seed) * (6 + layer * 8) -
          playerX * (1.0 + layer * 2.5);

      final y =
          lerpDoubleValue(horizonY - 20, size.height * 0.90, yBase) -
          ((worldZ * (8 + layer * 10) + seed * 17) % (size.height * 0.80));

      if (y < horizonY - 36 || y > size.height * 0.92) continue;

      final distToLight = (Offset(x, y) - lightCenter).distance;
      final glowBoost =
          (1.0 - (distToLight / (size.width * 0.42))).clamp(0.0, 1.0);

      final r = lerpDoubleValue(1.2, 3.6, layer * 0.8 + glowBoost * 0.2);
      final alpha = lerpDoubleValue(0.06, 0.24, glowBoost);

      final glowPaint = Paint()
        ..color = const Color(0xFFFFF4CC).withValues(alpha: alpha * 0.24);
      final motePaint = Paint()
        ..color = const Color(0xFFFFF4CC).withValues(alpha: alpha);

      canvas.drawCircle(Offset(x, y), r * 2.0, glowPaint);
      canvas.drawCircle(Offset(x, y), r, motePaint);
    }

    for (int i = 0; i < 14; i++) {
      final seed = i.toDouble();
      final side = i.isEven ? -1.0 : 1.0;
      final p = (i + 1) / 14.0;

      final x =
          size.width * 0.5 +
          side * lerpDoubleValue(size.width * 0.16, size.width * 0.40, p) +
          math.sin(worldZ * 0.8 + seed) * 12 -
          playerX * lerpDoubleValue(1.0, 3.0, p);

      final y =
          lerpDoubleValue(size.height * 0.50, size.height * 0.92, p) +
          math.cos(worldZ * 0.9 + seed * 1.3) * 5;

      final w = lerpDoubleValue(4, 9, p);
      final h = lerpDoubleValue(2, 5, p);

      final leafPaint = Paint()
        ..color = (i % 3 == 0
                ? const Color(0xFF8D6A36)
                : const Color(0xFF6A512C))
            .withValues(alpha: 0.14);

      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: w, height: h),
        leafPaint,
      );
    }
  }

  void _paintNearMotionDrift(Canvas canvas, Size size) {
    final centerX = size.width * 0.5;

    for (int i = 0; i < 18; i++) {
      final p = (i + 1) / 18.0;
      final y =
          lerpDoubleValue(size.height * 0.52, size.height * 0.94, p) -
          ((worldZ * 14 + i * 21) % 42);

      final leftX =
          centerX - lerpDoubleValue(size.width * 0.16, size.width * 0.34, p) -
          playerX * lerpDoubleValue(2.0, 5.0, p);
      final rightX =
          centerX + lerpDoubleValue(size.width * 0.16, size.width * 0.34, p) -
          playerX * lerpDoubleValue(2.0, 5.0, p);

      final width = lerpDoubleValue(8, 28, p);
      final height = lerpDoubleValue(1.2, 3.4, p);

      final streakPaint = Paint()
        ..color = const Color(0xFFFFF0C4).withValues(alpha: 0.04 + p * 0.05);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(leftX, y),
            width: width,
            height: height,
          ),
          Radius.circular(height),
        ),
        streakPaint,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(rightX, y),
            width: width,
            height: height,
          ),
          Radius.circular(height),
        ),
        streakPaint,
      );
    }
  }

  void _paintForegroundPosts(Canvas canvas, Size size) {
    final horizonY = size.height * 0.40;
    final bottomY = size.height;
    final shift = (-playerX * 16) + _travelShift(size);

    const depthStops = [0.66, 0.82, 0.94];

    for (int i = 0; i < depthStops.length; i++) {
      final t = depthStops[i];
      final y = lerpDoubleValue(horizonY + 10, bottomY + 28, t * t);

      final trunkHeight = lerpDoubleValue(120, 340, t);
      final trunkWidth = lerpDoubleValue(26, 88, t);

      final leftX =
          lerpDoubleValue(size.width * 0.30 + shift, 12 + shift, t);
      final rightX =
          lerpDoubleValue(size.width * 0.70 + shift, size.width - 12 + shift, t);

      _paintOnePost(canvas, leftX, y, trunkWidth, trunkHeight);
      _paintOnePost(canvas, rightX, y, trunkWidth, trunkHeight);
    }
  }

  void _paintOnePost(
    Canvas canvas,
    double x,
    double y,
    double trunkWidth,
    double trunkHeight,
  ) {
    final trunkRect = Rect.fromCenter(
      center: Offset(x, y - trunkHeight * 0.45),
      width: trunkWidth,
      height: trunkHeight,
    );

    final bark = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Color(0xFF6F4025),
          Color(0xFF935B36),
          Color(0xFF4E2D1A),
        ],
      ).createShader(trunkRect);

    final barkDark = Paint()
      ..color = const Color(0xFF4A2616).withValues(alpha: 0.90);

    final rootShadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.16);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x, trunkRect.bottom - 3),
        width: trunkWidth * 1.7,
        height: trunkWidth * 0.34,
      ),
      rootShadow,
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
    // HACKABLE: reduced bob so motion feels less fake / floaty
    final bobX = math.sin(bobTime * 2.6) * 1.8;
    final bobY = math.sin(bobTime * 5.0) * 1.2;
    final centerX = size.width / 2 + bobX;
    final baseY = size.height * 0.885 + bobY + (firePressed ? 3 : 0);

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
