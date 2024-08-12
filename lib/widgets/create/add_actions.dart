import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/create/create_entry.dart';
import 'package:lotti/logic/image_import.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:radial_button/widget/circle_floating_button.dart';

const actionIconSize = 32.0;

class RadialAddActionButtons extends StatefulWidget {
  const RadialAddActionButtons({
    required this.radius,
    super.key,
    this.navigatorKey,
    this.linked,
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
    final items = <Widget>[];

    if (widget.isMacOS) {
      items.add(
        FloatingActionButton(
          heroTag: 'screenshot',
          tooltip: context.messages.addActionAddScreenshot,
          onPressed: () async {
            rebuild();
            await createScreenshot(linkedId: widget.linked?.meta.id);
          },
          child: Icon(
            MdiIcons.monitorScreenshot,
            size: actionIconSize,
          ),
        ),
      );
    }

    items
      ..add(
        FloatingActionButton(
          heroTag: 'photo',
          tooltip: context.messages.addActionAddPhotos,
          onPressed: () {
            rebuild();

            importImageAssets(
              context,
              linked: widget.linked,
            );
          },
          child: const Icon(
            Icons.add_a_photo_outlined,
            size: actionIconSize,
          ),
        ),
      )
      ..add(
        FloatingActionButton(
          heroTag: 'text',
          tooltip: context.messages.addActionAddText,
          onPressed: () async {
            rebuild();
            final linkedId = widget.linked?.meta.id;
            await createTextEntry(linkedId: linkedId);
          },
          child: Icon(MdiIcons.textLong, size: actionIconSize),
        ),
      );

    if (widget.linked != null) {
      items.add(
        FloatingActionButton(
          heroTag: 'timer',
          tooltip: context.messages.addActionAddTimeRecording,
          onPressed: () async {
            rebuild();
            await createTimerEntry(linked: widget.linked);
          },
          child: Icon(
            MdiIcons.timerOutline,
            size: actionIconSize,
          ),
        ),
      );
    }

    items
      ..add(
        FloatingActionButton(
          heroTag: 'audio',
          tooltip: context.messages.addActionAddAudioRecording,
          onPressed: () {
            rebuild();
            final linkedId = widget.linked?.meta.id;
            if (getIt<NavService>().tasksTabActive()) {
              beamToNamed('/tasks/$linkedId/record_audio/$linkedId');
            } else {
              beamToNamed('/journal/$linkedId/record_audio/$linkedId');
            }
          },
          child: const Icon(Icons.mic_rounded, size: actionIconSize),
        ),
      )
      ..add(
        FloatingActionButton(
          heroTag: 'task',
          tooltip: context.messages.addActionAddTask,
          onPressed: () async {
            rebuild();
            final linkedId = widget.linked?.meta.id;
            final task = await createTask(
              linkedId: linkedId,
              categoryId: widget.linked?.meta.categoryId,
            );

            if (task != null) {
              beamToNamed('/journal/${task.meta.id}');
            }
          },
          child: const Icon(
            Icons.task_outlined,
            size: actionIconSize,
          ),
        ),
      )
      ..add(
        FloatingActionButton(
          heroTag: 'event',
          tooltip: context.messages.addActionAddEvent,
          onPressed: () async {
            rebuild();
            final linkedId = widget.linked?.meta.id;
            final event = await createEvent(linkedId: linkedId);

            if (event != null) {
              beamToNamed('/journal/${event.meta.id}');
            }
          },
          child: const Icon(
            Icons.event_outlined,
            size: actionIconSize,
          ),
        ),
      );

    return Padding(
      padding: const EdgeInsets.only(right: 1, bottom: 1.5),
      child: CircleFloatingButton.floatingActionButton(
        radius: 80 + items.length * 24,
        key: ValueKey('add_actions $keyDateTime'),
        useOpacity: true,
        color: context.colorScheme.primaryContainer,
        items: items,
        icon: Icons.add_rounded,
        duration: const Duration(milliseconds: 250),
        curveAnim: Curves.ease,
      ),
    );
  }
}
