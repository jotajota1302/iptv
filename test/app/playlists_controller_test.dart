import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iptv_player/src/app/playlists_controller.dart';
import 'package:iptv_player/src/domain/saved_playlist.dart';

void main() {
  test('añadir, activar, eliminar y persistir', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final n = PlaylistsNotifier(prefs);

    n.add(const SavedPlaylist(id: '1', name: 'Casa', url: 'http://a'));
    n.add(const SavedPlaylist(id: '2', name: 'Trabajo', url: 'http://b'));
    expect(n.state.playlists.length, 2);
    expect(n.state.activeId, '2'); // la última añadida queda activa
    expect(n.state.active?.name, 'Trabajo');

    n.setActive('1');
    expect(n.state.active?.url, 'http://a');

    // Persistencia: una nueva instancia recupera el estado.
    final n2 = PlaylistsNotifier(prefs);
    expect(n2.state.playlists.length, 2);
    expect(n2.state.activeId, '1');

    n2.remove('1');
    expect(n2.state.playlists.length, 1);
    expect(n2.state.activeId, '2'); // reasigna activa al eliminar la actual
  });
}
