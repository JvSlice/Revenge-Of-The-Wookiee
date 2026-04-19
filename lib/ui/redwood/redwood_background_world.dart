import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../game/game_render_data.dart';

double lerpDoubleValue(double a, double b, double t) {
  return a + (b - a) * t;
}

double topCenterX(GameRenderData data) {
  return data.size.width / 2 + data.travelTurn * data.size.width * 0.08;
}

double bottomCenterX(GameRenderData data) {
  return data.size.width / 2 + data.travelTurn * data.size.width * 0.18;
}

void paintBackground(Canvas canvas, GameRenderData data) {
  final size = data.size;

  // HACKABLE: dark canopy framing.
  final canopyShade = Paint()
    ..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.black.withValues(alpha: 0.34),
        Colors.black.withValues(alpha: 0.14),
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

  final horizonY = size.height * 0.39;
  final driftX = math.sin(data.worldZ * 0.012) * size.width * 0.012;
  final centerX = size.width * 0.5 + driftX + data.travelTurn * size.width * 0.03;

  // HACKABLE: vanishing-point glow.
  final vanishingGlow = Paint()
    ..shader = RadialGradient(
      colors: [
        const Color(0xFFFFF0BE).withValues(alpha: 0.22),
        const Color(0xFFFFF0BE).withValues(alpha: 0.08),
        Colors.transparent,
      ],
      stops: const [0.0, 0.28, 1.0],
    ).createShader(
      Rect.fromCenter(
        center: Offset(centerX, size.height * 0.47),
        width: size.width * 0.70,
        height: size.height * 0.32,
      ),
    );

  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(centerX, size.height * 0.47),
      width: size.width * 0.70,
      height: size.height * 0.32,
    ),
    vanishingGlow,
  );

  // HACKABLE: light shafts.
  final shaftPaintA = Paint()
    ..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFFFFF4D2).withValues(alpha: 0.10),
        const Color(0xFFFFF4D2).withValues(alpha: 0.04),
        Colors.transparent,
      ],
      stops: const [0.0, 0.40, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

  final shaftPaintB = Paint()
    ..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFFFFF8E1).withValues(alpha: 0.07),
        const Color(0xFFFFF8E1).withValues(alpha: 0.03),
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

  final edgeDarken = Paint()
    ..shader = RadialGradient(
      center: Alignment.center,
      radius: 1.06,
      colors: [
        Colors.transparent,
        Colors.black.withValues(alpha: 0.16),
        Colors.black.withValues(alpha: 0.30),
      ],
      stops: const [0.52, 0.82, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

  canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), edgeDarken);
}

void paintForestWorld(Canvas canvas, GameRenderData data) {
  final size = data.size;
  final horizonY = size.height * 0.39;
  final bottomY = size.height;

  final tCenterX = topCenterX(data);
  final bCenterX = bottomCenterX(data);

  final corridorTopHalf = size.width * 0.070;
  final corridorBottomHalf = size.width * 0.23;

  // Intentionally no procedural green side ground and no procedural boardwalk.
  // The image is now the environment. We only add moving foreground props + atmosphere.

  _paintForegroundPosts(
    canvas,
    data,
    horizonY,
    bottomY,
    tCenterX,
    bCenterX,
    corridorTopHalf,
    corridorBottomHalf,
  );

  _paintFloatingParticles(canvas, data, horizonY);
  _paintDepthShade(canvas, data, horizonY);
  _paintFogOverDistance(canvas, data, horizonY);
}

void _paintForegroundPosts(
  Canvas canvas,
  GameRenderData data,
  double horizonY,
  double bottomY,
  double topCenterXValue,
  double bottomCenterXValue,
  double corridorTopHalf,
  double corridorBottomHalf,
) {
  const depthStops = [0.66, 0.82, 0.94];

  for (int i = 0; i < depthStops.length; i++) {
    final t = depthStops[i];
    final y = lerpDoubleValue(horizonY + 10, bottomY + 28, t * t);

    final trunkHeight = lerpDoubleValue(120, 340, t);
    final trunkWidth = lerpDoubleValue(26, 88, t);

    final cx = lerpDoubleValue(topCenterXValue, bottomCenterXValue, t);
    final corridorHalf = lerpDoubleValue(corridorTopHalf, corridorBottomHalf, t);

    final leftX =
        cx - corridorHalf - lerpDoubleValue(40, 82, t) - data.playerX * 20.0;
    final rightX =
        cx + corridorHalf + lerpDoubleValue(40, 82, t) - data.playerX * 20.0;

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

void _paintFloatingParticles(
  Canvas canvas,
  GameRenderData data,
  double horizonY,
) {
  final size = data.size;
  final lightCenter = Offset(
    size.width * 0.5 + math.sin(data.worldZ * 0.01) * size.width * 0.01,
    size.height * 0.46,
  );

  for (int i = 0; i < 40; i++) {
    final seed = i.toDouble();
    final layer = (i % 3) / 2.0;

    final xBase = ((math.sin(seed * 12.9898) * 43758.5453).abs() % 1.0);
    final yBase = ((math.cos(seed * 78.233) * 24634.6345).abs() % 1.0);

    final x =
        xBase * size.width +
        math.sin(data.worldZ * (0.40 + layer * 0.22) + seed) * (6 + layer * 8) -
        data.playerX * (1.0 + layer * 2.5);

    final y =
        lerpDoubleValue(horizonY - 20, size.height * 0.90, yBase) -
        ((data.worldZ * (8 + layer * 10) + seed * 17) % (size.height * 0.80));

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
        math.sin(data.worldZ * 0.8 + seed) * 12 -
        data.playerX * lerpDoubleValue(1.0, 3.0, p);

    final y =
        lerpDoubleValue(size.height * 0.50, size.height * 0.92, p) +
        math.cos(data.worldZ * 0.9 + seed * 1.3) * 5;

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

void _paintDepthShade(Canvas canvas, GameRenderData data, double horizonY) {
  final size = data.size;

  final depthShade = Paint()
    ..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.transparent,
        Colors.black.withValues(alpha: 0.05),
        Colors.black.withValues(alpha: 0.14),
      ],
    ).createShader(
      Rect.fromLTWH(0, horizonY, size.width, size.height - horizonY),
    );

  canvas.drawRect(
    Rect.fromLTWH(0, horizonY, size.width, size.height - horizonY),
    depthShade,
  );
}

void _paintFogOverDistance(
  Canvas canvas,
  GameRenderData data,
  double horizonY,
) {
  final size = data.size;

  final fog = Paint()
    ..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFFF2E8C9).withValues(alpha: 0.16),
        const Color(0xFFD8D3B8).withValues(alpha: 0.08),
        Colors.transparent,
      ],
    ).createShader(
      Rect.fromLTWH(0, horizonY - 20, size.width, size.height * 0.22),
    );

  canvas.drawRect(
    Rect.fromLTWH(0, horizonY - 20, size.width, size.height * 0.22),
    fog,
  );
}
