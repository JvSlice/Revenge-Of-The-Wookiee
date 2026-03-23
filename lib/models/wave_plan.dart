import 'game_types.dart';

class WavePlan {
  WavePlan({
    required this.number,
    required this.spawnQueue,
    required this.isBossWave,
  });

  final int number;
  final List<EnemyType> spawnQueue;
  final bool isBossWave;
}
