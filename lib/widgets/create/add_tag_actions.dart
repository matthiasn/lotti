import 'package:flutter/material.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:radial_button/widget/circle_floating_button.dart';

class RadialAddTagButtons extends StatefulWidget {
  const RadialAddTagButtons({
    super.key,
    this.navigatorKey,
    this.radius = 120,
  });

  final GlobalKey? navigatorKey;
  final double radius;

  @override
  State<RadialAddTagButtons> createState() => _RadialAddTagButtonsState();
}

class _RadialAddTagButtonsState extends State<RadialAddTagButtons> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    void createTag(String tagType) =>
        beamToNamed('/settings/tags/create/$tagType');

    final items = <Widget>[
      FloatingActionButton(
        heroTag: 'tag',
        key: const Key('add_tag_action'),
        backgroundColor: colorConfig().actionColor,
        onPressed: () => createTag('TAG'),
        child: const Icon(
          MdiIcons.tagPlusOutline,
          size: 32,
        ),
      ),
      FloatingActionButton(
        heroTag: 'person',
        backgroundColor: colorConfig().actionColor,
        onPressed: () => createTag('PERSON'),
        child: const Icon(
          MdiIcons.tagFaces,
          size: 32,
        ),
      ),
      FloatingActionButton(
        heroTag: 'story',
        backgroundColor: colorConfig().actionColor,
        onPressed: () => createTag('STORY'),
        child: const Icon(
          MdiIcons.book,
          size: 32,
        ),
      ),
    ];

    return CircleFloatingButton.floatingActionButton(
      radius: widget.radius,
      useOpacity: true,
      items: items,
      color: colorConfig().actionColor,
      icon: Icons.add,
      duration: const Duration(milliseconds: 500),
      curveAnim: Curves.ease,
    );
  }
}
