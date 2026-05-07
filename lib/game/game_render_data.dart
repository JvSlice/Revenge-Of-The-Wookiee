part of 'game_page.dart';

extension _GamePageRenderingAdapter on _GamePageState {
  void _handleLayoutChange(Size size, bool isLandscape) {
    if (_lastLayoutSize != size || _lastLandscape != isLandscape) {
      moveStick.stop();
      aimStick.stop();
      firePressed = false;
      _lastLayoutSize = size;
      _lastLandscape = isLandscape;
    }
  }

  Widget _buildGamePainter(Size size) {
    // HACKABLE: background parallax strength
    final double backgroundShiftX =
        (-playerX * size.width * 0.06) + (math.sin(worldZ * 0.010) * 6.0);

    // HACKABLE: subtle forward-travel scale
    final double backgroundScale = 1.06;

    return SizedBox(
      width: size.width,
      height: size.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRect(
            child: Transform.translate(
              offset: Offset(backgroundShiftX, 0),
              child: Transform.scale(
                scale: backgroundScale,
                alignment: Alignment.center,
                child: Image.asset(
                  'assets/images/forrest_bg.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
              ),
            ),
          ),

          // HACKABLE: base darken so gameplay stays readable
          Container(
            color: Colors.black.withValues(alpha: 0.10),
          ),

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
        ],
      ),
    );
  }
}
