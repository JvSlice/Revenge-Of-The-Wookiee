import 'package:flutter/material.dart';

import '../game/game_render_data.dart';
import '../models/enemy.dart';
import '../models/enemy_projectile.dart';
import '../models/game_types.dart';
import '../models/shot_trace.dart';
import 'redwood/redwood_background_world.dart';
import 'redwood/redwood_combat_layers.dart';
import 'redwood/redwood_weapon_hud.dart';

class RedwoodPainter extends CustomPainter {
  RedwoodPainter({
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
  }) : data = GameRenderData(
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
         bossHealth: bossHealth,
         bossMaxHealth: bossMaxHealth,
         worldXToScreen: worldXToScreen,
         enemyScreenY: enemyScreenY,
         enemyRadius: enemyRadius,
         crosshairPosition: crosshairPosition,
         isTraveling: isTraveling,
         travelProgress: travelProgress,
         travelTurn: travelTurn,
       );

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

  final GameRenderData data;

  @override
  void paint(Canvas canvas, Size size) {
    paintBackground(canvas, data);
    paintForestWorld(canvas, data);
    paintEnemies(canvas, data);
    paintEnemyProjectiles(canvas, data);
    paintTraces(canvas, data);
    paintCrosshair(canvas, data);
    paintWeapon(canvas, data);
    paintBossHealthBar(canvas, data);
  }

  @override
  bool shouldRepaint(covariant RedwoodPainter oldDelegate) => true;
}
