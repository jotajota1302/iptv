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
  });

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
      );
}
