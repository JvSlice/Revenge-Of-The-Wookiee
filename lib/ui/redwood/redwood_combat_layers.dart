import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../config/game_config.dart';
import '../../game/game_render_data.dart';
import '../../models/enemy.dart';

double travelAimOffsetX(GameRenderData data) {
  return data.isTraveling ? data.travelTurn * 16.0 : 0.0;
}

void paintEnemies(Canvas canvas, GameRenderData data) {
  final sorted = [...data.enemies]
    ..sort((a, b) => b.distance.compareTo(a.distance));

  for (final enemy in sorted) {
    final emergence =
        ((GameConfig.enemyStartDistanceMax - enemy.distance) / 7.0).clamp(
          0.0,
          1.0,
        );
    if (emergence <= 0.02) continue;

    final x = data.worldXToScreen(enemy.x - data.playerX, enemy.distance, data.size);
    final y = data.enemyScreenY(enemy.distance, data.size);
    final r = data.enemyRadius(enemy.distance) * enemy.radiusScale;

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

void _paintEnemyShadow(Canvas canvas, double x, double y, double r, double vis) {
  final shadowPaint = Paint()
    ..color = Colors.black.withValues(alpha: 0.16 * vis);

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

void paintEnemyProjectiles(Canvas canvas, GameRenderData data) {
  for (final projectile in data.enemyProjectiles) {
    final screenX = data.worldXToScreen(
      projectile.position.dx - data.playerX,
      projectile.position.dy,
      data.size,
    );
    final screenY = data.enemyScreenY(projectile.position.dy, data.size);

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

void paintTraces(Canvas canvas, GameRenderData data) {
  for (final trace in data.traces) {
    final p = Paint()
      ..color = GameConfig.accent.withValues(
        alpha: (trace.life / 0.08).clamp(0.0, 1.0),
      )
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(trace.start, trace.end, p);
  }
}

void paintCrosshair(Canvas canvas, GameRenderData data) {
  if (data.state == GameState.menu) return;

  final c = Offset(
    data.crosshairPosition.dx + travelAimOffsetX(data),
    data.crosshairPosition.dy,
  );

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
