import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/checkboxes/design_system_checkbox.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_shared.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

typedef DesignSystemFilterOptionAppearanceResolver =
    DesignSystemFilterSelectionOptionAppearance? Function(String optionId);

@immutable
class DesignSystemFilterSelectionOptionAppearance {
  const DesignSystemFilterSelectionOptionAppearance({
    this.icon,
    this.foregroundColor,
    this.enabled = true,
  });

  final IconData? icon;
  final Color? foregroundColor;
  final bool enabled;
}

/// Shows a multi-select field selection modal for a task filter section.
///
/// Uses Wolt modal sheet — adapts between bottom sheet (mobile) and dialog
/// (desktop) automatically via [ModalUtils.modalTypeBuilder].
Future<DesignSystemTaskFilterState?>
showDesignSystemTaskFilterFieldSelectionModal({
  required BuildContext context,
  required DesignSystemTaskFilterState draftState,
  required DesignSystemTaskFilterSection section,
  DesignSystemFilterOptionAppearanceResolver? appearanceResolver,
}) async {
  final field = switch (section) {
    DesignSystemTaskFilterSection.status => draftState.statusField,
    DesignSystemTaskFilterSection.category => draftState.categoryField,
    DesignSystemTaskFilterSection.label => draftState.labelField,
    DesignSystemTaskFilterSection.project => draftState.projectField,
  };

  if (field == null) {
    return null;
  }

  // Only the Category section gets a search field — its option list is the
  // user's full category catalog and matches the Settings → Categories
  // Definition page. Status/label/project keep the simpler list layout.
  final searchHintText = section == DesignSystemTaskFilterSection.category
      ? context.messages.categorySearchPlaceholder
      : null;

  final selectedIds = await showDesignSystemFilterSelectionModal(
    context: context,
    title: field.label,
    options: field.options,
    initialSelectedIds: field.selectedIds,
    appearanceResolver: appearanceResolver,
    searchHintText: searchHintText,
  );

  if (selectedIds == null) {
    return null;
  }

  final updatedField = field.copyWith(selectedIds: selectedIds);
  return switch (section) {
    DesignSystemTaskFilterSection.status => draftState.copyWith(
      statusField: updatedField,
    ),
    DesignSystemTaskFilterSection.category => draftState.copyWith(
      categoryField: updatedField,
    ),
    DesignSystemTaskFilterSection.label => draftState.copyWith(
      labelField: updatedField,
    ),
    DesignSystemTaskFilterSection.project => draftState.copyWith(
      projectField: updatedField,
    ),
  };
}

/// Shows a generic multi-select filter selection modal.
///
/// Uses Wolt modal sheet — adapts between bottom sheet (mobile) and dialog
/// (desktop) automatically. The Done button is rendered as a sticky action bar
/// wrapped in [DesignSystemGlassStrip] so list rows scroll behind it.
///
/// Passing [searchHintText] adds a top-of-page search field that filters
/// options by case-insensitive substring match on the option label. When
/// omitted, the modal renders without a search bar (status-style layout).
Future<Set<String>?> showDesignSystemFilterSelectionModal({
  required BuildContext context,
  required String title,
  required List<DesignSystemTaskFilterOption> options,
  required Set<String> initialSelectedIds,
  DesignSystemFilterOptionAppearanceResolver? appearanceResolver,
  String? applyLabel,
  String? searchHintText,
}) async {
  final selectedIdsNotifier = ValueNotifier({...initialSelectedIds});
  final resolvedLabel = applyLabel ?? context.messages.doneButton;

  try {
    return await ModalUtils.showSinglePageModal<Set<String>>(
      context: context,
      title: title,
      padding: const EdgeInsets.only(left: 20, top: 8, right: 20, bottom: 20),
      stickyActionBarBuilder: (_) {
        return Builder(
          builder: (ctx) {
            final tokens = ctx.designTokens;
            final palette = DesignSystemFilterPalette.fromTokens(tokens);
            return DesignSystemGlassActionFooter(
              child: DesignSystemFilterActionButton(
                key: const ValueKey(
                  'design-system-filter-selection-apply',
                ),
                label: resolvedLabel,
                palette: palette,
                highlighted: true,
                textStyle: tokens.typography.styles.subtitle.subtitle1,
                onTap: () => Navigator.of(ctx).pop(
                  selectedIdsNotifier.value,
                ),
              ),
            );
          },
        );
      },
      builder: (modalContext) {
        return _DesignSystemFilterSelectionBody(
          options: options,
          selectedIdsNotifier: selectedIdsNotifier,
          appearanceResolver: appearanceResolver,
          searchHintText: searchHintText,
        );
      },
    );
  } finally {
    selectedIdsNotifier.dispose();
  }
}

class _DesignSystemFilterSelectionBody extends StatefulWidget {
  const _DesignSystemFilterSelectionBody({
    required this.options,
    required this.selectedIdsNotifier,
    required this.searchHintText,
    this.appearanceResolver,
  });

  final List<DesignSystemTaskFilterOption> options;
  final ValueNotifier<Set<String>> selectedIdsNotifier;
  final DesignSystemFilterOptionAppearanceResolver? appearanceResolver;
  final String? searchHintText;

  @override
  State<_DesignSystemFilterSelectionBody> createState() =>
      _DesignSystemFilterSelectionBodyState();
}

class _DesignSystemFilterSelectionBodyState
    extends State<_DesignSystemFilterSelectionBody> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
    final palette = DesignSystemFilterPalette.fromTokens(tokens);

    final queryLower = _query.trim().toLowerCase();
    final filteredOptions = queryLower.isEmpty
        ? widget.options
        : widget.options
              .where((o) => o.label.toLowerCase().contains(queryLower))
              .toList();

    final searchHintText = widget.searchHintText;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (searchHintText != null) ...[
          DesignSystemSearch(
            hintText: searchHintText,
            onChanged: (value) => setState(() => _query = value),
            onClear: () => setState(() => _query = ''),
          ),
          SizedBox(height: spacing.step5),
        ],
        if (filteredOptions.isEmpty)
          _DesignSystemFilterSelectionEmpty(palette: palette)
        else
          _DesignSystemFilterSelectionList(
            options: filteredOptions,
            selectedIdsNotifier: widget.selectedIdsNotifier,
            appearanceResolver: widget.appearanceResolver,
            palette: palette,
          ),
        const SizedBox(height: DesignSystemGlassActionFooter.reservedHeight),
      ],
    );
  }
}

/// Renders just the option rows. The [ValueListenableBuilder] on
/// `selectedIdsNotifier` is scoped to this subtree so a checkbox tap
/// rebuilds only the rows — not the search field in the parent
/// [_DesignSystemFilterSelectionBody]. Search keystrokes still rebuild
/// the full body (they have to, to recompute `filteredOptions`).
class _DesignSystemFilterSelectionList extends StatelessWidget {
  const _DesignSystemFilterSelectionList({
    required this.options,
    required this.selectedIdsNotifier,
    required this.appearanceResolver,
    required this.palette,
  });

  final List<DesignSystemTaskFilterOption> options;
  final ValueNotifier<Set<String>> selectedIdsNotifier;
  final DesignSystemFilterOptionAppearanceResolver? appearanceResolver;
  final DesignSystemFilterPalette palette;

  @override
  Widget build(BuildContext context) {
    final spacing = context.designTokens.spacing;
    return ValueListenableBuilder<Set<String>>(
      valueListenable: selectedIdsNotifier,
      builder: (ctx, selectedIds, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < options.length; index++) ...[
              _DesignSystemFilterSelectionRow(
                option: options[index],
                selected: selectedIds.contains(options[index].id),
                palette: palette,
                appearance: appearanceResolver?.call(options[index].id),
                onTap: () {
                  final next = {...selectedIds};
                  if (!next.add(options[index].id)) {
                    next.remove(options[index].id);
                  }
                  selectedIdsNotifier.value = next;
                },
              ),
              if (index != options.length - 1)
                Divider(
                  height: spacing.step6,
                  color: palette.dividerColor,
                ),
            ],
          ],
        );
      },
    );
  }
}

/// Empty placeholder shown when the search query filters out every option.
class _DesignSystemFilterSelectionEmpty extends StatelessWidget {
  const _DesignSystemFilterSelectionEmpty({required this.palette});

  final DesignSystemFilterPalette palette;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.step4),
      child: Text(
        context.messages.filterSelectionNoMatches,
        style: tokens.typography.styles.body.bodyMedium.copyWith(
          color: palette.secondaryText,
        ),
      ),
    );
  }
}

class _DesignSystemFilterSelectionRow extends StatelessWidget {
  const _DesignSystemFilterSelectionRow({
    required this.option,
    required this.selected,
    required this.palette,
    required this.onTap,
    this.appearance,
  });

  final DesignSystemTaskFilterOption option;
  final bool selected;
  final DesignSystemFilterPalette palette;
  final VoidCallback onTap;
  final DesignSystemFilterSelectionOptionAppearance? appearance;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
    final enabled = appearance?.enabled ?? true;
    final foregroundColor = enabled
        ? appearance?.foregroundColor ?? palette.primaryText
        : palette.secondaryText.withValues(alpha: 0.5);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('design-system-filter-selection-option-${option.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.step1,
            vertical: spacing.step4,
          ),
          child: Row(
            children: [
              if (appearance?.icon case final icon?) ...[
                Icon(
                  icon,
                  color: foregroundColor,
                  size: 28,
                ),
                SizedBox(width: spacing.step4),
              ],
              Expanded(
                child: Text(
                  option.label,
                  style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                    color: foregroundColor,
                  ),
                ),
              ),
              DesignSystemCheckbox(
                value: selected,
                onChanged: enabled ? (_) => onTap() : null,
                semanticsLabel: option.label,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
