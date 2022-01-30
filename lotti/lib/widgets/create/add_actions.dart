import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/audio/recorder_cubit.dart';
import 'package:lotti/blocs/journal/journal_image_cubit.dart';
import 'package:lotti/blocs/journal/persistence_cubit.dart';
import 'package:lotti/blocs/journal/persistence_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/pages/add/editor_page.dart';
import 'package:lotti/widgets/pages/add/new_measurement_page.dart';
import 'package:lotti/widgets/pages/add/new_task_page.dart';
import 'package:lotti/widgets/pages/add/survey_page.dart';
import 'package:lotti/widgets/pages/audio.dart';
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
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext _context) {
    List<Widget> items = [];

    items.add(
      FloatingActionButton(
        heroTag: 'measurement',
        child: const Icon(
          MdiIcons.tapeMeasure,
          size: 32,
        ),
        backgroundColor: AppColors.entryBgColor,
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (BuildContext context) {
                return NewMeasurementPage(
                  linked: widget.linked,
                );
              },
            ),
          );
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
        backgroundColor: AppColors.entryBgColor,
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (BuildContext context) {
                return SurveyPage(
                  linked: widget.linked,
                );
              },
            ),
          );
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
        backgroundColor: AppColors.entryBgColor,
        onPressed: () {
          context.read<JournalImageCubit>().pickImageAssets(
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
        backgroundColor: AppColors.entryBgColor,
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (BuildContext context) {
                return EditorPage(
                  linked: widget.linked,
                );
              },
            ),
          );
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
          backgroundColor: AppColors.entryBgColor,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (BuildContext context) {
                  return AudioPage(
                    linked: widget.linked,
                  );
                },
              ),
            );
            context.read<AudioRecorderCubit>().record();
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
        backgroundColor: AppColors.entryBgColor,
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (BuildContext context) {
                return NewTaskPage(
                  linked: widget.linked,
                );
              },
            ),
          );
        },
      ),
    );

    return BlocBuilder<PersistenceCubit, PersistenceState>(
        builder: (context, PersistenceState state) {
      return CircleFloatingButton.floatingActionButton(
        radius: items.length * 32,
        useOpacity: true,
        items: items,
        color: AppColors.entryBgColor,
        icon: Icons.add,
        duration: const Duration(milliseconds: 500),
        curveAnim: Curves.ease,
      );
    });
  }
}
