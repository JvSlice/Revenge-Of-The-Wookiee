
import 'package:flutter/material.dart';
import 'game_types.dart';

class Enemy {
  Enemy({
    required this.x,
    required this.distance,
    required this.speed,
    required this.tint,
    required this.type,
    required this.radiusScale,
    required this.health,
    required this.maxHealth,
    this.weave = 0.0,
  });

  double x;
  double distance;
  double speed;
  Color tint;
  EnemyType type;
  double radiusScale;
  int health;
  int maxHealth;
  double weave;

  bool alive = true;
  double flash = 0.0;
}
