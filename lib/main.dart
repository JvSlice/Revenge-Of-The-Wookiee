import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

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
/// Tweak game feel here first.
/// ============================================================
class GameConfig {
  // Rules
  static const int maxHealth = 5;
  static const int winScore = 35;

  // Movement
  static const double moveSpeed = 4.2;
  static const double playerClamp = 4.4;

  // Combat
  static const double fireCooldown = 0.24;

  // Fixed crosshair position
  // Increased from 0.58 so the aim point sits lower on screen.
  static const double crosshairY = 0.66;

  // Auto-hit tuning
  static const double hitPadding = 14.0;
  static const double centerBias = 0.70;
  static const double closeRangeBonus = 0.85;

  // Very close enemies get generous hit rules
  static const double emergencyHitDistance = 2.6;
  static const double emergencyHitPadding = 42.0;

  // Spawning / enemies
  static const double spawnStart = 1.55;
  static const double spawnMin = 0.42;
  static const double spawnRampPerSecond = 0.014;

  static const double enemyStartDistanceMin = 14.0;
  static const double enemyStartDistanceMax = 26.0;
  static const double enemyBaseSpeed = 2.7;
  static const double enemySpeedRamp = 0.04;
  static const double enemyLaneSpread = 3.8;

  // Colors
  static const Color accent = Color(0xFF92FF8F);
  static const Color redwoodDark = Color(0xFF3F1F14);
  static const Color redwoodMid = Color(0xFF6E3922);
  static const Color redwoodGlow = Color(0xFFA55B37);
  static const Color forestDark = Color(0xFF102315);
  static const Color forestMid = Color(0xFF1F3B25);
  static const Color mist = Color(0xFFBFD8C6);
}

enum GameState {
  menu,
  playing,
  paused,
  won,
  lost,
}

class Enemy {
  Enemy({
    required this.x,
    required this.distance,
    required this.speed,
    required this.tint,
  });

  double x;
  double distance;
  double speed;
  Color tint;

  bool alive = true;
  double flash = 0.0;
}

class ShotTrace {
  ShotTrace({
    required this.start,
    required this.end,
  });

  Offset start;
  Offset end;
  double life = 0.08;
}

/// ============================================================
/// SIMPLE MOVE STICK
/// ============================================================
class StickState {
  int? pointerId;
  Offset center = Offset.zero;
  Offset current = Offset.zero;
  bool active = false;

  void start(int id, Offset position) {
    pointerId = id;
    center = position;
    current = position;
    active = true;
  }

  void update(Offset position) {
    current = position;
  }

  void stop() {
    pointerId = null;
    center = Offset.zero;
    current = Offset.zero;
    active = false;
  }

  Offset get delta => active ? current - center : Offset.zero;
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  final math.Random _rng = math.Random();

  GameState state = GameState.menu;

  int score = 0;
  int health = GameConfig.maxHealth;
  double survivalTime = 0.0;
  double spawnTimer = 0.0;
  double spawnInterval = GameConfig.spawnStart;
  double fireCooldownTimer = 0.0;

  // World state
  double playerX = 0.0;
  double bobTime = 0.0;

  final List<Enemy> enemies = [];
  final List<ShotTrace> traces = [];

  final StickState moveStick = StickState();

  bool firePressed = false;
  Rect fireButtonRect = Rect.zero;
  Rect pauseButtonRect = Rect.zero;

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

  void _tick(Duration elapsed) {
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }

    final dt = (elapsed - _lastTick).inMicroseconds / 1000000.0;
    _lastTick = elapsed;

    if (state == GameState.playing) {
      _updateGame(dt);
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _startGame() {
    setState(() {
      state = GameState.playing;
      score = 0;
      health = GameConfig.maxHealth;
      survivalTime = 0.0;
      spawnTimer = 0.0;
      spawnInterval = GameConfig.spawnStart;
      fireCooldownTimer = 0.0;
      playerX = 0.0;
      bobTime = 0.0;
      enemies.clear();
      traces.clear();
      moveStick.stop();
      firePressed = false;
      _lastTick = Duration.zero;
    });
  }

  void _togglePause() {
    setState(() {
      if (state == GameState.playing) {
        state = GameState.paused;
        moveStick.stop();
        firePressed = false;
      } else if (state == GameState.paused) {
        state = GameState.playing;
        _lastTick = Duration.zero;
      }
    });
  }

  void _quitToMenu() {
    setState(() {
      state = GameState.menu;
      moveStick.stop();
      firePressed = false;
      _lastTick = Duration.zero;
    });
  }

  void _updateGame(double dt) {
    survivalTime += dt;
    fireCooldownTimer = math.max(0.0, fireCooldownTimer - dt);

    _updateControls(dt);
    _updateSpawning(dt);
    _updateEnemies(dt);
    _updateTraces(dt);

    if (health <= 0) {
      state = GameState.lost;
    } else if (score >= GameConfig.winScore) {
      state = GameState.won;
    }
  }

  void _updateControls(double dt) {
    double moveInput = 0.0;

    if (moveStick.active) {
      moveInput = (moveStick.delta.dx / 55.0).clamp(-1.0, 1.0);
    }

    playerX += moveInput * GameConfig.moveSpeed * dt;
    playerX = playerX.clamp(-GameConfig.playerClamp, GameConfig.playerClamp);

    bobTime += dt * (1.0 + moveInput.abs() * 2.0);
  }

  void _updateSpawning(double dt) {
    spawnInterval = math.max(
      GameConfig.spawnMin,
      GameConfig.spawnStart - survivalTime * GameConfig.spawnRampPerSecond,
    );

    spawnTimer += dt;
    if (spawnTimer >= spawnInterval) {
      spawnTimer = 0.0;
      _spawnEnemy();
    }
  }

  void _spawnEnemy() {
    final distance = _rng.nextDouble() *
            (GameConfig.enemyStartDistanceMax -
                GameConfig.enemyStartDistanceMin) +
        GameConfig.enemyStartDistanceMin;

    final speed = GameConfig.enemyBaseSpeed +
        (survivalTime * GameConfig.enemySpeedRamp) +
        _rng.nextDouble() * 0.7;

    final x = (_rng.nextDouble() * 2 - 1) * GameConfig.enemyLaneSpread;

    final tints = [
      const Color(0xFFC9D0D6),
      const Color(0xFFB5BEC7),
      const Color(0xFFE4D18B),
    ];

    enemies.add(
      Enemy(
        x: x,
        distance: distance,
        speed: speed,
        tint: tints[_rng.nextInt(tints.length)],
      ),
    );
  }

  void _updateEnemies(double dt) {
    final dead = <Enemy>[];

    for (final enemy in enemies) {
      if (!enemy.alive) {
        enemy.flash -= dt * 5.0;
        if (enemy.flash <= 0.0) {
          dead.add(enemy);
        }
        continue;
      }

      enemy.distance -= enemy.speed * dt;

      final driftTarget = playerX * 0.65;
      enemy.x += (driftTarget - enemy.x) * dt * 0.65;

      if (enemy.distance <= 0.8) {
        health -= 1;
        dead.add(enemy);
      }
    }

    enemies.removeWhere(dead.contains);
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

    final crosshair = _crosshairScreenPosition(size);

    traces.add(
      ShotTrace(
        start: Offset(size.width / 2, size.height * 0.86),
        end: crosshair,
      ),
    );

    Enemy? bestTarget;
    double bestScore = double.infinity;

    for (final enemy in enemies) {
      if (!enemy.alive) continue;

      final enemyScreen = _enemyScreenPosition(enemy, size);
      final radius = _enemyRadius(enemy.distance);

      final dx = (enemyScreen.dx - crosshair.dx).abs();
      final dy = (enemyScreen.dy - crosshair.dy).abs();

      final bool directlyHit =
          dx <= (radius + GameConfig.hitPadding) &&
          dy <= (radius + GameConfig.hitPadding);

      final bool emergencyCloseHit =
          enemy.distance <= GameConfig.emergencyHitDistance &&
          dx <= (radius + GameConfig.emergencyHitPadding);

      if (!directlyHit && !emergencyCloseHit) {
        continue;
      }

      final double centerDistance =
          (enemyScreen - crosshair).distance / math.max(radius, 1.0);

      final double closenessBonus =
          (1.0 / math.max(enemy.distance, 1.0)) * GameConfig.closeRangeBonus;

      final double emergencyBonus =
          enemy.distance <= GameConfig.emergencyHitDistance ? 0.75 : 0.0;

      final double scoreValue =
          centerDistance * GameConfig.centerBias -
          closenessBonus -
          emergencyBonus;

      if (scoreValue < bestScore) {
        bestScore = scoreValue;
        bestTarget = enemy;
      }
    }

    if (bestTarget != null) {
      bestTarget.alive = false;
      bestTarget.flash = 0.18;
      score += 1;
    }
  }

  void _handlePointerDown(PointerDownEvent event, Size size) {
    final p = event.localPosition;

    if (state == GameState.playing && pauseButtonRect.contains(p)) {
      _togglePause();
      return;
    }

    if (state == GameState.paused) return;
    if (state != GameState.playing) return;

    if (fireButtonRect.contains(p)) {
      firePressed = true;
      _fire(size);
      return;
    }

    if (!moveStick.active) {
      moveStick.start(event.pointer, p);
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (state != GameState.playing) return;

    if (event.pointer == moveStick.pointerId) {
      moveStick.update(event.localPosition);
    }
  }

  void _handlePointerUp(PointerEvent event) {
    if (event.pointer == moveStick.pointerId) {
      moveStick.stop();
    }
    firePressed = false;
  }

  double _worldXToScreen(double worldX, double distance, Size size) {
    final perspective = 1.0 / math.max(distance, 0.8);
    final scale = 530 * perspective;
    return size.width / 2 + worldX * scale;
  }

  double _enemyScreenY(double distance, Size size) {
    final t = (distance / GameConfig.enemyStartDistanceMax).clamp(0.0, 1.0);
    return _lerp(size.height * 0.84, size.height * 0.40, t);
  }

  double _enemyRadius(double distance) {
    final perspective = 1.0 / math.max(distance, 0.8);
    return (235 * perspective).clamp(12.0, 85.0);
  }

  Offset _enemyScreenPosition(Enemy enemy, Size size) {
    return Offset(
      _worldXToScreen(enemy.x - playerX, enemy.distance, size),
      _enemyScreenY(enemy.distance, size),
    );
  }

  Offset _crosshairScreenPosition(Size size) {
    return Offset(
      size.width / 2,
      size.height * GameConfig.crosshairY,
    );
  }

  Rect _calcFireButtonRect(Size size) {
    final double buttonSize = math.min(size.width * 0.16, 92);
    return Rect.fromLTWH(
      size.width - buttonSize - 18,
      size.height - buttonSize - 90,
      buttonSize,
      buttonSize,
    );
  }

  Rect _calcPauseButtonRect(Size size) {
    return Rect.fromLTWH(size.width - 66, 18, 48, 48);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          fireButtonRect = _calcFireButtonRect(size);
          pauseButtonRect = _calcPauseButtonRect(size);

          return Listener(
            onPointerDown: (e) => _handlePointerDown(e, size),
            onPointerMove: _handlePointerMove,
            onPointerUp: _handlePointerUp,
            onPointerCancel: _handlePointerUp,
            child: Stack(
              children: [
                CustomPaint(
                  size: size,
                  painter: RedwoodPainter(
                    size: size,
                    enemies: enemies,
                    traces: traces,
                    playerX: playerX,
                    bobTime: bobTime,
                    state: state,
                    firePressed: firePressed,
                    worldXToScreen: _worldXToScreen,
                    enemyScreenY: _enemyScreenY,
                    enemyRadius: _enemyRadius,
                    crosshairPosition: _crosshairScreenPosition(size),
                  ),
                ),
                if (state == GameState.playing || state == GameState.paused)
                  _buildHud(size),
                if (state == GameState.menu) _buildMenuOverlay(),
                if (state == GameState.paused) _buildPauseOverlay(),
                if (state == GameState.won || state == GameState.lost)
                  _buildEndOverlay(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHud(Size size) {
    final leftCenter = Offset(85, size.height - 95);

    return SafeArea(
      child: Stack(
        children: [
          Positioned(
            left: 14,
            top: 12,
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
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _pill('Score: $score'),
                    _pill('Health: $health'),
                    _pill('Time: ${survivalTime.toStringAsFixed(1)}'),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            right: 18,
            top: 18,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.30),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: GameConfig.accent.withValues(alpha: 0.55),
                ),
              ),
              child: Icon(
                Icons.pause,
                color: GameConfig.accent,
              ),
            ),
          ),
          _buildStickVisual(
            center: moveStick.active ? moveStick.center : leftCenter,
            knob: moveStick.active ? moveStick.current : leftCenter,
            label: 'MOVE',
            active: moveStick.active,
          ),
          Positioned(
            right: 18,
            bottom: 90,
            child: Container(
              width: fireButtonRect.width,
              height: fireButtonRect.height,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: firePressed
                    ? Colors.redAccent.withValues(alpha: 0.45)
                    : Colors.redAccent.withValues(alpha: 0.20),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.95),
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 18,
                    color: Colors.redAccent.withValues(alpha: 0.24),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'FIRE',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickVisual({
    required Offset center,
    required Offset knob,
    required String label,
    required bool active,
  }) {
    final Offset clamped = _clampKnob(center, knob, 34);

    return Positioned(
      left: center.dx - 45,
      top: center.dy - 45,
      child: IgnorePointer(
        child: SizedBox(
          width: 90,
          height: 90,
          child: Stack(
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.18),
                  border: Border.all(
                    color: GameConfig.accent.withValues(
                      alpha: active ? 0.9 : 0.35,
                    ),
                    width: 2,
                  ),
                ),
              ),
              Positioned(
                left: clamped.dx - center.dx + 27,
                top: clamped.dy - center.dy + 27,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: GameConfig.accent.withValues(
                      alpha: active ? 0.55 : 0.22,
                    ),
                    border: Border.all(
                      color: GameConfig.accent.withValues(alpha: 0.95),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Center(
                  child: Transform.translate(
                    offset: const Offset(0, 58),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.82),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
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
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: GameConfig.accent.withValues(alpha: 0.40),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildMenuOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF11161B),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: GameConfig.accent.withValues(alpha: 0.48),
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 18,
                color: Colors.black.withValues(alpha: 0.45),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'CANOPY DEFENSE',
                style: TextStyle(
                  color: GameConfig.accent,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'A retro forest corridor shooter.\nDefend the redwood passage from invading machines.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              const Text(
                'Move stick: dodge left and right\nCrosshair is fixed lower center\nFire button: shoot\nPause button: top right',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _startGame,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('START GAME'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPauseOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.62),
      child: Center(
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF10161C),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: GameConfig.accent.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'PAUSED',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: GameConfig.accent,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _togglePause,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('RESUME'),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _quitToMenu,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('QUIT TO MENU'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEndOverlay() {
    final bool won = state == GameState.won;

    return Container(
      color: Colors.black.withValues(alpha: 0.68),
      child: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF10161C),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: GameConfig.accent.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                won ? 'PASSAGE SECURED' : 'FOREST BREACHED',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: won ? GameConfig.accent : Colors.redAccent,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                won
                    ? 'You held the redwood corridor.'
                    : 'Too many invaders broke through.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Final Score: $score',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text('Survival Time: ${survivalTime.toStringAsFixed(1)}s'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _startGame,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('PLAY AGAIN'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Offset _clampKnob(Offset center, Offset current, double maxRadius) {
    final delta = current - center;
    final distance = delta.distance;
    if (distance <= maxRadius || distance == 0) return current;
    return center + (delta / distance) * maxRadius;
  }
}

class RedwoodPainter extends CustomPainter {
  RedwoodPainter({
    required this.size,
    required this.enemies,
    required this.traces,
    required this.playerX,
    required this.bobTime,
    required this.state,
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
    final Rect sky = Rect.fromLTWH(0, 0, size.width, size.height * 0.58);
    final Paint skyPaint = Paint()
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

    final Paint mistPaint = Paint()
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
    final double horizonY = size.height * 0.40;
    final double corridorBottom = size.height;
    final double corridorHalfTop = size.width * 0.10;
    final double corridorHalfBottom = size.width * 0.43;
    final double shift = -playerX * 22;

    final Path leftForest = Path()
      ..moveTo(0, corridorBottom)
      ..lineTo(size.width / 2 - corridorHalfBottom + shift, corridorBottom)
      ..lineTo(size.width / 2 - corridorHalfTop + shift, horizonY)
      ..lineTo(0, horizonY * 0.88)
      ..close();

    final Path rightForest = Path()
      ..moveTo(size.width, corridorBottom)
      ..lineTo(size.width / 2 + corridorHalfBottom + shift, corridorBottom)
      ..lineTo(size.width / 2 + corridorHalfTop + shift, horizonY)
      ..lineTo(size.width, horizonY * 0.88)
      ..close();

    final Paint forestPaint = Paint()
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

    final Path trail = Path()
      ..moveTo(size.width / 2 - corridorHalfBottom + shift, corridorBottom)
      ..lineTo(size.width / 2 + corridorHalfBottom + shift, corridorBottom)
      ..lineTo(size.width / 2 + corridorHalfTop + shift, horizonY)
      ..lineTo(size.width / 2 - corridorHalfTop + shift, horizonY)
      ..close();

    final Paint trailPaint = Paint()
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

    final Paint linePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..strokeWidth = 1.4;

    for (int i = 1; i <= 9; i++) {
      final double t = i / 10;
      final double y = _lerp(horizonY, corridorBottom, t * t);
      final double halfW = _lerp(corridorHalfTop, corridorHalfBottom, t);
      canvas.drawLine(
        Offset(size.width / 2 - halfW + shift, y),
        Offset(size.width / 2 + halfW + shift, y),
        linePaint,
      );
    }

    final Paint edgeGlow = Paint()
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
    final Paint bark = Paint()..color = GameConfig.redwoodMid;
    final Paint barkDark = Paint()..color = GameConfig.redwoodDark;
    final Paint moss = Paint()
      ..color = const Color(0xFF28452B).withValues(alpha: 0.45);

    for (int i = 0; i < 7; i++) {
      final double t = (i + 1) / 8;
      final double y = _lerp(horizonY + 10, bottomY + 30, t * t);
      final double trunkHeight = _lerp(24, 260, t);
      final double trunkWidth = _lerp(5, 68, t);

      final double edgeX = left
          ? _lerp(size.width * 0.40 + shift, 12 + shift, t)
          : _lerp(size.width * 0.60 + shift, size.width - 12 + shift, t);

      final Rect trunkRect = Rect.fromCenter(
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
      final double x = worldXToScreen(enemy.x - playerX, enemy.distance, size);
      final double y = enemyScreenY(enemy.distance, size);
      final double r = enemyRadius(enemy.distance);

      final Paint bodyPaint = Paint()
        ..color = enemy.alive
            ? enemy.tint
            : Colors.white.withValues(alpha: enemy.flash.clamp(0.0, 1.0));

      final Paint eyePaint = Paint()..color = Colors.redAccent;
      final Paint limbPaint = Paint()
        ..color = const Color(0xFF87929C)
        ..strokeWidth = math.max(2.0, r * 0.12)
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(x - r * 0.28, y + r * 0.72),
        Offset(x - r * 0.48, y + r * 1.32),
        limbPaint,
      );
      canvas.drawLine(
        Offset(x + r * 0.28, y + r * 0.72),
        Offset(x + r * 0.48, y + r * 1.32),
        limbPaint,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, y),
            width: r * 1.05,
            height: r * 1.50,
          ),
          Radius.circular(r * 0.16),
        ),
        bodyPaint,
      );

      canvas.drawLine(
        Offset(x - r * 0.45, y - r * 0.05),
        Offset(x - r * 0.98, y + r * 0.25),
        limbPaint,
      );
      canvas.drawLine(
        Offset(x + r * 0.45, y - r * 0.05),
        Offset(x + r * 0.98, y + r * 0.25),
        limbPaint,
      );

      canvas.drawCircle(Offset(x, y - r * 0.92), r * 0.40, bodyPaint);
      canvas.drawCircle(Offset(x - r * 0.10, y - r * 0.95), r * 0.05, eyePaint);
      canvas.drawCircle(Offset(x + r * 0.10, y - r * 0.95), r * 0.05, eyePaint);
    }
  }

  void _paintTraces(Canvas canvas) {
    for (final trace in traces) {
      final Paint p = Paint()
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

    final Offset c = crosshairPosition;

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
    final double bobX = math.sin(bobTime * 3.2) * 4;
    final double bobY = math.sin(bobTime * 6.4) * 3;
    final double centerX = size.width / 2 + bobX;
    final double baseY = size.height * 0.88 + bobY + (firePressed ? 4 : 0);

    final Paint wood = Paint()..color = const Color(0xFF5C3A24);
    final Paint darkWood = Paint()..color = const Color(0xFF3D2417);
    final Paint metal = Paint()..color = const Color(0xFFC2CCD2);
    final Paint stringPaint = Paint()
      ..color = const Color(0xFFE9DFC7)
      ..strokeWidth = 2.2;
    final Paint glow = Paint()
      ..color = GameConfig.accent.withValues(alpha: firePressed ? 0.55 : 0.18);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centerX, baseY),
          width: 52,
          height: 125,
        ),
        const Radius.circular(10),
      ),
      wood,
    );

    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(centerX - 10, baseY),
        width: 10,
        height: 125,
      ),
      darkWood,
    );

    canvas.drawLine(
      Offset(centerX - 88, baseY - 34),
      Offset(centerX + 88, baseY - 34),
      metal..strokeWidth = 8,
    );

    metal.strokeWidth = 5;
    canvas.drawLine(
      Offset(centerX - 88, baseY - 34),
      Offset(centerX - 112, baseY - 72),
      metal,
    );
    canvas.drawLine(
      Offset(centerX + 88, baseY - 34),
      Offset(centerX + 112, baseY - 72),
      metal,
    );

    canvas.drawLine(
      Offset(centerX - 112, baseY - 72),
      Offset(centerX, baseY - 9),
      stringPaint,
    );
    canvas.drawLine(
      Offset(centerX + 112, baseY - 72),
      Offset(centerX, baseY - 9),
      stringPaint,
    );

    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(centerX, baseY - 25),
        width: 12,
        height: 78,
      ),
      Paint()..color = const Color(0xFFBBC7CD),
    );

    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(centerX, baseY - 55),
        width: 6,
        height: 32,
      ),
      glow,
    );
  }

  @override
  bool shouldRepaint(covariant RedwoodPainter oldDelegate) => true;
}

double _lerp(double a, double b, double t) => a + (b - a) * t;
