import 'content_type.dart';

class Category {
  final String name;
  final ContentType type;
  final int itemCount;
  const Category({required this.name, required this.type, this.itemCount = 0});
}
