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
    _paintRedwoodHallway(canvas, size);
    _paintFogOverlay(canvas, size); // NEW: soft global fog layer
    _paintEnemies(canvas, size);
    _paintEnemyProjectiles(canvas, size);
    _paintTraces(canvas);
    _paintCrosshair(canvas);
    _paintWeapon(canvas, size);
    _paintBossHealthBar(canvas, size);
  }

  // =========================
  // BACKGROUND + SKY
  // =========================
  void _paintBackground(Canvas canvas, Size size) {
    final sky = Rect.fromLTWH(0, 0, size.width, size.height);

    final skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF243229),
          Color(0xFF4E6A54),
          Color(0xFF9FB59D),
          Color(0xFFBFD3C6), // HACKABLE: lighter horizon fog color
        ],
        stops: const [0.0, 0.4, 0.7, 1.0],
      ).createShader(sky);

    canvas.drawRect(sky, skyPaint);
  }

  // =========================
  // MAIN WORLD
  // =========================
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

    // TRAIL
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

    _paintRedwoodColumns(canvas, size, true, horizonY, corridorBottom, shift);
    _paintRedwoodColumns(canvas, size, false, horizonY, corridorBottom, shift);
  }

  // =========================
  // TREES WITH DEPTH FOG
  // =========================
  void _paintRedwoodColumns(
    Canvas canvas,
    Size size,
    bool left,
    double horizonY,
    double bottomY,
    double shift,
  ) {
    for (int i = 0; i < 7; i++) {
      final t = (i + 1) / 8;

      final y = lerpDoubleValue(horizonY + 10, bottomY + 30, t * t);
      final trunkHeight = lerpDoubleValue(24, 260, t);
      final trunkWidth = lerpDoubleValue(5, 68, t);

      final fogAmount = (1 - t); // HACKABLE: fog strength per depth

      final baseColor = GameConfig.redwoodMid;
      final foggedColor = Color.lerp(
        baseColor,
        const Color(0xFFBFD3C6), // fog color
        fogAmount * 0.7, // HACKABLE: fog intensity
      )!;

      final bark = Paint()
        ..color = foggedColor.withValues(
          alpha: (1 - fogAmount * 0.6), // HACKABLE fade
        );

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
    }
  }

  // =========================
  // GLOBAL FOG OVERLAY
  // =========================
  void _paintFogOverlay(Canvas canvas, Size size) {
    final fogRect = Rect.fromLTWH(0, 0, size.width, size.height);

    final fogPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          const Color(0xFFBFD3C6).withValues(alpha: 0.15),
          const Color(0xFFBFD3C6).withValues(alpha: 0.35),
        ],
        stops: const [0.4, 0.7, 1.0],
      ).createShader(fogRect);

    canvas.drawRect(fogRect, fogPaint);
  }

  // =========================
  // EXISTING SYSTEMS (UNCHANGED)
  // =========================
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

      canvas.drawCircle(Offset(x, y), r, bodyPaint);
    }
  }

  void _paintEnemyProjectiles(Canvas canvas, Size size) {}
  void _paintTraces(Canvas canvas) {}
  void _paintCrosshair(Canvas canvas) {}
  void _paintWeapon(Canvas canvas, Size size) {}
  void _paintBossHealthBar(Canvas canvas, Size size) {}

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
