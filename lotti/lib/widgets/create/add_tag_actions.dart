import 'package:flutter/material.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/widgets/pages/settings/tags_page.dart';
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
        onPressed: () {},
      ),
      FloatingActionButton(
        heroTag: 'tag',
        child: const Icon(
          MdiIcons.tagSearch,
          size: 32,
        ),
        backgroundColor: AppColors.entryBgColor,
        onPressed: () {},
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
