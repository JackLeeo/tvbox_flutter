import 'package:json_annotation/json_annotation.dart';

part 'video_detail.g.dart';

@JsonSerializable()
class VideoDetail {
  final String id;
  final String name;
  final String cover;
  final String? desc;
  final String? year;
  final String? area;
  final String? director;
  final String? actor;
  final List<Episode> episodes;

  VideoDetail({
    required this.id,
    required this.name,
    required this.cover,
    this.desc,
    this.year,
    this.area,
    this.director,
    this.actor,
    required this.episodes,
  });

  factory VideoDetail.fromJson(Map<String, dynamic> json) =>
      _$VideoDetailFromJson(json);

  Map<String, dynamic> toJson() => _$VideoDetailToJson(this);
}

@JsonSerializable()
class Episode {
  final String name;
  final List<Source> sources;

  Episode({
    required this.name,
    required this.sources,
  });

  factory Episode.fromJson(Map<String, dynamic> json) =>
      _$EpisodeFromJson(json);

  Map<String, dynamic> toJson() => _$EpisodeToJson(this);
}

@JsonSerializable()
class Source {
  final String name;
  final String url;

  Source({
    required this.name,
    required this.url,
  });

  factory Source.fromJson(Map<String, dynamic> json) =>
      _$SourceFromJson(json);

  Map<String, dynamic> toJson() => _$SourceToJson(this);
}