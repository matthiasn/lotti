import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/action_modal/ds_action_modal.dart';
import 'package:lotti/features/design_system/components/action_modal/ds_action_row.dart';
import 'package:lotti/features/design_system/components/action_modal/ds_action_toggle_chip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent buildDesignSystemActionModalWidgetbookComponent() {
  return WidgetbookComponent(
    name: 'Action modal',
    useCases: [
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

/// The modal's content as it appears inside the sheet, on a scrim-ish page —
/// Widgetbook renders a widget, not a route, so the presentation layer
/// ([DsActionModal.show]) is stood in for by the surface below.
class _ActionModalPreview extends StatefulWidget {
  const _ActionModalPreview({required this.title, required this.variant});

  final String title;
  final _ActionModalVariant variant;

  @override
  State<_ActionModalPreview> createState() => _ActionModalPreviewState();
}

class _ActionModalPreviewState extends State<_ActionModalPreview> {
  bool _starred = false;
  bool _private = true;
  bool _flagged = true;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return ColoredBox(
      color: tokens.colors.background.level01,
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(tokens.spacing.step9),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.colors.background.level02,
              borderRadius: BorderRadius.circular(tokens.radii.l),
              border: Border.all(color: tokens.colors.decorative.level01),
            ),
            child: SizedBox(
              width: 460,
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
          ),
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
