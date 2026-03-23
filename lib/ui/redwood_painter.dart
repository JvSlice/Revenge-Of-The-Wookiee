import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/game_config.dart';
import '../game/helpers.dart';
import '../models/enemy.dart';
import '../models/game_types.dart';
import '../models/shot_trace.dart';

class RedwoodPainter extends CustomPainter {
  RedwoodPainter({
    required this.size,
    required this.enemies,
    required this.traces,
    required this.playerX,
    required this.bobTime,
    required this.state,
    required this.currentWave,
    required this.firePressed,
    required this.worldXToScreen,
    required this.enemyScreenY,
    required this.enemyRadius,
    required this.crosshairPosition,
  });

  final Size size;
  final List<Enemy> enemies;
  final List<ShotTrace> traces;
  final double playerX;
  final double bobTime;
  final GameState state;
  final int currentWave;
  final bool firePressed;
  final Offset crosshairPosition;

  final double Function(double worldX, double distance, Size size)
      worldXToScreen;
  final double Function(double distance, Size size) enemyScreenY;
  final double Function(double distance) enemyRadius;

  @override
  void paint(Canvas canvas, Size size) {
    _paintBackground(canvas, size);
    _paintRedwoodHallway(canvas, size);
    _paintEnemies(canvas, size);
    _paintTraces(canvas);
    _paintCrosshair(canvas);
    _paintWeapon(canvas, size);
  }

  void _paintBackground(Canvas canvas, Size size) {
    final sky = Rect.fromLTWH(0, 0, size.width, size.height * 0.58);
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF243229),
          Color(0xFF4E6A54),
          Color(0xFF9FB59D),
        ],
      ).createShader(sky);

    canvas.drawRect(sky, skyPaint);

    final mistPaint = Paint()
      ..color = GameConfig.mist.withValues(alpha: 0.13);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.47),
        width: size.width * 0.95,
        height: size.height * 0.25,
      ),
      mistPaint,
    );
  }

  void _paintRedwoodHallway(Canvas canvas, Size size) {
    final horizonY = size.height * 0.40;
    final corridorBottom = size.height;
    final corridorHalfTop = size.width * 0.10;
    final corridorHalfBottom = size.width * 0.43;
    final shift = -playerX * 22;

    final leftForest = Path()
      ..moveTo(0, corridorBottom)
      ..lineTo(size.width / 2 - corridorHalfBottom + shift, corridorBottom)
      ..lineTo(size.width / 2 - corridorHalfTop + shift, horizonY)
      ..lineTo(0, horizonY * 0.88)
      ..close();

    final rightForest = Path()
      ..moveTo(size.width, corridorBottom)
      ..lineTo(size.width / 2 + corridorHalfBottom + shift, corridorBottom)
      ..lineTo(size.width / 2 + corridorHalfTop + shift, horizonY)
      ..lineTo(size.width, horizonY * 0.88)
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
          Color(0xFF6F4B2F),
          Color(0xFF4B2E1D),
          Color(0xFF2F1D13),
        ],
      ).createShader(
        Rect.fromLTWH(0, horizonY, size.width, size.height - horizonY),
      );

    canvas.drawPath(trail, trailPaint);

    final linePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..strokeWidth = 1.4;

    for (int i = 1; i <= 9; i++) {
      final t = i / 10;
      final y = lerpDoubleValue(horizonY, corridorBottom, t * t);
      final halfW = lerpDoubleValue(corridorHalfTop, corridorHalfBottom, t);
      canvas.drawLine(
        Offset(size.width / 2 - halfW + shift, y),
        Offset(size.width / 2 + halfW + shift, y),
        linePaint,
      );
    }

    final edgeGlow = Paint()
      ..color = GameConfig.redwoodGlow.withValues(alpha: 0.20)
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

  void _paintRedwoodColumns(
    Canvas canvas,
    Size size,
    bool left,
    double horizonY,
    double bottomY,
    double shift,
  ) {
    final bark = Paint()..color = GameConfig.redwoodMid;
    final barkDark = Paint()..color = GameConfig.redwoodDark;
    final moss = Paint()
      ..color = const Color(0xFF28452B).withValues(alpha: 0.45);

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

      if (i % 2 == 0) {
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

  @override
  bool shouldRepaint(covariant RedwoodPainter oldDelegate) => true;
}

double _lerp(double a, double b, double t) => a + (b - a) * t;
