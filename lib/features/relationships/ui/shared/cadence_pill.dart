import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// The one way this feature draws "the cadence has lapsed".
///
/// Two widgets say it — the People row's trailing pill (`5 days over`) and
/// the person header's cadence pill (`Due since Sat · 5 days over`). They
/// read the same model and differ only in how much of it they spell out, so
/// they must not differ in how they *encode* it. They did: the row grew a
/// warning glyph and the header kept a bare tint, which on the dark ground
/// reads as an inert brown next to the neutral chip beside it.
///
/// The label rides in high-emphasis ink rather than the warning hue: the
/// accent as text on its own wash fails contrast (the health chip's rule),
/// so the colour identity rides the tint and the glyph carries the urgency
/// at glance distance. The glyph is the one the briefing card's out-of-date
/// line already uses, so "needs attention" is drawn one way across the
/// feature.
DsPill relationshipOverduePill(
  BuildContext context, {
  required String label,
  required Key pillKey,
}) {
  final tokens = context.designTokens;
  return DsPill(
    key: pillKey,
    variant: DsPillVariant.tinted,
    shape: DsPillShape.tag,
    color: tokens.colors.alert.warning.defaultColor,
    leading: Icon(
      LottiIcons.warning,
      size: IconSizes.xs,
      color: tokens.colors.alert.warning.ink,
    ),
    labelColor: tokens.colors.text.highEmphasis,
    label: label,
  );
}
