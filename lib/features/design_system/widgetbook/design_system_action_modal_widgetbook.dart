import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/action_modal/ds_action_modal.dart';
import 'package:lotti/features/design_system/components/action_modal/ds_action_row.dart';
import 'package:lotti/features/design_system/components/action_modal/ds_action_toggle_chip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent buildDesignSystemActionModalWidgetbookComponent() {
  return WidgetbookComponent(
    name: 'Action modal',
    useCases: [
      // Overview first, like every other component in the catalogue — and the
      // right lead here anyway: the point of this component is that the two
      // sheets are one pattern, which only reads when they sit side by side.
      WidgetbookUseCase(
        name: 'Overview',
        builder: (context) => const _ActionModalOverview(),
      ),
      WidgetbookUseCase(
        name: 'Entry actions',
        builder: (context) => const _ActionModalPreview(
          title: 'Actions',
          variant: _ActionModalVariant.entryActions,
        ),
      ),
      WidgetbookUseCase(
        name: 'Add sheet',
        builder: (context) => const _ActionModalPreview(
          title: 'Add',
          variant: _ActionModalVariant.addSheet,
        ),
      ),
    ],
  );
}

enum _ActionModalVariant { entryActions, addSheet }

/// Both sheets on one canvas, which is the only view that shows the thing the
/// component exists for — that they are the same modal wearing two tones.
class _ActionModalOverview extends StatelessWidget {
  const _ActionModalOverview();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return ColoredBox(
      color: tokens.colors.background.level01,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(tokens.spacing.step9),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: tokens.spacing.step10,
          runSpacing: tokens.spacing.step10,
          children: const [
            _ActionModalSheet(
              title: 'Actions',
              variant: _ActionModalVariant.entryActions,
            ),
            _ActionModalSheet(
              title: 'Add',
              variant: _ActionModalVariant.addSheet,
            ),
          ],
        ),
      ),
    );
  }
}

/// One sheet on a scrim-ish page — Widgetbook renders a widget, not a route,
/// so the presentation layer ([DsActionModal.show]) is stood in for by the
/// surface below.
class _ActionModalPreview extends StatelessWidget {
  const _ActionModalPreview({required this.title, required this.variant});

  final String title;
  final _ActionModalVariant variant;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return ColoredBox(
      color: tokens.colors.background.level01,
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(tokens.spacing.step9),
          child: _ActionModalSheet(title: title, variant: variant),
        ),
      ),
    );
  }
}

/// The sheet itself: the real [DsActionModalHeader] and body inset inside a
/// stand-in for the modal's own surface.
class _ActionModalSheet extends StatefulWidget {
  const _ActionModalSheet({required this.title, required this.variant});

  final String title;
  final _ActionModalVariant variant;

  @override
  State<_ActionModalSheet> createState() => _ActionModalSheetState();
}

class _ActionModalSheetState extends State<_ActionModalSheet> {
  bool _starred = false;
  bool _private = true;
  bool _flagged = true;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.l),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      child: SizedBox(
        // The widest a sheet gets before the app switches to the dialog
        // branch — the app's own modal breakpoint rather than a number picked
        // to make the preview look right.
        width: WoltModalConfig.pageBreakpoint.toDouble(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DsActionModalHeader(title: widget.title),
            Padding(
              padding: DsActionModal.bodyPadding(context),
              child: switch (widget.variant) {
                _ActionModalVariant.entryActions => _entryActions(),
                _ActionModalVariant.addSheet => _addSheet(),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _entryActions() {
    return DsActionModalList(
      header: Wrap(
        spacing: context.designTokens.spacing.step3,
        runSpacing: context.designTokens.spacing.step3,
        children: [
          DsActionToggleChip(
            label: 'Favorite',
            icon: _starred ? LottiIconsFilled.star : LottiIcons.star,
            selected: _starred,
            onToggle: () => setState(() => _starred = !_starred),
          ),
          DsActionToggleChip(
            label: 'Private',
            icon: _private ? LottiIcons.lock : LottiIcons.unlocked,
            selected: _private,
            onToggle: () => setState(() => _private = !_private),
          ),
          DsActionToggleChip(
            label: 'Flagged',
            icon: _flagged ? LottiIconsFilled.flag : LottiIcons.flag,
            selected: _flagged,
            onToggle: () => setState(() => _flagged = !_flagged),
          ),
        ],
      ),
      destructive: DsActionRow(
        icon: LottiIcons.delete,
        title: 'Delete entry',
        tone: DsActionRowTone.destructive,
        onTap: () {},
      ),
      children: [
        DsActionRow(
          icon: LottiIcons.language,
          title: 'Set language',
          trailingValue: 'English',
          trailing: DsActionRowTrailing.chevron,
          onTap: () {},
        ),
        DsActionRow(
          icon: LottiIcons.link,
          title: 'Link from',
          trailing: DsActionRowTrailing.chevron,
          onTap: () {},
        ),
        DsActionRow(
          icon: LottiIcons.focus,
          title: 'Link to',
          trailing: DsActionRowTrailing.chevron,
          onTap: () {},
        ),
        DsActionRow(
          icon: LottiIcons.copy,
          title: 'Copy as text',
          onTap: () {},
        ),
        const DsActionRow(
          icon: LottiIcons.share,
          title: 'Share',
          trailing: DsActionRowTrailing.chevron,
          onTap: null,
        ),
      ],
    );
  }

  Widget _addSheet() {
    return DsActionModalList(
      children: [
        DsActionRow(
          icon: LottiIcons.note,
          title: 'Write a note',
          subtitle: 'Adds a linked note for details and thoughts',
          tone: DsActionRowTone.accent,
          trailing: DsActionRowTrailing.add,
          onTap: () {},
        ),
        DsActionRow(
          icon: LottiIcons.checkAll,
          title: 'Add a checklist',
          subtitle: 'Adds a list of checkable steps',
          tone: DsActionRowTone.accent,
          trailing: DsActionRowTrailing.add,
          onTap: () {},
        ),
        DsActionRow(
          icon: LottiIcons.mic,
          title: 'Record a voice note',
          subtitle: 'Opens the recorder without starting to record',
          tone: DsActionRowTone.accent,
          trailing: DsActionRowTrailing.chevron,
          onTap: () {},
        ),
        DsActionRow(
          icon: LottiIcons.addTask,
          title: 'Link a new task',
          subtitle: 'Creates and opens a new task linked to this one',
          tone: DsActionRowTone.accent,
          trailing: DsActionRowTrailing.chevron,
          onTap: () {},
        ),
        DsActionRow(
          icon: LottiIcons.screenshot,
          title: 'Capture a screenshot',
          subtitle: 'Closes this sheet, then captures the screen',
          tone: DsActionRowTone.accent,
          trailing: DsActionRowTrailing.add,
          onTap: () {},
        ),
      ],
    );
  }
}
