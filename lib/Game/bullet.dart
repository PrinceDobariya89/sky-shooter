import 'package:ad_mob_demo/Game/endless_runner_game.dart';
import 'package:ad_mob_demo/Game/enemy.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class Bullet extends SpriteAnimationComponent with CollisionCallbacks, HasGameRef<EndlessRunnerGame> {
  final double speed = 500;
  late final Vector2 velocity;
  final Vector2 deltaPosition = Vector2.zero();

  Bullet({super.position, super.angle}) : super(size: Vector2(10, 20), anchor: Anchor.center);
  @override
  void onMount() {
    debugPrint('Bullet spawned at $position with angle $angle');
    super.onMount();
  }
  @override
  Future<void> onLoad() async {
    add(CircleHitbox());
    animation = await game.loadSpriteAnimation(
        'bullet.png', SpriteAnimationData.sequenced(amount: 10, stepTime: 10, textureSize: Vector2(4, 18)));
    velocity = Vector2(0, -1)
      // ..rotate(angle)
      ..scale(speed);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.score >= 0 && game.score <= 100) {
      deltaPosition
        ..setFrom(velocity)
        ..scale(dt);
      position += deltaPosition;
    } else {
      position.y -= speed * dt;
    }
    if (position.y < 0 || position.x > game.size.x || position.x + size.x < 0) {
      removeFromParent();
    }
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Enemy) {
      other.kill();
      removeFromParent();
    }
  }
}
