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
    _paintForestWorld(canvas, size);
    _paintEnemies(canvas, size);
    _paintEnemyProjectiles(canvas, size);
    _paintTraces(canvas);
    _paintCrosshair(canvas);
    _paintWeapon(canvas, size);
    _paintBossHealthBar(canvas, size);
  }

  void _paintBackground(Canvas canvas, Size size) {
    final skyRect = Rect.fromLTWH(0, 0, size.width, size.height * 0.64);
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF0F1814),
          Color(0xFF1F2D25),
          Color(0xFF43584B),
          Color(0xFF6F8574),
        ],
      ).createShader(skyRect);

    canvas.drawRect(skyRect, skyPaint);

    final canopyShade = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withValues(alpha: 0.34),
          Colors.black.withValues(alpha: 0.08),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.34));

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.34),
      canopyShade,
    );
  }

  // ============================================================
  // HACKABLE: main world pass
  // ============================================================
  void _paintForestWorld(Canvas canvas, Size size) {
    final horizonY = size.height * 0.355;
    final bottomY = size.height;
    final centerX = size.width / 2;

    final corridorTopHalf = size.width * 0.072;
    final corridorBottomHalf = size.width * 0.23;

    _paintSideGroundMass(
      canvas,
      size,
      horizonY,
      bottomY,
      centerX,
      corridorTopHalf,
      corridorBottomHalf,
    );

    _paintGround(
      canvas,
      size,
      horizonY,
      bottomY,
      centerX,
      corridorTopHalf,
      corridorBottomHalf,
    );

    _paintFarTreeLine(canvas, size, horizonY, centerX, corridorTopHalf);

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

    _paintDepthShade(canvas, size, horizonY);
  }

  // ============================================================
  // HACKABLE: these dark wedges give the trunks "ground"
  // instead of making them float against open sky.
  // ============================================================
  void _paintSideGroundMass(
    Canvas canvas,
    Size size,
    double horizonY,
    double bottomY,
    double centerX,
    double corridorTopHalf,
    double corridorBottomHalf,
  ) {
    final leftGround = Path()
      ..moveTo(0, bottomY)
      ..lineTo(centerX - corridorBottomHalf, bottomY)
      ..lineTo(centerX - corridorTopHalf, horizonY)
      ..lineTo(0, horizonY + size.height * 0.02)
      ..close();

    final rightGround = Path()
      ..moveTo(size.width, bottomY)
      ..lineTo(centerX + corridorBottomHalf, bottomY)
      ..lineTo(centerX + corridorTopHalf, horizonY)
      ..lineTo(size.width, horizonY + size.height * 0.02)
      ..close();

    final sideGroundPaint = Paint()
      ..shader =
          const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B261F), Color(0xFF121910), Color(0xFF0B0A12)],
          ).createShader(
            Rect.fromLTWH(0, horizonY, size.width, size.height - horizonY),
          );

    canvas.drawPath(leftGround, sideGroundPaint);
    canvas.drawPath(rightGround, sideGroundPaint);
  }

  void _paintGround(
    Canvas canvas,
    Size size,
    double horizonY,
    double bottomY,
    double centerX,
    double corridorTopHalf,
    double corridorBottomHalf,
  ) {
    final groundPath = Path()
      ..moveTo(centerX - corridorBottomHalf, bottomY)
      ..lineTo(centerX + corridorBottomHalf, bottomY)
      ..lineTo(centerX + corridorTopHalf, horizonY)
      ..lineTo(centerX - corridorTopHalf, horizonY)
      ..close();

    final groundPaint = Paint()
      ..shader =
          const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF68482F), Color(0xFF472F20), Color(0xFF26180F)],
          ).createShader(
            Rect.fromLTWH(0, horizonY, size.width, size.height - horizonY),
          );

    canvas.drawPath(groundPath, groundPaint);

    final centerRut = Paint()..color = Colors.black.withValues(alpha: 0.10);
    canvas.drawPath(
      Path()
        ..moveTo(centerX - corridorBottomHalf * 0.18, bottomY)
        ..lineTo(centerX + corridorBottomHalf * 0.18, bottomY)
        ..lineTo(centerX + corridorTopHalf * 0.13, horizonY)
        ..lineTo(centerX - corridorTopHalf * 0.13, horizonY)
        ..close(),
      centerRut,
    );

    final edgeGlow = Paint()
      ..color = GameConfig.redwoodGlow.withValues(alpha: 0.20)
      ..strokeWidth = 3.2;

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

    final depthLines = Paint()
      ..color = Colors.black.withValues(alpha: 0.16)
      ..strokeWidth = 1.15;

    for (int i = 1; i <= 11; i++) {
      final t = i / 12;
      final y = lerpDoubleValue(horizonY, bottomY, t * t);
      final half = lerpDoubleValue(corridorTopHalf, corridorBottomHalf, t);
      canvas.drawLine(
        Offset(centerX - half, y),
        Offset(centerX + half, y),
        depthLines,
      );
    }

    _paintGroundStreaks(
      canvas,
      size,
      horizonY,
      bottomY,
      centerX,
      corridorTopHalf,
      corridorBottomHalf,
    );
  }

  void _paintGroundStreaks(
    Canvas canvas,
    Size size,
    double horizonY,
    double bottomY,
    double centerX,
    double corridorTopHalf,
    double corridorBottomHalf,
  ) {
    const int streakCount = 18;
    const double loopDepth = 44.0;
    const double spacing = 2.7;

    for (int i = 0; i < streakCount; i++) {
      final z =
          (((i * spacing) - worldZ * 10.5) % loopDepth + loopDepth) %
              loopDepth +
          0.9;
      final nearT = 1.0 - (z / loopDepth);
      final p = nearT * nearT;

      final y = lerpDoubleValue(horizonY + 10, bottomY + 8, p);
      final half = lerpDoubleValue(corridorTopHalf, corridorBottomHalf, p);

      final offsetSeed = ((i % 6) - 2.5) / 3.0;
      final x =
          centerX +
          offsetSeed * half * 0.75 +
          math.sin(worldZ * 1.4 + i) * lerpDoubleValue(0.2, 5.0, p) -
          playerX * lerpDoubleValue(1.5, 9.0, p);

      final width = lerpDoubleValue(3.0, 20.0, p);
      final height = lerpDoubleValue(1.0, 8.0, p);

      final alpha = lerpDoubleValue(0.04, 0.18, p);

      final debris = Paint()
        ..color = const Color(0xFF1A120D).withValues(alpha: alpha);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, y), width: width, height: height),
          Radius.circular(height * 0.35),
        ),
        debris,
      );
    }
  }

  // ============================================================
  // HACKABLE: this is the horizon forest wall.
  // Far trunks should sit behind this so they emerge naturally.
  // ============================================================
  void _paintFarTreeLine(
    Canvas canvas,
    Size size,
    double horizonY,
    double centerX,
    double corridorTopHalf,
  ) {
    final leftLine = Path()
      ..moveTo(0, horizonY + size.height * 0.01)
      ..lineTo(centerX - corridorTopHalf, horizonY)
      ..lineTo(centerX - corridorTopHalf - size.width * 0.02, horizonY - 6)
      ..lineTo(0, horizonY - size.height * 0.02)
      ..close();

    final rightLine = Path()
      ..moveTo(size.width, horizonY + size.height * 0.01)
      ..lineTo(centerX + corridorTopHalf, horizonY)
      ..lineTo(centerX + corridorTopHalf + size.width * 0.02, horizonY - 6)
      ..lineTo(size.width, horizonY - size.height * 0.02)
      ..close();

    final linePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF223028), Color(0xFF141C16)],
      ).createShader(Rect.fromLTWH(0, horizonY - 20, size.width, 40));

    canvas.drawPath(leftLine, linePaint);
    canvas.drawPath(rightLine, linePaint);

    final silhouettePaint = Paint()
      ..color = const Color(0xFF0F1712).withValues(alpha: 0.75);

    for (int i = 0; i < 18; i++) {
      final t = i / 17;
      final leftX = lerpDoubleValue(0, centerX - corridorTopHalf - 10, t);
      final rightX = lerpDoubleValue(
        centerX + corridorTopHalf + 10,
        size.width,
        t,
      );

      final h = 16 + (math.sin(i * 1.3) + 1) * 10;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(leftX - 6, horizonY - h, 12, h + 6),
          const Radius.circular(5),
        ),
        silhouettePaint,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(rightX - 6, horizonY - h, 12, h + 6),
          const Radius.circular(5),
        ),
        silhouettePaint,
      );
    }
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
    const int treeCount = 16;
    const double depthLoop = 98.0;
    const double spacing = 6.2;

    final side = isLeft ? -1.0 : 1.0;

    for (int i = 0; i < treeCount; i++) {
      final z =
          (((i * spacing) - worldZ * 12.0) % depthLoop + depthLoop) %
              depthLoop +
          1.0;

      final nearT = 1.0 - (z / depthLoop);
      final p = nearT * nearT;

      final y = lerpDoubleValue(horizonY + 6, bottomY + 40, p);
      final trunkHeight = lerpDoubleValue(26, 355, p);
      final trunkWidth = lerpDoubleValue(6, 96, p);

      final corridorEdge = lerpDoubleValue(
        corridorTopHalf,
        corridorBottomHalf,
        p,
      );
      final forestOffset = lerpDoubleValue(28, 205, p);

      final sway =
          math.sin(worldZ * 1.75 + i * 0.8 + (isLeft ? 0.0 : 1.5)) *
          lerpDoubleValue(0.8, 9.0, p);

      final parallax = -playerX * lerpDoubleValue(8.0, 31.0, p);

      final x =
          centerX + side * (corridorEdge + forestOffset) + sway + parallax;

      _paintSingleTree(
        canvas,
        x,
        y,
        trunkWidth,
        trunkHeight,
        p,
        bottomY,
        i,
        horizonY,
      );
    }
  }

  void _paintSingleTree(
    Canvas canvas,
    double x,
    double y,
    double trunkWidth,
    double trunkHeight,
    double p,
    double bottomY,
    int i,
    double horizonY,
  ) {
    final bark = Paint()
      ..color = GameConfig.redwoodMid.withValues(
        alpha: lerpDoubleValue(0.18, 0.98, p),
      );
    final barkDark = Paint()
      ..color = GameConfig.redwoodDark.withValues(
        alpha: lerpDoubleValue(0.16, 0.90, p),
      );
    final moss = Paint()
      ..color = const Color(
        0xFF284A2C,
      ).withValues(alpha: lerpDoubleValue(0.06, 0.34, p));
    final rootShadow = Paint()
      ..color = Colors.black.withValues(alpha: lerpDoubleValue(0.03, 0.16, p));

    final trunkRect = Rect.fromCenter(
      center: Offset(x, y - trunkHeight * 0.45),
      width: trunkWidth,
      height: trunkHeight,
    );

    // Hide more of far trees behind the distant tree line.
    final hideAmount = lerpDoubleValue(14.0, 0.0, p);
    final visibleTop = math.max(trunkRect.top + hideAmount, horizonY - 2);

    final visibleRect = Rect.fromLTRB(
      trunkRect.left,
      visibleTop,
      trunkRect.right,
      trunkRect.bottom,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(visibleRect, Radius.circular(trunkWidth * 0.18)),
      bark,
    );

    canvas.drawRect(
      Rect.fromLTWH(
        visibleRect.left + trunkWidth * 0.18,
        visibleRect.top,
        trunkWidth * 0.12,
        visibleRect.height,
      ),
      barkDark,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        visibleRect.left + trunkWidth * 0.58,
        visibleRect.top,
        trunkWidth * 0.10,
        visibleRect.height,
      ),
      barkDark,
    );

    if (i.isEven && visibleRect.height > trunkHeight * 0.2) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, visibleRect.top + visibleRect.height * 0.25),
          width: trunkWidth * 0.95,
          height: visibleRect.height * 0.14,
        ),
        moss,
      );
    }

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x, trunkRect.bottom - trunkWidth * 0.10),
        width: trunkWidth * 1.65,
        height: trunkWidth * 0.42,
      ),
      rootShadow,
    );

    final rootPaint = Paint()
      ..color = GameConfig.redwoodDark.withValues(
        alpha: lerpDoubleValue(0.14, 0.55, p),
      );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x - trunkWidth * 0.34, trunkRect.bottom - 1),
          width: trunkWidth * 0.42,
          height: trunkWidth * 0.18,
        ),
        Radius.circular(trunkWidth * 0.05),
      ),
      rootPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x + trunkWidth * 0.34, trunkRect.bottom - 1),
          width: trunkWidth * 0.42,
          height: trunkWidth * 0.18,
        ),
        Radius.circular(trunkWidth * 0.05),
      ),
      rootPaint,
    );

    if (p > 0.58) {
      final groundContact = Paint()
        ..color = Colors.black.withValues(alpha: 0.10 * p);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, bottomY - 4),
          width: trunkWidth * 1.35,
          height: trunkWidth * 0.32,
        ),
        groundContact,
      );
    }
  }

  void _paintDepthShade(Canvas canvas, Size size, double horizonY) {
    final depthShade = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.00),
              Colors.black.withValues(alpha: 0.05),
              Colors.black.withValues(alpha: 0.10),
            ],
          ).createShader(
            Rect.fromLTWH(0, horizonY - 4, size.width, size.height * 0.30),
          );

    canvas.drawRect(
      Rect.fromLTWH(0, horizonY - 4, size.width, size.height * 0.30),
      depthShade,
    );
  }

  void _paintEnemies(Canvas canvas, Size size) {
    final sorted = [...enemies]
      ..sort((a, b) => b.distance.compareTo(a.distance));

    for (final enemy in sorted) {
      final emergence =
          ((GameConfig.enemyStartDistanceMax - enemy.distance) / 7.0).clamp(
            0.0,
            1.0,
          );
      if (emergence <= 0.02) continue;

      final x = worldXToScreen(enemy.x - playerX, enemy.distance, size);
      final y = enemyScreenY(enemy.distance, size);
      final r = enemyRadius(enemy.distance) * enemy.radiusScale;

      final depthFade =
          (1.0 - (enemy.distance / GameConfig.enemyStartDistanceMax)).clamp(
            0.22,
            1.0,
          );
      final visibility = (depthFade * emergence).clamp(0.0, 1.0);

      _paintEnemyShadow(canvas, x, y, r, visibility);
      _paintDroid(canvas, enemy, x, y, r, visibility);
      _paintEnemyHealth(canvas, enemy, x, y, r, visibility);
    }
  }

  void _paintEnemyShadow(
    Canvas canvas,
    double x,
    double y,
    double r,
    double vis,
  ) {
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.14 * vis);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x, y + r * 1.26),
        width: r * 1.24,
        height: r * 0.34,
      ),
      shadowPaint,
    );
  }

  void _paintDroid(
    Canvas canvas,
    Enemy enemy,
    double x,
    double y,
    double r,
    double vis,
  ) {
    final bodyPaint = Paint()
      ..color = enemy.alive
          ? enemy.tint.withValues(alpha: vis)
          : Colors.white.withValues(alpha: enemy.flash.clamp(0.0, 1.0));

    final darkPaint = Paint()
      ..color = const Color(0xFF69747C).withValues(alpha: vis);
    final eyePaint = Paint()..color = Colors.redAccent.withValues(alpha: vis);
    final limbPaint = Paint()
      ..color = const Color(0xFF88949D).withValues(alpha: vis)
      ..strokeWidth = math.max(2.0, r * 0.10)
      ..strokeCap = StrokeCap.round;

    final bool isBoss = enemy.type == EnemyType.boss;
    final bool isHeavy = enemy.type == EnemyType.heavy;

    final headW = isBoss
        ? r * 1.02
        : isHeavy
        ? r * 0.90
        : r * 0.82;
    final headH = isBoss ? r * 0.56 : r * 0.48;
    final torsoW = isBoss
        ? r * 1.18
        : isHeavy
        ? r * 1.02
        : r * 0.90;
    final torsoH = isBoss
        ? r * 1.52
        : isHeavy
        ? r * 1.34
        : r * 1.18;

    final headRect = Rect.fromCenter(
      center: Offset(x, y - r * 0.96),
      width: headW,
      height: headH,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(headRect, Radius.circular(r * 0.10)),
      darkPaint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x, y - r * 0.96),
          width: headW * 0.82,
          height: r * 0.16,
        ),
        Radius.circular(r * 0.04),
      ),
      Paint()..color = const Color(0xFF1A2228).withValues(alpha: vis),
    );

    canvas.drawCircle(Offset(x - r * 0.14, y - r * 0.96), r * 0.05, eyePaint);
    canvas.drawCircle(Offset(x + r * 0.14, y - r * 0.96), r * 0.05, eyePaint);

    final torso = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(x, y + r * 0.12),
        width: torsoW,
        height: torsoH,
      ),
      Radius.circular(r * 0.10),
    );
    canvas.drawRRect(torso, bodyPaint);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x, y + r * 0.10),
          width: torsoW * 0.22,
          height: torsoH * 0.74,
        ),
        Radius.circular(r * 0.04),
      ),
      darkPaint,
    );

    final shoulderY = y - r * 0.26;
    canvas.drawLine(
      Offset(x - torsoW * 0.32, shoulderY),
      Offset(x - torsoW * 0.94, y + r * 0.18),
      limbPaint,
    );
    canvas.drawLine(
      Offset(x + torsoW * 0.32, shoulderY),
      Offset(x + torsoW * 0.94, y + r * 0.18),
      limbPaint,
    );

    final hipY = y + torsoH * 0.42;
    canvas.drawLine(
      Offset(x - torsoW * 0.16, hipY),
      Offset(x - torsoW * 0.35, y + r * 1.34),
      limbPaint,
    );
    canvas.drawLine(
      Offset(x + torsoW * 0.16, hipY),
      Offset(x + torsoW * 0.35, y + r * 1.34),
      limbPaint,
    );

    if (isHeavy || isBoss) {
      final armor = Paint()
        ..color = const Color(0xFFCCB46A).withValues(alpha: vis * 0.95);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x - torsoW * 0.37, y - r * 0.12),
            width: r * 0.24,
            height: r * 0.20,
          ),
          Radius.circular(r * 0.04),
        ),
        armor,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x + torsoW * 0.37, y - r * 0.12),
            width: r * 0.24,
            height: r * 0.20,
          ),
          Radius.circular(r * 0.04),
        ),
        armor,
      );
    }

    if (isBoss) {
      final crown = Paint()
        ..color = const Color(0xFFFFC36E).withValues(alpha: vis * 0.95);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, y - r * 1.28),
            width: r * 0.72,
            height: r * 0.14,
          ),
          Radius.circular(r * 0.04),
        ),
        crown,
      );
    }
  }

  void _paintEnemyHealth(
    Canvas canvas,
    Enemy enemy,
    double x,
    double y,
    double r,
    double vis,
  ) {
    if (enemy.maxHealth <= 1 || !enemy.alive) return;

    final bg = Paint()..color = Colors.black.withValues(alpha: 0.40);
    final fg = Paint()..color = Colors.redAccent.withValues(alpha: vis);
    final width = r * 1.04;
    final left = x - width / 2;
    final top = y - r * 1.76;

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
      ..color = GameConfig.accent.withValues(alpha: 0.16)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(c, 20, glowPaint);

    final ringPaint = Paint()
      ..color = GameConfig.accent.withValues(alpha: 1.0)
      ..strokeWidth = 2.3
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(c, 12, ringPaint);
    canvas.drawLine(Offset(c.dx - 18, c.dy), Offset(c.dx - 6, c.dy), ringPaint);
    canvas.drawLine(Offset(c.dx + 6, c.dy), Offset(c.dx + 18, c.dy), ringPaint);
    canvas.drawLine(Offset(c.dx, c.dy - 18), Offset(c.dx, c.dy - 6), ringPaint);
    canvas.drawLine(Offset(c.dx, c.dy + 6), Offset(c.dx, c.dy + 18), ringPaint);

    final centerDot = Paint()
      ..color = GameConfig.accent.withValues(alpha: 1.0)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(c, 3.0, centerDot);
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
