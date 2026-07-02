import '../domain/content_type.dart';
import '../domain/media_item.dart';

/// Argumentos del modo visor: la app lanzada con `--play <url>` arranca como
/// una ventana de reproducción independiente (sin navegación ni base de
/// datos), lo que permite ver N canales a la vez en ventanas del sistema.
class ViewerArgs {
  final String url;
  final String name;
  final ContentType type;
  const ViewerArgs({required this.url, required this.name, required this.type});

  /// Item sintético equivalente para el reproductor.
  MediaItem toItem() =>
      MediaItem(id: 'viewer:$url', name: name, streamUrl: url, type: type);
}

String? _value(List<String> args, String flag) {
  final i = args.indexOf(flag);
  return (i >= 0 && i + 1 < args.length) ? args[i + 1] : null;
}

/// Parsea los argumentos de línea de comandos. Null si no es modo visor.
ViewerArgs? parseViewerArgs(List<String> args) {
  final url = _value(args, '--play');
  if (url == null || url.isEmpty) return null;
  final typeName = _value(args, '--type');
  return ViewerArgs(
    url: url,
    name: _value(args, '--name') ?? 'IPTV Player',
    type: ContentType.values.firstWhere(
      (t) => t.name == typeName,
      orElse: () => ContentType.live,
    ),
  );
}
