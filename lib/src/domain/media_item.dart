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
  });

  MediaItem copyWith({bool? isFavorite, bool? isHidden, bool? isDeleted}) =>
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
      );
}
