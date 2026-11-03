import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_compact.dart';
import 'package:lotti/features/categories/ui/widgets/category_picker_sheet.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_picker_field.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:material_ui/material_ui.dart';

/// A subject's category as a field of its editor — a person's, a goal's: a
/// [DesignSystemPickerField] holding the category's icon and name, opening
/// the shared picker on tap. One field for both editors, sitting under an
/// *Agent name* input without changing idiom, so a person and a goal are
/// filed the same way.
///
/// Clearing happens through the picker's own no-category row rather than an
/// inline ×, so there is one way to change this field and one place that
/// knows what the choices are. [onChanged] reports the picked category's id,
/// or null for cleared; while it is null the field shows its value but
/// cannot be changed — a host still reading the current one.
class CategoryFieldRow extends ConsumerWidget {
  const CategoryFieldRow({
    required this.categoryId,
    required this.onChanged,
    this.filled = true,
    super.key,
  });

  final String? categoryId;
  final ValueChanged<String?>? onChanged;

  /// False inside a modal sheet; see [DesignSystemPickerField.filled].
  final bool filled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = context.messages;
    final category = ref
        .watch(entitiesCacheServiceProvider)
        ?.getCategoryById(categoryId);
    final onChanged = this.onChanged;

    return DesignSystemPickerField(
      fieldKey: const ValueKey('category-field'),
      filled: filled,
      trailingKey: const ValueKey('category-field-chevron'),
      label: messages.habitCategoryLabel,
      value: category?.name,
      placeholder: messages.habitCategoryHint,
      // Every picked field leads with a glyph, so its value starts where
      // the others' do: the category's own icon, or the neutral one.
      leading: category == null
          ? Icon(
              LottiIcons.category,
              size: IconSizes.m,
              color: context.designTokens.colors.text.lowEmphasis,
            )
          : CategoryIconCompact(
              category.id,
              key: const ValueKey('category-field-dot'),
            ),
      onTap: onChanged == null
          ? null
          : () async {
              final result = await showCategoryPicker(
                context: context,
                title: messages.habitCategoryLabel,
                currentCategoryId: categoryId,
              );
              // null = dismissed (no change); otherwise apply the pick or
              // the clear, which the picker reports as a category-less
              // result.
              if (result == null) return;
              onChanged(result.categoryOrNull?.id);
            },
    );
  }
}
