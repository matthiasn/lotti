import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/category_icon/category_icon.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_compact.dart';
import 'package:lotti/features/categories/ui/widgets/category_picker_sheet.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/repositories/entry_category_move.dart';
import 'package:material_ui/material_ui.dart';

/// The person's category above their name, as a selector: the category's
/// icon, its name and a down chevron, opening the shared category picker —
/// the one a journal entry, a task and an event reassign their category
/// with.
///
/// A pick moves the person through [entryCategoryMoveProvider], the same
/// move the person editor saves with, so their check-ins, notes, voice
/// notes, photos and meetings travel with them, and the agent follows the
/// new category's profile on its next run. Dismissing the picker changes
/// nothing; a failed move says so and leaves the old category showing.
///
/// A person in no category gets the same control, worded as the offer to
/// set one, so the place to change it never disappears.
class PersonCategoryCrumb extends ConsumerStatefulWidget {
  const PersonCategoryCrumb({
    required this.relationshipId,
    required this.categoryId,
    required this.categoryName,
    super.key,
  });

  final String relationshipId;
  final String? categoryId;

  /// The category's display name; null when the person is in none, or the
  /// category is unknown on this device.
  final String? categoryName;

  @override
  ConsumerState<PersonCategoryCrumb> createState() =>
      _PersonCategoryCrumbState();
}

class _PersonCategoryCrumbState extends ConsumerState<PersonCategoryCrumb> {
  var _hovered = false;
  var _moving = false;

  Future<void> _pick() async {
    if (_moving) return;
    final messages = context.messages;
    final move = ref.read(entryCategoryMoveProvider);
    final result = await showCategoryPicker(
      context: context,
      title: messages.habitCategoryLabel,
      currentCategoryId: widget.categoryId,
    );
    // null = dismissed; a pick or an explicit clear is a change.
    if (result == null) return;
    final categoryId = result.categoryOrNull?.id;
    if (categoryId == widget.categoryId) return;
    if (!mounted) return;
    setState(() => _moving = true);
    final moved = await move.move(widget.relationshipId, categoryId);
    if (!mounted) return;
    setState(() => _moving = false);
    if (!moved) {
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: messages.relationshipErrorUpdateFailed,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final name = widget.categoryName;
    final ink = name == null
        ? tokens.colors.text.lowEmphasis
        : tokens.colors.text.mediumEmphasis;
    final label = name ?? messages.taskSetCategoryLabel;
    final radius = BorderRadius.circular(tokens.radii.s);
    // The inset the hover wash needs, given back as a negative offset so the
    // icon still starts on the page's content gutter, where the name below
    // starts.
    final inset = tokens.spacing.step1;

    return Transform.translate(
      offset: Offset(-inset, 0),
      child: Semantics(
        button: true,
        label: '${messages.habitCategoryLabel}: $label',
        excludeSemantics: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: const ValueKey('person-category-crumb'),
            borderRadius: radius,
            onTap: _moving ? null : _pick,
            onHover: (value) => setState(() => _hovered = value),
            child: AnimatedContainer(
              duration: MotionDurations.short2,
              decoration: BoxDecoration(
                color: _hovered
                    ? tokens.colors.surface.hover
                    : Colors.transparent,
                borderRadius: radius,
              ),
              padding: EdgeInsetsDirectional.fromSTEB(
                inset,
                inset,
                tokens.spacing.step2,
                inset,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.categoryId != null) ...[
                    CategoryIconCompact(
                      widget.categoryId,
                      size: CategoryIconConstants.iconSizeExtraSmall,
                    ),
                    SizedBox(width: tokens.spacing.step2),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      key: const ValueKey('person-eyebrow'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: captionLabelStyle(tokens, color: ink),
                    ),
                  ),
                  SizedBox(width: tokens.spacing.step1),
                  Icon(LottiIcons.chevronDown, size: IconSizes.s, color: ink),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
