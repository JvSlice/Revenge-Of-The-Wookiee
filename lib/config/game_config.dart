import 'package:flutter/material.dart';

class GameConfig {
  // ============================================================
  // HACKABLE: core game rules
  // ============================================================
  static const int maxHealth = 5;
  static const int finalWave = 10;

  // ============================================================
  // HACKABLE: player movement / aiming
  // ============================================================
  static const double moveSpeed = 4.2;
  static const double aimSpeed = 4.8;
  static const double aimVerticalSpeed = 4.2;

  static const double playerClamp = 4.4;
  static const double aimClamp = 3.8;

  // Vertical aim clamp in "aim units"
  static const double aimVerticalUpClamp = -1.4;
  static const double aimVerticalDownClamp = 1.6;

  // Crosshair base position and scaling
  static const double crosshairBaseY = 0.64;
  static const double crosshairHorizontalScale = 36.0;
  static const double crosshairVerticalScale = 30.0;

  // ============================================================
  // HACKABLE: player combat
  // ============================================================
  static const double fireCooldown = 0.22;
  static const double hitPadding = 16.0;
  static const double emergencyHitDistance = 2.6;
  static const double emergencyHitPadding = 42.0;

  // ============================================================
  // HACKABLE: enemy spawning / movement
  // ============================================================
  static const double enemyStartDistanceMin = 14.0;
  static const double enemyStartDistanceMax = 25.0;
  static const double enemyBaseSpeed = 2.4;
  static const double enemySpeedRamp = 0.055;
  static const double enemyLaneSpread = 4.0;

  // ============================================================
  // HACKABLE: wave pacing
  // ============================================================
  static const double timeBetweenWaves = 2.4;
  static const double waveSpawnDelay = 0.78;
  static const double bossSpawnDelay = 1.2;

  // ============================================================
  // HACKABLE: enemy projectile tuning
  // ============================================================
  static const double projectileBaseSpeed = 6.2;
  static const double projectileBossSpeed = 7.8;
  static const double projectileHitRadius = 22.0;

  static const double standardFireCooldownMin = 2.0;
  static const double standardFireCooldownMax = 3.2;

  static const double heavyFireCooldownMin = 1.8;
  static const double heavyFireCooldownMax = 2.8;

  static const double bossFireCooldownMin = 1.2;
  static const double bossFireCooldownMax = 1.8;

  // ============================================================
  // HACKABLE: fire button size
  // ============================================================
  static const double fireButtonWidthFactor = 0.18;
  static const double fireButtonMaxSize = 102.0;

  // ============================================================
  // HACKABLE: colors
  // ============================================================
  static const Color accent = Color(0xFF92FF8F);
  static const Color redwoodDark = Color(0xFF3F1F14);
  static const Color redwoodMid = Color(0xFF6E3922);
  static const Color redwoodGlow = Color(0xFFA55B37);
  static const Color forestDark = Color(0xFF102315);
  static const Color forestMid = Color(0xFF1F3B25);
  static const Color mist = Color(0xFFBFD8C6);
}
