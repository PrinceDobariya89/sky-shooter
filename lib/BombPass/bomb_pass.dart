// Bomb Pass Multiplayer — Full Game (Flame) - main.dart
// ---------------------------------------------------------------
// This is a single-file example demonstrating a local LAN (hotspot) multiplayer
// top-down game built with Flame. It includes:
//  - Joystick-based player movement
//  - Animated player sprite placeholder (replace with your sprite sheet)
//  - Host (ServerSocket) authoritative world state simulation
//  - Clients send input; host broadcasts authoritative positions
//  - Simple shooting system (bullets), map obstacles, and basic hit detection
// Notes / Requirements:
//  - Add to pubspec.yaml:
//      flame: ^1.14.0
//      flutter_hooks: ^0.18.6
//  - Add Android INTERNET permission in AndroidManifest.xml
//      <uses-permission android:name="android.permission.INTERNET" />
//  - This demo uses simple colored rectangles so you can run without image assets.
//    For sprite animations, replace the drawing code in PlayerComponent with SpriteAnimationComponent.
//  - Run host on device that creates hotspot; clients must connect to host IP:port.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';

// -------------------- CONFIG --------------------
const int SERVER_PORT = 5050;
const double PLAYER_SPEED = 140; // px / sec
const double TICK_INTERVAL = 0.05; // 50ms

// -------------------- DATA MODELS --------------------
class NetMsg {
  String type;
  Map<String, dynamic> data;
  NetMsg(this.type, [this.data = const {}]);
  String encode() => jsonEncode({'type': type, 'data': data});
  static NetMsg decode(String s) {
    final m = jsonDecode(s);
    return NetMsg(m['type'] as String, Map<String, dynamic>.from(m['data'] ?? {}));
  }
}

// -------------------- GAME COMPONENTS --------------------
class PlayerComponent extends PositionComponent with HasGameRef<MyGame> {
  String id;
  String name;
  Paint paintBody;
  Vector2 velocity = Vector2.zero();
  bool isLocal = false;
  double radius = 18;
  int health = 100;
  String character = 'Soldier'; // placeholder

  PlayerComponent({required this.id, required this.name, this.isLocal = false}) : paintBody = Paint() {
    paintBody.color = isLocal ? Colors.blue : Colors.green;
    size = Vector2.all(radius * 2);
    anchor = Anchor.center;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    // Draw body (circle)
    canvas.drawCircle(Offset(radius, radius), radius, paintBody);
    // Draw name above
    TextPaint(style: TextStyle(color: Colors.white, fontSize: 12)).render(canvas, name, Vector2(0, -12));
    // draw health bar
    final barW = 36.0;
    final hX = (size.x - barW) / 2;
    final hp = (health.clamp(0, 100) / 100);
    canvas.drawRect(Rect.fromLTWH(hX, -18, barW, 4), Paint()..color = Colors.black.withOpacity(0.5));
    canvas.drawRect(Rect.fromLTWH(hX, -18, barW * hp, 4), Paint()..color = Colors.red);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (velocity.length > 0) {
      position += velocity.normalized() * PLAYER_SPEED * dt;
      // clamp to world bounds
      final w = gameRef.worldSize.x;
      final h = gameRef.worldSize.y;
      position.x = position.x.clamp(radius, w - radius);
      position.y = position.y.clamp(radius, h - radius);
    }
  }
}

class BulletComponent extends PositionComponent with HasGameRef<MyGame> {
  Vector2 dir;
  double speed = 320;
  String ownerId;
  Paint paintBullet = Paint()..color = Colors.yellow;
  double lifetime = 3.0;

  BulletComponent({required Vector2 pos, required this.dir, required this.ownerId}) : super(position: pos.clone(), size: Vector2.all(8), anchor: Anchor.center) {
    dir = dir.normalized();
  }

  @override
  void update(double dt) {
    super.update(dt);
    position += dir * speed * dt;
    lifetime -= dt;
    if (lifetime <= 0) removeFromParent();

    // collision with players
    for (var p in gameRef.players.values) {
      if (p.id == ownerId) continue; // don't hit owner
      if ((p.position - position).length < p.radius + 4) {
        p.health -= 25;
        removeFromParent();
        // notify host if client-owned bullet? For simplicity host handles damage
        break;
      }
    }

    // collision with obstacles
    for (var obs in gameRef.obstacles) {
      if (obs.toRect().contains(Offset(position.x, position.y))) {
        removeFromParent();
        break;
      }
    }
  }
}

// Simple obstacle class
class Obstacle {
  Rect rect;
  Obstacle(this.rect);
  Rect toRect() => rect;
  void render(Canvas canvas) {
    canvas.drawRect(rect, Paint()..color = Colors.brown);
  }
}

// -------------------- GAME --------------------
class MyGame extends FlameGame with /*HasDraggables, HasTappables,*/ HasKeyboardHandlerComponents {
  final bool isHost;
  final NetworkManager network;
  late Vector2 worldSize;
  Map<String, PlayerComponent> players = {};
  List<Obstacle> obstacles = [];
  double lastNetTick = 0;

  MyGame({required this.isHost, required this.network});

  @override
  Future<void> onLoad() async {
    worldSize = Vector2(1600, 900);
    // initial obstacles
    obstacles.add(Obstacle(Rect.fromLTWH(300, 200, 200, 40)));
    obstacles.add(Obstacle(Rect.fromLTWH(800, 400, 60, 260)));
    obstacles.add(Obstacle(Rect.fromLTWH(1200, 100, 220, 120)));

    // create local player placeholder (will be replaced by network init)
    // network will call addPlayer when players join
  }

  @override
  void render(Canvas canvas) {
    // draw background
    canvas.drawRect(Rect.fromLTWH(0, 0, worldSize.x, worldSize.y), Paint()..color = Colors.green[800]!);
    // draw grid for map feel
    final gridPaint = Paint()..color = Colors.black.withOpacity(0.05);
    for (double x = 0; x < worldSize.x; x += 64) canvas.drawLine(Offset(x, 0), Offset(x, worldSize.y), gridPaint);
    for (double y = 0; y < worldSize.y; y += 64) canvas.drawLine(Offset(0, y), Offset(worldSize.x, y), gridPaint);

    // obstacles
    for (var o in obstacles) o.render(canvas);

    super.render(canvas);
  }

  void addPlayer(String id, String name, {bool isLocal = false}) {
    if (players.containsKey(id)) return;
    final p = PlayerComponent(id: id, name: name, isLocal: isLocal);
    // random spawn
    final r = Random();
    p.position = Vector2(100 + r.nextDouble() * (worldSize.x - 200), 100 + r.nextDouble() * (worldSize.y - 200));
    add(p);
    players[id] = p;
  }

  void removePlayer(String id) {
    if (!players.containsKey(id)) return;
    players[id]!.removeFromParent();
    players.remove(id);
  }

  // Host-only: simulate world and broadcast positions
  void hostTick(double dt) {
    // step world, handle bullets, remove dead
    final dead = <String>[];
    for (var p in players.values) {
      if (p.health <= 0) dead.add(p.id);
    }
    for (var d in dead) {
      players[d]!.removeFromParent();
      players.remove(d);
      // broadcast death
      network.broadcast(NetMsg('player_dead', {'id': d}).encode());
    }

    lastNetTick += dt;
    if (lastNetTick >= TICK_INTERVAL) {
      lastNetTick = 0;
      final payload = {
        'players': players.values.map((p) => {
          'id': p.id,
          'x': p.position.x,
          'y': p.position.y,
          'vx': p.velocity.x,
          'vy': p.velocity.y,
          'hp': p.health
        }).toList()
      };
      network.broadcast(NetMsg('state', payload).encode());
    }
  }

  // Client: apply authoritative state updates
  void applyState(Map<String, dynamic> state) {
    final remote = Map<String, dynamic>.from(state);
    final list = (remote['players'] as List<dynamic>);
    final presentIds = list.map((e) => e['id'] as String).toSet();

    // update or add players
    for (var pdat in list) {
      final id = pdat['id'] as String;
      final x = (pdat['x'] as num).toDouble();
      final y = (pdat['y'] as num).toDouble();
      final vx = (pdat['vx'] as num).toDouble();
      final vy = (pdat['vy'] as num).toDouble();
      final hp = (pdat['hp'] as num).toInt();
      if (!players.containsKey(id)) {
        addPlayer(id, id, isLocal: false);
      }
      final pc = players[id]!;
      // interpolation: simple teleport for now; you can smooth
      pc.position = Vector2(x, y);
      pc.velocity = Vector2(vx, vy);
      pc.health = hp;
    }

    // remove players not present
    final toRemove = players.keys.where((k) => !presentIds.contains(k)).toList();
    for (var k in toRemove) removePlayer(k);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isHost) hostTick(dt);
  }
}

// -------------------- NETWORK --------------------
class NetworkManager {
  // Both host & client use parts of this. Host has server & clients; client has socket
  ServerSocket? server;
  List<Socket> clients = [];
  Socket? clientSocket;
  MyGame? game;

  // Start host server
  Future<void> startHost(MyGame g) async {
    game = g;
    server = await ServerSocket.bind(InternetAddress.anyIPv4, SERVER_PORT);
    server!.listen((sock) {
      clients.add(sock);
      print('Client connected ${sock.remoteAddress.address}:${sock.remotePort}');
      // when client connects, send a welcome and current players
      sock.write(NetMsg('welcome', {'id': '${sock.remoteAddress.address}:${sock.remotePort}'}).encode());
      // also add a player for this client
      final pid = '${sock.remoteAddress.address}:${sock.remotePort}';
      game!.addPlayer(pid, pid);

      sock.listen((data) {
        final msg = NetMsg.decode(utf8.decode(data));
        _handleClientMsg(msg, sock);
      }, onDone: () {
        print('Client disconnected');
        clients.remove(sock);
        final pid = '${sock.remoteAddress.address}:${sock.remotePort}';
        game!.removePlayer(pid);
      });
    });
  }

  void _handleClientMsg(NetMsg msg, Socket sock) {
    if (game == null) return;
    if (msg.type == 'input') {
      final id = '${sock.remoteAddress.address}:${sock.remotePort}';
      final dx = (msg.data['dx'] as num).toDouble();
      final dy = (msg.data['dy'] as num).toDouble();
      final shoot = msg.data['shoot'] == true;
      final pc = game!.players[id];
      if (pc != null) {
        pc.velocity = Vector2(dx, dy);
        if (shoot) {
          final dir = Vector2(dx, dy);
          if (dir.length == 0) dir.setValues(0, -1);
          final b = BulletComponent(pos: pc.position.clone(), dir: dir, ownerId: id);
          game!.add(b);
          // broadcast bullet spawn
          broadcast(NetMsg('bullet_spawn', {'x': b.position.x, 'y': b.position.y, 'dx': dir.x, 'dy': dir.y, 'owner': id}).encode());
        }
      }
    }
  }

  // Host broadcast
  void broadcast(String s) {
    for (var c in clients) {
      try {
        c.write(s);
      } catch (e) {
        print('Broadcast send error $e');
      }
    }
  }

  // Client connect to host
  Future<bool> connectToHost(String hostIp, MyGame g) async {
    try {
      clientSocket = await Socket.connect(hostIp, SERVER_PORT, timeout: Duration(seconds: 6));
      game = g;
      clientSocket!.listen((data) {
        final msg = NetMsg.decode(utf8.decode(data));
        _handleServerMsg(msg);
      }, onDone: () {
        print('Disconnected from host');
      });
      return true;
    } catch (e) {
      print('Client connect error: $e');
      return false;
    }
  }

  void _handleServerMsg(NetMsg msg) {
    if (game == null) return;
    if (msg.type == 'state') {
      game!.applyState(msg.data);
    } else if (msg.type == 'welcome') {
      // server sent our id. Create local player with that id
      final id = msg.data['id'] as String;
      // create local player and send join (id used as unique)
      game!.addPlayer(id, id, isLocal: true);
      // also let server add player on its side will happen already
    } else if (msg.type == 'bullet_spawn') {
      final x = (msg.data['x'] as num).toDouble();
      final y = (msg.data['y'] as num).toDouble();
      final dx = (msg.data['dx'] as num).toDouble();
      final dy = (msg.data['dy'] as num).toDouble();
      final owner = msg.data['owner'] as String;
      final b = BulletComponent(pos: Vector2(x, y), dir: Vector2(dx, dy), ownerId: owner);
      game!.add(b);
    } else if (msg.type == 'player_dead') {
      final id = msg.data['id'] as String;
      game!.removePlayer(id);
    }
  }

  // Client send input
  void sendInput(double dx, double dy, {bool shoot = false}) {
    if (clientSocket == null) return;
    final msg = NetMsg('input', {'dx': dx, 'dy': dy, 'shoot': shoot});
    try {
      clientSocket!.write(msg.encode());
    } catch (e) {
      print('sendInput error $e');
    }
  }

  void stop() {
    try {
      clientSocket?.destroy();
      for (var s in clients) s.destroy();
      server?.close();
    } catch (_) {}
  }
}

// -------------------- UI / Joystick --------------------
class GameScreen extends StatefulWidget {
  final bool isHost;
  final String? hostIp;
  GameScreen({required this.isHost, this.hostIp});

  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late NetworkManager net;
  late MyGame game;
  final joystick = JoystickComponent(
    knob: CircleComponent(radius: 20, paint: Paint()..color = Colors.white),
    background: CircleComponent(radius: 50, paint: Paint()..color = Colors.white24),
    margin: const EdgeInsets.only(left: 30, bottom: 30),
  );
  String status = 'Loading...';

  @override
  void initState() {
    super.initState();
    net = NetworkManager();
    game = MyGame(isHost: widget.isHost, network: net);
    game.add(joystick);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.isHost) {
        await net.startHost(game);
        // host also creates a host-local player
        final hostId = 'HOST';
        game.addPlayer(hostId, 'Host', isLocal: true);
        setState(() => status = 'Hosting on port $SERVER_PORT');
      } else {
        final ok = await net.connectToHost(widget.hostIp ?? '', game);
        if (!ok) {
          setState(() => status = 'Failed to connect');
          return;
        }
        setState(() => status = 'Connected to ${widget.hostIp}');
        // after welcome, server will spawn players and game
      }
    });
  }

  // translate joystick to input send
  void onJoystickChange(Offset p) {
    final dx = p.dx; // -1 to 1
    final dy = p.dy; // -1 to 1
    // send to network as input; if client
    if (!widget.isHost) {
      net.sendInput(dx, dy);
    } else {
      // host directly controls its local player (HOST)
      final my = game.players['HOST'];
      if (my != null) my.velocity = Vector2(dx, dy);
    }
  }

  void onShoot() {
    if (widget.isHost) {
      final my = game.players['HOST'];
      if (my != null) {
        final dir = my.velocity.length == 0 ? Vector2(0, -1) : my.velocity.normalized();
        final b = BulletComponent(pos: my.position.clone(), dir: dir, ownerId: my.id);
        game.add(b);
        // host broadcast
        net.broadcast(NetMsg('bullet_spawn', {'x': b.position.x, 'y': b.position.y, 'dx': dir.x, 'dy': dir.y, 'owner': my.id}).encode());
      }
    } else {
      // client send shoot flag
      net.sendInput(0, 0, shoot: true);
    }
  }

  @override
  void dispose() {
    net.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isHost ? 'Host Game' : 'Client Game'), actions: [Center(child: Text(status)), SizedBox(width: 12)]),
      body: Stack(children: [
        GameWidget(game: game),
        Positioned(bottom: 20, left: 20, child: JoystickWidget(onChange: onJoystickChange)),
        Positioned(bottom: 24, right: 24, child: ElevatedButton(onPressed: onShoot, child: Icon(Icons.radio_button_checked))),
      ]),
    );
  }
}

// Simple Joystick Widget (native Flutter) to send -1..1 offsets
class JoystickWidget extends StatefulWidget {
  final void Function(Offset) onChange;
  JoystickWidget({required this.onChange});
  @override
  _JoystickWidgetState createState() => _JoystickWidgetState();
}

class _JoystickWidgetState extends State<JoystickWidget> {
  Offset knobPos = Offset.zero;
  double radius = 50;

  void _updateFromGlobal(Offset globalPos) {
    final box = context.findRenderObject() as RenderBox;
    final local = box.globalToLocal(globalPos);
    final c = Offset(radius, radius);
    var d = local - c;
    if (d.distance > radius) d = Offset.fromDirection(d.direction, radius);
    setState(() => knobPos = d);
    widget.onChange(Offset(d.dx / radius, d.dy / radius));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (e) => _updateFromGlobal(e.globalPosition),
      onPanUpdate: (e) => _updateFromGlobal(e.globalPosition),
      onPanEnd: (e) {
        setState(() => knobPos = Offset.zero);
        widget.onChange(Offset.zero);
      },
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: Stack(children: [
          Positioned(left: 0, top: 0, child: Container(width: radius * 2, height: radius * 2, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white24))),
          Positioned(left: radius + knobPos.dx - 20, top: radius + knobPos.dy - 20, child: Container(width: 40, height: 40, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white)) ),
        ]),
      ),
    );
  }
}

// -------------------- APP ENTRY / LOBBY --------------------
class LobbyScreen extends StatefulWidget {
  @override
  _LobbyScreenState createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final hostIpController = TextEditingController();
  bool isHost = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Bomb Pass - Realistic Demo')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: [
          SizedBox(height: 12),
          ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GameScreen(isHost: true))), child: Text('Start as Host (create hotspot manually)')),
          SizedBox(height: 12),
          TextField(controller: hostIpController, decoration: InputDecoration(labelText: 'Host IP (e.g. 192.168.43.1)')),
          SizedBox(height: 8),
          ElevatedButton(onPressed: () {
            final ip = hostIpController.text.trim();
            if (ip.isEmpty) return;
            Navigator.push(context, MaterialPageRoute(builder: (_) => GameScreen(isHost: false, hostIp: ip)));
          }, child: Text('Join as Client')),
          SizedBox(height: 24),
          Text('Notes: Host must create a hotspot or both devices must be on same Wi‑Fi. Client must enter host IP.'),
        ]),
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(home: LobbyScreen()));
}

// ---------------------------------------------------------------
// End of file
// ---------------------------------------------------------------
