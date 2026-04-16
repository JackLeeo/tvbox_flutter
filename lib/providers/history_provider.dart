import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tvbox_flutter/models/video_item.dart';
import 'package:tvbox_flutter/constants/app_constants.dart';
import 'dart:convert';

class HistoryProvider extends ChangeNotifier {
  List<VideoItem> _history = [];

  List<VideoItem> get history => _history;

  HistoryProvider() {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList(AppConstants.keyHistory) ?? [];
    
    _history = historyJson
        .map((json) => VideoItem.fromJson(jsonDecode(json)))
        .toList();
    
    notifyListeners();
  }

  Future<void> addToHistory(VideoItem video) async {
    _history.removeWhere((v) => v.id == video.id);
    _history.insert(0, video);
    
    // 只保留最近100条记录
    if (_history.length > 100) {
      _history = _history.sublist(0, 100);
    }
    
    await _saveHistory();
    notifyListeners();
  }

  Future<void> removeFromHistory(String id) async {
    _history.removeWhere((v) => v.id == id);
    await _saveHistory();
    notifyListeners();
  }

  Future<void> clearHistory() async {
    _history.clear();
    await _saveHistory();
    notifyListeners();
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = _history.map((v) => jsonEncode(v.toJson())).toList();
    await prefs.setStringList(AppConstants.keyHistory, historyJson);
  }
}
