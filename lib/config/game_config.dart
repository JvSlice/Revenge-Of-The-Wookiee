import 'package:flutter/material.dart';

class GameConfig {
  static const int maxHealth = 5;
  static const int finalWave = 10;

  static const double moveSpeed = 4.2;
  static const double aimSpeed = 4.8;
  static const double playerClamp = 4.4;
  static const double aimClamp = 3.8;

  static const double fireCooldown = 0.22;
  static const double crosshairY = 0.66;
  static const double hitPadding = 16.0;
  static const double emergencyHitDistance = 2.6;
  static const double emergencyHitPadding = 42.0;

  static const double enemyStartDistanceMin = 14.0;
  static const double enemyStartDistanceMax = 25.0;
  static const double enemyBaseSpeed = 2.4;
  static const double enemySpeedRamp = 0.055;
  static const double enemyLaneSpread = 4.0;

  static const double timeBetweenWaves = 2.4;
  static const double waveSpawnDelay = 0.78;
  static const double bossSpawnDelay = 1.2;

  static const Color accent = Color(0xFF92FF8F);
  static const Color redwoodDark = Color(0xFF3F1F14);
  static const Color redwoodMid = Color(0xFF6E3922);
  static const Color redwoodGlow = Color(0xFFA55B37);
  static const Color forestDark = Color(0xFF102315);
  static const Color forestMid = Color(0xFF1F3B25);
  static const Color mist = Color(0xFFBFD8C6);
}
