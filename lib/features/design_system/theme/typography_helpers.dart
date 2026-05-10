import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// Mono-metadata cell style — used for ids, timestamps, and small numeric
/// counts that need to align vertically across rows.
///
/// Closest design-system token is `caption`; the Inconsolata override and
/// zeroed letter-spacing live here because the token tree has no mono
/// family token. Color defaults to `colors.text.lowEmphasis` for the
/// "this is metadata, not the primary content" reading; pass a different
/// color via `.copyWith` if a stronger emphasis is needed.
TextStyle monoMetaStyle(DsTokens tokens, DsColors colors) {
  return tokens.typography.styles.others.caption.copyWith(
    fontFamily: 'Inconsolata',
    color: colors.text.lowEmphasis,
    letterSpacing: 0,
  );
}
