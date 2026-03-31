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
    required this.worldZ,
    required this.state,
    required this.currentWave,
    required this.firePressed,
    required this.bossHealth,
    required this.bossMaxHealth,
    required this.worldXToScreen,
    required this.enemyScreenY,
    required this.enemyRadius,
    required this.crosshairPosition,
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

  final double Function(double worldX, double distance, Size size)
  worldXToScreen;
  final double Function(double distance, Size size) enemyScreenY;
  final double Function(double distance) enemyRadius;

  @override
  void paint(Canvas canvas, Size size) {
    _paintBackground(canvas, size);
    _paintMovingForest(canvas, size);
    _paintEnemies(canvas, size);
    _paintEnemyProjectiles(canvas, size);
    _paintTraces(canvas);
    _paintCrosshair(canvas);
    _paintWeapon(canvas, size);
    _paintBossHealthBar(canvas, size);
  }

  void _paintBackground(Canvas canvas, Size size) {
    final sky = Rect.fromLTWH(0, 0, size.width, size.height * 0.62);
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF17231D), Color(0xFF30443A), Color(0xFF7D9782)],
      ).createShader(sky);

    canvas.drawRect(sky, skyPaint);

    final mistPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              GameConfig.mist.withValues(alpha: 0.06),
              GameConfig.mist.withValues(alpha: 0.16),
            ],
          ).createShader(
            Rect.fromLTWH(
              0,
              size.height * 0.25,
              size.width,
              size.height * 0.40,
            ),
          );

    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.25, size.width, size.height * 0.40),
      mistPaint,
    );
  }

  // ============================================================
  // HACKABLE: moving forest system
  // worldZ drives the illusion that the player is moving forward.
  // ============================================================
  void _paintMovingForest(Canvas canvas, Size size) {
    final horizonY = size.height * 0.37;
    final bottomY = size.height;
    final centerX = size.width / 2;

    // HACKABLE: corridor shape
    final corridorTopHalf = size.width * 0.08;
    final corridorBottomHalf = size.width * 0.26;

    final trail = Path()
      ..moveTo(centerX - corridorBottomHalf, bottomY)
      ..lineTo(centerX + corridorBottomHalf, bottomY)
      ..lineTo(centerX + corridorTopHalf, horizonY)
      ..lineTo(centerX - corridorTopHalf, horizonY)
      ..close();

    final trailPaint = Paint()
      ..shader =
          const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6B4A2F), Color(0xFF4A2F1E), Color(0xFF24170F)],
          ).createShader(
            Rect.fromLTWH(0, horizonY, size.width, size.height - horizonY),
          );

    canvas.drawPath(trail, trailPaint);

    final linePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..strokeWidth = 1.25;

    for (int i = 1; i <= 10; i++) {
      final t = i / 11;
      final y = lerpDoubleValue(horizonY, bottomY, t * t);
      final halfW = lerpDoubleValue(corridorTopHalf, corridorBottomHalf, t);
      canvas.drawLine(
        Offset(centerX - halfW, y),
        Offset(centerX + halfW, y),
        linePaint,
      );
    }

    final edgeGlow = Paint()
      ..color = GameConfig.redwoodGlow.withValues(alpha: 0.18)
      ..strokeWidth = 2.8;

    canvas.drawLine(
      Offset(centerX - corridorTopHalf, horizonY),
      Offset(centerX - corridorBottomHalf, bottomY),
      edgeGlow,
    );
    canvas.drawLine(
      Offset(centerX + corridorTopHalf, horizonY),
      Offset(centerX + corridorBottomHalf, bottomY),
      edgeGlow,
    );

    _paintForestSide(
      canvas,
      size,
      isLeft: true,
      centerX: centerX,
      horizonY: horizonY,
      bottomY: bottomY,
      corridorTopHalf: corridorTopHalf,
      corridorBottomHalf: corridorBottomHalf,
    );

    _paintForestSide(
      canvas,
      size,
      isLeft: false,
      centerX: centerX,
      horizonY: horizonY,
      bottomY: bottomY,
      corridorTopHalf: corridorTopHalf,
      corridorBottomHalf: corridorBottomHalf,
    );

    final fogFront = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              GameConfig.mist.withValues(alpha: 0.03),
              GameConfig.mist.withValues(alpha: 0.10),
            ],
          ).createShader(
            Rect.fromLTWH(0, horizonY - 10, size.width, size.height * 0.35),
          );

    canvas.drawRect(
      Rect.fromLTWH(0, horizonY - 10, size.width, size.height * 0.35),
      fogFront,
    );
  }

  void _paintForestSide(
    Canvas canvas,
    Size size, {
    required bool isLeft,
    required double centerX,
    required double horizonY,
    required double bottomY,
    required double corridorTopHalf,
    required double corridorBottomHalf,
  }) {
    const int treeCount = 14;
    const double depthLoop = 92.0;
    const double depthSpacing = 7.0;

    final barkBase = GameConfig.redwoodMid;
    final barkDarkBase = GameConfig.redwoodDark;
    final mossBase = const Color(0xFF2B4C2D);

    final side = isLeft ? -1.0 : 1.0;

    for (int i = 0; i < treeCount; i++) {
      final z =
          (((i * depthSpacing) - worldZ * 12.0) % depthLoop + depthLoop) %
              depthLoop +
          1.2;

      final nearT = 1.0 - (z / depthLoop);
      final perspective = nearT * nearT;

      final y = lerpDoubleValue(horizonY + 6, bottomY + 40, perspective);
      final trunkHeight = lerpDoubleValue(26, 320, perspective);
      final trunkWidth = lerpDoubleValue(5, 82, perspective);

      final corridorEdge = lerpDoubleValue(
        corridorTopHalf,
        corridorBottomHalf,
        perspective,
      );

      final forestOffset = lerpDoubleValue(26, 185, perspective);

      final sway =
          math.sin((worldZ * 1.7) + i * 0.9 + (isLeft ? 0.0 : 1.4)) *
          lerpDoubleValue(1.0, 8.0, perspective);

      final playerParallax = -playerX * lerpDoubleValue(8.0, 28.0, perspective);

      final x =
          centerX +
          side * (corridorEdge + forestOffset) +
          sway +
          playerParallax;

      final bark = Paint()
        ..color = barkBase.withValues(
          alpha: lerpDoubleValue(0.22, 0.98, perspective),
        );
      final barkDark = Paint()
        ..color = barkDarkBase.withValues(
          alpha: lerpDoubleValue(0.20, 0.90, perspective),
        );
      final moss = Paint()
        ..color = mossBase.withValues(
          alpha: lerpDoubleValue(0.10, 0.36, perspective),
        );

      final trunkRect = Rect.fromCenter(
        center: Offset(x, y - trunkHeight * 0.45),
        width: trunkWidth,
        height: trunkHeight,
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

      if (i.isEven) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(x, trunkRect.top + trunkHeight * 0.28),
            width: trunkWidth * 0.92,
            height: trunkHeight * 0.14,
          ),
          moss,
        );
      }
    }
  }

  void _paintEnemies(Canvas canvas, Size size) {
    final sorted = [...enemies]
      ..sort((a, b) => b.distance.compareTo(a.distance));

    for (final enemy in sorted) {
      final x = worldXToScreen(enemy.x - playerX, enemy.distance, size);
      final y = enemyScreenY(enemy.distance, size);
      final r = enemyRadius(enemy.distance) * enemy.radiusScale;

      final fog = (1.0 - (enemy.distance / GameConfig.enemyStartDistanceMax))
          .clamp(0.30, 1.0);

      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.12 * fog);

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y + r * 1.25),
          width: r * 1.15,
          height: r * 0.32,
        ),
        shadowPaint,
      );

      final bodyPaint = Paint()
        ..color = enemy.alive
            ? enemy.tint.withValues(alpha: fog)
            : Colors.white.withValues(alpha: enemy.flash.clamp(0.0, 1.0));

      final darkPaint = Paint()
        ..color = const Color(0xFF7A848D).withValues(alpha: fog);
      final eyePaint = Paint()..color = Colors.redAccent.withValues(alpha: fog);
      final limbPaint = Paint()
        ..color = const Color(0xFF8C979F).withValues(alpha: fog)
        ..strokeWidth = math.max(2.0, r * 0.10)
        ..strokeCap = StrokeCap.round;

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
        final fg = Paint()..color = Colors.redAccent.withValues(alpha: fog);
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
            Rect.fromLTWH(
              left,
              top,
              width * (enemy.health / enemy.maxHealth),
              6,
            ),
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
        ..color =
            (projectile.isBossShot ? Colors.orangeAccent : Colors.redAccent)
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
        Rect.fromCenter(center: Offset(centerX, baseY), width: 70, height: 138),
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
  bool shouldRepaint(covariant RedwoodPainter oldDelegate) => true;
}
