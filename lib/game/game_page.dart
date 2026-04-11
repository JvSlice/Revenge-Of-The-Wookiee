import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../config/game_config.dart';
import '../models/enemy.dart';
import '../models/enemy_projectile.dart';
import '../models/game_types.dart';
import '../models/shot_trace.dart';
import '../models/stick_state.dart';
import '../models/wave_plan.dart';
import '../ui/redwood_painter.dart';

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

  static const String appVersion = 'v1.0.0';

  GameState state = GameState.menu;
  DifficultyMode selectedDifficulty = DifficultyMode.medium;

  int score = 0;
  int health = GameConfig.maxHealth;
  double survivalTime = 0.0;
  double fireCooldownTimer = 0.0;

  double playerX = 0.0;
  double aimX = 0.0;
  double aimY = 0.0;
  double bobTime = 0.0;
  double worldZ = 0.0;

  final List<Enemy> enemies = [];
  final List<EnemyProjectile> enemyProjectiles = [];
  final List<ShotTrace> traces = [];

  final StickState moveStick = StickState();
  final StickState aimStick = StickState();

  bool firePressed = false;
  Rect fireButtonRect = Rect.zero;
  Rect pauseButtonRect = Rect.zero;

  Size _lastLayoutSize = Size.zero;
  bool _lastLandscape = false;

  int currentWave = 0;
  bool betweenWaves = false;
  double betweenWaveTimer = 0.0;

  WavePlan? activeWave;
  int waveSpawnIndex = 0;
  double waveSpawnTimer = 0.0;

  String bannerText = '';
  double bannerTimer = 0.0;

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

  int _startingHealthForDifficulty() {
    switch (selectedDifficulty) {
      case DifficultyMode.easy:
        return 5;
      case DifficultyMode.hard:
        return 1;
      case DifficultyMode.medium:
        return GameConfig.maxHealth;
    }
  }

  bool get _enemyProjectilesEnabled =>
      selectedDifficulty != DifficultyMode.easy;

  bool get _hardModeBossBonus => selectedDifficulty == DifficultyMode.hard;

  void _startGame() {
    setState(() {
      state = GameState.playing;
      score = 0;
      health = _startingHealthForDifficulty();
      survivalTime = 0.0;
      fireCooldownTimer = 0.0;
      playerX = 0.0;
      aimX = 0.0;
      aimY = 0.0;
      bobTime = 0.0;
      worldZ = 0.0;

      enemies.clear();
      enemyProjectiles.clear();
      traces.clear();

      moveStick.stop();
      aimStick.stop();
      firePressed = false;

      currentWave = 0;
      betweenWaves = false;
      betweenWaveTimer = 0.0;

      activeWave = null;
      waveSpawnIndex = 0;
      waveSpawnTimer = 0.0;

      bannerText = '';
      bannerTimer = 0.0;

      _beginNextWave();
      _lastTick = Duration.zero;
    });
  }

  void _togglePause() {
    setState(() {
      if (state == GameState.playing) {
        state = GameState.paused;
        moveStick.stop();
        aimStick.stop();
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
      aimStick.stop();
      firePressed = false;
      _lastTick = Duration.zero;
    });
  }

  void _showBanner(String text, [double duration = 1.8]) {
    bannerText = text;
    bannerTimer = duration;
  }

  void _updateGame(double dt) {
    worldZ += dt * 1.0;
    survivalTime += dt;
    fireCooldownTimer = math.max(0.0, fireCooldownTimer - dt);

    if (bannerTimer > 0) {
      bannerTimer -= dt;
      if (bannerTimer <= 0) {
        bannerText = '';
      }
    }

    _updateControls(dt);
    _updateWaveLogic(dt);
    _updateEnemies(dt);

    if (_enemyProjectilesEnabled) {
      _updateEnemyProjectiles(dt);
    } else {
      enemyProjectiles.clear();
    }

    _updateTraces(dt);

    if (health <= 0) {
      state = GameState.lost;
      return;
    }

    if (currentWave > GameConfig.finalWave &&
        enemies.isEmpty &&
        enemyProjectiles.isEmpty) {
      state = GameState.won;
    }
  }

  void _updateControls(double dt) {
    double moveInput = 0.0;
    double aimInputX = 0.0;
    double aimInputY = 0.0;

    const double stickRange = 55.0;
    const double deadzone = 10.0;

    if (moveStick.active) {
      final delta = moveStick.current - moveStick.center;
      final dx = delta.dx;

      if (dx.abs() > deadzone) {
        final normalized = ((dx.abs() - deadzone) / (stickRange - deadzone))
            .clamp(0.0, 1.0);
        moveInput = dx.isNegative ? -normalized : normalized;
      }
    }

    if (aimStick.active) {
      final delta = aimStick.current - aimStick.center;
      final dx = delta.dx;
      final dy = delta.dy;

      if (dx.abs() > deadzone) {
        final normalized = ((dx.abs() - deadzone) / (stickRange - deadzone))
            .clamp(0.0, 1.0);
        aimInputX = dx.isNegative ? -normalized : normalized;
      }

      if (dy.abs() > deadzone) {
        final normalized = ((dy.abs() - deadzone) / (stickRange - deadzone))
            .clamp(0.0, 1.0);
        aimInputY = dy.isNegative ? -normalized : normalized;
      }
    }

    playerX += moveInput * GameConfig.moveSpeed * dt;
    aimX += aimInputX * GameConfig.aimSpeed * dt;
    aimY += aimInputY * GameConfig.aimVerticalSpeed * dt;

    playerX = playerX.clamp(-GameConfig.playerClamp, GameConfig.playerClamp);
    aimX = aimX.clamp(-GameConfig.aimClamp, GameConfig.aimClamp);
    aimY = aimY.clamp(
      GameConfig.aimVerticalUpClamp,
      GameConfig.aimVerticalDownClamp,
    );

    bobTime += dt * (1.0 + moveInput.abs() * 2.0);
  }

  void _updateWaveLogic(double dt) {
    if (betweenWaves) {
      betweenWaveTimer -= dt;
      if (betweenWaveTimer <= 0) {
        betweenWaves = false;
        _beginNextWave();
      }
      return;
    }

    if (activeWave != null && waveSpawnIndex < activeWave!.spawnQueue.length) {
      waveSpawnTimer -= dt;
      if (waveSpawnTimer <= 0) {
        final type = activeWave!.spawnQueue[waveSpawnIndex];
        _spawnEnemy(type);
        waveSpawnIndex += 1;

        waveSpawnTimer = activeWave!.isBossWave
            ? GameConfig.bossSpawnDelay
            : GameConfig.waveSpawnDelay;
      }
    }

    final waveFullySpawned =
        activeWave != null && waveSpawnIndex >= activeWave!.spawnQueue.length;

    if (waveFullySpawned && enemies.isEmpty && enemyProjectiles.isEmpty) {
      if (currentWave >= GameConfig.finalWave) {
        currentWave = GameConfig.finalWave + 1;
      } else {
        betweenWaves = true;
        betweenWaveTimer = GameConfig.timeBetweenWaves;
        _showBanner('WAVE CLEAR');
      }
    }
  }

  void _beginNextWave() {
    currentWave += 1;

    if (currentWave > GameConfig.finalWave) {
      activeWave = null;
      return;
    }

    activeWave = _buildWave(currentWave);
    waveSpawnIndex = 0;
    waveSpawnTimer = 0.4;

    if (activeWave!.isBossWave) {
      _showBanner('BOSS WAVE $currentWave');
    } else {
      _showBanner('WAVE $currentWave');
    }
  }

  WavePlan _buildWave(int waveNumber) {
    switch (waveNumber) {
      case 1:
        return WavePlan(
          number: 1,
          isBossWave: false,
          spawnQueue: const [
            EnemyType.standard,
            EnemyType.standard,
            EnemyType.standard,
            EnemyType.standard,
            EnemyType.standard,
            EnemyType.standard,
          ],
        );
      case 2:
        return WavePlan(
          number: 2,
          isBossWave: false,
          spawnQueue: const [
            EnemyType.standard,
            EnemyType.scout,
            EnemyType.standard,
            EnemyType.scout,
            EnemyType.standard,
            EnemyType.heavy,
            EnemyType.standard,
            EnemyType.scout,
          ],
        );
      case 3:
        return WavePlan(
          number: 3,
          isBossWave: true,
          spawnQueue: const [
            EnemyType.standard,
            EnemyType.scout,
            EnemyType.boss,
          ],
        );
      case 4:
        return WavePlan(
          number: 4,
          isBossWave: false,
          spawnQueue: const [
            EnemyType.scout,
            EnemyType.scout,
            EnemyType.standard,
            EnemyType.heavy,
            EnemyType.standard,
            EnemyType.scout,
            EnemyType.heavy,
            EnemyType.standard,
            EnemyType.scout,
          ],
        );
      case 5:
        return WavePlan(
          number: 5,
          isBossWave: false,
          spawnQueue: const [
            EnemyType.heavy,
            EnemyType.standard,
            EnemyType.scout,
            EnemyType.heavy,
            EnemyType.standard,
            EnemyType.scout,
            EnemyType.standard,
            EnemyType.heavy,
            EnemyType.scout,
            EnemyType.standard,
          ],
        );
      case 6:
        return WavePlan(
          number: 6,
          isBossWave: true,
          spawnQueue: const [
            EnemyType.heavy,
            EnemyType.standard,
            EnemyType.boss,
            EnemyType.scout,
          ],
        );
      case 7:
        return WavePlan(
          number: 7,
          isBossWave: false,
          spawnQueue: const [
            EnemyType.scout,
            EnemyType.scout,
            EnemyType.heavy,
            EnemyType.standard,
            EnemyType.heavy,
            EnemyType.standard,
            EnemyType.scout,
            EnemyType.heavy,
            EnemyType.standard,
            EnemyType.scout,
            EnemyType.heavy,
          ],
        );
      case 8:
        return WavePlan(
          number: 8,
          isBossWave: false,
          spawnQueue: const [
            EnemyType.heavy,
            EnemyType.scout,
            EnemyType.heavy,
            EnemyType.standard,
            EnemyType.scout,
            EnemyType.heavy,
            EnemyType.standard,
            EnemyType.heavy,
            EnemyType.scout,
            EnemyType.standard,
            EnemyType.heavy,
            EnemyType.scout,
          ],
        );
      case 9:
        return WavePlan(
          number: 9,
          isBossWave: true,
          spawnQueue: const [
            EnemyType.heavy,
            EnemyType.boss,
            EnemyType.scout,
            EnemyType.heavy,
          ],
        );
      case 10:
      default:
        return WavePlan(
          number: 10,
          isBossWave: true,
          spawnQueue: const [
            EnemyType.heavy,
            EnemyType.standard,
            EnemyType.boss,
            EnemyType.scout,
            EnemyType.heavy,
            EnemyType.boss,
          ],
        );
    }
  }

  void _spawnEnemy(EnemyType type) {
    final distance =
        _rng.nextDouble() *
            (GameConfig.enemyStartDistanceMax -
                GameConfig.enemyStartDistanceMin) +
        GameConfig.enemyStartDistanceMin;

    double x = (_rng.nextDouble() * 2 - 1) * GameConfig.enemyLaneSpread;

    double speed;
    Color tint;
    double radiusScale;
    int hp;
    double weave;
    double shootCooldown;

    switch (type) {
      case EnemyType.scout:
        speed = GameConfig.enemyBaseSpeed + 1.1 + currentWave * 0.10;
        tint = const Color(0xFFD8E0EA);
        radiusScale = 0.82;
        hp = 1;
        weave = 1.5 + currentWave * 0.03;
        shootCooldown = 999.0;
        break;
      case EnemyType.heavy:
        speed = GameConfig.enemyBaseSpeed + 0.10 + currentWave * 0.08;
        tint = const Color(0xFFE1C77A);
        radiusScale = 1.18;
        hp = 2 + (currentWave >= 8 ? 1 : 0);
        weave = 0.2;
        shootCooldown = _randomRange(
          GameConfig.heavyFireCooldownMin,
          GameConfig.heavyFireCooldownMax,
        );
        break;
      case EnemyType.boss:
        speed = GameConfig.enemyBaseSpeed + currentWave * 0.06;
        tint = const Color(0xFFFFC36E);
        radiusScale = currentWave >= 10 ? 2.0 : 1.75;
        hp = currentWave >= 10
            ? 8
            : currentWave >= 6
            ? 6
            : 5;

        if (_hardModeBossBonus) {
          hp += currentWave;
        }

        weave = 0.12;
        x *= 0.45;
        shootCooldown = _randomRange(
          GameConfig.bossFireCooldownMin,
          GameConfig.bossFireCooldownMax,
        );
        break;
      case EnemyType.standard:
        speed =
            GameConfig.enemyBaseSpeed +
            (currentWave * GameConfig.enemySpeedRamp) +
            _rng.nextDouble() * 0.45;
        tint = const Color(0xFFC9D0D6);
        radiusScale = 1.0;
        hp = currentWave >= 7 ? 2 : 1;
        weave = 0.45 + currentWave * 0.01;
        shootCooldown = _randomRange(
          GameConfig.standardFireCooldownMin,
          GameConfig.standardFireCooldownMax,
        );
        break;
    }

    enemies.add(
      Enemy(
        x: x,
        distance: distance,
        speed: speed,
        tint: tint,
        type: type,
        radiusScale: radiusScale,
        health: hp,
        maxHealth: hp,
        weave: weave,
        shootCooldown: shootCooldown,
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

      if (enemy.weave != 0) {
        enemy.x +=
            math.sin(survivalTime * (1.5 + enemy.weave)) *
            enemy.weave *
            dt *
            0.9;
      }

      if (_enemyProjectilesEnabled) {
        _updateEnemyShooting(enemy, dt);
      }

      if (enemy.distance <= 0.8) {
        health -= enemy.type == EnemyType.boss ? 2 : 1;
        dead.add(enemy);
      }
    }

    enemies.removeWhere(dead.contains);
  }

  void _updateEnemyShooting(Enemy enemy, double dt) {
    enemy.shootCooldown -= dt;
    if (enemy.shootCooldown > 0) return;

    if (enemy.type == EnemyType.boss) {
      _spawnEnemyProjectile(enemy, -0.22, true);
      _spawnEnemyProjectile(enemy, 0.0, true);
      _spawnEnemyProjectile(enemy, 0.22, true);
      enemy.shootCooldown = _randomRange(
        GameConfig.bossFireCooldownMin,
        GameConfig.bossFireCooldownMax,
      );
      return;
    }

    if (enemy.type == EnemyType.standard) {
      _spawnEnemyProjectile(enemy, 0.0, false);
      enemy.shootCooldown = _randomRange(
        GameConfig.standardFireCooldownMin,
        GameConfig.standardFireCooldownMax,
      );
      return;
    }

    if (enemy.type == EnemyType.heavy) {
      _spawnEnemyProjectile(enemy, 0.0, false);
      enemy.shootCooldown = _randomRange(
        GameConfig.heavyFireCooldownMin,
        GameConfig.heavyFireCooldownMax,
      );
      return;
    }
  }

  void _spawnEnemyProjectile(
    Enemy enemy,
    double horizontalSpread,
    bool isBossShot,
  ) {
    final startX = enemy.x;
    final startY = enemy.distance;

    final targetX = playerX;
    const targetY = 0.9;

    final dx = (targetX - startX) + horizontalSpread;
    final dy = targetY - startY;

    final len = math.sqrt(dx * dx + dy * dy);
    if (len == 0) return;

    final speed = isBossShot
        ? GameConfig.projectileBossSpeed
        : GameConfig.projectileBaseSpeed;

    final velocity = Offset((dx / len) * speed, (dy / len) * speed);

    enemyProjectiles.add(
      EnemyProjectile(
        position: Offset(startX, startY),
        velocity: velocity,
        radius: isBossShot ? 10.0 : 8.0,
        life: 4.0,
        isBossShot: isBossShot,
      ),
    );
  }

  void _updateEnemyProjectiles(double dt) {
    final dead = <EnemyProjectile>[];

    for (final projectile in enemyProjectiles) {
      projectile.position = Offset(
        projectile.position.dx + projectile.velocity.dx * dt,
        projectile.position.dy + projectile.velocity.dy * dt,
      );

      projectile.life -= dt;
      if (projectile.life <= 0) {
        dead.add(projectile);
        continue;
      }

      final playerHitX = playerX;
      const playerHitY = 0.9;

      final dx = projectile.position.dx - playerHitX;
      final dy = projectile.position.dy - playerHitY;
      final distance = math.sqrt(dx * dx + dy * dy);

      if (distance <= (GameConfig.projectileHitRadius / 100.0)) {
        health -= projectile.isBossShot ? 2 : 1;
        dead.add(projectile);
      }
    }

    enemyProjectiles.removeWhere(dead.contains);
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
      final radius = _enemyRadius(enemy.distance) * enemy.radiusScale;

      final dx = (enemyScreen.dx - crosshair.dx).abs();
      final dy = (enemyScreen.dy - crosshair.dy).abs();

      final directlyHit =
          dx <= (radius + GameConfig.hitPadding) &&
          dy <= (radius + GameConfig.hitPadding);

      final emergencyCloseHit =
          enemy.distance <= GameConfig.emergencyHitDistance &&
          dx <= (radius + GameConfig.emergencyHitPadding);

      if (!directlyHit && !emergencyCloseHit) continue;

      final centerDistance =
          (enemyScreen - crosshair).distance / math.max(radius, 1.0);
      final closeBonus = 1.0 / math.max(enemy.distance, 1.0);
      final scoreValue = centerDistance - closeBonus * 0.85;

      if (scoreValue < bestScore) {
        bestScore = scoreValue;
        bestTarget = enemy;
      }
    }

    if (bestTarget != null) {
      bestTarget.health -= 1;
      bestTarget.flash = 0.18;

      if (bestTarget.health <= 0) {
        bestTarget.alive = false;
        score += bestTarget.type == EnemyType.boss
            ? 12
            : bestTarget.type == EnemyType.heavy
            ? 4
            : bestTarget.type == EnemyType.scout
            ? 2
            : 1;
      }
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

    if (p.dx < size.width * 0.5) {
      if (!moveStick.active) {
        moveStick.start(event.pointer, p);
      }
    } else {
      if (!aimStick.active) {
        aimStick.start(event.pointer, p);
      }
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (state != GameState.playing) return;

    if (event.pointer == moveStick.pointerId) {
      moveStick.update(event.localPosition);
    } else if (event.pointer == aimStick.pointerId) {
      aimStick.update(event.localPosition);
    }
  }

  void _handlePointerUp(PointerEvent event) {
    if (event.pointer == moveStick.pointerId) {
      moveStick.stop();
    } else if (event.pointer == aimStick.pointerId) {
      aimStick.stop();
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
      size.width / 2 + aimX * GameConfig.crosshairHorizontalScale,
      size.height * GameConfig.crosshairBaseY +
          aimY * GameConfig.crosshairVerticalScale,
    );
  }

  double _randomRange(double min, double max) {
    return min + _rng.nextDouble() * (max - min);
  }

  Rect _calcFireButtonRect(Size size) {
    final bool isTablet = size.shortestSide >= 600;
    final bool isLandscape = size.width > size.height;

    final double buttonSize = math.min(
      size.width * (isTablet ? 0.16 : GameConfig.fireButtonWidthFactor),
      isTablet ? 112.0 : GameConfig.fireButtonMaxSize,
    );

    return Rect.fromLTWH(
      size.width - buttonSize - (isLandscape ? 10.0 : (isTablet ? 14.0 : 18.0)),
      size.height -
          buttonSize -
          (isLandscape ? 85.0 : (isTablet ? 155.0 : 110.0)),
      buttonSize,
      buttonSize,
    );
  }

  Rect _calcPauseButtonRect(Size size) {
    return Rect.fromLTWH(size.width - 66.0, 18.0, 48.0, 48.0);
  }

  int get _currentBossHealth {
    for (final enemy in enemies) {
      if (enemy.type == EnemyType.boss && enemy.alive) {
        return enemy.health;
      }
    }
    return 0;
  }

  int get _currentBossMaxHealth {
    for (final enemy in enemies) {
      if (enemy.type == EnemyType.boss && enemy.alive) {
        return enemy.maxHealth;
      }
    }
    return 0;
  }

  String get _difficultyLabel {
    switch (selectedDifficulty) {
      case DifficultyMode.easy:
        return 'Easy';
      case DifficultyMode.medium:
        return 'Medium';
      case DifficultyMode.hard:
        return 'Hard';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          fireButtonRect = _calcFireButtonRect(size);
          pauseButtonRect = _calcPauseButtonRect(size);

          final isLandscape = size.width > size.height;

          if (_lastLayoutSize != size || _lastLandscape != isLandscape) {
            moveStick.stop();
            aimStick.stop();
            firePressed = false;
            _lastLayoutSize = size;
            _lastLandscape = isLandscape;
          }

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
                    enemyProjectiles: enemyProjectiles,
                    traces: traces,
                    playerX: playerX,
                    bobTime: bobTime,
                    worldZ: worldZ,
                    state: state,
                    currentWave: currentWave,
                    firePressed: firePressed,
                    bossHealth: _currentBossHealth,
                    bossMaxHealth: _currentBossMaxHealth,
                    worldXToScreen: _worldXToScreen,
                    enemyScreenY: _enemyScreenY,
                    enemyRadius: _enemyRadius,
                    crosshairPosition: _crosshairScreenPosition(size),
                    isTraveling: false,
                    travelProgress: 0.0,
                    travelTurn: 0.0,
                  ),
                ),
                if (state == GameState.playing || state == GameState.paused)
                  _buildHud(size),
                if (bannerText.isNotEmpty &&
                    (state == GameState.playing || state == GameState.paused))
                  _buildBanner(),
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
    final bool isTablet = size.shortestSide >= 600;
    final bool isLandscape = size.width > size.height;
    final double hudScale = isTablet ? 1.18 : 1.0;

    final leftCenter = Offset(
      isLandscape ? 95 * hudScale : 85 * hudScale,
      size.height - (isTablet ? 120 : 95),
    );

    final rightCenter = Offset(
      isLandscape
          ? size.width - (isTablet ? 250 : 220)
          : size.width - (isTablet ? 185 : 160),
      isLandscape
          ? size.height - (isTablet ? 110 : 95)
          : size.height - (isTablet ? 145 : 120),
    );

    final double fireBottom = isLandscape
        ? (isTablet ? 90 : 75)
        : (isTablet ? 135 : 110);

    final double fireRight = isLandscape
        ? (isTablet ? 28 : 22)
        : (isTablet ? 20 : 18);

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
                  'Wookiee revenge',
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
                    _pill('Wave: $currentWave'),
                    _pill('Score: $score'),
                    _pill('Health: $health'),
                    _pill(_difficultyLabel),
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
              child: Icon(Icons.pause, color: GameConfig.accent),
            ),
          ),
          _buildStickVisual(
            center: moveStick.active ? moveStick.center : leftCenter,
            knob: moveStick.active ? moveStick.current : leftCenter,
            label: 'MOVE',
            active: moveStick.active,
            sizeMultiplier: hudScale,
          ),
          _buildStickVisual(
            center: aimStick.active ? aimStick.center : rightCenter,
            knob: aimStick.active ? aimStick.current : rightCenter,
            label: 'AIM',
            active: aimStick.active,
            sizeMultiplier: hudScale,
          ),
          Positioned(
            right: fireRight,
            bottom: fireBottom,
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
    double sizeMultiplier = 1.0,
  }) {
    final double baseSize = 90 * sizeMultiplier;
    final double knobSize = 36 * sizeMultiplier;
    final double maxRadius = 34 * sizeMultiplier;

    final clamped = _clampKnob(center, knob, maxRadius);

    return Positioned(
      left: center.dx - baseSize / 2,
      top: center.dy - baseSize / 2,
      child: IgnorePointer(
        child: SizedBox(
          width: baseSize,
          height: baseSize,
          child: Stack(
            children: [
              Container(
                width: baseSize,
                height: baseSize,
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
                left: clamped.dx - center.dx + (baseSize - knobSize) / 2,
                top: clamped.dy - center.dy + (baseSize - knobSize) / 2,
                child: Container(
                  width: knobSize,
                  height: knobSize,
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
                    offset: Offset(0, 58 * sizeMultiplier),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11 * sizeMultiplier,
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
        border: Border.all(color: GameConfig.accent.withValues(alpha: 0.40)),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildBanner() {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 84),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: GameConfig.accent.withValues(alpha: 0.45),
              ),
            ),
            child: Text(
              bannerText,
              style: TextStyle(
                color: GameConfig.accent,
                fontWeight: FontWeight.bold,
                fontSize: 20,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyButton({
    required DifficultyMode mode,
    required String title,
    required String subtitle,
  }) {
    final isSelected = selectedDifficulty == mode;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedDifficulty = mode;
        });
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? GameConfig.accent.withValues(alpha: 0.14)
              : Colors.black.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? GameConfig.accent.withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.16),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: isSelected ? GameConfig.accent : Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF11161B),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: GameConfig.accent.withValues(alpha: 0.48),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Wookiee revenge',
                style: TextStyle(
                  color: GameConfig.accent,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Retro forest corridor shooter.\nNow with 10 waves, bosses, and enemy projectiles.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              const Text(
                'Left stick: move\nRight stick: aim up/down + left/right\nFire button: shoot\nPause button: top right',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _buildDifficultyButton(
                mode: DifficultyMode.easy,
                title: 'Easy',
                subtitle: '5 health • no enemy projectiles',
              ),
              _buildDifficultyButton(
                mode: DifficultyMode.medium,
                title: 'Medium',
                subtitle: 'Current default balance',
              ),
              _buildDifficultyButton(
                mode: DifficultyMode.hard,
                title: 'Hard',
                subtitle:
                    '1 health • enemy projectiles • bosses gain +wave health',
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 18),
              Text(
                appVersion,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 12,
                  letterSpacing: 1.0,
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
            border: Border.all(color: GameConfig.accent.withValues(alpha: 0.5)),
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
    final won = state == GameState.won;

    return Container(
      color: Colors.black.withValues(alpha: 0.68),
      child: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF10161C),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: GameConfig.accent.withValues(alpha: 0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                won ? 'FOREST SECURED' : 'FOREST BREACHED',
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
                    ? 'You survived every wave.'
                    : 'The invaders broke through.',
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
              Text('Wave Reached: $currentWave'),
              const SizedBox(height: 6),
              Text('Mode: $_difficultyLabel'),
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

double _lerp(double a, double b, double t) => a + (b - a) * t;
