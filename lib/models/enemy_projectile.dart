import 'package:flutter/material.dart';

class EnemyProjectile {
  EnemyProjectile({
    required this.position,
    required this.velocity,
    this.radius = 8.0,
    this.life = 4.0,
    this.isBossShot = false,
  });

  Offset position;
  Offset velocity;
  double radius;
  double life;
  bool isBossShot;
}
