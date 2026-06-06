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

// ---------------------------------------------------------------------------
// Calm typography — the "ship calm" type system from the Daily OS design
// handoff (v2, item 6). The generated token tree still carries the louder
// legacy scale (overline 12/700/+8 tracking, heading1 35/700); these helpers
// derive the calmer treatment on top of the existing token styles so every
// surface converges on one system. The values fold into the generated tokens
// once the Figma export catches up — keep call sites on these helpers, not on
// hand-rolled `copyWith`s.
// ---------------------------------------------------------------------------

/// Calm eyebrow / overline — 11px / 600 / 0.04em tracking, `text.lowEmphasis`
/// by default. Eyebrows should recede, not announce: never 700 weight, never
/// the legacy +8 letter-spacing. Uppercase comes from the label string
/// itself (the `.arb` overline strings are stored uppercase).
TextStyle calmEyebrowStyle(DsTokens tokens, {Color? color}) {
  const fontSize = 11.0;
  return tokens.typography.styles.others.overline.copyWith(
    fontSize: fontSize,
    fontWeight: tokens.typography.weight.semiBold,
    letterSpacing: fontSize * 0.04,
    color: color ?? tokens.colors.text.lowEmphasis,
  );
}

/// Calm page header — 23px / 600 / −0.015em. Replaces the louder 25–35px /
/// 700 headers; hierarchy is carried by contrast, not size.
TextStyle calmPageTitleStyle(DsTokens tokens, {Color? color}) {
  const fontSize = 23.0;
  return tokens.typography.styles.heading.heading2.copyWith(
    fontSize: fontSize,
    fontWeight: tokens.typography.weight.semiBold,
    letterSpacing: fontSize * -0.015,
    color: color ?? tokens.colors.text.highEmphasis,
  );
}

/// Calm hero — 34px / 500 / −0.02em. Used for the single large display line
/// on a screen (e.g. the Capture headline "What's on your mind for today?").
TextStyle calmHeroStyle(DsTokens tokens, {Color? color}) {
  const fontSize = 34.0;
  return tokens.typography.styles.heading.heading1.copyWith(
    fontSize: fontSize,
    fontWeight: FontWeight.w500,
    letterSpacing: fontSize * -0.02,
    color: color ?? tokens.colors.text.highEmphasis,
  );
}

/// Calm display moment — 26px / 600 / −0.02em. Signature lines like the
/// Commit lead-in ("Make it yours.") and the LockInScene captions.
TextStyle calmDisplayStyle(DsTokens tokens, {Color? color}) {
  const fontSize = 26.0;
  return tokens.typography.styles.heading.heading2.copyWith(
    fontSize: fontSize,
    fontWeight: tokens.typography.weight.semiBold,
    letterSpacing: fontSize * -0.02,
    color: color ?? tokens.colors.text.highEmphasis,
  );
}

/// Calm greeting line — 12px / 500, `text.lowEmphasis` by default. The quiet
/// "Hi, Matthias 👋" tier above a page title.
TextStyle calmGreetingStyle(DsTokens tokens, {Color? color}) {
  return tokens.typography.styles.others.caption.copyWith(
    fontWeight: FontWeight.w500,
    color: color ?? tokens.colors.text.lowEmphasis,
  );
}
