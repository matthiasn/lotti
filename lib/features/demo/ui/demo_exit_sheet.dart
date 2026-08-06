import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/demo/copy/demo_copy_candidates.dart';
import 'package:lotti/features/demo/state/demo_mode_gateway.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// Opens the demo exit sheet: step 1 confirms leaving (the demo world stays
/// saved), step 2 — reachable only when the user created something — picks
/// what to copy into the real world before exiting: tasks, journal entries,
/// and any AI setup the user connected inside the demo.
Future<void> showDemoExitSheet(
  BuildContext context, {
  DemoModeGateway? gateway,
  Future<DemoCopyCandidates> Function()? loadCandidates,
}) {
  final resolved = gateway ?? maybeDemoModeGatewayOf(context);
  if (resolved == null) return Future.value();
  return ModalUtils.showSinglePageModal<void>(
    context: context,
    builder: (modalContext) => DemoExitSheetContent(
      gateway: resolved,
      loadCandidates: loadCandidates,
    ),
  );
}

enum _ExitStep { confirm, pick, working }

/// The exit sheet's content: confirm → (optional) pick-and-copy → working.
///
/// The copied-item count deliberately has no completion toast: applying the
/// copy happens AFTER the profile switch back to the real world, which
/// replaces the entire widget tree (this sheet included) with the new
/// generation — there is no surviving messenger to toast on. The working
/// step surfaces progress until the switch swallows the UI;
/// `DemoModeGateway.exitWithCopy` returns the count for logs and tests.
class DemoExitSheetContent extends StatefulWidget {
  const DemoExitSheetContent({
    required this.gateway,
    this.loadCandidates,
    super.key,
  });

  final DemoModeGateway gateway;

  /// Test seam; production reads the ACTIVE demo generation's journal.
  final Future<DemoCopyCandidates> Function()? loadCandidates;

  @override
  State<DemoExitSheetContent> createState() => _DemoExitSheetContentState();
}

class _DemoExitSheetContentState extends State<DemoExitSheetContent> {
  _ExitStep _step = _ExitStep.confirm;
  late final Future<DemoCopyCandidates> _candidates;
  final Set<String> _selected = {};

  /// Whether the working step is a copy run — a plain exit is near-instant
  /// (the switch splash takes over) and must not claim to be copying.
  bool _copying = false;

  @override
  void initState() {
    super.initState();
    _candidates = (widget.loadCandidates ?? _loadFromActiveWorld)();
    // Log a failed candidate load exactly once; the confirm step also
    // surfaces it (see [_buildConfirm]) so the copy option never vanishes
    // silently. The derived future swallows the error on purpose — the
    // FutureBuilder consumes the original.
    unawaited(
      _candidates.then<void>(
        (_) {},
        onError: _logError,
      ),
    );
  }

  static Future<DemoCopyCandidates> _loadFromActiveWorld() =>
      loadDemoCopyCandidates(
        journalDb: getIt<JournalDb>(),
        aiConfigRepository: getIt<AiConfigRepository>(),
        demoRoot: getIt<Directory>(),
      );

  Future<void> _exitPlain() async {
    setState(() {
      _copying = false;
      _step = _ExitStep.working;
    });
    try {
      // On success the profile switch unmounts this sheet with the rest of
      // the old generation's tree.
      await widget.gateway.exitDemo();
    } catch (exception, stackTrace) {
      _logError(exception, stackTrace);
      if (mounted) {
        setState(() => _step = _ExitStep.confirm);
        // Tell the user why the sheet snapped back instead of exiting.
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.demoExitFailedToast,
        );
      }
    }
  }

  /// [aiCandidateIds] are the ids rendered in the "AI setup" section — they
  /// route to the copier's AI path rather than the journal closure.
  Future<void> _copyAndExit(Set<String> aiCandidateIds) async {
    setState(() {
      _copying = true;
      _step = _ExitStep.working;
    });
    try {
      await widget.gateway.exitWithCopy(
        selectedIds: _selected.difference(aiCandidateIds),
        selectedAiConfigIds: _selected.intersection(aiCandidateIds),
      );
    } catch (exception, stackTrace) {
      _logError(exception, stackTrace);
      if (mounted) {
        setState(() => _step = _ExitStep.pick);
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.demoExitFailedToast,
        );
      }
    }
  }

  void _logError(Object exception, StackTrace stackTrace) {
    if (!getIt.isRegistered<DomainLogger>()) return;
    getIt<DomainLogger>().error(
      LogDomain.general,
      exception,
      stackTrace: stackTrace,
      subDomain: 'demoExitSheet',
    );
  }

  @override
  Widget build(BuildContext context) {
    return switch (_step) {
      _ExitStep.confirm => _buildConfirm(context),
      _ExitStep.pick => _buildPick(context),
      _ExitStep.working => _buildWorking(context),
    };
  }

  Widget _buildConfirm(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return FutureBuilder<DemoCopyCandidates>(
      future: _candidates,
      builder: (context, snapshot) {
        // The exit decision waits for the candidate query (a fast local
        // read): leaving before it resolves could silently bypass the copy
        // picker for a user who did create work in the demo.
        final resolved = snapshot.connectionState == ConnectionState.done;
        final hasCandidates = snapshot.data?.isNotEmpty ?? false;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              messages.demoExitSheetTitle,
              textAlign: TextAlign.center,
              style: tokens.typography.styles.heading.heading3.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
            ),
            SizedBox(height: tokens.spacing.step3),
            Text(
              messages.demoExitSheetBody,
              textAlign: TextAlign.center,
              style: tokens.typography.styles.body.bodyMedium.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
            SizedBox(height: tokens.spacing.step6),
            DesignSystemModalActionBar(
              layout: DesignSystemModalActionBarLayout.compactPrimary,
              primary: DesignSystemButton(
                label: messages.demoExitConfirm,
                size: DesignSystemButtonSize.large,
                fullWidth: true,
                onPressed: resolved ? () => unawaited(_exitPlain()) : null,
              ),
              secondary: [
                if (hasCandidates)
                  DesignSystemButton(
                    label: messages.demoExitTakeWork,
                    variant: DesignSystemButtonVariant.secondary,
                    size: DesignSystemButtonSize.large,
                    onPressed: () => setState(() => _step = _ExitStep.pick),
                  ),
                DesignSystemButton(
                  label: MaterialLocalizations.of(context).cancelButtonLabel,
                  variant: DesignSystemButtonVariant.tertiary,
                  size: DesignSystemButtonSize.large,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            if (snapshot.hasError) ...[
              // A failed candidate read must not silently remove the copy
              // option — say so; the plain exit stays available.
              SizedBox(height: tokens.spacing.step3),
              Text(
                messages.demoExitCandidatesError,
                textAlign: TextAlign.center,
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: tokens.colors.alert.error.ink,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildPick(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return FutureBuilder<DemoCopyCandidates>(
      future: _candidates,
      builder: (context, snapshot) {
        final candidates = snapshot.data ?? DemoCopyCandidates.empty;
        final aiCandidateIds = {
          for (final provider in candidates.aiProviders) provider.id,
        };
        final allIds = {
          for (final entity in candidates.tasks) entity.meta.id,
          for (final entity in candidates.entries) entity.meta.id,
          ...aiCandidateIds,
        };
        final allSelected =
            allIds.isNotEmpty && _selected.length == allIds.length;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              messages.demoCopyTitle,
              textAlign: TextAlign.center,
              style: tokens.typography.styles.heading.heading3.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
            ),
            SizedBox(height: tokens.spacing.step3),
            Text(
              messages.demoCopyBody,
              textAlign: TextAlign.center,
              style: tokens.typography.styles.body.bodyMedium.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
            SizedBox(height: tokens.spacing.step4),
            DesignSystemSelectionRow(
              title: messages.demoCopySelectAll,
              type: DesignSystemSelectionRowType.multiSelect,
              selected: allSelected,
              showSelectedBackground: false,
              onTap: () => setState(() {
                if (allSelected) {
                  _selected.clear();
                } else {
                  _selected
                    ..clear()
                    ..addAll(allIds);
                }
              }),
            ),
            if (candidates.tasks.isNotEmpty)
              _CandidateSection(
                title: messages.demoCopySectionTasks,
                items: [
                  for (final entity in candidates.tasks)
                    (
                      id: entity.meta.id,
                      title: demoCopyCandidateTitle(context, entity),
                    ),
                ],
                selected: _selected,
                onToggle: _toggle,
              ),
            if (candidates.entries.isNotEmpty)
              _CandidateSection(
                title: messages.demoCopySectionEntries,
                items: [
                  for (final entity in candidates.entries)
                    (
                      id: entity.meta.id,
                      title: demoCopyCandidateTitle(context, entity),
                    ),
                ],
                selected: _selected,
                onToggle: _toggle,
              ),
            if (candidates.aiProviders.isNotEmpty)
              _CandidateSection(
                title: messages.demoCopySectionAiSetup,
                items: [
                  for (final provider in candidates.aiProviders)
                    (id: provider.id, title: provider.name),
                ],
                selected: _selected,
                onToggle: _toggle,
              ),
            SizedBox(height: tokens.spacing.step6),
            DesignSystemButton(
              label: messages.demoCopyConfirm,
              size: DesignSystemButtonSize.large,
              fullWidth: true,
              onPressed: _selected.isEmpty
                  ? null
                  : () => unawaited(_copyAndExit(aiCandidateIds)),
            ),
            SizedBox(height: tokens.spacing.step2),
            DesignSystemButton(
              label: MaterialLocalizations.of(context).cancelButtonLabel,
              variant: DesignSystemButtonVariant.tertiary,
              size: DesignSystemButtonSize.large,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  void _toggle(String id) => setState(() {
    if (!_selected.remove(id)) _selected.add(id);
  });

  Widget _buildWorking(BuildContext context) {
    final tokens = context.designTokens;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: tokens.spacing.step4),
        const CircularProgressIndicator(),
        if (_copying) ...[
          SizedBox(height: tokens.spacing.step5),
          Text(
            context.messages.demoCopyProgress,
            textAlign: TextAlign.center,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ],
        SizedBox(height: tokens.spacing.step4),
      ],
    );
  }
}

class _CandidateSection extends StatelessWidget {
  const _CandidateSection({
    required this.title,
    required this.items,
    required this.selected,
    required this.onToggle,
  });

  final String title;
  final List<({String id, String title})> items;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(
            top: tokens.spacing.step4,
            bottom: tokens.spacing.step2,
          ),
          child: Text(
            title,
            style: tokens.typography.styles.subtitle.subtitle2.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ),
        for (final item in items)
          DesignSystemSelectionRow(
            title: item.title,
            type: DesignSystemSelectionRowType.multiSelect,
            selected: selected.contains(item.id),
            showSelectedBackground: false,
            onTap: () => onToggle(item.id),
          ),
      ],
    );
  }
}

/// Row label for a copy candidate: the task title, the entry text's first
/// line, or — for media without any text — the entry's localized date.
@visibleForTesting
String demoCopyCandidateTitle(BuildContext context, JournalEntity entity) {
  final fromTask = entity.maybeMap(
    task: (task) => task.data.title,
    orElse: () => null,
  );
  if (fromTask != null && fromTask.trim().isNotEmpty) return fromTask;
  final text = entity.entryText?.plainText.trim() ?? '';
  if (text.isNotEmpty) return text.split('\n').first;
  final localeTag = Localizations.localeOf(context).toLanguageTag();
  return DateFormat.yMMMd(localeTag).format(entity.meta.dateFrom);
}
