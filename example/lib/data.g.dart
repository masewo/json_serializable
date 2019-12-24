// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Data _$DataFromJson(Map<String, dynamic> json) {
  return Data(
    id: json['glossary']['GlossDiv']['GlossList']['GlossEntry']['ID'] as String,
  );
}

Map<String, dynamic> _$DataToJson(Data instance) => <String, dynamic>{
      'glossary': {
        'GlossDiv': {
          'GlossList': {
            'GlossEntry': {
              'ID': instance.id,
            },
          },
        },
      },
    };
