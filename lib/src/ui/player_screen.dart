import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../domain/media_item.dart';
import '../player/media_kit_player_controller.dart';

class PlayerScreen extends StatefulWidget {
  final MediaItem item;
  const PlayerScreen({super.key, required this.item});
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final MediaKitPlayerController _ctrl = MediaKitPlayerController();
  late final VideoController _video = VideoController(_ctrl.player);

  @override
  void initState() {
    super.initState();
    _ctrl.open(widget.item.streamUrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.item.name)),
      backgroundColor: Colors.black,
      body: Center(child: Video(controller: _video)),
    );
  }
}
