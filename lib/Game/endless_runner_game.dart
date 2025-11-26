import 'package:ad_mob_demo/Game/background.dart';
import 'package:ad_mob_demo/Game/bullet.dart';
import 'package:ad_mob_demo/Game/enemy.dart';
import 'package:ad_mob_demo/Game/game_over.dart';
import 'package:ad_mob_demo/Game/player.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/input.dart';
import 'package:flame/game.dart';

class EndlessRunnerGame extends FlameGame with PanDetector, HasCollisionDetection {
  late Player player;

  bool isGameOver = false;
  int score = 0;

  late TextComponent _scoreText;

  @override
  Future<void> onLoad() async {
    add(Background());

    player = Player();
    addAll([
      FpsTextComponent(position: size - Vector2(16, 50), anchor: Anchor.bottomRight),
      _scoreText = TextComponent(
          text: 'Render time: 0ms',
          anchor: Anchor.bottomRight,
          position: size - Vector2(0, 0),
          priority: 1),
      TextComponent(
          position:  Vector2(16, 25),
          anchor: Anchor.topLeft,
          priority: 1,
          text: 'Score: $score'),
    ]);
    add(player);
    spawnBot();
    overlays.addEntry('GameOverMenu', (_, __) => GameOverMenu(game: this));
    overlays.remove('GameOverMenu');
  }

  void restartGame() {
    isGameOver = false;
    score = 0;
    _scoreText.text = 'Score: $score';
    children.whereType<Enemy>().forEach(remove);
    add(player);
    // spawnBot();
  }

  @override
  void update(double dt) {
    _scoreText.text = 'Score: $score';
    super.update(dt);
  }

  void gameOver() {
    isGameOver = true;
    print("Game Over score = $score");
    pauseEngine();
    overlays.add('GameOverMenu');
  }

  void shoot() {
    final bullet = Bullet(position: player.position + Vector2(player.size.x / 2 - 5, 0));
    add(bullet);
  }

  void spawnBot() {
    final enemy = EnemyCreator();
    add(enemy);
  }

  @override
  void onPanStart(info) {
    player.fire();
  }

  @override
  void onPanCancel() {
    player.stopFire();
  }

  @override
  void onPanEnd(DragEndInfo info) {
    player.stopFire();
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    super.onPanUpdate(info);
    // player.position += info.delta.global;
    player.move(info.delta.global);
  }

  void increaseScore(int kill) {
    score += 1;
  }
}
