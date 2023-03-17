import 'package:flutter/material.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/themes/theme.dart';

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
