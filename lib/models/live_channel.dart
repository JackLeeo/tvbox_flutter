import 'package:json_annotation/json_annotation.dart';

part 'live_channel.g.dart';

@JsonSerializable()
class LiveChannel {
  final String id;
  final String name;
  final String url;
  final String? logo;
  final String? group;

  LiveChannel({
    required this.id,
    required this.name,
    required this.url,
    this.logo,
    this.group,
  });

  factory LiveChannel.fromJson(Map<String, dynamic> json) =>
      _$LiveChannelFromJson(json);

  Map<String, dynamic> toJson() => _$LiveChannelToJson(this);
}