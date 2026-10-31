import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/categories/ui/widgets/category_picker_sheet.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/color.dart';
import 'package:material_ui/material_ui.dart';

/// A subject's category as one quiet row — a person's, a goal's: its name
/// beside a colour dot, opening the shared picker on tap. The dot is the
/// whole colour treatment — a second large avatar would compete with the
/// person's own (design 2026-09-06 §6). One row for both, so a person and a
/// goal are filed the same way.
///
/// Clearing happens through the picker's own no-category row rather than an
/// inline ×, so there is one way to change this field and one place that
/// knows what the choices are. [onChanged] reports the picked category's id,
/// or null for cleared.
class CategoryFieldRow extends ConsumerWidget {
  const CategoryFieldRow({
    required this.categoryId,
    required this.onChanged,
    super.key,
  });

  final String? categoryId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final category = ref
        .watch(entitiesCacheServiceProvider)
        ?.getCategoryById(categoryId);

    return InkWell(
      key: const ValueKey('category-field'),
      borderRadius: BorderRadius.circular(tokens.radii.m),
      onTap: () async {
        final result = await showCategoryPicker(
          context: context,
          title: messages.habitCategoryLabel,
          currentCategoryId: categoryId,
        );
        // null = dismissed (no change); otherwise apply the pick or the
        // clear, which the picker reports as a category-less result.
        if (result == null) return;
        onChanged(result.categoryOrNull?.id);
      },
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: tokens.spacing.step2),
        child: Row(
          children: [
            // The swatch leads the value, as a category's colour does on
            // every other row that names one; trailing, it sat where the
            // chevron belongs.
            if (category != null) ...[
              Container(
                key: const ValueKey('category-field-dot'),
                width: tokens.spacing.step3,
                height: tokens.spacing.step3,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorFromCssHex(
                    category.color,
                    substitute: tokens.colors.text.lowEmphasis,
                  ),
                ),
              ),
              SizedBox(width: tokens.spacing.step3),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    messages.habitCategoryLabel,
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: tokens.colors.text.lowEmphasis,
                    ),
                  ),
                  SizedBox(height: tokens.spacing.step1),
                  Text(
                    category?.name ?? messages.habitCategoryHint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: category == null
                          ? tokens.colors.text.lowEmphasis
                          : tokens.colors.text.highEmphasis,
                    ),
                  ),
                ],
              ),
            ),
            // The chevron the context chips wear, and it ends the row:
            // without it the row read as a read-out between two fields,
            // not the selector it is.
            SizedBox(width: tokens.spacing.step3),
            Icon(
              LottiIcons.chevronDown,
              key: const ValueKey('category-field-chevron'),
              size: IconSizes.s,
              color: tokens.colors.text.lowEmphasis,
            ),
          ],
        ),
      ),
    );
  }
}
