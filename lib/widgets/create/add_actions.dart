import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/create/create_entry.dart';
import 'package:lotti/logic/image_import.dart';
import 'package:lotti/services/nav_service.dart';
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
    final localizations = AppLocalizations.of(context)!;

    final items = <Widget>[];

    if (widget.isMacOS) {
      items.add(
        FloatingActionButton(
          heroTag: 'screenshot',
          tooltip: localizations.addActionAddScreenshot,
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
          tooltip: localizations.addActionAddPhotos,
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
          tooltip: localizations.addActionAddText,
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
          tooltip: localizations.addActionAddTimeRecording,
          onPressed: () async {
            rebuild();
            final linkedId = widget.linked?.meta.id;
            await createTimerEntry(linkedId: linkedId);
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
          tooltip: localizations.addActionAddAudioRecording,
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
          tooltip: localizations.addActionAddTask,
          onPressed: () async {
            rebuild();
            final linkedId = widget.linked?.meta.id;
            final task = await createTask(linkedId: linkedId);

            if (task != null) {
              beamToNamed('/journal/${task.meta.id}');
            }
          },
          child: const Icon(
            Icons.task_outlined,
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
        color: Theme.of(context).colorScheme.primaryContainer,
        items: items,
        icon: Icons.add_rounded,
        duration: const Duration(milliseconds: 250),
        curveAnim: Curves.ease,
      ),
    );
  }
}
