enum PlayerStatus { idle, buffering, playing, paused, error }

abstract class PlayerController {
  Future<void> open(String url);
  Future<void> play();
  Future<void> pause();
  Future<void> dispose();
  Stream<PlayerStatus> get status;
}
