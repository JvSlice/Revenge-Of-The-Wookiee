import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../config/game_config.dart';
import '../models/enemy.dart';
import '../models/enemy_projectile.dart';
import '../models/game_types.dart';
import '../models/shot_trace.dart';
import '../models/stick_state.dart';
import '../models/wave_plan.dart';
import '../ui/redwood_painter.dart';
import 'widgets/game_overlays.dart';

part 'game_logic.dart';
part 'game_input_and_projection.dart';
part 'game_rendering_adapter.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  final math.Random _rng = math.Random();

  static const String appVersion = 'v1.0.0';

  GameState state = GameState.menu;
  DifficultyMode selectedDifficulty = DifficultyMode.medium;

  int score = 0;
  int health = GameConfig.maxHealth;
  double survivalTime = 0.0;
  double fireCooldownTimer = 0.0;

  double playerX = 0.0;
  double aimX = 0.0;
  double aimY = 0.0;
  double bobTime = 0.0;
  double worldZ = 0.0;

  final List<Enemy> enemies = [];
  final List<EnemyProjectile> enemyProjectiles = [];
  final List<ShotTrace> traces = [];

  final StickState moveStick = StickState();
  final StickState aimStick = StickState();

  bool firePressed = false;
  Rect fireButtonRect = Rect.zero;
  Rect pauseButtonRect = Rect.zero;

  Size _lastLayoutSize = Size.zero;
  bool _lastLandscape = false;

  int currentWave = 0;
  bool betweenWaves = false;
  double betweenWaveTimer = 0.0;

  WavePlan? activeWave;
  int waveSpawnIndex = 0;
  double waveSpawnTimer = 0.0;

  String bannerText = '';
  double bannerTimer = 0.0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          fireButtonRect = _calcFireButtonRect(size);
          pauseButtonRect = _calcPauseButtonRect(size);

          final isLandscape = size.width > size.height;
          _handleLayoutChange(size, isLandscape);

          return Listener(
            onPointerDown: (e) => _handlePointerDown(e, size),
            onPointerMove: _handlePointerMove,
            onPointerUp: _handlePointerUp,
            onPointerCancel: _handlePointerUp,
            child: Stack(
              children: [
                _buildGamePainter(size),
                if (state == GameState.playing || state == GameState.paused)
                  GameHud(
                    size: size,
                    currentWave: currentWave,
                    score: score,
                    health: health,
                    difficultyLabel: _difficultyLabel,
                    moveStick: moveStick,
                    aimStick: aimStick,
                    firePressed: firePressed,
                    fireButtonRect: fireButtonRect,
                  ),
                if (bannerText.isNotEmpty &&
                    (state == GameState.playing || state == GameState.paused))
                  GameBanner(bannerText: bannerText),
                if (state == GameState.menu)
                  GameMenuOverlay(
                    selectedDifficulty: selectedDifficulty,
                    onDifficultySelected: (mode) {
                      setState(() {
                        selectedDifficulty = mode;
                      });
                    },
                    onStartGame: _startGame,
                    appVersion: appVersion,
                  ),
                if (state == GameState.paused)
                  GamePauseOverlay(
                    onResume: _togglePause,
                    onQuitToMenu: _quitToMenu,
                  ),
                if (state == GameState.won || state == GameState.lost)
                  GameEndOverlay(
                    won: state == GameState.won,
                    score: score,
                    currentWave: currentWave,
                    difficultyLabel: _difficultyLabel,
                    onPlayAgain: _startGame,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t;
