import 'package:flutter/material.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/pages/settings/tags/tag_details.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:radial_button/widget/circle_floating_button.dart';

class RadialAddTagButtons extends StatefulWidget {
  const RadialAddTagButtons({
    Key? key,
    this.navigatorKey,
    this.radius = 120,
  }) : super(key: key);

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
  Widget build(BuildContext _context) {
    List<Widget> items = [
      FloatingActionButton(
        heroTag: 'tag',
        key: const Key('add_tag_action'),
        child: const Icon(
          MdiIcons.tagPlusOutline,
          size: 32,
        ),
        backgroundColor: AppColors.entryBgColor,
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (BuildContext context) {
                DateTime now = DateTime.now();
                return TagDetailRoute(
                  tagEntity: TagEntity.genericTag(
                    id: uuid.v1(),
                    vectorClock: null,
                    createdAt: now,
                    updatedAt: now,
                    private: false,
                    tag: '',
                  ),
                );
              },
            ),
          );
        },
      ),
      FloatingActionButton(
        heroTag: 'person',
        child: const Icon(
          MdiIcons.tagFaces,
          size: 32,
        ),
        backgroundColor: AppColors.entryBgColor,
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (BuildContext context) {
                DateTime now = DateTime.now();
                return TagDetailRoute(
                  tagEntity: TagEntity.personTag(
                    id: uuid.v1(),
                    vectorClock: null,
                    createdAt: now,
                    updatedAt: now,
                    private: false,
                    tag: '',
                  ),
                );
              },
            ),
          );
        },
      ),
      FloatingActionButton(
        heroTag: 'story',
        child: const Icon(
          MdiIcons.book,
          size: 32,
        ),
        backgroundColor: AppColors.entryBgColor,
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (BuildContext context) {
                DateTime now = DateTime.now();
                return TagDetailRoute(
                  tagEntity: TagEntity.storyTag(
                    id: uuid.v1(),
                    vectorClock: null,
                    createdAt: now,
                    updatedAt: now,
                    private: false,
                    tag: '',
                  ),
                );
              },
            ),
          );
        },
      ),
    ];

    return CircleFloatingButton.floatingActionButton(
      radius: widget.radius,
      useOpacity: true,
      items: items,
      color: AppColors.entryBgColor,
      icon: Icons.add,
      duration: const Duration(milliseconds: 500),
      curveAnim: Curves.ease,
    );
  }
}
