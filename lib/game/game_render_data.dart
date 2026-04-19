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
    return SizedBox(
      width: size.width,
      height: size.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/forrest_bg.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),

          // HACKABLE: slight darken so HUD / enemies / weapon still read.
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
