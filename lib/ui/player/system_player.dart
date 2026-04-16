import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class SystemPlayerWidget extends StatefulWidget {
  final String url;
  final Function(bool isPlaying, double position, double duration) onPlayerStateChanged;
  final VoidCallback onTap;

  const SystemPlayerWidget({
    super.key,
    required this.url,
    required this.onPlayerStateChanged,
    required this.onTap,
  });

  @override
  State<SystemPlayerWidget> createState() => _SystemPlayerWidgetState();
}

class _SystemPlayerWidgetState extends State<SystemPlayerWidget> {
  late VideoPlayerController _videoController;
  late ChewieController _chewieController;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.network(widget.url);
    _chewieController = ChewieController(
      videoPlayerController: _videoController,
      autoPlay: true,
      showControls: false,
    );
    
    _videoController.addListener(_onPlayerStateChanged);
  }

  @override
  void dispose() {
    _videoController.removeListener(_onPlayerStateChanged);
    _videoController.dispose();
    _chewieController.dispose();
    super.dispose();
  }

  void _onPlayerStateChanged() {
    widget.onPlayerStateChanged(
      _videoController.value.isPlaying,
      _videoController.value.position.inMilliseconds.toDouble(),
      _videoController.value.duration.inMilliseconds.toDouble(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Chewie(controller: _chewieController),
    );
  }
}