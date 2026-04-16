import 'package:json_annotation/json_annotation.dart';

part 'cloud_drive.g.dart';

@JsonSerializable()
class CloudDrive {
  final String id;
  final String name;
  final String type;
  final Map<String, dynamic> config;

  CloudDrive({
    required this.id,
    required this.name,
    required this.type,
    required this.config,
  });

  factory CloudDrive.fromJson(Map<String, dynamic> json) =>
      _$CloudDriveFromJson(json);

  Map<String, dynamic> toJson() => _$CloudDriveToJson(this);
}

@JsonSerializable()
class DriveFile {
  final String id;
  final String name;
  final String type; // 'folder' or 'file'
  final int? size;
  final String? updatedAt;

  DriveFile({
    required this.id,
    required this.name,
    required this.type,
    this.size,
    this.updatedAt,
  });

  factory DriveFile.fromJson(Map<String, dynamic> json) =>
      _$DriveFileFromJson(json);

  Map<String, dynamic> toJson() => _$DriveFileToJson(this);
}