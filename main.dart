import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

void main() {
  runApp(const CanopyDefenseApp());
}

class CanopyDefenseApp extends StatelessWidget {
  const CanopyDefenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Canopy Defense',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const GamePage(),
    );
  }
}

/// ============================================================
/// HACKABLE CONSTANTS
/// Change these first when tuning gameplay.
/// ============================================================
class GameConfig {
  // Core pacing
  static const double targetFps = 60.0;
  static const double spawnIntervalStart = 1.6;
  static const double spawnIntervalMin = 0.45;
  static const double spawnDifficultyRampPerSecond = 0.015;

  // Player
  static const double playerMoveSpeed = 2.8; // world units/sec
  static const double playerAimSpeed = 1.8; // drag sensitivity
  static const double fireCooldown = 0.22;
  static const int maxHealth = 5;

  // Enemies
  static const double enemyStartDistanceMin = 16.0;
  static const double enemyStartDistanceMax = 26.0;
  static const double enemyBaseSpeed = 3.2;
  static const double enemySpeedRampPerSecond = 0.035;
  static const double enemyHitRadius = 0.55;
  static const double enemyLaneSpread = 4.2;

  // Combat
  static const double shotAimToleranceBase = 0.32;
  static const double shotAimToleranceFarBonus = 0.02;
  static const double shotEffectiveDistance = 30.0;

  // Presentation
  static const Color skyTop = Color(0xFF17304D);
  static const Color skyBottom = Color(0xFF274D6E);
  static const Color groundTop = Color(0xFF3C5B2B);
  static const Color groundBottom = Color(0xFF1D2F15);
  static const Color accent = Color(0xFF92FF8F);

  // Win condition
  static const int winScore = 40;
}

/// ============================================================
/// SIMPLE DATA MODELS
/// ============================================================
class Enemy {
  Enemy({
    required this.x,
    required this.distance,
    required this.speed,
    required this.color,
  });

  double x; // horizontal position in world space
  double distance; // distance from player
  double speed;
  Color color;

  bool isAlive = true;
  double hitFlash = 0.0;
}

class ShotTrace {
  ShotTrace({
    required this.start,
    required this.end,
  });

  Offset start;
  Offset end;
  double life = 0.10;
}

enum GameState {
  playing,
  won,
  lost,
}

/// ============================================================
/// GAME PAGE
/// ============================================================
class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  final math.Random _rng = math.Random();

  // Game state
  GameState state = GameState.playing;
  int score = 0;
  int health = GameConfig.maxHealth;
  double survivalTime = 0.0;

  // Player state
  double playerX = 0.0;
  double aimX = 0.0;
  double fireCooldownTimer = 0.0;

  // Touch tracking
  int? leftPointerId;
  int? rightPointerId;
  Offset? leftStart;
  Offset? rightStart;
  Offset? leftCurrent;
  Offset? rightCurrent;

  // Spawn timing
  double spawnTimer = 0.0;
  double currentSpawnInterval = GameConfig.spawnIntervalStart;

  final List<Enemy> enemies = [];
  final List<ShotTrace> traces = [];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _restart() {
    setState(() {
      state = GameState.playing;
      score = 0;
      health = GameConfig.maxHealth;
      survivalTime = 0.0;
      playerX = 0.0;
      aimX = 0.0;
      fireCooldownTimer = 0.0;
      spawnTimer = 0.0;
      currentSpawnInterval = GameConfig.spawnIntervalStart;
      enemies.clear();
      traces.clear();
      leftPointerId = null;
      rightPointerId = null;
      leftStart = null;
      rightStart = null;
      leftCurrent = null;
      rightCurrent = null;
      _lastTick = Duration.zero;
    });
  }

  void _tick(Duration elapsed) {
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }

    final dt = (elapsed - _lastTick).inMicroseconds / 1000000.0;
    _lastTick = elapsed;

    if (!mounted) return;

    if (state == GameState.playing) {
      _updateGame(dt);
    }

    setState(() {});
  }

  void _updateGame(double dt) {
    survivalTime += dt;
    fireCooldownTimer = math.max(0.0, fireCooldownTimer - dt);

    _updateTouchControls(dt);
    _updateSpawning(dt);
    _updateEnemies(dt);
    _updateTraces(dt);

    if (health <= 0) {
      state = GameState.lost;
    } else if (score >= GameConfig.winScore) {
      state = GameState.won;
    }
  }

  void _updateTouchControls(double dt) {
    // Left side drag = strafe
    if (leftStart != null && leftCurrent != null) {
      final dx = (leftCurrent!.dx - leftStart!.dx) / 140.0;
      playerX += dx * GameConfig.playerMoveSpeed * dt * 8.0;
    }

    // Right side drag = aim
    if (rightStart != null && rightCurrent != null) {
      final dx = (rightCurrent!.dx - rightStart!.dx) / 140.0;
      aimX += dx * GameConfig.playerAimSpeed * dt * 8.0;
    }

    // Clamp both
    playerX = playerX.clamp(-4.5, 4.5);
    aimX = aimX.clamp(-5.0, 5.0);
  }

  void _updateSpawning(double dt) {
    currentSpawnInterval =
        math.max(GameConfig.spawnIntervalMin,
            GameConfig.spawnIntervalStart - survivalTime * GameConfig.spawnDifficultyRampPerSecond);

    spawnTimer += dt;
    if (spawnTimer >= currentSpawnInterval) {
      spawnTimer = 0.0;
      _spawnEnemy();
    }
  }

  void _spawnEnemy() {
    final distance = _rng.nextDouble() *
            (GameConfig.enemyStartDistanceMax - GameConfig.enemyStartDistanceMin) +
        GameConfig.enemyStartDistanceMin;

    final speed = GameConfig.enemyBaseSpeed +
        (survivalTime * GameConfig.enemySpeedRampPerSecond) +
        _rng.nextDouble() * 0.7;

    final x = (_rng.nextDouble() * 2 - 1) * GameConfig.enemyLaneSpread;

    final colors = [
      const Color(0xFFD8D8D8),
      const Color(0xFFC6D0DA),
      const Color(0xFFE5C87A),
    ];

    enemies.add(
      Enemy(
        x: x,
        distance: distance,
        speed: speed,
        color: colors[_rng.nextInt(colors.length)],
      ),
    );
  }

  void _updateEnemies(double dt) {
    final toRemove = <Enemy>[];

    for (final enemy in enemies) {
      if (!enemy.isAlive) {
        enemy.hitFlash -= dt * 5.0;
        if (enemy.hitFlash <= 0.0) {
          toRemove.add(enemy);
        }
        continue;
      }

      enemy.distance -= enemy.speed * dt;

      // Small tracking drift toward player
      final driftTarget = playerX * 0.6;
      enemy.x += (driftTarget - enemy.x) * dt * 0.55;

      if (enemy.distance <= 0.6) {
        health -= 1;
        toRemove.add(enemy);
      }
    }

    enemies.removeWhere((e) => toRemove.contains(e));
  }

  void _updateTraces(double dt) {
    for (final trace in traces) {
      trace.life -= dt;
    }
    traces.removeWhere((t) => t.life <= 0);
  }

  void _fire(Size size) {
    if (state != GameState.playing) return;
    if (fireCooldownTimer > 0) return;

    fireCooldownTimer = GameConfig.fireCooldown;

    final start = Offset(size.width / 2, size.height * 0.82);
    final aimScreenX = _worldXToScreen(aimX, GameConfig.shotEffectiveDistance, size);
    final end = Offset(aimScreenX, size.height * 0.42);

    traces.add(ShotTrace(start: start, end: end));

    Enemy? bestHit;
    double bestDistance = double.infinity;

    for (final enemy in enemies) {
      if (!enemy.isAlive) continue;

      final tolerance = GameConfig.shotAimToleranceBase +
          (GameConfig.enemyStartDistanceMax - enemy.distance) * GameConfig.shotAimToleranceFarBonus;

      final aligned = (enemy.x - aimX).abs() <= tolerance;
      if (aligned && enemy.distance < bestDistance) {
        bestDistance = enemy.distance;
        bestHit = enemy;
      }
    }

    if (bestHit != null) {
      bestHit.isAlive = false;
      bestHit.hitFlash = 0.18;
      score += 1;
    }
  }

  double _worldXToScreen(double worldX, double distance, Size size) {
    final perspective = 1 / math.max(distance, 0.8);
    final scale = 520 * perspective;
    return size.width / 2 + worldX * scale;
  }

  double _enemyScreenY(double distance, Size size) {
    final t = (distance / GameConfig.enemyStartDistanceMax).clamp(0.0, 1.0);
    return lerpDouble(size.height * 0.78, size.height * 0.35, t)!;
  }

  double _enemyScreenRadius(double distance, Size size) {
    final perspective = 1 / math.max(distance, 0.8);
    return (220 * perspective).clamp(12.0, 80.0);
  }

  void _handlePointerDown(PointerDownEvent event, Size size) {
    final isLeft = event.localPosition.dx < size.width / 2;

    if (isLeft && leftPointerId == null) {
      leftPointerId = event.pointer;
      leftStart = event.localPosition;
      leftCurrent = event.localPosition;
    } else if (!isLeft && rightPointerId == null) {
      rightPointerId = event.pointer;
      rightStart = event.localPosition;
      rightCurrent = event.localPosition;

      // Tap-to-fire immediately on right side
      _fire(size);
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer == leftPointerId) {
      leftCurrent = event.localPosition;
    } else if (event.pointer == rightPointerId) {
      rightCurrent = event.localPosition;
    }
  }

  void _handlePointerUp(PointerEvent event) {
    if (event.pointer == leftPointerId) {
      leftPointerId = null;
      leftStart = null;
      leftCurrent = null;
    } else if (event.pointer == rightPointerId) {
      rightPointerId = null;
      rightStart = null;
      rightCurrent = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);

          return Listener(
            onPointerDown: (e) => _handlePointerDown(e, size),
            onPointerMove: _handlePointerMove,
            onPointerUp: _handlePointerUp,
            onPointerCancel: _handlePointerUp,
            child: Stack(
              children: [
                CustomPaint(
                  size: size,
                  painter: GamePainter(
                    size: size,
                    score: score,
                    health: health,
                    state: state,
                    enemies: enemies,
                    traces: traces,
                    aimX: aimX,
                    playerX: playerX,
                    survivalTime: survivalTime,
                    worldXToScreen: _worldXToScreen,
                    enemyScreenY: _enemyScreenY,
                    enemyScreenRadius: _enemyScreenRadius,
                  ),
                ),
                _buildHud(size),
                if (state != GameState.playing) _buildEndOverlay(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHud(Size size) {
    return IgnorePointer(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CANOPY DEFENSE',
                style: TextStyle(
                  color: GameConfig.accent,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _pill('Score: $score'),
                  const SizedBox(width: 8),
                  _pill('Health: $health'),
                  const SizedBox(width: 8),
                  _pill('Time: ${survivalTime.toStringAsFixed(1)}'),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: _controlHint('LEFT: STRAFE'),
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: _controlHint('RIGHT: AIM / TAP FIRE'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        border: Border.all(color: GameConfig.accent.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _controlHint(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.30),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withOpacity(0.82),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEndOverlay() {
    final won = state == GameState.won;

    return Container(
      color: Colors.black.withOpacity(0.62),
      child: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF10161C),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: GameConfig.accent.withOpacity(0.5)),
            boxShadow: const [
              BoxShadow(
                blurRadius: 18,
                color: Colors.black54,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                won ? 'VICTORY' : 'DEFEAT',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: won ? GameConfig.accent : Colors.redAccent,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                won
                    ? 'You held the forest line.'
                    : 'The invaders broke through.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              Text(
                'Final Score: $score',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Survival Time: ${survivalTime.toStringAsFixed(1)}s',
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _restart,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('RESTART'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ============================================================
/// PAINTER
/// ============================================================
class GamePainter extends CustomPainter {
  GamePainter({
    required this.size,
    required this.score,
    required this.health,
    required this.state,
    required this.enemies,
    required this.traces,
    required this.aimX,
    required this.playerX,
    required this.survivalTime,
    required this.worldXToScreen,
    required this.enemyScreenY,
    required this.enemyScreenRadius,
  });

  final Size size;
  final int score;
  final int health;
  final GameState state;
  final List<Enemy> enemies;
  final List<ShotTrace> traces;
  final double aimX;
  final double playerX;
  final double survivalTime;

  final double Function(double, double, Size) worldXToScreen;
  final double Function(double, Size) enemyScreenY;
  final double Function(double, Size) enemyScreenRadius;

  @override
  void paint(Canvas canvas, Size size) {
    _paintBackground(canvas, size);
    _paintDepthLines(canvas, size);
    _paintEnemies(canvas, size);
    _paintWeaponOverlay(canvas, size);
    _paintTraces(canvas, size);
    _paintCrosshair(canvas, size);
  }

  void _paintBackground(Canvas canvas, Size size) {
    final skyRect = Rect.fromLTWH(0, 0, size.width, size.height * 0.52);
    final groundRect = Rect.fromLTWH(0, size.height * 0.52, size.width, size.height * 0.48);

    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [GameConfig.skyTop, GameConfig.skyBottom],
      ).createShader(skyRect);

    final groundPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [GameConfig.groundTop, GameConfig.groundBottom],
      ).createShader(groundRect);

    canvas.drawRect(skyRect, skyPaint);
    canvas.drawRect(groundRect, groundPaint);

    final horizonPaint = Paint()
      ..color = GameConfig.accent.withOpacity(0.15)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(0, size.height * 0.52),
      Offset(size.width, size.height * 0.52),
      horizonPaint,
    );

    // Stylized trees
    for (int i = 0; i < 12; i++) {
      final x = i * (size.width / 11);
      final h = 60 + (i % 4) * 20.0;
      final trunkPaint = Paint()..color = const Color(0xFF2B1B11);
      final canopyPaint = Paint()..color = const Color(0xFF173A1B);

      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(x, size.height * 0.49),
          width: 10,
          height: h,
        ),
        trunkPaint,
      );
      canvas.drawCircle(Offset(x, size.height * 0.44 - (i % 3) * 8), 24 + (i % 3) * 6, canopyPaint);
    }
  }

  void _paintDepthLines(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..strokeWidth = 1;

    final centerX = size.width / 2 - playerX * 12;
    final horizonY = size.height * 0.52;

    for (int i = -5; i <= 5; i++) {
      final startX = centerX + i * 42;
      canvas.drawLine(
        Offset(centerX, horizonY),
        Offset(startX * 1.8, size.height),
        paint,
      );
    }
  }

  void _paintEnemies(Canvas canvas, Size size) {
    final sorted = [...enemies]..sort((a, b) => b.distance.compareTo(a.distance));

    for (final enemy in sorted) {
      final x = worldXToScreen(enemy.x - playerX, enemy.distance, size);
      final y = enemyScreenY(enemy.distance, size);
      final r = enemyScreenRadius(enemy.distance, size);

      final bodyPaint = Paint()
        ..color = enemy.isAlive
            ? enemy.color
            : Colors.white.withOpacity(enemy.hitFlash.clamp(0.0, 1.0));

      final eyePaint = Paint()..color = Colors.redAccent;
      final limbPaint = Paint()
        ..color = const Color(0xFF7D868E)
        ..strokeWidth = math.max(2, r * 0.12)
        ..strokeCap = StrokeCap.round;

      // legs
      canvas.drawLine(Offset(x - r * 0.25, y + r * 0.75), Offset(x - r * 0.45, y + r * 1.35), limbPaint);
      canvas.drawLine(Offset(x + r * 0.25, y + r * 0.75), Offset(x + r * 0.45, y + r * 1.35), limbPaint);

      // body
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, y), width: r * 1.1, height: r * 1.5),
          Radius.circular(r * 0.18),
        ),
        bodyPaint,
      );

      // arms
      canvas.drawLine(Offset(x - r * 0.5, y - r * 0.05), Offset(x - r * 1.0, y + r * 0.3), limbPaint);
      canvas.drawLine(Offset(x + r * 0.5, y - r * 0.05), Offset(x + r * 1.0, y + r * 0.3), limbPaint);

      // head
      canvas.drawCircle(Offset(x, y - r * 0.95), r * 0.42, bodyPaint);
      canvas.drawCircle(Offset(x - r * 0.12, y - r * 0.98), r * 0.05, eyePaint);
      canvas.drawCircle(Offset(x + r * 0.12, y - r * 0.98), r * 0.05, eyePaint);
    }
  }

  void _paintWeaponOverlay(Canvas canvas, Size size) {
    final basePaint = Paint()..color = const Color(0xFF4B2F1B);
    final accentPaint = Paint()..color = GameConfig.accent.withOpacity(0.35);

    final center = Offset(size.width / 2, size.height * 0.90);

    final weaponPath = Path()
      ..moveTo(center.dx - 90, center.dy)
      ..quadraticBezierTo(center.dx - 65, center.dy - 20, center.dx - 20, center.dy - 16)
      ..lineTo(center.dx + 20, center.dy - 16)
      ..quadraticBezierTo(center.dx + 65, center.dy - 20, center.dx + 90, center.dy)
      ..lineTo(center.dx + 50, center.dy + 24)
      ..lineTo(center.dx - 50, center.dy + 24)
      ..close();

    canvas.drawPath(weaponPath, basePaint);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(center.dx, center.dy - 18), width: 26, height: 36),
        const Radius.circular(8),
      ),
      accentPaint,
    );
  }

  void _paintTraces(Canvas canvas, Size size) {
    for (final trace in traces) {
      final p = Paint()
        ..color = GameConfig.accent.withOpacity((trace.life / 0.10).clamp(0.0, 1.0))
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(trace.start, trace.end, p);
    }
  }

  void _paintCrosshair(Canvas canvas, Size size) {
    final x = worldXToScreen(aimX - playerX * 0.15, 18, size);
    final y = size.height * 0.56;

    final paint = Paint()
      ..color = GameConfig.accent.withOpacity(0.92)
      ..strokeWidth = 2;

    canvas.drawCircle(Offset(x, y), 16, paint..style = PaintingStyle.stroke);
    paint.style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromCenter(center: Offset(x, y), width: 3, height: 3), paint);

    canvas.drawLine(Offset(x - 24, y), Offset(x - 10, y), paint);
    canvas.drawLine(Offset(x + 10, y), Offset(x + 24, y), paint);
    canvas.drawLine(Offset(x, y - 24), Offset(x, y - 10), paint);
    canvas.drawLine(Offset(x, y + 10), Offset(x, y + 24), paint);
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => true;
}

/// ============================================================
/// SMALL HELPER
/// ============================================================
double? lerpDouble(num? a, num? b, double t) {
  if (a == null && b == null) return null;
  a ??= 0.0;
  b ??= 0.0;
  return a + (b - a) * t;
}
