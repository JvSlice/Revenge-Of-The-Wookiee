import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../config/game_config.dart';
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
  final skyRect = Rect.fromLTWH(0, 0, size.width, size.height);

  final skyPaint = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF101714),
        Color(0xFF23302A),
        Color(0xFF596C62),
        Color(0xFF9D9F8C),
      ],
      stops: [0.0, 0.36, 0.72, 1.0],
    ).createShader(skyRect);

  canvas.drawRect(skyRect, skyPaint);

  final canopyShade = Paint()
    ..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.black.withValues(alpha: 0.42),
        Colors.black.withValues(alpha: 0.20),
        Colors.transparent,
      ],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.34));

  canvas.drawRect(
    Rect.fromLTWH(0, 0, size.width, size.height * 0.34),
    canopyShade,
  );

  final mistRect = Rect.fromLTWH(
    size.width * 0.16,
    size.height * 0.18,
    size.width * 0.68,
    size.height * 0.48,
  );

  final mistPaint = Paint()
    ..shader = RadialGradient(
      center: const Alignment(0, -0.05),
      radius: 0.95,
      colors: [
        const Color(0xFFFFF3CF).withValues(alpha: 0.22),
        const Color(0xFFE9E5C9).withValues(alpha: 0.12),
        Colors.transparent,
      ],
      stops: const [0.0, 0.45, 1.0],
    ).createShader(mistRect);

  canvas.drawRect(mistRect, mistPaint);

  final edgeDarken = Paint()
    ..shader = RadialGradient(
      center: Alignment.center,
      radius: 1.06,
      colors: [
        Colors.transparent,
        Colors.black.withValues(alpha: 0.18),
        Colors.black.withValues(alpha: 0.34),
      ],
      stops: const [0.50, 0.82, 1.0],
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

  _paintSideGroundMass(
    canvas,
    data,
    horizonY,
    bottomY,
    tCenterX,
    bCenterX,
    corridorTopHalf,
    corridorBottomHalf,
  );

  _paintGround(
    canvas,
    data,
    horizonY,
    bottomY,
    tCenterX,
    bCenterX,
    corridorTopHalf,
    corridorBottomHalf,
  );

  _paintFarTreeLine(canvas, data, horizonY, tCenterX, corridorTopHalf);

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

void _paintSideGroundMass(
  Canvas canvas,
  GameRenderData data,
  double horizonY,
  double bottomY,
  double topCenterXValue,
  double bottomCenterXValue,
  double corridorTopHalf,
  double corridorBottomHalf,
) {
  final size = data.size;

  final leftGround = Path()
    ..moveTo(0, bottomY)
    ..lineTo(bottomCenterXValue - corridorBottomHalf, bottomY)
    ..lineTo(topCenterXValue - corridorTopHalf, horizonY)
    ..lineTo(0, horizonY + size.height * 0.02)
    ..close();

  final rightGround = Path()
    ..moveTo(size.width, bottomY)
    ..lineTo(bottomCenterXValue + corridorBottomHalf, bottomY)
    ..lineTo(topCenterXValue + corridorTopHalf, horizonY)
    ..lineTo(size.width, horizonY + size.height * 0.02)
    ..close();

  final sideGroundPaint = Paint()
    ..shader =
        const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1C241E), Color(0xFF121710), Color(0xFF0A0B0A)],
        ).createShader(
          Rect.fromLTWH(0, horizonY, size.width, size.height - horizonY),
        );

  //canvas.drawPath(leftGround, sideGroundPaint);
  //canvas.drawPath(rightGround, sideGroundPaint);

  final sideWallShade = Paint()
    ..shader =
        LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.black.withValues(alpha: 0.24),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.24),
          ],
        ).createShader(
          Rect.fromLTWH(0, horizonY, size.width, size.height - horizonY),
        );

  canvas.drawRect(
    Rect.fromLTWH(0, horizonY, size.width, size.height - horizonY),
    sideWallShade,
  );
}

void _paintGround(
  Canvas canvas,
  GameRenderData data,
  double horizonY,
  double bottomY,
  double topCenterXValue,
  double bottomCenterXValue,
  double corridorTopHalf,
  double corridorBottomHalf,
) {
  final size = data.size;

  final groundPath = Path()
    ..moveTo(bottomCenterXValue - corridorBottomHalf, bottomY)
    ..lineTo(bottomCenterXValue + corridorBottomHalf, bottomY)
    ..lineTo(topCenterXValue + corridorTopHalf, horizonY)
    ..lineTo(topCenterXValue - corridorTopHalf, horizonY)
    ..close();

  final groundPaint = Paint()
    ..shader =
        const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF845432), Color(0xFF5A3923), Color(0xFF2C1B12)],
        ).createShader(
          Rect.fromLTWH(0, horizonY, size.width, size.height - horizonY),
        );

  canvas.drawPath(groundPath, groundPaint);

  final centerGlow = Paint()
    ..shader =
        LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFE6B57D).withValues(alpha: 0.04),
            const Color(0xFFFFD59B).withValues(alpha: 0.09),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromLTWH(0, horizonY, size.width, size.height - horizonY),
        );

  canvas.drawPath(groundPath, centerGlow);

  final seamPaint = Paint()
    ..color = Colors.black.withValues(alpha: 0.22)
    ..strokeWidth = 1.4;

  for (int i = 1; i <= 12; i++) {
    final t = i / 13;
    final y = lerpDoubleValue(horizonY + 4, bottomY, t * t);
    final half = lerpDoubleValue(corridorTopHalf, corridorBottomHalf, t);
    final cx = lerpDoubleValue(topCenterXValue, bottomCenterXValue, t);

    canvas.drawLine(Offset(cx - half, y), Offset(cx + half, y), seamPaint);
  }

  final edgeGlow = Paint()
    ..color = GameConfig.redwoodGlow.withValues(alpha: 0.22)
    ..strokeWidth = 3.0;

  canvas.drawLine(
    Offset(topCenterXValue - corridorTopHalf, horizonY),
    Offset(bottomCenterXValue - corridorBottomHalf, bottomY),
    edgeGlow,
  );
  canvas.drawLine(
    Offset(topCenterXValue + corridorTopHalf, horizonY),
    Offset(bottomCenterXValue + corridorBottomHalf, bottomY),
    edgeGlow,
  );

  final depthLines = Paint()
    ..color = Colors.black.withValues(alpha: 0.12)
    ..strokeWidth = 1.0;

  for (int i = 1; i <= 11; i++) {
    final t = i / 12;
    final y = lerpDoubleValue(horizonY, bottomY, t * t);
    final half = lerpDoubleValue(corridorTopHalf, corridorBottomHalf, t);
    final cx = lerpDoubleValue(topCenterXValue, bottomCenterXValue, t);

    canvas.drawLine(
      Offset(cx - half * 0.98, y),
      Offset(cx + half * 0.98, y),
      depthLines,
    );
  }

  final centerRut = Paint()..color = Colors.black.withValues(alpha: 0.08);

  canvas.drawPath(
    Path()
      ..moveTo(bottomCenterXValue - corridorBottomHalf * 0.10, bottomY)
      ..lineTo(bottomCenterXValue + corridorBottomHalf * 0.10, bottomY)
      ..lineTo(topCenterXValue + corridorTopHalf * 0.06, horizonY)
      ..lineTo(topCenterXValue - corridorTopHalf * 0.06, horizonY)
      ..close(),
    centerRut,
  );

  _paintGroundStreaks(
    canvas,
    data,
    horizonY,
    bottomY,
    topCenterXValue,
    bottomCenterXValue,
    corridorTopHalf,
    corridorBottomHalf,
  );
}

void _paintGroundStreaks(
  Canvas canvas,
  GameRenderData data,
  double horizonY,
  double bottomY,
  double topCenterXValue,
  double bottomCenterXValue,
  double corridorTopHalf,
  double corridorBottomHalf,
) {
  const int streakCount = 20;
  const double loopDepth = 44.0;
  const double spacing = 2.5;

  for (int i = 0; i < streakCount; i++) {
    final z =
        (((i * spacing) - data.worldZ * 10.5) % loopDepth + loopDepth) %
            loopDepth +
        0.9;
    final nearT = 1.0 - (z / loopDepth);
    final p = nearT * nearT;

    final y = lerpDoubleValue(horizonY + 10, bottomY + 8, p);
    final half = lerpDoubleValue(corridorTopHalf, corridorBottomHalf, p);
    final cx = lerpDoubleValue(topCenterXValue, bottomCenterXValue, p);

    final offsetSeed = ((i % 6) - 2.5) / 3.0;
    final x =
        cx +
        offsetSeed * half * 0.75 +
        math.sin(data.worldZ * 1.4 + i) * lerpDoubleValue(0.2, 5.0, p) -
        data.playerX * lerpDoubleValue(1.5, 9.0, p);

    final width = lerpDoubleValue(3.0, 18.0, p);
    final height = lerpDoubleValue(1.0, 6.0, p);
    final alpha = lerpDoubleValue(0.04, 0.16, p);

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

void _paintFarTreeLine(
  Canvas canvas,
  GameRenderData data,
  double horizonY,
  double topCenterXValue,
  double corridorTopHalf,
) {
  final size = data.size;

  final leftLine = Path()
    ..moveTo(0, horizonY + size.height * 0.01)
    ..lineTo(topCenterXValue - corridorTopHalf, horizonY)
    ..lineTo(
      topCenterXValue - corridorTopHalf - size.width * 0.02,
      horizonY - 6,
    )
    ..lineTo(0, horizonY - size.height * 0.02)
    ..close();

  final rightLine = Path()
    ..moveTo(size.width, horizonY + size.height * 0.01)
    ..lineTo(topCenterXValue + corridorTopHalf, horizonY)
    ..lineTo(
      topCenterXValue + corridorTopHalf + size.width * 0.02,
      horizonY - 6,
    )
    ..lineTo(size.width, horizonY - size.height * 0.02)
    ..close();

  final linePaint = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF243229), Color(0xFF121913)],
    ).createShader(Rect.fromLTWH(0, horizonY - 20, size.width, 40));

  canvas.drawPath(leftLine, linePaint);
  canvas.drawPath(rightLine, linePaint);

  final silhouettePaint = Paint()
    ..color = const Color(0xFF0F1712).withValues(alpha: 0.72);

  for (int i = 0; i < 18; i++) {
    final t = i / 17;
    final leftX = lerpDoubleValue(0, topCenterXValue - corridorTopHalf - 10, t);
    final rightX = lerpDoubleValue(
      topCenterXValue + corridorTopHalf + 10,
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
  GameRenderData data, {
  required bool isLeft,
  required double topCenterXValue,
  required double bottomCenterXValue,
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
        (((i * spacing) - data.worldZ * 12.0) % depthLoop + depthLoop) %
            depthLoop +
        1.0;

    final nearT = 1.0 - (z / depthLoop);
    final p = nearT * nearT;

    final y = lerpDoubleValue(horizonY + 6, bottomY + 40, p);
    final trunkHeight = lerpDoubleValue(30, 380, p);
    final trunkWidth = lerpDoubleValue(12, 110, p);

    final corridorEdge = lerpDoubleValue(
      corridorTopHalf,
      corridorBottomHalf,
      p,
    );
    final forestOffset = lerpDoubleValue(34, 240, p);
    final cx = lerpDoubleValue(topCenterXValue, bottomCenterXValue, p);

    final sway =
        math.sin(data.worldZ * 1.75 + i * 0.8 + (isLeft ? 0.0 : 1.5)) *
        lerpDoubleValue(0.6, 8.0, p);

    final parallax = -data.playerX * lerpDoubleValue(8.0, 31.0, p);

    final x = cx + side * (corridorEdge + forestOffset) + sway + parallax;

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
    ..shader =
        LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color(
              0xFF7A4526,
            ).withValues(alpha: lerpDoubleValue(0.22, 1.0, p)),
            const Color(
              0xFF9A5E36,
            ).withValues(alpha: lerpDoubleValue(0.22, 1.0, p)),
            const Color(
              0xFF59311C,
            ).withValues(alpha: lerpDoubleValue(0.22, 1.0, p)),
          ],
        ).createShader(
          Rect.fromLTWH(
            x - trunkWidth / 2,
            y - trunkHeight,
            trunkWidth,
            trunkHeight,
          ),
        );

  final barkDark = Paint()
    ..color = const Color(
      0xFF4B2615,
    ).withValues(alpha: lerpDoubleValue(0.18, 0.92, p));

  final moss = Paint()
    ..color = const Color(
      0xFF36563A,
    ).withValues(alpha: lerpDoubleValue(0.05, 0.28, p));

  final rootShadow = Paint()
    ..color = Colors.black.withValues(alpha: lerpDoubleValue(0.03, 0.18, p));

  final trunkRect = Rect.fromCenter(
    center: Offset(x, y - trunkHeight * 0.45),
    width: trunkWidth,
    height: trunkHeight,
  );

  final hideAmount = lerpDoubleValue(16.0, 0.0, p);
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
      visibleRect.left + trunkWidth * 0.15,
      visibleRect.top,
      trunkWidth * 0.08,
      visibleRect.height,
    ),
    barkDark,
  );
  canvas.drawRect(
    Rect.fromLTWH(
      visibleRect.left + trunkWidth * 0.33,
      visibleRect.top,
      trunkWidth * 0.06,
      visibleRect.height,
    ),
    barkDark,
  );
  canvas.drawRect(
    Rect.fromLTWH(
      visibleRect.left + trunkWidth * 0.58,
      visibleRect.top,
      trunkWidth * 0.08,
      visibleRect.height,
    ),
    barkDark,
  );

  if (i.isEven && visibleRect.height > trunkHeight * 0.2) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x, visibleRect.top + visibleRect.height * 0.22),
        width: trunkWidth * 0.86,
        height: visibleRect.height * 0.12,
      ),
      moss,
    );
  }

  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(x, trunkRect.bottom - trunkWidth * 0.08),
      width: trunkWidth * 1.72,
      height: trunkWidth * 0.42,
    ),
    rootShadow,
  );

  final rootPaint = Paint()
    ..color = const Color(
      0xFF4D2918,
    ).withValues(alpha: lerpDoubleValue(0.16, 0.55, p));

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
      ..color = Colors.black.withValues(alpha: 0.11 * p);
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

void _paintDepthShade(Canvas canvas, GameRenderData data, double horizonY) {
  final size = data.size;

  final depthShade = Paint()
    ..shader =
        LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.00),
            Colors.black.withValues(alpha: 0.05),
            Colors.black.withValues(alpha: 0.12),
          ],
        ).createShader(
          Rect.fromLTWH(0, horizonY - 4, size.width, size.height * 0.32),
        );

  canvas.drawRect(
    Rect.fromLTWH(0, horizonY - 4, size.width, size.height * 0.32),
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
    ..shader =
        LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFF2E8C9).withValues(alpha: 0.18),
            const Color(0xFFD8D3B8).withValues(alpha: 0.10),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromLTWH(0, horizonY - 16, size.width, size.height * 0.22),
        );

  canvas.drawRect(
    Rect.fromLTWH(0, horizonY - 16, size.width, size.height * 0.22),
    fog,
  );
}
