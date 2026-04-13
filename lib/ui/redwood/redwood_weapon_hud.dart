import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../config/game_config.dart';
import '../../game/game_render_data.dart';

double travelWeaponOffsetX(GameRenderData data) {
  return data.isTraveling ? data.travelTurn * 22.0 : 0.0;
}

double travelWeaponOffsetY(GameRenderData data) {
  return data.isTraveling
      ? math.sin(data.travelProgress * math.pi) * 4.0
      : 0.0;
}

void paintWeapon(Canvas canvas, GameRenderData data) {
  final size = data.size;

  final bobX = math.sin(data.bobTime * 3.2) * 4;
  final bobY = math.sin(data.bobTime * 6.4) * 3;
  final centerX = size.width / 2 + bobX + travelWeaponOffsetX(data);
  final baseY = size.height * 0.885 +
      bobY +
      (data.firePressed ? 4 : 0) +
      travelWeaponOffsetY(data);

  final wood = Paint()..color = const Color(0xFF5A3A24);
  final darkWood = Paint()..color = const Color(0xFF3A2417);
  final metal = Paint()..color = const Color(0xFFB8C2C9);
  final darkMetal = Paint()..color = const Color(0xFF7E8A92);
  final stringPaint = Paint()
    ..color = const Color(0xFFE7DEC8)
    ..strokeWidth = 2.4;
  final energyGlow = Paint()
    ..color = GameConfig.accent.withValues(
      alpha: data.firePressed ? 0.55 : 0.22,
    );
  final nodePaint = Paint()..color = const Color(0xFFC9D3DA);
  final nodeGlow = Paint()
    ..color = GameConfig.accent.withValues(
      alpha: data.firePressed ? 0.45 : 0.18,
    );

  canvas.drawShadow(
    Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(centerX, baseY + 8),
            width: 78,
            height: 144,
          ),
          const Radius.circular(12),
        ),
      ),
    Colors.black.withValues(alpha: 0.35),
    10,
    true,
  );

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

void paintBossHealthBar(Canvas canvas, GameRenderData data) {
  if (data.bossMaxHealth <= 0 || data.bossHealth <= 0) return;

  final size = data.size;

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

  final fillWidth = rect.width * (data.bossHealth / data.bossMaxHealth);
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
