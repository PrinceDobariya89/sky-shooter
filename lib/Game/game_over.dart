import 'package:flutter/material.dart';

import 'endless_runner_game.dart';

class GameOverMenu extends StatelessWidget {
  final EndlessRunnerGame game;

  const GameOverMenu({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('Game Over', style: TextStyle(fontSize: 40, color: Colors.red)),
          const SizedBox(height: 20),
          ElevatedButton(
              onPressed: () {
                game.overlays.remove('GameOverMenu');
                game.resumeEngine();
                game.restartGame();
              },
              child: const Text('Restart')),
        ]),
      ),
    );
  }
}
