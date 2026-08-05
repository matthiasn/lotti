import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/demo/copy/demo_copy_candidates.dart';
import 'package:lotti/features/demo/state/demo_mode_gateway.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// Opens the demo exit sheet: step 1 confirms leaving (the demo world stays
/// saved), step 2 — reachable only when the user created something — picks
/// what to copy into the real journal before exiting.
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
  }

  static Future<DemoCopyCandidates> _loadFromActiveWorld() =>
      loadDemoCopyCandidates(
        journalDb: getIt<JournalDb>(),
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
      if (mounted) setState(() => _step = _ExitStep.confirm);
    }
  }

  Future<void> _copyAndExit() async {
    setState(() {
      _copying = true;
      _step = _ExitStep.working;
    });
    try {
      await widget.gateway.exitWithCopy(selectedIds: Set.of(_selected));
    } catch (exception, stackTrace) {
      _logError(exception, stackTrace);
      if (mounted) setState(() => _step = _ExitStep.pick);
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
            DesignSystemButton(
              label: messages.demoExitConfirm,
              size: DesignSystemButtonSize.large,
              fullWidth: true,
              onPressed: () => unawaited(_exitPlain()),
            ),
            if (hasCandidates) ...[
              SizedBox(height: tokens.spacing.step3),
              DesignSystemButton(
                label: messages.demoExitTakeWork,
                variant: DesignSystemButtonVariant.secondary,
                size: DesignSystemButtonSize.large,
                fullWidth: true,
                onPressed: () => setState(() => _step = _ExitStep.pick),
              ),
            ],
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

  Widget _buildPick(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return FutureBuilder<DemoCopyCandidates>(
      future: _candidates,
      builder: (context, snapshot) {
        final candidates = snapshot.data ?? DemoCopyCandidates.empty;
        final allIds = {
          for (final entity in candidates.tasks) entity.meta.id,
          for (final entity in candidates.entries) entity.meta.id,
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
                entities: candidates.tasks,
                selected: _selected,
                onToggle: _toggle,
              ),
            if (candidates.entries.isNotEmpty)
              _CandidateSection(
                title: messages.demoCopySectionEntries,
                entities: candidates.entries,
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
                  : () => unawaited(_copyAndExit()),
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
    required this.entities,
    required this.selected,
    required this.onToggle,
  });

  final String title;
  final List<JournalEntity> entities;
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
        for (final entity in entities)
          DesignSystemSelectionRow(
            title: demoCopyCandidateTitle(context, entity),
            type: DesignSystemSelectionRowType.multiSelect,
            selected: selected.contains(entity.meta.id),
            showSelectedBackground: false,
            onTap: () => onToggle(entity.meta.id),
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
