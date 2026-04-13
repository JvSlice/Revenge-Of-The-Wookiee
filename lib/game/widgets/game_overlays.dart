import 'package:flutter/material.dart';

import '../../config/game_config.dart';
import '../../models/game_types.dart';
import '../../models/stick_state.dart';

class GameHud extends StatelessWidget {
  const GameHud({
    super.key,
    required this.size,
    required this.currentWave,
    required this.score,
    required this.health,
    required this.difficultyLabel,
    required this.moveStick,
    required this.aimStick,
    required this.firePressed,
    required this.fireButtonRect,
  });

  final Size size;
  final int currentWave;
  final int score;
  final int health;
  final String difficultyLabel;
  final StickState moveStick;
  final StickState aimStick;
  final bool firePressed;
  final Rect fireButtonRect;

  @override
  Widget build(BuildContext context) {
    final bool isTablet = size.shortestSide >= 600;
    final bool isLandscape = size.width > size.height;
    final double hudScale = isTablet ? 1.18 : 1.0;

    final leftCenter = Offset(
      isLandscape ? 95 * hudScale : 85 * hudScale,
      size.height - (isTablet ? 120 : 95),
    );

    final rightCenter = Offset(
      isLandscape
          ? size.width - (isTablet ? 250 : 220)
          : size.width - (isTablet ? 185 : 160),
      isLandscape
          ? size.height - (isTablet ? 110 : 95)
          : size.height - (isTablet ? 145 : 120),
    );

    final double fireBottom = isLandscape
        ? (isTablet ? 90 : 75)
        : (isTablet ? 135 : 110);

    final double fireRight = isLandscape
        ? (isTablet ? 28 : 22)
        : (isTablet ? 20 : 18);

    return SafeArea(
      child: Stack(
        children: [
          Positioned(
            left: 14,
            top: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Wookiee revenge',
                  style: TextStyle(
                    color: GameConfig.accent,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _pill('Wave: $currentWave'),
                    _pill('Score: $score'),
                    _pill('Health: $health'),
                    _pill(difficultyLabel),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            right: 18,
            top: 18,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.30),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: GameConfig.accent.withValues(alpha: 0.55),
                ),
              ),
              child: Icon(Icons.pause, color: GameConfig.accent),
            ),
          ),
          _StickVisual(
            center: moveStick.active ? moveStick.center : leftCenter,
            knob: moveStick.active ? moveStick.current : leftCenter,
            label: 'MOVE',
            active: moveStick.active,
            sizeMultiplier: hudScale,
          ),
          _StickVisual(
            center: aimStick.active ? aimStick.center : rightCenter,
            knob: aimStick.active ? aimStick.current : rightCenter,
            label: 'AIM',
            active: aimStick.active,
            sizeMultiplier: hudScale,
          ),
          Positioned(
            right: fireRight,
            bottom: fireBottom,
            child: Container(
              width: fireButtonRect.width,
              height: fireButtonRect.height,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: firePressed
                    ? Colors.redAccent.withValues(alpha: 0.45)
                    : Colors.redAccent.withValues(alpha: 0.20),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.95),
                  width: 2.5,
                ),
              ),
              child: const Center(
                child: Text(
                  'FIRE',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GameConfig.accent.withValues(alpha: 0.40)),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

class GameBanner extends StatelessWidget {
  const GameBanner({
    super.key,
    required this.bannerText,
  });

  final String bannerText;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 84),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: GameConfig.accent.withValues(alpha: 0.45),
              ),
            ),
            child: Text(
              bannerText,
              style: TextStyle(
                color: GameConfig.accent,
                fontWeight: FontWeight.bold,
                fontSize: 20,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GameMenuOverlay extends StatelessWidget {
  const GameMenuOverlay({
    super.key,
    required this.selectedDifficulty,
    required this.onDifficultySelected,
    required this.onStartGame,
    required this.appVersion,
  });

  final DifficultyMode selectedDifficulty;
  final ValueChanged<DifficultyMode> onDifficultySelected;
  final VoidCallback onStartGame;
  final String appVersion;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF11161B),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: GameConfig.accent.withValues(alpha: 0.48),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Wookiee revenge',
                style: TextStyle(
                  color: GameConfig.accent,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Retro forest corridor shooter.\nNow with 10 waves, bosses, and enemy projectiles.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              const Text(
                'Left stick: move\nRight stick: aim up/down + left/right\nFire button: shoot\nPause button: top right',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              GameDifficultyButton(
                mode: DifficultyMode.easy,
                selectedDifficulty: selectedDifficulty,
                title: 'Easy',
                subtitle: '5 health • no enemy projectiles',
                onSelected: onDifficultySelected,
              ),
              GameDifficultyButton(
                mode: DifficultyMode.medium,
                selectedDifficulty: selectedDifficulty,
                title: 'Medium',
                subtitle: 'Current default balance',
                onSelected: onDifficultySelected,
              ),
              GameDifficultyButton(
                mode: DifficultyMode.hard,
                selectedDifficulty: selectedDifficulty,
                title: 'Hard',
                subtitle: '1 health • enemy projectiles • bosses gain +wave health',
                onSelected: onDifficultySelected,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onStartGame,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('START GAME'),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                appVersion,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 12,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GamePauseOverlay extends StatelessWidget {
  const GamePauseOverlay({
    super.key,
    required this.onResume,
    required this.onQuitToMenu,
  });

  final VoidCallback onResume;
  final VoidCallback onQuitToMenu;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.62),
      child: Center(
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF10161C),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: GameConfig.accent.withValues(alpha: 0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'PAUSED',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: GameConfig.accent,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onResume,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('RESUME'),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onQuitToMenu,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('QUIT TO MENU'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GameEndOverlay extends StatelessWidget {
  const GameEndOverlay({
    super.key,
    required this.won,
    required this.score,
    required this.currentWave,
    required this.difficultyLabel,
    required this.onPlayAgain,
  });

  final bool won;
  final int score;
  final int currentWave;
  final String difficultyLabel;
  final VoidCallback onPlayAgain;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.68),
      child: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF10161C),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: GameConfig.accent.withValues(alpha: 0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                won ? 'FOREST SECURED' : 'FOREST BREACHED',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: won ? GameConfig.accent : Colors.redAccent,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                won
                    ? 'You survived every wave.'
                    : 'The invaders broke through.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Final Score: $score',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text('Wave Reached: $currentWave'),
              const SizedBox(height: 6),
              Text('Mode: $difficultyLabel'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onPlayAgain,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('PLAY AGAIN'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GameDifficultyButton extends StatelessWidget {
  const GameDifficultyButton({
    super.key,
    required this.mode,
    required this.selectedDifficulty,
    required this.title,
    required this.subtitle,
    required this.onSelected,
  });

  final DifficultyMode mode;
  final DifficultyMode selectedDifficulty;
  final String title;
  final String subtitle;
  final ValueChanged<DifficultyMode> onSelected;

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedDifficulty == mode;

    return GestureDetector(
      onTap: () => onSelected(mode),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? GameConfig.accent.withValues(alpha: 0.14)
              : Colors.black.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? GameConfig.accent.withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.16),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: isSelected ? GameConfig.accent : Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StickVisual extends StatelessWidget {
  const _StickVisual({
    required this.center,
    required this.knob,
    required this.label,
    required this.active,
    required this.sizeMultiplier,
  });

  final Offset center;
  final Offset knob;
  final String label;
  final bool active;
  final double sizeMultiplier;

  @override
  Widget build(BuildContext context) {
    final double baseSize = 90 * sizeMultiplier;
    final double knobSize = 36 * sizeMultiplier;
    final double maxRadius = 34 * sizeMultiplier;

    final clamped = _clampKnob(center, knob, maxRadius);

    return Positioned(
      left: center.dx - baseSize / 2,
      top: center.dy - baseSize / 2,
      child: IgnorePointer(
        child: SizedBox(
          width: baseSize,
          height: baseSize,
          child: Stack(
            children: [
              Container(
                width: baseSize,
                height: baseSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.18),
                  border: Border.all(
                    color: GameConfig.accent.withValues(
                      alpha: active ? 0.9 : 0.35,
                    ),
                    width: 2,
                  ),
                ),
              ),
              Positioned(
                left: clamped.dx - center.dx + (baseSize - knobSize) / 2,
                top: clamped.dy - center.dy + (baseSize - knobSize) / 2,
                child: Container(
                  width: knobSize,
                  height: knobSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: GameConfig.accent.withValues(
                      alpha: active ? 0.55 : 0.22,
                    ),
                    border: Border.all(
                      color: GameConfig.accent.withValues(alpha: 0.95),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Center(
                  child: Transform.translate(
                    offset: Offset(0, 58 * sizeMultiplier),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11 * sizeMultiplier,
                        color: Colors.white.withValues(alpha: 0.82),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Offset _clampKnob(Offset center, Offset current, double maxRadius) {
    final delta = current - center;
    final distance = delta.distance;
    if (distance <= maxRadius || distance == 0) return current;
    return center + (delta / distance) * maxRadius;
  }
}
