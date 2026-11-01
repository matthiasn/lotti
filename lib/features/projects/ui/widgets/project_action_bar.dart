import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/helpers/automatic_image_analysis_trigger.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/ui/create/entry_creation_service.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:material_ui/material_ui.dart';

/// Sticky action bar pinned to the bottom of a project's page.
///
/// The project counterpart of the task page's `TaskActionBar` and the entry
/// page's `EntryActionBar`: the same edge-to-edge glass strip and 48 px
/// chips on the same `step4` rhythm. Everything it makes is linked to the
/// project and categorized like it, so it lands in the project's timeline
/// and its agent's log. Left to right:
///
/// * **Record audio** — the one filled shape: a voice note is the quickest
///   way to tell a project what happened. It takes the alert fill while a
///   recording linked to this project is in progress.
/// * **Write a note** — makes a note linked to the project and opens it, so
///   the writing starts at once rather than on an empty card below the fold.
/// * **Import an image**.
/// * **Add** — the plus: the Add sheet for the rest (screenshot, paste,
///   event…), linked to the project. The sheet leaves out a timer, as time
///   is tracked on the project's tasks, and a linked task, which would not be
///   one of the project's tasks — those are added from the tasks panel.
///
/// The host page must use `Scaffold.extendBody: true` so the content paints
/// behind the strip, and keep its last content clear of it. The row is a
/// [Wrap], so large text folds the chips onto another line.
class ProjectActionBar extends ConsumerWidget {
  const ProjectActionBar({required this.project, super.key});

  /// The project whose page hosts the bar.
  final ProjectEntry project;

  /// Stable test key for the Record audio pill.
  @visibleForTesting
  static const Key audioKey = ValueKey('project-action-bar-audio');

  /// Stable test key for the Write a note button.
  @visibleForTesting
  static const Key noteKey = ValueKey('project-action-bar-note');

  /// Stable test key for the Import image button.
  @visibleForTesting
  static const Key imageKey = ValueKey('project-action-bar-image');

  /// Stable test key for the plus that opens the Add sheet.
  @visibleForTesting
  static const Key addKey = ValueKey('project-action-bar-add');

  /// Inner row widths below which a round button gives way, so the row stays
  /// one line: the image first, then the note — both stay in the Add sheet.
  /// Priced for the widest translated pill (French), 48 px buttons and
  /// `step4` gaps; the recording pill and the plus always stay.
  @visibleForTesting
  static const double minWidthForImageButton = 430;

  /// See [minWidthForImageButton].
  @visibleForTesting
  static const double minWidthForNoteButton = 370;

  String get _id => project.meta.id;
  String? get _categoryId => project.meta.categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
    final messages = context.messages;
    final creation = ref.read(entryCreationServiceProvider);
    final recording = ref.watch(
      audioRecorderControllerProvider.select(
        (state) => state.isActiveSessionFor(_id),
      ),
    );
    // The glass reaches into the home-indicator inset; the row sits above.
    final safeBottomInset = MediaQuery.paddingOf(context).bottom;

    return DesignSystemGlassStrip(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          spacing.step5,
          spacing.step4,
          spacing.step5,
          spacing.step4 + safeBottomInset,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: spacing.step4,
            runSpacing: spacing.step4,
            children: [
              DsGlassPill(
                key: audioKey,
                icon: LottiIcons.mic,
                label: messages.taskFirstRunRecordAudio,
                semanticLabel: recording
                    ? messages.taskActionBarAudioRecordingActive
                    : messages.taskFirstRunRecordAudio,
                fillColor: recording
                    ? tokens.colors.alert.error.defaultColor
                    : tokens.colors.interactive.enabled,
                // The ink for both fills: the accent and the alert.
                foregroundColor: tokens.colors.text.onInteractiveAlert,
                onTap: () => creation.showAudioRecordingModal(
                  context,
                  linkedId: _id,
                  categoryId: _categoryId,
                ),
              ),
              if (constraints.maxWidth >= minWidthForNoteButton)
                DsGlassRoundButton(
                  key: noteKey,
                  icon: LottiIcons.note,
                  semanticLabel: messages.taskFirstRunWriteNote,
                  onPressed: () async {
                    final note = await creation.createTextEntry(
                      linkedId: _id,
                      categoryId: _categoryId,
                    );
                    if (note != null) beamToNamed('/journal/${note.meta.id}');
                  },
                ),
              if (constraints.maxWidth >= minWidthForImageButton)
                DsGlassRoundButton(
                  key: imageKey,
                  icon: LottiIcons.image,
                  semanticLabel: messages.addActionImportImage,
                  onPressed: () => creation.importImage(
                    context,
                    linkedId: _id,
                    categoryId: _categoryId,
                    analysisTrigger: ref.read(
                      automaticImageAnalysisTriggerProvider,
                    ),
                  ),
                ),
              DsGlassRoundButton(
                key: addKey,
                icon: LottiIcons.add,
                semanticLabel: messages.addLinkedEntryLabel,
                onPressed: () => creation.showCreateEntryModal(
                  context,
                  linkedFromId: _id,
                  categoryId: _categoryId,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
