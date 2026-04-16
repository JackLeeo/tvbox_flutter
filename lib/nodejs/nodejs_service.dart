import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class NodeJSService extends ChangeNotifier {
  static final NodeJSService instance = NodeJSService._internal();
  static const MethodChannel _channel = MethodChannel('com.tvbox/nodejs');

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  NodeJSService._internal();

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _isInitialized = await _channel.invokeMethod('startNodeJS');
      notifyListeners();
      print('Node.js service initialized: $_isInitialized');
    } catch (e) {
      print('Failed to initialize Node.js: $e');
      _isInitialized = false;
    }
  }

  Future<dynamic> sendRequest(String action, Map<String, dynamic> params) async {
    if (!_isInitialized) {
      throw Exception('Node.js service not initialized');
    }

    final message = jsonEncode({
      'action': action,
      'params': params,
    });

    return await _channel.invokeMethod('sendMessage', message);
  }

  // 数据源API
  Future<void> loadSource(String url) async {
    await sendRequest('loadSource', {'url': url});
  }

  Future<List<dynamic>> getHomeContent() async {
    final result = await sendRequest('getHomeContent', {});
    return result as List<dynamic>;
  }

  Future<List<dynamic>> getCategoryContent(String categoryId, int page) async {
    final result = await sendRequest('getCategoryContent', {
      'categoryId': categoryId,
      'page': page,
    });
    return result as List<dynamic>;
  }

  Future<Map<String, dynamic>> getVideoDetail(String videoId) async {
    final result = await sendRequest('getVideoDetail', {'videoId': videoId});
    return result as Map<String, dynamic>;
  }

  Future<String> getPlayUrl(String playId) async {
    final result = await sendRequest('getPlayUrl', {'playId': playId});
    return result as String;
  }

  Future<List<dynamic>> search(String keyword) async {
    final result = await sendRequest('search', {'keyword': keyword});
    return result as List<dynamic>;
  }

  // 网盘API
  Future<void> addCloudDrive(String type, Map<String, dynamic> config) async {
    await sendRequest('addCloudDrive', {
      'type': type,
      'config': config,
    });
  }

  Future<List<dynamic>> listCloudDriveFiles(String driveId, String path) async {
    final result = await sendRequest('listCloudDriveFiles', {
      'driveId': driveId,
      'path': path,
    });
    return result as List<dynamic>;
  }

  Future<String> getCloudDrivePlayUrl(String driveId, String fileId) async {
    final result = await sendRequest('getCloudDrivePlayUrl', {
      'driveId': driveId,
      'fileId': fileId,
    });
    return result as String;
  }

  // 直播API
  Future<List<dynamic>> getLiveChannels() async {
    final result = await sendRequest('getLiveChannels', {});
    return result as List<dynamic>;
  }

  Future<String> getLivePlayUrl(String channelId) async {
    final result = await sendRequest('getLivePlayUrl', {'channelId': channelId});
    return result as String;
  }
}
