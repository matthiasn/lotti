import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// Conventional two-step surface elevation shared by the app's calm, card-on-
/// canvas surfaces (Time Analysis, Habits, …): a darker page canvas with the
/// cards a step lighter sitting on it.
///
/// The design-system background ramp runs in opposite directions per theme —
/// in the (dark-first) dark theme `level02` (#222222) is lighter than the
/// `level01` (#181818) base, but in light mode `level02` (#F1F4F3) is *darker*
/// than the white `level01`. Reading the same token for "page" and "card" in
/// both themes would therefore put darker cards on a white page in light mode
/// (cards look recessed, not raised). Swapping which level is the page vs the
/// card by brightness keeps "cards lighter than the page" true either way.
///
/// Lives in the design-system theme layer so any feature can speak the same
/// elevation language without depending on another feature's widgets.
Color dsPageSurface(BuildContext context) {
  final tokens = context.designTokens;
  return Theme.of(context).brightness == Brightness.dark
      ? tokens.colors.background.level01
      : tokens.colors.background.level02;
}

/// The card/elevated surface — always a step lighter than [dsPageSurface] in
/// the active theme. See that function for why this swaps by brightness.
Color dsCardSurface(BuildContext context) {
  final tokens = context.designTokens;
  return Theme.of(context).brightness == Brightness.dark
      ? tokens.colors.background.level02
      : tokens.colors.background.level01;
}
