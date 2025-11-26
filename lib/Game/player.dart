import 'package:ad_mob_demo/Game/bullet.dart';
import 'package:ad_mob_demo/Game/endless_runner_game.dart';
import 'package:ad_mob_demo/Game/enemy.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

class Player extends SpriteAnimationComponent with CollisionCallbacks, HasGameReference<EndlessRunnerGame> {
  double jumpSpeed = -300;
  final double speedLimit = 300;
  double gravity = 600;
  Vector2 velocity = Vector2(0, 0);
  late TimerComponent bullet;

  Player() : super(size: Vector2(100, 50), position: Vector2(200, 650));

  @override
  Future<void> onLoad() async {
    position = Vector2(
      (game.size.x - size.x) / 2,
      game.size.y - size.y - 20,
    );
    // debugMode = true;
    add(CircleHitbox());
    // final bulletAngles = [0.5, 0.3, 0.0, -0.5, -0.3];
    final bulletAngles = [-3.14 , 0.0, 3.14];
    add(
      bullet = TimerComponent(
        period: 0.20,
        repeat: true,
        autoStart: false,
        onTick: () {
          game.addAll(bulletAngles.map(
            (e) => Bullet(
              position: position + Vector2(size.x / 2 - e, 0),
              angle: bulletAngles[0],
            ),
          ));
          // game.add(Bullet(
          //   position: position,
          //   angle: bulletAngles[1],
          // ));
          // game.add(Bullet(
          //   position: position + Vector2(size.x, 0),
          //   angle: bulletAngles[1],
          // ));
          // game.add(Bullet(
          //   position: position + Vector2(size.x / 2, 0),
          //   angle: bulletAngles[1],
          // ));
        },
      ),
    );

    animation = await game.loadSpriteAnimation(
        'player.png',
        SpriteAnimationData.sequenced(
          amount: 4,
          stepTime: 0.2,
          textureSize: Vector2(32, 40),
        ));
  }

  void move(Vector2 delta) {
    position.x += delta.x.clamp(-speedLimit, speedLimit);

    if (position.x < 0) {
      position.x = 0;
    } else if (position.x > game.size.x - size.x) {
      position.x = game.size.x - size.x;
    }
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Enemy) {
      kill();
    }
  }

  void fire() {
    bullet.timer.start();
  }

  void stopFire() {
    bullet.timer.pause();
  }

  void kill() {
    game.gameOver();
  }
}
