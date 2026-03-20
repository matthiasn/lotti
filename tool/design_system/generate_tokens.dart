import 'dart:convert';
import 'dart:io';

const _inputPath = 'assets/design_system/tokens.json';
const _outputPath =
    'lib/features/design_system/theme/generated/design_tokens.g.dart';

void main() {
  final inputFile = File(_inputPath);
  if (!inputFile.existsSync()) {
    stderr.writeln('Token source not found: $_inputPath');
    exitCode = 1;
    return;
  }

  final jsonMap =
      jsonDecode(inputFile.readAsStringSync()) as Map<String, dynamic>;
  final generator = _DesignTokenGenerator(jsonMap);
  final outputFile = File(_outputPath)
    ..createSync(recursive: true)
    ..writeAsStringSync(generator.generate());

  stdout.writeln('Generated ${outputFile.path}');
}

enum _LeafKind {
  color,
  doubleValue,
  stringValue,
  fontWeight,
  textStyle,
}

final class _Node {
  const _Node.group({
    required this.fieldName,
    required this.className,
    required this.children,
    this.isThemeExtension = false,
  }) : kind = null,
       lightLiteral = null,
       darkLiteral = null;

  const _Node.leaf({
    required this.fieldName,
    required this.kind,
    required this.lightLiteral,
    required this.darkLiteral,
  }) : className = null,
       children = const [],
       isThemeExtension = false;

  final String fieldName;
  final String? className;
  final List<_Node> children;
  final _LeafKind? kind;
  final String? lightLiteral;
  final String? darkLiteral;
  final bool isThemeExtension;

  bool get isLeaf => kind != null;
}

final class _ColorSpec {
  const _ColorSpec(this.argb);

  final int argb;
}

final class _TextStyleSpec {
  const _TextStyleSpec({
    required this.fontFamily,
    required this.fontWeightLiteral,
    required this.fontSize,
    required this.lineHeight,
    required this.letterSpacing,
  });

  final String fontFamily;
  final String fontWeightLiteral;
  final double fontSize;
  final double lineHeight;
  final double letterSpacing;
}

final class _DesignTokenGenerator {
  _DesignTokenGenerator(this._json);

  final Map<String, dynamic> _json;

  late final Map<String, dynamic> _colorJson =
      _json['color'] as Map<String, dynamic>;
  late final Map<String, dynamic> _typographyJson =
      _json['typography'] as Map<String, dynamic>;
  late final Map<String, dynamic> _spacingJson =
      _json['spacing'] as Map<String, dynamic>;
  late final Map<String, dynamic> _borderRadiusJson =
      _json['borderRadius'] as Map<String, dynamic>;

  String generate() {
    final root = _buildRootNode();
    final classes = <String>[];
    _emitClass(root, classes);

    final buffer = StringBuffer()
      ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND')
      ..writeln()
      ..writeln("import 'dart:ui' show lerpDouble;")
      ..writeln()
      ..writeln("import 'package:flutter/material.dart';")
      ..writeln()
      ..writeln(_emitRootConstants(root))
      ..writeln();

    for (final classDefinition in classes) {
      buffer
        ..writeln(classDefinition)
        ..writeln();
    }

    return buffer.toString();
  }

  _Node _buildRootNode() {
    return _Node.group(
      fieldName: 'tokens',
      className: 'DsTokens',
      isThemeExtension: true,
      children: [
        _buildColorsNode(),
        _buildTypographyNode(),
        _buildSpacingNode(),
        _buildRadiiNode(),
      ],
    );
  }

  _Node _buildColorsNode() {
    final categories = <_Node>[
      _buildColorGroupNode(
        fieldName: 'text',
        className: 'DsColorsText',
        jsonMap: _colorJson['text'] as Map<String, dynamic>,
        path: const ['color', 'text'],
      ),
      _buildColorGroupNode(
        fieldName: 'surface',
        className: 'DsColorsSurface',
        jsonMap: _colorJson['surface'] as Map<String, dynamic>,
        path: const ['color', 'surface'],
      ),
      _buildColorGroupNode(
        fieldName: 'alert',
        className: 'DsColorsAlert',
        jsonMap: _colorJson['alert'] as Map<String, dynamic>,
        path: const ['color', 'alert'],
      ),
      _buildColorGroupNode(
        fieldName: 'background',
        className: 'DsColorsBackground',
        jsonMap: _colorJson['background'] as Map<String, dynamic>,
        path: const ['color', 'background'],
      ),
      _buildColorGroupNode(
        fieldName: 'interactive',
        className: 'DsColorsInteractive',
        jsonMap: _colorJson['interactive'] as Map<String, dynamic>,
        path: const ['color', 'interactive'],
      ),
      _buildColorGroupNode(
        fieldName: 'decorative',
        className: 'DsColorsDecorative',
        jsonMap: _colorJson['decorative'] as Map<String, dynamic>,
        path: const ['color', 'decorative'],
      ),
    ];

    return _Node.group(
      fieldName: 'colors',
      className: 'DsColors',
      children: categories,
    );
  }

  _Node _buildTypographyNode() {
    final stylesJson = _typographyJson['styles'] as Map<String, dynamic>;
    final stylesByGroup = <String, Map<String, _TextStyleSpec>>{};

    for (final entry in stylesJson.entries) {
      final parts = entry.key.split('/');
      final groupName = _normalizeSimpleName(parts.first);
      final styleName = _normalizeTypographyStyleName(parts.last);
      final styleMap = entry.value as Map<String, dynamic>;
      stylesByGroup.putIfAbsent(
        groupName,
        () => <String, _TextStyleSpec>{},
      )[styleName] = _parseTextStyle(
        parts.first,
        styleMap,
      );
    }

    final styleGroupNodes = stylesByGroup.entries
        .map(
          (entry) => _Node.group(
            fieldName: entry.key,
            className: 'DsTypographyStyles${_pascalCase(entry.key)}',
            children: entry.value.entries
                .map(
                  (styleEntry) => _Node.leaf(
                    fieldName: styleEntry.key,
                    kind: _LeafKind.textStyle,
                    lightLiteral: _emitTextStyle(styleEntry.value),
                    darkLiteral: _emitTextStyle(styleEntry.value),
                  ),
                )
                .toList(),
          ),
        )
        .toList();

    final variables = _typographyJson['variables'] as Map<String, dynamic>;
    final families = variables['family'] as Map<String, dynamic>;
    final weights = variables['weight'] as Map<String, dynamic>;
    final sizes = variables['size'] as Map<String, dynamic>;
    final lineHeights = variables['lineHeight'] as Map<String, dynamic>;
    final letterSpacing = variables['letterSpacing'] as Map<String, dynamic>;

    return _Node.group(
      fieldName: 'typography',
      className: 'DsTypography',
      children: [
        _Node.group(
          fieldName: 'styles',
          className: 'DsTypographyStyles',
          children: styleGroupNodes,
        ),
        _Node.group(
          fieldName: 'family',
          className: 'DsTypographyFamily',
          children: families.entries
              .map(
                (entry) => _Node.leaf(
                  fieldName: _normalizeSimpleName(entry.key),
                  kind: _LeafKind.stringValue,
                  lightLiteral: _emitString(entry.value as String),
                  darkLiteral: _emitString(entry.value as String),
                ),
              )
              .toList(),
        ),
        _Node.group(
          fieldName: 'weight',
          className: 'DsTypographyWeight',
          children: weights.entries
              .map(
                (entry) => _Node.leaf(
                  fieldName: _normalizeSimpleName(entry.key),
                  kind: _LeafKind.fontWeight,
                  lightLiteral: _fontWeightLiteral(entry.value as String),
                  darkLiteral: _fontWeightLiteral(entry.value as String),
                ),
              )
              .toList(),
        ),
        _buildDoubleGroupNode(
          fieldName: 'size',
          className: 'DsTypographySize',
          values: sizes,
        ),
        _buildDoubleGroupNode(
          fieldName: 'lineHeight',
          className: 'DsTypographyLineHeight',
          values: lineHeights,
        ),
        _buildDoubleGroupNode(
          fieldName: 'letterSpacing',
          className: 'DsTypographyLetterSpacing',
          values: letterSpacing,
        ),
      ],
    );
  }

  _Node _buildSpacingNode() {
    final steps = _spacingJson['steps'] as Map<String, dynamic>;
    final commonUsages = _spacingJson['commonUsages'] as Map<String, dynamic>;

    final children = <_Node>[
      for (final entry in steps.entries)
        _Node.leaf(
          fieldName: 'step${entry.key}',
          kind: _LeafKind.doubleValue,
          lightLiteral: _emitDouble(
            ((entry.value as Map<String, dynamic>)['value']) as Object,
          ),
          darkLiteral: _emitDouble(
            ((entry.value as Map<String, dynamic>)['value']) as Object,
          ),
        ),
      for (final entry in commonUsages.entries)
        _Node.leaf(
          fieldName: _normalizeSimpleName(entry.key),
          kind: _LeafKind.doubleValue,
          lightLiteral: _emitDouble(
            ((entry.value as Map<String, dynamic>)['value']) as Object,
          ),
          darkLiteral: _emitDouble(
            ((entry.value as Map<String, dynamic>)['value']) as Object,
          ),
        ),
    ];

    return _Node.group(
      fieldName: 'spacing',
      className: 'DsSpacing',
      children: children,
    );
  }

  _Node _buildRadiiNode() {
    final tokens = _borderRadiusJson['tokens'] as Map<String, dynamic>;
    final commonUsages =
        _borderRadiusJson['commonUsages'] as Map<String, dynamic>;

    final children = <_Node>[
      for (final entry in tokens.entries)
        _Node.leaf(
          fieldName: _normalizeSimpleName(entry.key),
          kind: _LeafKind.doubleValue,
          lightLiteral: _emitDouble(
            ((entry.value as Map<String, dynamic>)['value']) as Object,
          ),
          darkLiteral: _emitDouble(
            ((entry.value as Map<String, dynamic>)['value']) as Object,
          ),
        ),
      for (final entry in commonUsages.entries)
        _Node.leaf(
          fieldName: _normalizeSimpleName(entry.key),
          kind: _LeafKind.doubleValue,
          lightLiteral: _emitDouble(
            ((entry.value as Map<String, dynamic>)['value']) as Object,
          ),
          darkLiteral: _emitDouble(
            ((entry.value as Map<String, dynamic>)['value']) as Object,
          ),
        ),
    ];

    return _Node.group(
      fieldName: 'radii',
      className: 'DsRadii',
      children: children,
    );
  }

  _Node _buildDoubleGroupNode({
    required String fieldName,
    required String className,
    required Map<String, dynamic> values,
  }) {
    return _Node.group(
      fieldName: fieldName,
      className: className,
      children: values.entries
          .map(
            (entry) => _Node.leaf(
              fieldName: _normalizeSimpleName(entry.key),
              kind: _LeafKind.doubleValue,
              lightLiteral: _emitDouble(entry.value as Object),
              darkLiteral: _emitDouble(entry.value as Object),
            ),
          )
          .toList(),
    );
  }

  _Node _buildColorGroupNode({
    required String fieldName,
    required String className,
    required Map<String, dynamic> jsonMap,
    required List<String> path,
  }) {
    final children = jsonMap.entries
        .where((entry) => entry.key != 'collectionId' && entry.key != 'modes')
        .map(
          (entry) => _buildColorNodeEntry(
            fieldName: _normalizeColorFieldName(entry.key, path: path),
            className:
                '$className${_pascalCase(_normalizeColorFieldName(entry.key, path: path))}',
            jsonValue: entry.value,
            path: [...path, entry.key],
          ),
        )
        .toList();

    return _Node.group(
      fieldName: fieldName,
      className: className,
      children: children,
    );
  }

  _Node _buildColorNodeEntry({
    required String fieldName,
    required String className,
    required dynamic jsonValue,
    required List<String> path,
  }) {
    final value = jsonValue as Map<String, dynamic>;
    if (_isColorLeaf(value)) {
      final lightSpec = _parseColorValue(
        value['light'] as String,
        isDark: false,
      );
      final darkSpec = _parseColorValue(value['dark'] as String, isDark: true);

      return _Node.leaf(
        fieldName: fieldName == 'default' ? 'defaultColor' : fieldName,
        kind: _LeafKind.color,
        lightLiteral: _emitColor(lightSpec),
        darkLiteral: _emitColor(darkSpec),
      );
    }

    final children = value.entries
        .map(
          (entry) => _buildColorNodeEntry(
            fieldName: _normalizeColorFieldName(entry.key, path: path),
            className:
                '$className${_pascalCase(_normalizeColorFieldName(entry.key, path: path))}',
            jsonValue: entry.value,
            path: [...path, entry.key],
          ),
        )
        .toList();

    return _Node.group(
      fieldName: fieldName,
      className: className,
      children: children,
    );
  }

  bool _isColorLeaf(Map<String, dynamic> map) {
    return map.containsKey('light') && map.containsKey('dark');
  }

  _ColorSpec _parseColorValue(String rawValue, {required bool isDark}) {
    final match = RegExp(
      r'^(.+?)(?:\s*@\s*(\d+)%){0,1}$',
    ).firstMatch(rawValue.trim());
    if (match == null) {
      throw FormatException('Unsupported color token: $rawValue');
    }

    final baseName = match.group(1)!.trim();
    final opacityPercent = match.group(2) == null
        ? 100
        : int.parse(match.group(2)!);
    final resolvedHex = _resolveColorName(baseName, isDark: isDark);
    final hex = resolvedHex.replaceFirst('#', '');
    if (hex.length != 6) {
      throw FormatException('Unsupported hex color: $resolvedHex');
    }

    final rgb = int.parse(hex, radix: 16);
    final alpha = ((opacityPercent / 100) * 255).round().clamp(0, 255);
    final argb = (alpha << 24) | rgb;
    return _ColorSpec(argb);
  }

  String _resolveColorName(String value, {required bool isDark}) {
    if (value.startsWith('#')) {
      return value;
    }

    final interactiveEnabled =
        _colorJson['interactive'] as Map<String, dynamic>;
    final interactiveBase =
        interactiveEnabled['enabled'] as Map<String, dynamic>;
    final aliases = <String, String>{
      'teal': interactiveBase[isDark ? 'dark' : 'light'] as String,
      'teal-light': interactiveBase['dark'] as String,
    };

    final resolved = aliases[value];
    if (resolved == null) {
      throw FormatException('Unresolved symbolic color token: $value');
    }
    return resolved;
  }

  _TextStyleSpec _parseTextStyle(
    String groupName,
    Map<String, dynamic> jsonMap,
  ) {
    final family =
        (_typographyJson['variables'] as Map<String, dynamic>)['family']
            as Map<String, dynamic>;
    final fontFamily = groupName == 'Display'
        ? family['display'] as String
        : family['text'] as String;

    return _TextStyleSpec(
      fontFamily: fontFamily,
      fontWeightLiteral: _fontWeightLiteral(jsonMap['weight'] as String),
      fontSize: _asDouble(jsonMap['size'] as Object),
      lineHeight: _asDouble(jsonMap['lineHeight'] as Object),
      letterSpacing: _asDouble(jsonMap['letterSpacing'] as Object),
    );
  }

  String _emitRootConstants(_Node root) {
    return '''
const DsTokens dsTokensLight = ${_emitGroupInitializer(root, isDark: false)};
const DsTokens dsTokensDark = ${_emitGroupInitializer(root, isDark: true)};
''';
  }

  void _emitClass(_Node node, List<String> classes) {
    if (node.isLeaf) {
      return;
    }

    for (final child in node.children) {
      _emitClass(child, classes);
    }

    final className = node.className!;
    final fields = node.children;
    final fieldDeclarations = fields
        .map((field) => '  final ${_fieldType(field)} ${field.fieldName};')
        .join('\n');
    final constructorParams = fields
        .map((field) => '    required this.${field.fieldName},')
        .join('\n');
    final copyWithParams = fields
        .map((field) => '    ${_fieldType(field)}? ${field.fieldName},')
        .join('\n');
    final copyWithAssignments = fields
        .map(
          (field) =>
              '      ${field.fieldName}: ${field.fieldName} ?? this.${field.fieldName},',
        )
        .join('\n');
    final equalityChecks = fields
        .map((field) => '${field.fieldName} == other.${field.fieldName}')
        .join(' && ');
    final hashFields = fields.map((field) => field.fieldName).join(', ');
    final lerpAssignments = fields
        .map(
          (field) =>
              '      ${field.fieldName}: ${_lerpExpression(field, otherName: 'other', tName: 't')},',
        )
        .join('\n');

    final buffer = StringBuffer()
      ..writeln('@immutable')
      ..writeln(
        node.isThemeExtension
            ? 'class $className extends ThemeExtension<$className> {'
            : 'class $className {',
      )
      ..writeln(fieldDeclarations)
      ..writeln()
      ..writeln('  const $className({')
      ..writeln(constructorParams)
      ..writeln('  });')
      ..writeln()
      ..writeln(node.isThemeExtension ? '  @override' : '')
      ..writeln('  $className copyWith({')
      ..writeln(copyWithParams)
      ..writeln('  }) {')
      ..writeln('    return $className(')
      ..writeln(copyWithAssignments)
      ..writeln('    );')
      ..writeln('  }')
      ..writeln()
      ..writeln(node.isThemeExtension ? '  @override' : '')
      ..writeln('  $className lerp(covariant $className? other, double t) {')
      ..writeln('    if (other == null) {')
      ..writeln('      return this;')
      ..writeln('    }')
      ..writeln('    return $className(')
      ..writeln(lerpAssignments)
      ..writeln('    );')
      ..writeln('  }')
      ..writeln()
      ..writeln('  @override')
      ..writeln('  bool operator ==(Object other) {')
      ..writeln('    if (identical(this, other)) {')
      ..writeln('      return true;')
      ..writeln('    }')
      ..writeln('    return other is $className && $equalityChecks;')
      ..writeln('  }')
      ..writeln()
      ..writeln('  @override')
      ..writeln('  int get hashCode => Object.hashAll([$hashFields]);')
      ..writeln('}');

    classes.add(buffer.toString().replaceAll('\n\n\n', '\n\n'));
  }

  String _emitGroupInitializer(_Node node, {required bool isDark}) {
    final className = node.className!;
    final assignments = node.children
        .map(
          (child) =>
              '${child.fieldName}: ${child.isLeaf ? (isDark ? child.darkLiteral! : child.lightLiteral!) : _emitGroupInitializer(child, isDark: isDark)}',
        )
        .join(', ');
    return '$className($assignments)';
  }

  String _fieldType(_Node node) {
    if (!node.isLeaf) {
      return node.className!;
    }

    return switch (node.kind!) {
      _LeafKind.color => 'Color',
      _LeafKind.doubleValue => 'double',
      _LeafKind.stringValue => 'String',
      _LeafKind.fontWeight => 'FontWeight',
      _LeafKind.textStyle => 'TextStyle',
    };
  }

  String _lerpExpression(
    _Node node, {
    required String otherName,
    required String tName,
  }) {
    if (!node.isLeaf) {
      return '${node.fieldName}.lerp($otherName.${node.fieldName}, $tName)';
    }

    return switch (node.kind!) {
      _LeafKind.color =>
        'Color.lerp(${node.fieldName}, $otherName.${node.fieldName}, $tName) ?? ${node.fieldName}',
      _LeafKind.doubleValue =>
        'lerpDouble(${node.fieldName}, $otherName.${node.fieldName}, $tName) ?? ${node.fieldName}',
      _LeafKind.stringValue =>
        '$tName < 0.5 ? ${node.fieldName} : $otherName.${node.fieldName}',
      _LeafKind.fontWeight =>
        '$tName < 0.5 ? ${node.fieldName} : $otherName.${node.fieldName}',
      _LeafKind.textStyle =>
        'TextStyle.lerp(${node.fieldName}, $otherName.${node.fieldName}, $tName) ?? ${node.fieldName}',
    };
  }

  String _emitColor(_ColorSpec color) {
    final hex = color.argb.toRadixString(16).padLeft(8, '0').toUpperCase();
    return 'Color(0x$hex)';
  }

  String _emitTextStyle(_TextStyleSpec spec) {
    final height = spec.lineHeight / spec.fontSize;
    return '''
TextStyle(
  fontFamily: ${_emitString(spec.fontFamily)},
  fontSize: ${_emitDouble(spec.fontSize)},
  fontWeight: ${spec.fontWeightLiteral},
  height: ${_emitDouble(height)},
  letterSpacing: ${_emitDouble(spec.letterSpacing)},
)'''
        .replaceAll('\n', ' ');
  }

  String _emitString(String value) => "'${value.replaceAll("'", r"\'")}'";

  String _emitDouble(Object value) => _asDouble(value).toStringAsFixed(
    _asDouble(value).truncateToDouble() == _asDouble(value) ? 1 : 4,
  );

  double _asDouble(Object value) {
    return switch (value) {
      final int intValue => intValue.toDouble(),
      final double doubleValue => doubleValue,
      _ => double.parse(value.toString()),
    };
  }

  String _fontWeightLiteral(String value) {
    return switch (value) {
      'Bold' => 'FontWeight.w700',
      'Semi Bold' => 'FontWeight.w600',
      'Regular' => 'FontWeight.w400',
      _ => throw FormatException('Unsupported font weight: $value'),
    };
  }

  String _normalizeColorFieldName(String key, {required List<String> path}) {
    if (RegExp(r'^\d+$').hasMatch(key)) {
      final parent = path.last;
      if (parent == 'background' || parent == 'decorative') {
        return 'level${key.padLeft(2, '0')}';
      }
    }
    return _normalizeSimpleName(key);
  }

  String _normalizeTypographyStyleName(String value) {
    return _normalizeSimpleName(value);
  }

  String _normalizeSimpleName(String value) {
    final sanitized = value
        .replaceAll('/', ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp('[^A-Za-z0-9 ]'), ' ')
        .trim();
    if (sanitized.isEmpty) {
      throw FormatException('Cannot normalize empty token name from "$value"');
    }

    final parts = sanitized.split(RegExp(r'\s+'));
    final firstPart = parts.first;
    final first = '${firstPart[0].toLowerCase()}${firstPart.substring(1)}';
    final rest = parts.skip(1).map(_pascalCase).join();
    final candidate = '$first$rest';
    return RegExp(r'^\d').hasMatch(candidate) ? 'value$candidate' : candidate;
  }

  String _pascalCase(String value) {
    final parts = value
        .replaceAll(RegExp('[^A-Za-z0-9]+'), ' ')
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    return parts
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join();
  }
}
