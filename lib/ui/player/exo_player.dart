import 'package:flutter/material.dart';
import 'package:exoplayer/exoplayer.dart';

class ExoPlayerWidget extends StatefulWidget {
  final String url;
  final Function(bool isPlaying, double position, double duration) onPlayerStateChanged;
  final VoidCallback onTap;

  const ExoPlayerWidget({
    super.key,
    required this.url,
    required this.onPlayerStateChanged,
    required this.onTap,
  });

  @override
  State<ExoPlayerWidget> createState() => _ExoPlayerWidgetState();
}

class _ExoPlayerWidgetState extends State<ExoPlayerWidget> {
  late ExoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ExoPlayerController.network(
      widget.url,
      autoPlay: true,
    );
    
    _controller.addListener(_onPlayerStateChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onPlayerStateChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onPlayerStateChanged() {
    widget.onPlayerStateChanged(
      _controller.value.isPlaying,
      _controller.value.position.inMilliseconds.toDouble(),
      _controller.value.duration.inMilliseconds.toDouble(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: ExoPlayer(controller: _controller),
    );
  }
}