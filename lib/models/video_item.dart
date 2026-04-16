import 'package:json_annotation/json_annotation.dart';

part 'video_item.g.dart';

@JsonSerializable()
class VideoItem {
  final String id;
  final String name;
  final String cover;
  final String? desc;
  final String? year;
  final String? area;
  final String? director;
  final String? actor;
  final String? remark;

  VideoItem({
    required this.id,
    required this.name,
    required this.cover,
    this.desc,
    this.year,
    this.area,
    this.director,
    this.actor,
    this.remark,
  });

  factory VideoItem.fromJson(Map<String, dynamic> json) =>
      _$VideoItemFromJson(json);

  Map<String, dynamic> toJson() => _$VideoItemToJson(this);
}