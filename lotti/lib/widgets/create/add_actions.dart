import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/audio/recorder_cubit.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/image_import.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/routes/router.gr.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/utils/screenshots.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:radial_button/widget/circle_floating_button.dart';

class RadialAddActionButtons extends StatefulWidget {
  const RadialAddActionButtons({
    Key? key,
    this.navigatorKey,
    this.linked,
    required this.radius,
  }) : super(key: key);

  final GlobalKey? navigatorKey;
  final JournalEntity? linked;
  final double radius;

  @override
  State<RadialAddActionButtons> createState() => _RadialAddActionButtonsState();
}

class _RadialAddActionButtonsState extends State<RadialAddActionButtons> {
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext _context) {
    List<Widget> items = [];

    if (Platform.isMacOS) {
      items.add(
        FloatingActionButton(
          heroTag: 'screenshot',
          child: const Icon(
            MdiIcons.monitorScreenshot,
            size: 32,
          ),
          backgroundColor: AppColors.actionColor,
          onPressed: () async {
            ImageData imageData = await takeScreenshotMac();
            await persistenceLogic.createImageEntry(
              imageData,
              linked: widget.linked,
            );
          },
        ),
      );
    }

    items.add(
      FloatingActionButton(
        heroTag: 'measurement',
        child: const Icon(
          MdiIcons.tapeMeasure,
          size: 32,
        ),
        backgroundColor: AppColors.actionColor,
        onPressed: () {
          String? linkedId = widget.linked?.meta.id;
          context.router.push(CreateMeasurementWithLinkedRoute(
            linkedId: linkedId,
          ));
        },
      ),
    );

    items.add(
      FloatingActionButton(
        heroTag: 'survey',
        child: const Icon(
          MdiIcons.clipboardOutline,
          size: 32,
        ),
        backgroundColor: AppColors.actionColor,
        onPressed: () {
          String? linkedId = widget.linked?.meta.id;
          context.router.pushNamed('/journal/create_survey/$linkedId');
        },
      ),
    );

    items.add(
      FloatingActionButton(
        heroTag: 'photo',
        child: const Icon(
          Icons.camera_roll_outlined,
          size: 32,
        ),
        backgroundColor: AppColors.actionColor,
        onPressed: () {
          importImageAssets(
            context,
            linked: widget.linked,
          );
        },
      ),
    );

    items.add(
      FloatingActionButton(
        heroTag: 'text',
        child: const Icon(
          MdiIcons.textLong,
          size: 32,
        ),
        backgroundColor: AppColors.actionColor,
        onPressed: () {
          String? linkedId = widget.linked?.meta.id;
          context.router.pushNamed('/journal/create/$linkedId');
        },
      ),
    );

    if (Platform.isIOS || Platform.isAndroid) {
      items.add(
        FloatingActionButton(
          heroTag: 'audio',
          child: const Icon(
            MdiIcons.microphone,
            size: 32,
          ),
          backgroundColor: AppColors.actionColor,
          onPressed: () {
            String? linkedId = widget.linked?.meta.id;
            context.router.pushNamed('/journal/record_audio/$linkedId');

            context.read<AudioRecorderCubit>().record(
                  linkedId: widget.linked?.meta.id,
                );
          },
        ),
      );
    }

    items.add(
      FloatingActionButton(
        heroTag: 'task',
        child: const Icon(
          Icons.task_outlined,
          size: 32,
        ),
        backgroundColor: AppColors.actionColor,
        onPressed: () {
          String? linkedId = widget.linked?.meta.id;
          context.router.pushNamed('/tasks/create/$linkedId');
        },
      ),
    );

    return CircleFloatingButton.floatingActionButton(
      radius: items.length * 32,
      useOpacity: true,
      items: items,
      color: AppColors.actionColor,
      icon: Icons.add,
      duration: const Duration(milliseconds: 500),
      curveAnim: Curves.ease,
    );
  }
}
