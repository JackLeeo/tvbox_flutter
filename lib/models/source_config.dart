import 'package:json_annotation/json_annotation.dart';

part 'source_config.g.dart';

@JsonSerializable()
class SourceConfig {
  final String id;
  final String name;
  final String url;
  final bool isEnabled;

  SourceConfig({
    required this.id,
    required this.name,
    required this.url,
    this.isEnabled = true,
  });

  SourceConfig copyWith({
    String? id,
    String? name,
    String? url,
    bool? isEnabled,
  }) {
    return SourceConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  factory SourceConfig.fromJson(Map<String, dynamic> json) =>
      _$SourceConfigFromJson(json);

  Map<String, dynamic> toJson() => _$SourceConfigToJson(this);
}