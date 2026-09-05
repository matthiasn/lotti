import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// One accent per person, stable per id (design plan §0.7). The palette is
/// the same family the goal agents draw from: the design system's semantic
/// accents plus the two hand-authored goal hues. Assignment is a
/// deterministic hash of the id, so the same person lands on the same
/// accent on every device and across reloads — the avatar does not
/// reshuffle when the list reorders.
///
/// Every entry comes from the exported token sets — the brightness picks
/// which set, nothing here holds a color literal of its own. The alert
/// accents use the `ink` variant because the accent is rendered as text
/// (the initial), and ink is the text-weight resolution of each hue.
Color personaAccentForId(String id, Brightness brightness) {
  // A stable, well-mixed 32-bit hash of the id. String.hashCode is not
  // guaranteed stable across Dart versions, so fold the bytes by hand.
  var hash = 0x811C9DC5; // FNV-1a 32-bit offset basis.
  for (final byte in id.codeUnits) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0xFFFFFFFF; // FNV-1a prime.
  }
  final tokens = brightness == Brightness.dark ? dsTokensDark : dsTokensLight;
  final palette = <Color>[
    tokens.colors.interactive.enabled,
    GoalAccentHues.neon(brightness),
    GoalAccentHues.aurora(brightness),
    tokens.colors.alert.warning.ink,
    tokens.colors.alert.info.ink,
    tokens.colors.alert.success.ink,
  ];
  return palette[hash % palette.length];
}

/// A persona-tinted circle avatar: `color-mix(accent 20%, transparent)`
/// fill with an accent-colored initial (design plan §0.7).
///
/// The accent is derived from [id] when supplied; callers that already
/// hold an accent (e.g. a beat rail reusing the person's accent) pass it
/// directly via [accent].
class PersonaAvatar extends StatelessWidget {
  const PersonaAvatar({
    required this.initial,
    this.id,
    this.accent,
    this.size = 40,
    super.key,
  }) : assert(
         id != null || accent != null,
         'PersonaAvatar needs either an id (to derive the accent) or an '
         'explicit accent.',
       );

  /// The single character shown (usually the first letter of the name).
  final String initial;

  /// The person's entity id — used to derive a stable accent. Ignored when
  /// [accent] is supplied.
  final String? id;

  /// An explicit accent, overriding the id-derived one.
  final Color? accent;

  /// The avatar diameter in logical pixels.
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final accent =
        this.accent ?? personaAccentForId(id!, Theme.of(context).brightness);
    final fontSize = size * 0.42;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.20),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial.isEmpty ? '·' : initial,
        style: tokens.typography.styles.subtitle.subtitle1.copyWith(
          color: accent,
          fontSize: fontSize,
          fontWeight: tokens.typography.weight.semiBold,
          height: 1,
        ),
      ),
    );
  }
}

/// Convenience: the first letter of [name], uppercased, falling back to "·"
/// for the empty/null name (the import list can carry a contact whose
/// display name is blank).
String personaInitial(String? name) {
  final trimmed = name?.trim() ?? '';
  if (trimmed.isEmpty) return '·';
  return trimmed[0].toUpperCase();
}
