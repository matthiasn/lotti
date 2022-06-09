import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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
  DateTime keyDateTime = DateTime.now();

  @override
  void initState() {
    super.initState();
  }

  void rebuild() {
    setState(() {
      keyDateTime = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    List<Widget> items = [];

    if (Platform.isMacOS) {
      items.add(
        FloatingActionButton(
          heroTag: 'screenshot',
          tooltip: localizations.addActionAddScreenshot,
          backgroundColor: AppColors.actionColor,
          onPressed: () async {
            rebuild();

            ImageData imageData = await takeScreenshotMac();

            JournalEntity? journalEntity =
                await _persistenceLogic.createImageEntry(
              imageData,
              linkedId: widget.linked?.meta.id,
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
        tooltip: localizations.addActionAddMeasurable,
        onPressed: () {
          rebuild();

          String? linkedId = widget.linked?.meta.id;
          context.router.push(CreateMeasurementWithLinkedRoute(
            linkedId: linkedId,
          ));
        },
        child: const Icon(
          Icons.insights,
          size: 32,
        ),
      ),
    );

    items.add(
      FloatingActionButton(
        heroTag: 'survey',
        tooltip: localizations.addActionAddSurvey,
        backgroundColor: AppColors.actionColor,
        onPressed: () {
          rebuild();

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
        tooltip: localizations.addActionAddPhotos,
        backgroundColor: AppColors.actionColor,
        onPressed: () {
          rebuild();

          importImageAssets(
            context,
            linked: widget.linked,
          );
        },
        child: const Icon(
          Icons.add_a_photo_outlined,
          size: 32,
        ),
      ),
    );

    items.add(
      FloatingActionButton(
        heroTag: 'text',
        tooltip: localizations.addActionAddText,
        backgroundColor: AppColors.actionColor,
        onPressed: () {
          rebuild();

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
          tooltip: localizations.addActionAddTimeRecording,
          backgroundColor: AppColors.actionColor,
          onPressed: () async {
            rebuild();

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
          tooltip: localizations.addActionAddAudioRecording,
          backgroundColor: AppColors.actionColor,
          onPressed: () {
            rebuild();

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
        tooltip: localizations.addActionAddTask,
        backgroundColor: AppColors.actionColor,
        onPressed: () {
          rebuild();

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
      key: Key(keyDateTime.toString()),
      duration: const Duration(milliseconds: 500),
      curveAnim: Curves.ease,
    );
  }
}
