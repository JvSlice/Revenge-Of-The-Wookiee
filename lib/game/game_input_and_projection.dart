part of 'game_page.dart';

extension _GamePageInputAndProjection on _GamePageState {
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
}
