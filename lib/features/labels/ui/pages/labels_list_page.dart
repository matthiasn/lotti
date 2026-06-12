import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_chip.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/settings/ui/pages/definitions_list_page.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/color.dart';

/// Embeddable body alias for the Settings V2 detail pane (plan
/// step 8). See `CategoriesListBody` for the polish note about the
/// duplicate header.
class LabelsListBody extends StatelessWidget {
  const LabelsListBody({super.key});

  @override
  Widget build(BuildContext context) => const LabelsListPage();
}

/// Labels list on the shared [DefinitionsListPage] shell.
///
/// Each label row leads with a [DefinitionIconChip] color swatch (label
/// color, first-letter fallback), followed by the label name, a
/// usage-count subtitle, status icons, and a chevron. Search also matches
/// descriptions, and a query with no match offers creating a label with
/// that name.
class LabelsListPage extends ConsumerWidget {
  const LabelsListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = context.messages;
    final usageCounts = ref
        .watch(labelUsageStatsProvider)
        .maybeWhen(
          data: (value) => value,
          orElse: () => const <String, int>{},
        );

    return DefinitionsListPage<LabelDefinition>(
      itemsAsync: ref.watch(labelsStreamProvider),
      title: messages.settingsLabelsTitle,
      searchHint: messages.settingsLabelsSearchHint,
      displayName: (label) => label.name,
      searchText: (label) => '${label.name} ${label.description ?? ''}',
      emptyIcon: Icons.label_outline,
      emptyTitle: messages.settingsLabelsEmptyState,
      emptyHint: messages.settingsLabelsEmptyStateHint,
      noMatchMessage: messages.settingsLabelsNoMatchQuery,
      noMatchActionBuilder: (context, query) => DesignSystemButton(
        label: context.messages.settingsLabelsNoMatchCreate(query),
        leadingIcon: Icons.add,
        onPressed: () {
          final encoded = Uri.encodeComponent(query);
          beamToNamed('/settings/labels/create?name=$encoded');
        },
      ),
      errorTitle: messages.settingsLabelsErrorLoading,
      createLabel: messages.settingsLabelsCreateTitle,
      onCreate: () => beamToNamed('/settings/labels/create'),
      itemBuilder: (context, label, {required bool showDivider}) =>
          _LabelListItem(
            label: label,
            usageCount: usageCounts[label.id] ?? 0,
            showDivider: showDivider,
          ),
    );
  }
}

/// A single label row using [DesignSystemListItem].
class _LabelListItem extends StatelessWidget {
  const _LabelListItem({
    required this.label,
    required this.usageCount,
    required this.showDivider,
  });

  final LabelDefinition label;
  final int usageCount;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final isPrivate = label.private ?? false;

    return DesignSystemListItem(
      title: label.name,
      // Stable subtitle semantics: always the usage count, never the
      // description — every row's second line answers the same question.
      subtitle: context.messages.settingsLabelsUsageCount(usageCount),
      leading: DefinitionIconChip(
        background: colorFromCssHex(
          label.color,
          substitute: Theme.of(context).colorScheme.primary,
        ),
        name: label.name,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPrivate)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                Icons.lock_outline,
                size: 18,
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          Icon(
            Icons.chevron_right_rounded,
            size: tokens.spacing.step6,
            color: tokens.colors.text.lowEmphasis,
          ),
        ],
      ),
      showDivider: showDivider,
      dividerIndent:
          tokens.spacing.step5 +
          DefinitionIconChip.defaultSize +
          tokens.spacing.step3,
      onTap: () => beamToNamed('/settings/labels/${label.id}'),
    );
  }
}
