import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/theming/state/theming_controller.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:radial_button/widget/circle_floating_button.dart';

class RadialAddTagButtons extends ConsumerStatefulWidget {
  const RadialAddTagButtons({
    super.key,
    this.radius = 120,
  });

  final double radius;

  @override
  ConsumerState<RadialAddTagButtons> createState() =>
      _RadialAddTagButtonsState();
}

class _RadialAddTagButtonsState extends ConsumerState<RadialAddTagButtons> {
  @override
  Widget build(BuildContext context) {
    final themingState = ref.watch(themingControllerProvider);
    final brightness = Theme.of(context).brightness;
    final isGamey = themingState.isGameyThemeForBrightness(brightness);

    void createTag(String tagType) =>
        beamToNamed('/settings/tags/create/$tagType');

    final items = <Widget>[
      FloatingActionButton(
        heroTag: 'tag',
        key: const Key('add_tag_action'),
        backgroundColor: Theme.of(context).primaryColor,
        onPressed: () => createTag('TAG'),
        child: Icon(
          MdiIcons.tagPlusOutline,
          size: 32,
        ),
      ),
      FloatingActionButton(
        heroTag: 'person',
        backgroundColor: Theme.of(context).primaryColor,
        onPressed: () => createTag('PERSON'),
        child: Icon(
          MdiIcons.tagFaces,
          size: 32,
        ),
      ),
      FloatingActionButton(
        heroTag: 'story',
        backgroundColor: Theme.of(context).primaryColor,
        onPressed: () => createTag('STORY'),
        child: Icon(MdiIcons.book, size: 32),
      ),
    ];

    return CircleFloatingButton.floatingActionButton(
      radius: widget.radius,
      useOpacity: true,
      items: items,
      color: Theme.of(context).primaryColor,
      icon: Icons.add_rounded,
      duration: const Duration(milliseconds: 500),
      curveAnim: Curves.ease,
      child: isGamey
          ? Image.asset(
              'assets/images/gamey/add_button.png',
              width: 64,
              height: 64,
              fit: BoxFit.contain,
            )
          : null,
    );
  }
}
