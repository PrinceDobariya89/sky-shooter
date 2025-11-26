import 'package:ad_mob_demo/BombPass/bomb_pass.dart';
import 'package:ad_mob_demo/Game/endless_runner_game.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Sky Shooter',
        theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            useMaterial3: true),
        home: const MyHomePage(title: 'Home'));
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  void _incrementCounter() {
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GameWidget(
              game: EndlessRunnerGame(),
              loadingBuilder: (p0) {
                return const Center(child: CircularProgressIndicator());
              }),
        ));
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> homeList = [
      {
        'action': GameWidget(
            game: EndlessRunnerGame(),
            loadingBuilder: (p0) {
              return const Center(child: CircularProgressIndicator());
            }),
        'title': 'Sky Shooter'
      },
      {
        'action': GameWidget(
            game: MyGame(isHost: true, network: NetworkManager()),
            loadingBuilder: (p0) {
              return const Center(child: CircularProgressIndicator());
            }),
        'title': 'Boom Pass'
      },
    ];
    return Scaffold(
      appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(widget.title)),
      body: ListView.builder(
        itemCount: homeList.length,
        itemBuilder: (context, index) {
          Map<String, dynamic> data = homeList[index];
          return ListTile(
            title: Text(data['title']),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => data['action'],
                )),
          );
        },
      ),
    );
  }
}
