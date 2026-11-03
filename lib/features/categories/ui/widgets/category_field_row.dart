import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_compact.dart';
import 'package:lotti/features/categories/ui/widgets/category_picker_sheet.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:material_ui/material_ui.dart';

/// A subject's category as a field of its editor — a person's, a goal's:
/// the text inputs' own label above a box of the same shape and border,
/// holding the category's icon and name and a down chevron, opening the
/// shared picker on tap. One field for both editors, sitting under an
/// *Agent name* input without changing idiom, so a person and a goal are
/// filed the same way.
///
/// Clearing happens through the picker's own no-category row rather than an
/// inline ×, so there is one way to change this field and one place that
/// knows what the choices are. [onChanged] reports the picked category's id,
/// or null for cleared; while it is null the field shows its value but
/// cannot be changed — a host still reading the current one.
class CategoryFieldRow extends ConsumerStatefulWidget {
  const CategoryFieldRow({
    required this.categoryId,
    required this.onChanged,
    super.key,
  });

  final String? categoryId;
  final ValueChanged<String?>? onChanged;

  @override
  ConsumerState<CategoryFieldRow> createState() => _CategoryFieldRowState();
}

class _CategoryFieldRowState extends ConsumerState<CategoryFieldRow> {
  var _hovered = false;

  Future<void> _pick() async {
    final result = await showCategoryPicker(
      context: context,
      title: context.messages.habitCategoryLabel,
      currentCategoryId: widget.categoryId,
    );
    // null = dismissed (no change); otherwise apply the pick or the clear,
    // which the picker reports as a category-less result.
    if (result == null) return;
    widget.onChanged?.call(result.categoryOrNull?.id);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final category = ref
        .watch(entitiesCacheServiceProvider)
        ?.getCategoryById(widget.categoryId);
    final enabled = widget.onChanged != null;
    final radius = BorderRadius.circular(tokens.radii.l);
    final value = category?.name ?? messages.habitCategoryHint;

    return Semantics(
      button: true,
      enabled: enabled,
      label: '${messages.habitCategoryLabel}: $value',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            messages.habitCategoryLabel,
            style: tokens.typography.styles.subtitle.subtitle2.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step2),
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              key: const ValueKey('category-field'),
              borderRadius: radius,
              onTap: enabled ? _pick : null,
              onHover: (value) => setState(() => _hovered = value),
              child: Ink(
                decoration: BoxDecoration(
                  color: tokens.colors.background.level01,
                  borderRadius: radius,
                  border: Border.all(
                    color: designSystemFieldBorderColor(
                      tokens,
                      hovered: _hovered && enabled,
                    ),
                  ),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: tokens.spacing.step9),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: tokens.spacing.step4,
                      vertical: tokens.spacing.step2,
                    ),
                    child: Row(
                      children: [
                        // The category's own icon, as the person header's
                        // selector and every other row naming it draw it.
                        if (category != null) ...[
                          CategoryIconCompact(
                            category.id,
                            key: const ValueKey('category-field-dot'),
                          ),
                          SizedBox(width: tokens.spacing.step3),
                        ],
                        Expanded(
                          child: Text(
                            value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tokens.typography.styles.body.bodyMedium
                                .copyWith(
                                  color: category == null
                                      ? tokens.colors.text.lowEmphasis
                                      : tokens.colors.text.highEmphasis,
                                ),
                          ),
                        ),
                        SizedBox(width: tokens.spacing.step3),
                        Icon(
                          LottiIcons.chevronDown,
                          key: const ValueKey('category-field-chevron'),
                          size: IconSizes.m,
                          color: tokens.colors.text.mediumEmphasis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
