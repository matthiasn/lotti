import 'package:lotti/features/agents/ui/listing/agent_list_data.dart';
import 'package:lotti/features/agents/ui/listing/widgets/soul_avatar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:material_ui/material_ui.dart';

/// Single-line dense row used inside grouped sections of any
/// `AgentListingShell`. Pure: takes only [AgentListRowData] and renders
/// it; never reaches into Riverpod, providers, or live state.
///
/// Two layouts: wide (≥ 600px) keeps everything on one line; compact
/// stacks title / subtitle / id, then pills + meta + trailing on a
/// second row underneath.
class AgentListRow extends StatelessWidget {
  const AgentListRow({required this.data, super.key});

  final AgentListRowData data;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final colors = tokens.colors;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(tokens.radii.s),
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.radii.s),
        onTap: data.onTap,
        hoverColor: colors.surface.hover,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step4,
            vertical: tokens.spacing.step3,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 600;
              return isCompact
                  ? _compactLayout(context, tokens, colors)
                  : _wideLayout(context, tokens, colors);
            },
          ),
        ),
      ),
    );
  }

  Widget _wideLayout(BuildContext context, DsTokens tokens, DsColors colors) {
    return Row(
      children: [
        if (data.leading != null) ...[
          _buildLeading(data.leading!),
          SizedBox(width: tokens.spacing.step4),
        ],
        Expanded(child: _titleAndSubtitle(tokens, colors, inline: true)),
        for (final pill in data.pills) ...[
          SizedBox(width: tokens.spacing.step3),
          _Pill(pill: pill),
        ],
        if (data.metaRight != null) ...[
          SizedBox(width: tokens.spacing.step4),
          Text(data.metaRight!, style: monoMetaStyle(tokens, colors)),
        ],
        if (data.trailing != null) ...[
          SizedBox(width: tokens.spacing.step3),
          data.trailing!(context),
        ] else if (data.onTap != null) ...[
          SizedBox(width: tokens.spacing.step3),
          Icon(
            LottiIcons.chevronRight,
            size: 16,
            color: colors.text.lowEmphasis,
          ),
        ],
      ],
    );
  }

  Widget _compactLayout(
    BuildContext context,
    DsTokens tokens,
    DsColors colors,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (data.leading != null) ...[
              _buildLeading(data.leading!),
              SizedBox(width: tokens.spacing.step4),
            ],
            Expanded(child: _titleAndSubtitle(tokens, colors, inline: false)),
          ],
        ),
        SizedBox(height: tokens.spacing.step3),
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: tokens.spacing.step3,
                runSpacing: tokens.spacing.step2,
                children: [
                  for (final pill in data.pills) _Pill(pill: pill),
                ],
              ),
            ),
            if (data.metaRight != null ||
                data.trailing != null ||
                data.onTap != null) ...[
              SizedBox(width: tokens.spacing.step3),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (data.metaRight != null)
                      Flexible(
                        child: Text(
                          data.metaRight!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: monoMetaStyle(tokens, colors),
                        ),
                      ),
                    if (data.trailing != null) ...[
                      SizedBox(width: tokens.spacing.step3),
                      data.trailing!(context),
                    ] else if (data.onTap != null) ...[
                      SizedBox(width: tokens.spacing.step3),
                      Icon(
                        LottiIcons.chevronRight,
                        size: 16,
                        color: colors.text.lowEmphasis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// Wide layout puts title and subtitle on one ellipsised line ("Title ·
  /// Subtitle"); compact stacks them. The mono id under both layouts
  /// comes from `data.id`, rendered with the shared mono style.
  Widget _titleAndSubtitle(
    DsTokens tokens,
    DsColors colors, {
    required bool inline,
  }) {
    final titleStyle = tokens.typography.styles.subtitle.subtitle2.copyWith(
      color: colors.text.highEmphasis,
    );
    final subtitleStyle = tokens.typography.styles.body.bodySmall.copyWith(
      color: colors.text.lowEmphasis,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (inline)
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: data.title, style: titleStyle),
                if (data.subtitle != null) ...[
                  TextSpan(
                    text: '  ·  ',
                    style: TextStyle(color: colors.text.lowEmphasis),
                  ),
                  TextSpan(text: data.subtitle, style: subtitleStyle),
                ],
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          )
        else ...[
          Text(
            data.title,
            style: titleStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (data.subtitle != null) ...[
            SizedBox(height: tokens.spacing.step1),
            Text(
              data.subtitle!,
              style: tokens.typography.styles.others.caption.copyWith(
                color: colors.text.lowEmphasis,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
        SizedBox(height: tokens.spacing.step1),
        Text(
          data.id,
          style: monoMetaStyle(tokens, colors),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildLeading(AgentListLeading leading) {
    return switch (leading) {
      AgentListAvatarLeading() => SoulAvatar(
        label: leading.label,
        hue: leading.hue,
        size: leading.size,
      ),
      AgentListIconLeading() => Icon(
        leading.icon,
        size: leading.size,
        color: leading.color,
      ),
    };
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.pill});
  final AgentListPill pill;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final colors = tokens.colors;
    final (fg, bg) = _toneColors(pill, colors);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step3,
        vertical: tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(tokens.radii.xs),
      ),
      child: Text(
        pill.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: tokens.typography.styles.others.caption.copyWith(
          color: fg,
          fontWeight: tokens.typography.weight.semiBold,
        ),
      ),
    );
  }

  /// Resolves the (foreground, background) for a [pill] given the
  /// design tokens. `customColor` overrides the tone's accent only; a
  /// neutral pill has no accent and ignores it.
  (Color, Color) _toneColors(AgentListPill pill, DsColors colors) {
    (Color, Color) tinted(Color toneAccent, {double alpha = 0.14}) {
      final accent = pill.customColor ?? toneAccent;
      return (accent, accent.withValues(alpha: alpha));
    }

    return switch (pill.tone) {
      AgentListPillTone.neutral => (
        colors.text.highEmphasis,
        colors.surface.enabled,
      ),
      AgentListPillTone.interactive => tinted(colors.interactive.enabled),
      AgentListPillTone.warning => tinted(colors.alert.warning.ink),
      AgentListPillTone.error => tinted(colors.alert.error.ink),
      AgentListPillTone.info => tinted(colors.alert.info.ink),
      AgentListPillTone.muted => tinted(
        colors.text.mediumEmphasis,
        alpha: 0.06,
      ),
    };
  }
}
