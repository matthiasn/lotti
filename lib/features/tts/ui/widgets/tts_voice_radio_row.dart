import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// One voice in a voice list: a radio mark, the voice's [title] with an
/// optional [tag] beside it and a [caption] under it, and an optional
/// [trailing] control. Shared by the on-device voice list and the cloud voice
/// picker, so the two voice choosers on Speech settings are one control.
///
/// A small [DesignSystemListItem] underneath, so it takes the list's hover,
/// pressed and focus states and its one centring axis for the radio, the
/// text block and the trailing control. The radio's slot tops the row up to
/// [TapTargets.compact], so every row keeps the touch floor with its content
/// centred in it. The selected voice carries a check mark, a heavier
/// name and the activated surface (shape, weight and area, not color alone)
/// and a selected semantics flag.
class TtsVoiceRadioRow extends StatelessWidget {
  const TtsVoiceRadioRow({
    required this.title,
    required this.selected,
    required this.onTap,
    this.caption,
    this.tag,
    this.trailing,
    this.fullWidthDivider = false,
    super.key,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  /// A second line describing the voice, e.g. its gender and mood tags; the
  /// spans may carry their own ink over the list's caption style.
  final List<InlineSpan>? caption;

  /// A small marker after the title, e.g. the default voice's tag.
  final Widget? tag;

  final Widget? trailing;

  /// Draws a full-width rule under the row: the edge of a group, such as
  /// the voices pinned above a filtered list.
  final bool fullWidthDivider;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final styles = tokens.typography.styles;
    final hasCaption = caption != null && caption!.isNotEmpty;

    return DesignSystemListItem(
      size: DesignSystemListItemSize.small,
      selected: selected,
      // The picked row is findable by its area too, not only its mark.
      activated: selected,
      onTap: onTap,
      // With the small row's own padding above and below, this makes the
      // row exactly a touch target tall when nothing else is taller.
      leading: SizedBox(
        height: TapTargets.compact - 2 * tokens.spacing.step3,
        child: Icon(
          selected ? LottiIcons.confirmCircled : LottiIcons.radioUnselected,
          size: IconSizes.m,
          color: selected
              ? tokens.colors.aiCard.accent
              : tokens.colors.text.lowEmphasis,
        ),
      ),
      titleContent: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        spacing: tokens.spacing.step3,
        children: [
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  (selected ? styles.subtitle.subtitle2 : styles.body.bodySmall)
                      .copyWith(color: tokens.colors.text.highEmphasis),
            ),
          ),
          ?tag,
        ],
      ),
      subtitleSpans: hasCaption ? caption : null,
      trailing: trailing,
      showDivider: fullWidthDivider,
      dividerIndent: 0,
    );
  }
}
