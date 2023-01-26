import 'package:flutter/material.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/themes/theme.dart';
import 'package:tinycolor2/tinycolor2.dart';

Color darken(Color color, int value) {
  return TinyColor.fromColor(color).darken(value).color;
}

Color lighten(Color color, int value) {
  return TinyColor.fromColor(color).lighten(value).color;
}

Color getTagColor(TagEntity tagEntity) {
  if (tagEntity.private) {
    return styleConfig().privateTagColor;
  }

  return tagEntity.maybeMap(
    personTag: (_) => styleConfig().personTagColor,
    storyTag: (_) => styleConfig().storyTagColor,
    orElse: () => styleConfig().tagColor,
  );
}
