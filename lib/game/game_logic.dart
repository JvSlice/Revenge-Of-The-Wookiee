part of 'game_page.dart';

extension _GamePageLogic on _GamePageState {
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
}
