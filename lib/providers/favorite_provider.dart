import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tvbox_flutter/models/video_item.dart';
import 'package:tvbox_flutter/constants/app_constants.dart';

class FavoriteProvider extends ChangeNotifier {
  List<VideoItem> _favorites = [];

  List<VideoItem> get favorites => _favorites;

  FavoriteProvider() {
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesJson = prefs.getStringList(AppConstants.keyFavorites) ?? [];
    
    _favorites = favoritesJson
        .map((json) => VideoItem.fromJson(jsonDecode(json)))
        .toList();
    
    notifyListeners();
  }

  Future<void> addToFavorites(VideoItem video) async {
    if (!isFavorite(video.id)) {
      _favorites.add(video);
      await _saveFavorites();
      notifyListeners();
    }
  }

  Future<void> removeFromFavorites(String id) async {
    _favorites.removeWhere((v) => v.id == id);
    await _saveFavorites();
    notifyListeners();
  }

  bool isFavorite(String id) {
    return _favorites.any((v) => v.id == id);
  }

  Future<void> toggleFavorite(VideoItem video) async {
    if (isFavorite(video.id)) {
      await removeFromFavorites(video.id);
    } else {
      await addToFavorites(video);
    }
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesJson = _favorites.map((v) => jsonEncode(v.toJson())).toList();
    await prefs.setStringList(AppConstants.keyFavorites, favoritesJson);
  }
}