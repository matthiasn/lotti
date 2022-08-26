import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/blocs/audio/recorder_cubit.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/logic/create/create_entry.dart';
import 'package:lotti/logic/image_import.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:radial_button/widget/circle_floating_button.dart';

class RadialAddActionButtons extends StatefulWidget {
  const RadialAddActionButtons({
    super.key,
    this.navigatorKey,
    this.linked,
    required this.radius,
    this.isMacOS = false,
    this.isIOS = false,
    this.isAndroid = false,
  });

  final GlobalKey? navigatorKey;
  final JournalEntity? linked;
  final double radius;
  final bool isMacOS;
  final bool isIOS;
  final bool isAndroid;

  @override
  State<RadialAddActionButtons> createState() => _RadialAddActionButtonsState();
}

class _RadialAddActionButtonsState extends State<RadialAddActionButtons> {
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
    final localizations = AppLocalizations.of(context)!;
    final items = <Widget>[];

    if (widget.isMacOS) {
      items.add(
        FloatingActionButton(
          heroTag: 'screenshot',
          tooltip: localizations.addActionAddScreenshot,
          backgroundColor: colorConfig().actionColor,
          onPressed: () async {
            rebuild();
            await createScreenshot(linkedId: widget.linked?.meta.id);
          },
          child: const Icon(
            MdiIcons.monitorScreenshot,
            size: 32,
          ),
        ),
      );
    }

    items
      ..add(
        FloatingActionButton(
          heroTag: 'measurement',
          backgroundColor: colorConfig().actionColor,
          tooltip: localizations.addActionAddMeasurable,
          onPressed: () async {
            rebuild();
            final linkedId = widget.linked?.meta.id;
            beamToNamed('/journal/measure_linked/$linkedId');
          },
          child: const Icon(
            Icons.insights,
            size: 32,
          ),
        ),
      )
      ..add(
        FloatingActionButton(
          heroTag: 'survey',
          tooltip: localizations.addActionAddSurvey,
          backgroundColor: colorConfig().actionColor,
          onPressed: () {
            rebuild();
            final linkedId = widget.linked?.meta.id;
            beamToNamed('/journal/fill_survey_linked/$linkedId');
          },
          child: const Icon(
            MdiIcons.clipboardOutline,
            size: 32,
          ),
        ),
      )
      ..add(
        FloatingActionButton(
          heroTag: 'photo',
          tooltip: localizations.addActionAddPhotos,
          backgroundColor: colorConfig().actionColor,
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
      )
      ..add(
        FloatingActionButton(
          heroTag: 'text',
          tooltip: localizations.addActionAddText,
          backgroundColor: colorConfig().actionColor,
          onPressed: () async {
            rebuild();
            final linkedId = widget.linked?.meta.id;
            await createTextEntry(linkedId: linkedId);
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
          backgroundColor: colorConfig().actionColor,
          onPressed: () async {
            rebuild();
            final linkedId = widget.linked?.meta.id;
            await createTimerEntry(linkedId: linkedId);
          },
          child: const Icon(
            MdiIcons.timerOutline,
            size: 32,
          ),
        ),
      );
    }

    if (widget.isIOS || widget.isAndroid) {
      items.add(
        FloatingActionButton(
          heroTag: 'audio',
          tooltip: localizations.addActionAddAudioRecording,
          backgroundColor: colorConfig().actionColor,
          onPressed: () {
            rebuild();
            final linkedId = widget.linked?.meta.id;
            beamToNamed('/journal/record_audio/$linkedId');
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
        backgroundColor: colorConfig().actionColor,
        onPressed: () async {
          rebuild();
          final linkedId = widget.linked?.meta.id;
          final task = await createTask(linkedId: linkedId);
          if (task != null) {
            beamToNamed('/tasks/${task.meta.id}');
          }
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
      color: colorConfig().actionColor,
      icon: Icons.add,
      key: Key(keyDateTime.toString()),
      duration: const Duration(milliseconds: 500),
      curveAnim: Curves.ease,
    );
  }
}
