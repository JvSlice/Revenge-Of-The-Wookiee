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

  // DARK EDGE VIGNETTE (keeps focus forward)
  final edgeDarken = Paint()
    ..shader = RadialGradient(
      center: Alignment.center,
      radius: 1.1,
      colors: [
        Colors.transparent,
        Colors.black.withValues(alpha: 0.15),
        Colors.black.withValues(alpha: 0.35),
      ],
      stops: const [0.5, 0.8, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

  canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), edgeDarken);
}

void paintForestWorld(Canvas canvas, GameRenderData data) {
  final size = data.size;
  final horizonY = size.height * 0.355;
  final bottomY = size.height;

  final tCenterX = topCenterX(data);
  final bCenterX = bottomCenterX(data);

  final corridorTopHalf = size.width * 0.072;
  final corridorBottomHalf = size.width * 0.23;

  // ❌ REMOVED:
  // _paintSideGroundMass
  // _paintGround
  // _paintFarTreeLine

  // ✅ KEEP TREES ONLY (adds motion + parallax)
  _paintForestSide(
    canvas,
    data,
    isLeft: true,
    topCenterXValue: tCenterX,
    bottomCenterXValue: bCenterX,
    horizonY: horizonY,
    bottomY: bottomY,
    corridorTopHalf: corridorTopHalf,
    corridorBottomHalf: corridorBottomHalf,
  );

  _paintForestSide(
    canvas,
    data,
    isLeft: false,
    topCenterXValue: tCenterX,
    bottomCenterXValue: bCenterX,
    horizonY: horizonY,
    bottomY: bottomY,
    corridorTopHalf: corridorTopHalf,
    corridorBottomHalf: corridorBottomHalf,
  );

  _paintDepthShade(canvas, data, horizonY);
  _paintFogOverDistance(canvas, data, horizonY);
}

void _paintForestSide(
  Canvas canvas,
  GameRenderData data, {
  required bool isLeft,
  required double topCenterXValue,
  required double bottomCenterXValue,
  required double horizonY,
  required double bottomY,
  required double corridorTopHalf,
  required double corridorBottomHalf,
}) {
  const int treeCount = 14;
  const double depthLoop = 100.0;
  const double spacing = 6.5;

  final side = isLeft ? -1.0 : 1.0;

  for (int i = 0; i < treeCount; i++) {
    final z =
        (((i * spacing) - data.worldZ * 12.0) % depthLoop + depthLoop) %
            depthLoop +
        1.0;

    final nearT = 1.0 - (z / depthLoop);
    final p = nearT * nearT;

    final y = lerpDoubleValue(horizonY + 6, bottomY + 40, p);
    final trunkHeight = lerpDoubleValue(40, 420, p);
    final trunkWidth = lerpDoubleValue(16, 120, p);

    final corridorEdge = lerpDoubleValue(
      corridorTopHalf,
      corridorBottomHalf,
      p,
    );

    final forestOffset = lerpDoubleValue(40, 260, p);

    final cx = lerpDoubleValue(topCenterXValue, bottomCenterXValue, p);

    final sway =
        math.sin(data.worldZ * 1.8 + i * 0.9) *
        lerpDoubleValue(0.5, 10.0, p);

    final parallax = -data.playerX * lerpDoubleValue(8.0, 32.0, p);

    final x = cx + side * (corridorEdge + forestOffset) + sway + parallax;

    _paintTree(canvas, x, y, trunkWidth, trunkHeight, p, bottomY);
  }
}

void _paintTree(
  Canvas canvas,
  double x,
  double y,
  double width,
  double height,
  double p,
  double bottomY,
) {
  final trunk = Paint()
    ..color = Color.lerp(
      const Color(0xFF7A4526),
      const Color(0xFF3E2315),
      1 - p,
    )!
        .withValues(alpha: lerpDoubleValue(0.3, 1.0, p));

  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(x, y - height * 0.5),
        width: width,
        height: height,
      ),
      Radius.circular(width * 0.2),
    ),
    trunk,
  );

  final shadow = Paint()
    ..color = Colors.black.withValues(alpha: 0.2 * p);

  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(x, bottomY - 2),
      width: width * 1.4,
      height: width * 0.3,
    ),
    shadow,
  );
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
        Colors.black.withValues(alpha: 0.18),
      ],
    ).createShader(
      Rect.fromLTWH(0, horizonY, size.width, size.height - horizonY),
    );

  canvas.drawRect(
    Rect.fromLTWH(0, horizonY, size.width, size.height - horizonY),
    depthShade,
  );
}

void _paintFogOverDistance(Canvas canvas, GameRenderData data, double horizonY) {
  final size = data.size;

  final fog = Paint()
    ..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white.withValues(alpha: 0.15),
        Colors.white.withValues(alpha: 0.08),
        Colors.transparent,
      ],
    ).createShader(
      Rect.fromLTWH(0, horizonY - 20, size.width, size.height * 0.25),
    );

  canvas.drawRect(
    Rect.fromLTWH(0, horizonY - 20, size.width, size.height * 0.25),
    fog,
  );
}
