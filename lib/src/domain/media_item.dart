import 'content_type.dart';

class MediaItem {
  final String id;
  final String name;
  final String streamUrl;
  final String? logoUrl;
  final String? tvgId;
  final String? groupTitle;
  final ContentType type;
  final bool isFavorite;
  final bool isHidden;
  final bool isDeleted;

  /// Segundos de reproducción guardados para reanudar (VOD). 0 = desde el inicio.
  final int positionSeconds;

  /// Duración total en segundos (VOD), si se conoce. 0 = desconocida.
  final int durationSeconds;

  /// Marca de tiempo (epoch ms) en que se añadió a la caché (para "novedades").
  final int addedAt;

  const MediaItem({
    required this.id,
    required this.name,
    required this.streamUrl,
    this.logoUrl,
    this.tvgId,
    this.groupTitle,
    this.type = ContentType.unknown,
    this.isFavorite = false,
    this.isHidden = false,
    this.isDeleted = false,
    this.positionSeconds = 0,
    this.durationSeconds = 0,
    this.addedAt = 0,
  });

  /// Año de estreno tomado del título del proveedor ("Película (2023)").
  /// 0 = desconocido (el título no trae año entre paréntesis).
  int get releaseYear {
    final m = RegExp(r'\(((?:19|20)\d{2})\)').firstMatch(name);
    return m == null ? 0 : int.parse(m.group(1)!);
  }

  /// Fracción vista (0..1) si se conoce la duración; si no, 0.
  double get watchedFraction =>
      durationSeconds > 0 ? (positionSeconds / durationSeconds).clamp(0, 1) : 0;

  MediaItem copyWith(
          {bool? isFavorite,
          bool? isHidden,
          bool? isDeleted,
          int? positionSeconds,
          int? durationSeconds}) =>
      MediaItem(
        id: id,
        name: name,
        streamUrl: streamUrl,
        logoUrl: logoUrl,
        tvgId: tvgId,
        groupTitle: groupTitle,
        type: type,
        isFavorite: isFavorite ?? this.isFavorite,
        isHidden: isHidden ?? this.isHidden,
        isDeleted: isDeleted ?? this.isDeleted,
        positionSeconds: positionSeconds ?? this.positionSeconds,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        addedAt: addedAt,
      );
}
