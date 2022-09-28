import 'package:flutter/material.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/themes/theme.dart';
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
    return styleConfig().privateTagColor;
  }

  return tagEntity.maybeMap(
    personTag: (_) => styleConfig().personTagColor,
    storyTag: (_) => styleConfig().storyTagColor,
    orElse: () => styleConfig().tagColor,
  );
}

class ColorThemeRefresh extends StatefulWidget {
  const ColorThemeRefresh({
    required this.child,
    required this.keyPrefix,
    super.key,
  });
  final Widget child;
  final String keyPrefix;

  @override
  State<ColorThemeRefresh> createState() => _ColorThemeRefreshState();
}

class _ColorThemeRefreshState extends State<ColorThemeRefresh> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DateTime>(
      stream: getIt<ThemesService>().getLastUpdateStream(),
      builder: (context, snapshot) {
        final key = '${widget.keyPrefix}-${snapshot.data}';
        debugPrint('ColorThemeRefresh $key');
        return Container(
          key: Key(key),
          child: widget.child,
        );
      },
    );
  }
}
