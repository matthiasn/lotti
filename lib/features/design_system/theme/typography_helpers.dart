import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// Mono-metadata cell style — used for ids, timestamps, and small numeric
/// counts that need to align vertically across rows.
///
/// Closest design-system token is `caption`; the Inconsolata override and
/// zeroed letter-spacing live here because the token tree has no mono
/// family token. Defaults — `caption` base + `text.lowEmphasis` color —
/// match the "this is metadata, not the primary content" reading; pass
/// [base] and/or [color] when a surface needs a different base style or
/// stronger emphasis (e.g. the provider detail page's connection rows,
/// which want `bodySmall` + `text.highEmphasis`). Keeping both knobs
/// behind one helper means no caller has to reach for raw
/// `fontFamily: 'Inconsolata'` / `letterSpacing: 0` overrides.
TextStyle monoMetaStyle(
  DsTokens tokens,
  DsColors colors, {
  TextStyle? base,
  Color? color,
}) {
  return (base ?? tokens.typography.styles.others.caption).copyWith(
    fontFamily: 'Inconsolata',
    color: color ?? colors.text.lowEmphasis,
    letterSpacing: 0,
  );
}
