import 'dart:io';
import 'package:flutter/foundation.dart';
import '../domain/media_item.dart';

/// El visor externo solo tiene sentido en escritorio (ventanas del SO).
bool get canOpenExternalViewer =>
    !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

/// Abre [item] en una ventana independiente lanzando este mismo ejecutable en
/// modo visor (`--play`). El proceso queda desacoplado: se puede cerrar la
/// ventana principal o abrir tantos visores como se quiera.
Future<void> openExternalViewer(MediaItem item) {
  return Process.start(
    Platform.resolvedExecutable,
    ['--play', item.streamUrl, '--name', item.name, '--type', item.type.name],
    mode: ProcessStartMode.detached,
  );
}
