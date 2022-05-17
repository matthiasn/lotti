import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/audio/recorder_cubit.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/image_import.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/routes/router.gr.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
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
  final PersistenceLogic _persistenceLogic = getIt<PersistenceLogic>();
  final TimeService _timeService = getIt<TimeService>();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> items = [];

    if (Platform.isMacOS) {
      items.add(
        FloatingActionButton(
          heroTag: 'screenshot',
          backgroundColor: AppColors.actionColor,
          onPressed: () async {
            ImageData imageData = await takeScreenshotMac();

            JournalEntity? journalEntity =
                await _persistenceLogic.createImageEntry(
              imageData,
              linked: widget.linked,
            );

            if (journalEntity != null) {
              _persistenceLogic.addGeolocation(journalEntity.meta.id);
            }
          },
          child: const Icon(
            MdiIcons.monitorScreenshot,
            size: 32,
          ),
        ),
      );
    }

    items.add(
      FloatingActionButton(
        heroTag: 'measurement',
        backgroundColor: AppColors.actionColor,
        onPressed: () {
          String? linkedId = widget.linked?.meta.id;
          context.router.push(CreateMeasurementWithLinkedRoute(
            linkedId: linkedId,
          ));
        },
        child: const Icon(
          MdiIcons.tapeMeasure,
          size: 32,
        ),
      ),
    );

    items.add(
      FloatingActionButton(
        heroTag: 'survey',
        backgroundColor: AppColors.actionColor,
        onPressed: () {
          String? linkedId = widget.linked?.meta.id;
          pushNamedRoute('/journal/create_survey/$linkedId');
        },
        child: const Icon(
          MdiIcons.clipboardOutline,
          size: 32,
        ),
      ),
    );

    items.add(
      FloatingActionButton(
        heroTag: 'photo',
        backgroundColor: AppColors.actionColor,
        onPressed: () {
          importImageAssets(
            context,
            linked: widget.linked,
          );
        },
        child: const Icon(
          Icons.camera_roll_outlined,
          size: 32,
        ),
      ),
    );

    items.add(
      FloatingActionButton(
        heroTag: 'text',
        backgroundColor: AppColors.actionColor,
        onPressed: () {
          if (widget.linked != null) {
            _persistenceLogic.createTextEntry(
              EntryText(plainText: ''),
              linkedId: widget.linked!.meta.id,
              started: DateTime.now(),
            );
          } else {
            String? linkedId = widget.linked?.meta.id;
            pushNamedRoute('/journal/create/$linkedId');
          }
        },
        child: const Icon(
          MdiIcons.textLong,
          size: 32,
        ),
      ),
    );

    if (widget.linked != null) {
      items.add(
        FloatingActionButton(
          heroTag: 'timer',
          backgroundColor: AppColors.actionColor,
          onPressed: () async {
            if (widget.linked != null) {
              JournalEntity? timerItem =
                  await _persistenceLogic.createTextEntry(
                EntryText(plainText: ''),
                linkedId: widget.linked!.meta.id,
                started: DateTime.now(),
              );
              if (timerItem != null) {
                _timeService.start(timerItem);
              }
            } else {
              String? linkedId = widget.linked?.meta.id;
              pushNamedRoute('/journal/create/$linkedId');
            }
          },
          child: const Icon(
            MdiIcons.timerOutline,
            size: 32,
          ),
        ),
      );
    }

    if (Platform.isIOS || Platform.isAndroid) {
      items.add(
        FloatingActionButton(
          heroTag: 'audio',
          backgroundColor: AppColors.actionColor,
          onPressed: () {
            String? linkedId = widget.linked?.meta.id;
            pushNamedRoute('/journal/record_audio/$linkedId');

            context.read<AudioRecorderCubit>().record(
                  linkedId: widget.linked?.meta.id,
                );
          },
          child: const Icon(
            MdiIcons.microphone,
            size: 32,
          ),
        ),
      );
    }

    items.add(
      FloatingActionButton(
        heroTag: 'task',
        backgroundColor: AppColors.actionColor,
        onPressed: () {
          String? linkedId = widget.linked?.meta.id;
          pushNamedRoute('/tasks/create/$linkedId');
        },
        child: const Icon(
          Icons.task_outlined,
          size: 32,
        ),
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
