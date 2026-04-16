import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tvbox_flutter/nodejs/nodejs_service.dart';
import 'package:tvbox_flutter/providers/history_provider.dart';
import 'package:tvbox_flutter/providers/favorite_provider.dart';
import 'package:tvbox_flutter/models/video_detail.dart';
import 'package:tvbox_flutter/models/video_item.dart';
import 'package:tvbox_flutter/ui/player/video_player_page.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:cached_network_image/cached_network_image.dart';

class DetailPage extends StatefulWidget {
  final VideoItem video;

  const DetailPage({
    super.key,
    required this.video,
  });

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  VideoDetail? _detail;
  bool _isLoading = true;
  int _selectedEpisode = 0;

  @override
  void initState() {
    super.initState();
    _loadDetail();
    _addToHistory();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    
    try {
      final detailJson = await NodeJSService.instance.getVideoDetail(widget.video.id);
      setState(() {
        _detail = VideoDetail.fromJson(detailJson);
      });
    } catch (e) {
      print('Load detail error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addToHistory() {
    Provider.of<HistoryProvider>(context, listen: false)
        .addToHistory(widget.video);
  }

  void _toggleFavorite() {
    Provider.of<FavoriteProvider>(context, listen: false)
        .toggleFavorite(widget.video);
  }

  Future<void> _playEpisode(int index) async {
    if (_detail == null) return;
    
    setState(() => _selectedEpisode = index);
    final episode = _detail!.episodes[index];
    final source = episode.sources.first;
    
    final playUrl = await NodeJSService.instance.getPlayUrl(source.url);
    
    if (!mounted) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerPage(
          playUrl: playUrl,
          title: '${_detail!.name} 第${index + 1}集',
          videoDetail: _detail,
          initialEpisodeIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFavorite = Provider.of<FavoriteProvider>(context)
        .isFavorite(widget.video.id);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.video.name),
        actions: [
          IconButton(
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite ? Colors.red : null,
            ),
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: SpinKitFadingCircle(
                color: Colors.blue,
                size: 50.0,
              ),
            )
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_detail == null) return const SizedBox();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 封面
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: widget.video.cover,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 16),
          
          // 信息
          Text(
            _detail!.name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (_detail!.year != null)
            Text('年份: ${_detail!.year}'),
          if (_detail!.area != null)
            Text('地区: ${_detail!.area}'),
          if (_detail!.director != null)
            Text('导演: ${_detail!.director}'),
          if (_detail!.actor != null)
            Text('演员: ${_detail!.actor}'),
          if (_detail!.desc != null) ...[
            const SizedBox(height: 8),
            Text('简介: ${_detail!.desc}'),
          ],
          const SizedBox(height: 16),
          
          // 播放按钮
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _playEpisode(_selectedEpisode),
              child: const Text('立即播放'),
            ),
          ),
          const SizedBox(height: 16),
          
          // 集数选择
          const Text(
            '选集',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              childAspectRatio: 1.2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _detail!.episodes.length,
            itemBuilder: (context, index) {
              return ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: index == _selectedEpisode
                      ? Colors.blue
                      : Colors.grey[800],
                  padding: EdgeInsets.zero,
                ),
                onPressed: () => _playEpisode(index),
                child: Text('${index + 1}'),
              );
            },
          ),
        ],
      ),
    );
  }
}
