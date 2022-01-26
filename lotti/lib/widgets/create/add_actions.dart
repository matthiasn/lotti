import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/journal/journal_image_cubit.dart';
import 'package:lotti/blocs/journal/persistence_cubit.dart';
import 'package:lotti/blocs/journal/persistence_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/pages/add/editor_page.dart';
import 'package:lotti/widgets/pages/add/health_page.dart';
import 'package:lotti/widgets/pages/add/new_measurement_page.dart';
import 'package:lotti/widgets/pages/add/survey_page.dart';
import 'package:lotti/widgets/pages/audio.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class AddActionButtons extends StatefulWidget {
  const AddActionButtons({
    Key? key,
    this.navigatorKey,
    this.linked,
  }) : super(key: key);

  final GlobalKey? navigatorKey;
  final JournalEntity? linked;

  @override
  State<AddActionButtons> createState() => _AddActionButtonsState();
}

class _AddActionButtonsState extends State<AddActionButtons> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext _context) {
    return BlocBuilder<PersistenceCubit, PersistenceState>(
        builder: (context, PersistenceState state) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Visibility(
              visible: widget.linked == null &&
                  (Platform.isIOS || Platform.isAndroid),
              child: FloatingActionButton(
                heroTag: 'health',
                child: const Icon(
                  MdiIcons.heart,
                  size: 32,
                ),
                backgroundColor: AppColors.entryBgColor,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (BuildContext context) {
                        return const HealthPage();
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(
              width: 16,
            ),
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
            Visibility(
              visible: widget.linked == null,
              child: const SizedBox(
                width: 16,
              ),
            ),
            Visibility(
              visible: widget.linked == null,
              child: FloatingActionButton(
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
                        return const SurveyPage();
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(
              width: 16,
            ),
            FloatingActionButton(
              heroTag: 'photo',
              child: const Icon(
                Icons.camera_roll,
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
            const SizedBox(
              width: 16,
            ),
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
            const SizedBox(
              width: 16,
            ),
            Visibility(
              visible: Platform.isIOS || Platform.isAndroid,
              child: FloatingActionButton(
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
                },
              ),
            ),
          ],
        ),
      );
    });
  }
}
