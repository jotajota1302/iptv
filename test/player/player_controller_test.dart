import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/src/player/player_controller.dart';

class FakePlayerController implements PlayerController {
  final _ctrl = StreamController<PlayerStatus>.broadcast();
  String? opened;

  @override
  Stream<PlayerStatus> get status => _ctrl.stream;

  @override
  Future<void> open(String url) async {
    opened = url;
    _ctrl.add(PlayerStatus.buffering);
    _ctrl.add(PlayerStatus.playing);
  }

  @override
  Future<void> play() async => _ctrl.add(PlayerStatus.playing);

  @override
  Future<void> pause() async => _ctrl.add(PlayerStatus.paused);

  @override
  Future<void> dispose() async => _ctrl.close();
}

void main() {
  test('open emite buffering y luego playing', () async {
    final p = FakePlayerController();
    final events = <PlayerStatus>[];
    p.status.listen(events.add);
    await p.open('http://x/1.ts');
    await Future<void>.delayed(Duration.zero);
    expect(p.opened, 'http://x/1.ts');
    expect(events, [PlayerStatus.buffering, PlayerStatus.playing]);
  });
}
