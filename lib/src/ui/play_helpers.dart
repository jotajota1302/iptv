import 'package:flutter/material.dart';
import '../domain/content_type.dart';
import '../domain/media_item.dart';
import 'player_screen.dart';

/// Abre el reproductor para cualquier item. El VOD (película/serie) reanuda
/// desde la posición guardada; la TV en directo empieza siempre desde el vivo.
/// Devuelve un Future que se completa al cerrar el reproductor (para refrescar).
Future<void> openPlayer(BuildContext context, MediaItem item) {
  final resume =
      item.type == ContentType.movie || item.type == ContentType.series;
  return Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => PlayerScreen(item: item, resume: resume),
  ));
}
