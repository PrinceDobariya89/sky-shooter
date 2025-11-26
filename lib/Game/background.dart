import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/sprite.dart';

class Background extends Component with HasGameRef {
  final gapSize = 12;

  late final SpriteSheet spriteSheet;
  Random random = Random();

  Background();

  @override
  Future<void> onLoad() async {
    spriteSheet = SpriteSheet.fromColumnsAndRows(
        image: await game.images.load('stars.png'), columns: 4, rows: 4);

    final starGapTime = (game.size.y / gapSize) / StarComponent.speed;

    add(
      TimerComponent(
          period: starGapTime, repeat: true, onTick: () => _createRowOfStars(0)),
    );

    final rows = game.size.y / gapSize;

    for (var i = 0; i < gapSize; i++) {
      _createRowOfStars(i * rows);
    }
  }

  void _createRowOfStars(double y) {
    const gapSize = 6;
    final starGap = game.size.x / gapSize;

    for (var i = 0; i < gapSize; i++) {
      _createStarAt(
        starGap * i + (random.nextDouble() * starGap),
        y + (random.nextDouble() * 20),
      );
    }
  }

  void _createStarAt(double x, double y) {
    final animation = spriteSheet.createAnimation(
      row: random.nextInt(3),
      to: 4,
      stepTime: 0.1,
    )..variableStepTimes = [max(20, 100 * random.nextDouble()), 0.1, 0.1, 0.1];

    game.add(StarComponent(animation: animation, position: Vector2(x, y)));
  }
}

class StarComponent extends SpriteAnimationComponent with HasGameRef {
  static const speed = 50;

  StarComponent({super.animation, super.position}) : super(size: Vector2.all(20));

  @override
  void update(double dt) {
    super.update(dt);
    y += dt * speed;
    if (y >= game.size.y) {
      removeFromParent();
    }
  }
}
