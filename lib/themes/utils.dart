import 'package:flutter/material.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/themes/colors.dart';

Color getTagColor(TagEntity tagEntity) {
  if (tagEntity.private) {
    return alarm;
  }

  return tagEntity.maybeMap(
    personTag: (_) => personTagColor,
    storyTag: (_) => storyTagColor,
    orElse: () => tagColor,
  );
}
