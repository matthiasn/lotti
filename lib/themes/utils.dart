import 'package:flutter/material.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/themes/colors.dart';

Color getTagColor(TagEntity tagEntity) {
  if (tagEntity.private) {
    return alarm;
  }

  return switch (tagEntity) {
    PersonTag() => personTagColor,
    StoryTag() => storyTagColor,
    _ => tagColor,
  };
}
