// Copyright (c) 2018, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/element/element.dart';
import 'package:json_annotation/json_annotation.dart';

import 'constants.dart';
import 'helper_core.dart';
import 'type_helpers/json_converter_helper.dart';
import 'unsupported_type_error.dart';

abstract class EncodeHelper implements HelperCore {
  String _fieldAccess(FieldElement field) => '$_toJsonParamName.${field.name}';

  Iterable<String> createToJson(Set<FieldElement> accessibleFields) sync* {
    assert(config.createToJson);

    final buffer = StringBuffer();

    final functionName = '${prefix}ToJson${genericClassArgumentsImpl(true)}';
    buffer.write('Map<String, dynamic> '
        '$functionName($targetClassReference $_toJsonParamName) ');

    final writeNaive = accessibleFields.every(_writeJsonValueNaive);

    final root = _FieldNode('');
    for (final field in accessibleFields) {
      final path = _buildPath(field);
      if (path == null || path.isEmpty) {
        root.addField(field);
      } else {
        var parent = root;
        for (final pathElement in path) {
          parent = parent.getOrAddChild(pathElement);
        }
        parent.addField(field);
      }
    }
    ;

    if (writeNaive) {
      // write simple `toJson` method that includes all keys...
      _writeToJsonSimple(buffer, root);
    } else {
      // At least one field should be excluded if null
      _writeToJsonWithNullChecks(buffer, root);
    }

    yield buffer.toString();
  }

  void _writeToJsonSimple(
      StringBuffer buffer,
      _FieldNode root,
      Iterable<FieldElement> fields) {
    buffer.writeln('=> <String, dynamic>{');

    _writeFieldNaive(buffer, root);

    buffer.writeln('};');
  }

  void _writeFieldNaive(StringBuffer buffer, _FieldNode root) {
    final writePath = root.path != null && root.path.isNotEmpty;
    if (writePath) buffer.writeln("'${root.path}':{");

    root.fields.forEach((field) {
      final access = _fieldAccess(field);

      buffer.writeln('${safeNameAccess(field)}: ${_serializeField(field, access)},');
    });
    if (root.childPaths.isNotEmpty) {
      root.childPaths.forEach((child) {
        _writeFieldNaive(buffer, child);
      });
    }

    if (writePath) buffer.writeln('}');
  }

  String _generateAccessorPath(List<String> path, FieldElement field, {String access, String expression}) {
    final pathBuffer = StringBuffer();
    for (final pathEntry in path) {
      pathBuffer.writeln("'$pathEntry': {");
    }
    pathBuffer.writeln('${safeNameAccess(field)}: ${expression ?? _serializeField(field, access)},');
    for (final pathEntry in path) {
      pathBuffer.writeln('}');
    }
    return pathBuffer.toString();
  }

  static const _toJsonParamName = 'instance';

  void _writeToJsonWithNullChecks(
      StringBuffer buffer,
      _FieldNode root,
      Iterable<FieldElement> fields) {
    buffer.writeln('{');

    buffer.writeln('    final $generatedLocalVarName = <String, dynamic>{');

    // Note that the map literal is left open above. As long as target fields
    // don't need to be intercepted by the `only if null` logic, write them
    // to the map literal directly. In theory, should allow more efficient
    // serialization.
    var directWrite = true;

    // First write out the top level fields.
    for (final field in root.fields) {
      var safeFieldAccess = _fieldAccess(field);
      final safeJsonKeyString = safeNameAccess(field);

      // If `fieldName` collides with one of the local helpers, prefix
      // access with `this.`.
      if (safeFieldAccess == generatedLocalVarName || safeFieldAccess == toJsonMapHelperName) {
        safeFieldAccess = 'this.$safeFieldAccess';
      }

      final expression = _serializeField(field, safeFieldAccess);
      if (_writeJsonValueNaive(field)) {
        if (directWrite) {
          buffer.writeln('      $safeJsonKeyString: $expression,');
        } else {
          buffer.writeln('    $generatedLocalVarName[$safeJsonKeyString] = $expression;');
        }
      } else {
        if (directWrite) {
          // close the still-open map literal
          buffer
            ..writeln('    };')
            ..writeln()

            directWrite = false;
          // write the helper to be used by all following null-excluding
          // fields
          ..writeln('''
    void $toJsonMapHelperName(String key, dynamic value) {
      if (value != null) {
        $generatedLocalVarName[key] = value;
      }
    }
''');
        }
        buffer.writeln('    $toJsonMapHelperName($safeJsonKeyString, $expression);');
      }
    }
    if (directWrite) {
      buffer.writeln('    };');
    }

    // We have children in path, they need to be 'safe'
    for (final child in root.childPaths) {
      _writeSafe(buffer, generatedLocalVarName, child, []);
    }

    buffer..writeln('    return $generatedLocalVarName;')..writeln('  }');
  }

  String _serializeField(FieldElement field, String accessExpression) {
    try {
      return getHelperContext(field).serialize(field.type, accessExpression).toString();
    } on UnsupportedTypeError catch (e) // ignore: avoid_catching_errors
    {
      throw createInvalidGenerationError('toJson', field, e);
    }
  }

  void _writeSafe(StringBuffer buffer, String mapName, _FieldNode root, List<String> currentPath) {
    if (root.fields.isNotEmpty) {
      for (final field in root.fields) {
        var safeFieldAccess = _fieldAccess(field);
        if (safeFieldAccess == generatedLocalVarName || safeFieldAccess == toJsonMapHelperName) {
          safeFieldAccess = 'this.$safeFieldAccess';
        }
        final nullCheck = !_writeJsonValueNaive(field);
        var accessor = _serializeField(field, safeFieldAccess);
        if (nullCheck) {
          buffer
            ..writeln('{')
            ..writeln('// ignore: non_constant_identifier_names')
            ..writeln('final __jsonNullCheck__ = $accessor;')
            ..writeln('if (__jsonNullCheck__ != null) {');
          accessor = '__jsonNullCheck__';
        }

        buffer.write('$mapName');
        for (final path in currentPath) {
          buffer.writeln(".putIfAbsent('$path', () => <String,dynamic>{})");
        }
        buffer.writeln(".putIfAbsent('${root.path}', () => <String,dynamic>{})");
        buffer.writeln('[${safeNameAccess(field)}] = $accessor;');

        if (nullCheck) {
          buffer..writeln('}')..writeln('}');
        }
      }
    }
    for (final child in root.childPaths) {
      _writeSafe(buffer, mapName, child, [...currentPath, root.path]);
    }
  }

  /// Returns `true` if the field can be written to JSON 'naively' – meaning
  /// we can avoid checking for `null`.
  bool _writeJsonValueNaive(FieldElement field) {
    final jsonKey = jsonKeyFor(field);
    return jsonKey.includeIfNull ||
        (!jsonKey.nullable && !_fieldHasCustomEncoder(field));
  }

  /// Returns `true` if [field] has a user-defined encoder.
  ///
  /// This can be either a `toJson` function in [JsonKey] or a [JsonConverter]
  /// annotation.
  bool _fieldHasCustomEncoder(FieldElement field) {
    final helperContext = getHelperContext(field);
    return helperContext.serializeConvertData != null ||
        const JsonConverterHelper()
                .serialize(field.type, 'test', helperContext) !=
            null;
  }

  List<String> _buildPath(FieldElement field) {
    final jsonKeyPath = jsonKeyFor(field).path;
    final configPath = config.path;

    if (configPath == null && jsonKeyPath == null) return null;
    final parts = List<String>();
    if (configPath != null && configPath.isNotEmpty) {
      parts.addAll(configPath.split('/'));
    }
    if (jsonKeyPath != null && jsonKeyPath.isNotEmpty) {
      parts.addAll(jsonKeyPath.split('/'));
    }
    return parts;
  }
}

/// Helper class for creating tree of nodes that belong together (by path)
class _FieldNode {
  final String path;
  final List<FieldElement> fields = [];
  final List<_FieldNode> childPaths = [];

  _FieldNode(this.path);

  _FieldNode getOrAddChild(String path) {
    return childPaths.singleWhere((item) => item.path == path, orElse: () {
      final child = _FieldNode(path);
      childPaths.add(child);
      return child;
    });
  }

  void addField(FieldElement element) {
    fields.add(element);
  }

  Iterable<FieldElement> enumerateFields() {
    final fieldItems = [...fields];
    for (final child in childPaths) {
      fieldItems.addAll(child.enumerateFields());
    }
    return fieldItems;
  }
}
