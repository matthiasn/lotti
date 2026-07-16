import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/ui/widgets/category_picker_sheet.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/category_color.dart';
import 'package:lotti/features/daily_os_next/ui/time_format.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/calendar_pickers/design_system_date_picker_modal.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/entry_datetime_multipage_modal.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/entry_datetime_range.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:lotti/widgets/settings/settings_picker_field.dart';

/// Atomic draft returned by [DayBlockEditModal].
///
/// The modal never persists a partial edit: even the nested start/end page
/// only mutates this draft. The caller commits every changed field together
/// after the overview's primary action is pressed.
@immutable
class DayBlockEditResult {
  const DayBlockEditResult({
    required this.title,
    required this.category,
    required this.start,
    required this.end,
  });

  final String title;
  final DayAgentCategory category;
  final DateTime start;
  final DateTime end;
}

/// Design-system editor for a planned Daily OS calendar block.
///
/// The overview follows the app's recent modal form language. Start/end opens
/// a second page backed by the same responsive wheels and duration status used
/// by time-recording entries. Task-owned title/category fields stay read-only;
/// the task remains their source of truth.
class DayBlockEditModal {
  static Future<DayBlockEditResult?> show({
    required BuildContext context,
    required TimeBlock block,
    List<CategoryDefinition>? categoryOptions,
    VoidCallback? onOpenTask,
  }) async {
    final tokens = context.designTokens;
    final session = _BlockEditSession(
      title: block.title,
      category: block.category,
      range: EntryDateTimeRange.fromBounds(block.start, block.end),
    );
    return ModalUtils.showMultiPageModal<DayBlockEditResult>(
      context: context,
      pageIndexNotifier: session.pageIndexNotifier,
      modalTypeBuilderOverride: entryDateTimeModalTypeBuilder,
      modalDecorator: (modal) => _BlockEditSessionHost(
        session: session,
        child: modal,
      ),
      pageListBuilder: (modalContext) => [
        ModalUtils.modalSheetPage(
          context: modalContext,
          titleWidget: _modalTitle(modalContext),
          showCloseButton: true,
          padding: EdgeInsets.fromLTRB(
            tokens.spacing.step5,
            tokens.spacing.step3,
            tokens.spacing.step5,
            DesignSystemGlassActionFooter.reservedHeight,
          ),
          stickyActionBar: _SaveActionBar(
            block: block,
            titleController: session.titleController,
            categoryNotifier: session.categoryNotifier,
            rangeNotifier: session.rangeNotifier,
          ),
          child: _BlockEditOverview(
            block: block,
            titleController: session.titleController,
            categoryNotifier: session.categoryNotifier,
            rangeNotifier: session.rangeNotifier,
            categoryOptions: categoryOptions,
            onEditTime: () => session.pageIndexNotifier.value = 1,
            onOpenTask: onOpenTask == null
                ? null
                : () {
                    Navigator.of(modalContext).pop();
                    onOpenTask();
                  },
          ),
        ),
        ModalUtils.modalSheetPage(
          context: modalContext,
          title: modalContext.messages.dailyOsNextBlockEditTimeLabel,
          showCloseButton: true,
          onTapBack: () => session.pageIndexNotifier.value = 0,
          padding: EdgeInsets.fromLTRB(
            tokens.spacing.step5,
            tokens.spacing.step5,
            tokens.spacing.step5,
            tokens.spacing.step11 + tokens.spacing.step6,
          ),
          stickyActionBar: DesignSystemDatePickerActionBar(
            onClear: null,
            onDone: () => session.pageIndexNotifier.value = 0,
          ),
          child: EntryDateTimeEditor(
            session.rangeNotifier,
            showDateControls: false,
          ),
        ),
      ],
    );
  }

  static Widget _modalTitle(BuildContext context) {
    final tokens = context.designTokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.edit_calendar_rounded,
          size: tokens.spacing.step6,
          color: tokens.colors.interactive.enabled,
        ),
        SizedBox(width: tokens.spacing.step3),
        Text(
          context.messages.dailyOsNextBlockEditTitle,
          style: ModalUtils.modalTitleStyle(context),
        ),
      ],
    );
  }
}

class _BlockEditSession {
  _BlockEditSession({
    required String title,
    required DayAgentCategory category,
    required EntryDateTimeRange range,
  }) : titleController = TextEditingController(text: title),
       categoryNotifier = ValueNotifier(category),
       rangeNotifier = ValueNotifier(range);

  final TextEditingController titleController;
  final ValueNotifier<DayAgentCategory> categoryNotifier;
  final ValueNotifier<EntryDateTimeRange> rangeNotifier;
  final ValueNotifier<int> pageIndexNotifier = ValueNotifier(0);

  void dispose() {
    titleController.dispose();
    categoryNotifier.dispose();
    rangeNotifier.dispose();
    pageIndexNotifier.dispose();
  }
}

/// Owns the draft for the complete route lifetime, including the reverse
/// transition after Navigator.pop. Disposing it in the static `show` method's
/// `finally` would be too early because Wolt still paints the outgoing page for
/// that transition.
class _BlockEditSessionHost extends StatefulWidget {
  const _BlockEditSessionHost({required this.session, required this.child});

  final _BlockEditSession session;
  final Widget child;

  @override
  State<_BlockEditSessionHost> createState() => _BlockEditSessionHostState();
}

class _BlockEditSessionHostState extends State<_BlockEditSessionHost> {
  @override
  void dispose() {
    widget.session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _BlockEditOverview extends StatelessWidget {
  const _BlockEditOverview({
    required this.block,
    required this.titleController,
    required this.categoryNotifier,
    required this.rangeNotifier,
    required this.categoryOptions,
    required this.onEditTime,
    required this.onOpenTask,
  });

  final TimeBlock block;
  final TextEditingController titleController;
  final ValueNotifier<DayAgentCategory> categoryNotifier;
  final ValueNotifier<EntryDateTimeRange> rangeNotifier;
  final List<CategoryDefinition>? categoryOptions;
  final VoidCallback onEditTime;
  final VoidCallback? onOpenTask;

  bool get _taskOwned => block.taskId?.trim().isNotEmpty ?? false;
  bool get _identityEditable =>
      !_taskOwned && block.type != TimeBlockType.buffer;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return AnimatedBuilder(
      animation: Listenable.merge([categoryNotifier, rangeNotifier]),
      builder: (context, _) {
        final category = categoryNotifier.value;
        final range = rangeNotifier.value;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_identityEditable)
              DesignSystemPickerSection(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DesignSystemTextInput(
                      controller: titleController,
                      label: context.messages.dailyOsNextBlockEditNameLabel,
                      leadingIcon: Icons.title_rounded,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    SizedBox(height: tokens.spacing.step5),
                    SettingsPickerField(
                      label: context.messages.dailyOsNextBlockEditCategoryLabel,
                      valueText: category.name,
                      leading: _CategoryDot(category: category),
                      onTap: () => _pickCategory(context),
                    ),
                  ],
                ),
              )
            else if (_taskOwned)
              DesignSystemPickerSection(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ReadOnlyValue(
                      label: context.messages.dailyOsNextBlockEditNameLabel,
                      value: block.title,
                    ),
                    SizedBox(height: tokens.spacing.step5),
                    _ReadOnlyValue(
                      label: context.messages.dailyOsNextBlockEditCategoryLabel,
                      value: category.name,
                      leading: _CategoryDot(category: category),
                    ),
                    if (onOpenTask != null) ...[
                      SizedBox(height: tokens.spacing.step5),
                      DesignSystemButton(
                        label: context.messages.dailyOsNextBlockEditOpenTask,
                        leadingIcon: Icons.open_in_new_rounded,
                        variant: DesignSystemButtonVariant.secondary,
                        size: DesignSystemButtonSize.large,
                        fullWidth: true,
                        onPressed: onOpenTask,
                      ),
                    ],
                  ],
                ),
              ),
            if (_identityEditable || _taskOwned)
              SizedBox(height: tokens.spacing.step6),
            DesignSystemPickerSection(
              child: SettingsPickerField(
                label: context.messages.dailyOsNextBlockEditTimeLabel,
                valueText: formatClockRange(
                  context,
                  range.dateFrom,
                  range.dateTo,
                ),
                leading: Icon(
                  Icons.schedule_rounded,
                  color: tokens.colors.interactive.enabled,
                  size: tokens.spacing.step6,
                ),
                onTap: onEditTime,
              ),
            ),
            if (block.reason?.trim().isNotEmpty ?? false) ...[
              SizedBox(height: tokens.spacing.step6),
              DesignSystemPickerSection(
                child: _ReadOnlyValue(
                  label: context.messages.dailyOsNextBlockEditWhyLabel,
                  value: block.reason!.trim(),
                  leading: Icon(
                    Icons.auto_awesome_rounded,
                    color: tokens.colors.interactive.enabled,
                    size: tokens.spacing.step6,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _pickCategory(BuildContext context) async {
    final result = await showCategoryPicker(
      context: context,
      title: context.messages.dailyOsNextBlockEditCategoryLabel,
      currentCategoryId: categoryNotifier.value.id,
      options: categoryOptions,
      allowCreate: false,
    );
    if (result is! CategoryPicked) return;
    categoryNotifier.value = _projectCategory(
      result.category,
      fallback: categoryNotifier.value,
    );
  }
}

class _ReadOnlyValue extends StatelessWidget {
  const _ReadOnlyValue({
    required this.label,
    required this.value,
    this.leading,
  });

  final String label;
  final String value;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: tokens.typography.styles.subtitle.subtitle2.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leading != null) ...[
              leading!,
              SizedBox(width: tokens.spacing.step3),
            ],
            Expanded(
              child: Text(
                value,
                style: tokens.typography.styles.body.bodyMedium.copyWith(
                  color: tokens.colors.text.highEmphasis,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CategoryDot extends StatelessWidget {
  const _CategoryDot({required this.category});

  final DayAgentCategory category;

  @override
  Widget build(BuildContext context) {
    final size = context.designTokens.spacing.step4;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: categoryColorFromHex(category.colorHex),
      ),
    );
  }
}

class _SaveActionBar extends StatelessWidget {
  const _SaveActionBar({
    required this.block,
    required this.titleController,
    required this.categoryNotifier,
    required this.rangeNotifier,
  });

  final TimeBlock block;
  final TextEditingController titleController;
  final ValueNotifier<DayAgentCategory> categoryNotifier;
  final ValueNotifier<EntryDateTimeRange> rangeNotifier;

  bool get _identityEditable =>
      !(block.taskId?.trim().isNotEmpty ?? false) &&
      block.type != TimeBlockType.buffer;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        titleController,
        categoryNotifier,
        rangeNotifier,
      ]),
      builder: (context, _) {
        final title = titleController.text.trim();
        final category = categoryNotifier.value;
        final range = rangeNotifier.value;
        final start = range.dateFrom;
        final end = range.dateTo;
        final insidePlanDay = _rangeIsInsidePlanDay(
          start: start,
          end: end,
          planDate: block.start,
        );
        final changed =
            start != block.start ||
            end != block.end ||
            (_identityEditable && title != block.title) ||
            (_identityEditable && category != block.category);
        final canSave =
            (!_identityEditable || title.isNotEmpty) &&
            end.isAfter(start) &&
            insidePlanDay &&
            changed;

        return DesignSystemGlassActionFooter(
          child: DesignSystemButton(
            label: context.messages.dailyOsNextBlockEditSave,
            leadingIcon: Icons.check_rounded,
            size: DesignSystemButtonSize.large,
            fullWidth: true,
            onPressed: canSave
                ? () => Navigator.of(context).pop(
                    DayBlockEditResult(
                      title: _identityEditable ? title : block.title,
                      category: _identityEditable ? category : block.category,
                      start: start,
                      end: end,
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }
}

DayAgentCategory _projectCategory(
  CategoryDefinition definition, {
  required DayAgentCategory fallback,
}) {
  return DayAgentCategory(
    id: definition.id,
    name: definition.name,
    colorHex: normalizeCategoryColorHex(definition.color) ?? fallback.colorHex,
  );
}

bool _rangeIsInsidePlanDay({
  required DateTime start,
  required DateTime end,
  required DateTime planDate,
}) {
  final dayStart = planDate.isUtc
      ? DateTime.utc(planDate.year, planDate.month, planDate.day)
      : DateTime(planDate.year, planDate.month, planDate.day);
  final dayEnd = dayStart.add(const Duration(days: 1));
  return !start.isBefore(dayStart) && !end.isAfter(dayEnd);
}
