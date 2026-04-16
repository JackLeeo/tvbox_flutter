class AppConstants {
  static const String appName = 'TVBox';
  static const String appVersion = '1.4.0';
  
  // 存储键
  static const String keySources = 'sources';
  static const String keyCurrentSource = 'current_source';
  static const String keyHistory = 'history';
  static const String keyFavorites = 'favorites';
  static const String keyCloudDrives = 'cloud_drives';
  static const String keyDefaultPlayer = 'default_player';
  static const String keyHardwareAcceleration = 'hardware_acceleration';
  static const String keyPlaybackSpeed = 'playback_speed';
  
  // 超时设置
  static const int networkTimeout = 30000; // 30秒
  static const int spiderTimeout = 10000; // 10秒
  
  // 分页设置
  static const int pageSize = 20;
}