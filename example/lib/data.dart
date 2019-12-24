import 'package:json_annotation/json_annotation.dart';

part 'data.g.dart';

@JsonSerializable(path: 'glossary')
class Data {
  @JsonKey(path: 'GlossDiv/GlossList/GlossEntry', name: 'ID')
  final String id;

  Data({this.id});

  factory Data.fromJson(Map<String, dynamic> json) => _$DataFromJson(json);

  Map<String, dynamic> toJson() => _$DataToJson(this);
}
