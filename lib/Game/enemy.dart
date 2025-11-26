import 'dart:math';

import 'package:ad_mob_demo/Game/endless_runner_game.dart';
import 'package:ad_mob_demo/Game/explosion.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

class Enemy extends SpriteAnimationComponent with HasGameReference<EndlessRunnerGame> {
  double speed = 150;
  static final Vector2 initialSize = Vector2.all(25);

  Enemy({required super.position}) : super(size: initialSize);

  @override
  Future<void> onLoad() async {
    // debugMode = true;
    animation = await game.loadSpriteAnimation(
        'enemy.png',
        SpriteAnimationData.sequenced(
          amount: 4,
          stepTime: 0.2,
          textureSize: Vector2.all(16),
        ));
    add(CircleHitbox(collisionType: CollisionType.passive));
  }

  @override
  void update(double dt) {
    super.update(dt);
    y += speed * dt;
    if (y > game.size.y) {
      removeFromParent();
    }
  }

  void kill() {
    removeFromParent();
    game.add(Explosion(position: position));
    game.increaseScore(1);
  }
}

class EnemyCreator extends TimerComponent with HasGameRef {
  final _halfWidth = Enemy.initialSize.x / 2;

  EnemyCreator() : super(period: 0.30, repeat: true);

  @override
  void onTick() {
    game.addAll(
      List.generate(
        1,
        (index) => Enemy(
          position: Vector2(_halfWidth + (game.size.x - _halfWidth) * Random().nextDouble(), 0),
        ),
      ),
    );
  }
}
