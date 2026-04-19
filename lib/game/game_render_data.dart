import 'dart:ui';

import '../models/enemy.dart';
import '../models/enemy_projectile.dart';
import '../models/game_types.dart';
import '../models/shot_trace.dart';

class GameRenderData {
  const GameRenderData({
    required this.size,
    required this.enemies,
    required this.enemyProjectiles,
    required this.traces,
    required this.playerX,
    required this.bobTime,
    required this.worldZ,
    required this.state,
    required this.currentWave,
    required this.firePressed,
    required this.bossHealth,
    required this.bossMaxHealth,
    required this.worldXToScreen,
    required this.enemyScreenY,
    required this.enemyRadius,
    required this.crosshairPosition,
    required this.isTraveling,
    required this.travelProgress,
    required this.travelTurn,
  });

  final Size size;
  final List<Enemy> enemies;
  final List<EnemyProjectile> enemyProjectiles;
  final List<ShotTrace> traces;

  final double playerX;
  final double bobTime;
  final double worldZ;

  final GameState state;
  final int currentWave;
  final bool firePressed;

  final int bossHealth;
  final int bossMaxHealth;

  final Offset crosshairPosition;

  final bool isTraveling;
  final double travelProgress;
  final double travelTurn;

  final double Function(double worldX, double distance, Size size)
      worldXToScreen;
  final double Function(double distance, Size size) enemyScreenY;
  final double Function(double distance) enemyRadius;
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

          // HACKABLE: base scene darkening so HUD / enemies / weapon read clearly.
          Container(
            color: Colors.black.withValues(alpha: 0.14),
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
