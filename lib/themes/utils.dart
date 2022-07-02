import 'package:flutter/material.dart';
import 'package:flutter_fadein/flutter_fadein.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/themes/themes_service.dart';
import 'package:tinycolor2/tinycolor2.dart';

Color darken(Color color, int value) {
  return TinyColor.fromColor(color).darken(value).color;
}

Color lighten(Color color, int value) {
  return TinyColor.fromColor(color).lighten(value).color;
}

Color getTagColor(TagEntity tagEntity) {
  if (tagEntity.private) {
    return colorConfig().privateTagColor;
  }

  return tagEntity.maybeMap(
    personTag: (_) => colorConfig().personTagColor,
    storyTag: (_) => colorConfig().storyTagColor,
    orElse: () => colorConfig().tagColor,
  );
}

class ColorThemeRefresh extends StatelessWidget {
  const ColorThemeRefresh({
    required this.child,
    super.key,
  });
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ColorConfig>(
      stream: getIt<ColorsService>().getStream(),
      builder: (context, snapshot) {
        final key = 'theme-${snapshot.data}';
        debugPrint('ColorThemeRefresh $key');
        return FadeIn(
          key: Key(key),
          child: child,
        );
      },
    );
  }
}
