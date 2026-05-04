import 'package:flutter/material.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/ui/agent_date_format.dart';
import 'package:lotti/features/agents/ui/instances/instance_view_model.dart';
import 'package:lotti/features/agents/ui/instances/widgets/soul_avatar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Single-line dense row used inside grouped sections.
///
/// `showSoul` adds a leading avatar — used when the page is grouping
/// by Type or Status (so the soul stays visually identifiable). When
/// grouping by Soul the avatar is on the section header instead, so we
/// suppress it here.
class InstanceRow extends StatelessWidget {
  const InstanceRow({
    required this.vm,
    required this.onTap,
    this.showSoul = false,
    super.key,
  });

  final InstanceVm vm;
  final VoidCallback onTap;
  final bool showSoul;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final colors = tokens.colors;
    final messages = context.messages;

    final title = vm.type == InstanceType.evolution && vm.sessionNumber != null
        ? messages.agentEvolutionSessionTitle(vm.sessionNumber!)
        : vm.displayName;
    final task = vm.type == InstanceType.evolution
        ? null
        : (vm.templateName != null && vm.templateName != vm.displayName
              ? vm.templateName
              : null);
    final soulHue = hueForSeed(vm.soulId ?? vm.templateId ?? vm.id);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(tokens.radii.s),
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.radii.s),
        onTap: onTap,
        hoverColor: colors.surface.hover,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step4,
            vertical: tokens.spacing.step3,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 600;
              if (isCompact) {
                return _compactLayout(
                  tokens,
                  colors,
                  title,
                  task,
                  soulHue,
                  vm,
                );
              }
              return _wideLayout(tokens, colors, title, task, soulHue, vm);
            },
          ),
        ),
      ),
    );
  }

  Widget _wideLayout(
    DsTokens tokens,
    DsColors colors,
    String title,
    String? task,
    int soulHue,
    InstanceVm vm,
  ) {
    return Row(
      children: [
        if (showSoul) ...[
          SoulAvatar(label: vm.soulName ?? '?', hue: soulHue, size: 20),
          SizedBox(width: tokens.spacing.step4),
        ],
        Expanded(child: _titleAndId(colors, title, task, vm)),
        SizedBox(width: tokens.spacing.step4),
        _TypePill(type: vm.type),
        SizedBox(width: tokens.spacing.step3),
        _StatusPill(status: vm.status),
        SizedBox(width: tokens.spacing.step4),
        Text(
          _formatTime(vm.updatedAt),
          style: TextStyle(
            fontFamily: 'Inconsolata',
            fontSize: 10.5,
            color: colors.text.lowEmphasis,
          ),
        ),
        SizedBox(width: tokens.spacing.step3),
        Icon(Icons.chevron_right, size: 16, color: colors.text.lowEmphasis),
      ],
    );
  }

  /// Compact: title + subtitle stacked, then id, then pills + time + chevron
  /// on a separate row below. Matches the mobile mock the user shared.
  Widget _compactLayout(
    DsTokens tokens,
    DsColors colors,
    String title,
    String? task,
    int soulHue,
    InstanceVm vm,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showSoul) ...[
              SoulAvatar(label: vm.soulName ?? '?', hue: soulHue, size: 20),
              SizedBox(width: tokens.spacing.step4),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.text.highEmphasis,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (task != null) ...[
                    SizedBox(height: tokens.spacing.step1),
                    Text(
                      task,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: colors.text.lowEmphasis,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  SizedBox(height: tokens.spacing.step1),
                  Text(
                    vm.id,
                    style: TextStyle(
                      fontFamily: 'Inconsolata',
                      fontSize: 10,
                      color: colors.text.lowEmphasis,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: tokens.spacing.step3),
        Row(
          children: [
            _TypePill(type: vm.type),
            SizedBox(width: tokens.spacing.step3),
            _StatusPill(status: vm.status),
            const Spacer(),
            Text(
              _formatTime(vm.updatedAt),
              style: TextStyle(
                fontFamily: 'Inconsolata',
                fontSize: 10.5,
                color: colors.text.lowEmphasis,
              ),
            ),
            SizedBox(width: tokens.spacing.step3),
            Icon(Icons.chevron_right, size: 16, color: colors.text.lowEmphasis),
          ],
        ),
      ],
    );
  }

  Widget _titleAndId(
    DsColors colors,
    String title,
    String? task,
    InstanceVm vm,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.text.highEmphasis,
                ),
              ),
              if (task != null) ...[
                TextSpan(
                  text: '  ·  ',
                  style: TextStyle(color: colors.text.lowEmphasis),
                ),
                TextSpan(
                  text: task,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: colors.text.lowEmphasis,
                  ),
                ),
              ],
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          vm.id,
          style: TextStyle(
            fontFamily: 'Inconsolata',
            fontSize: 10,
            color: colors.text.lowEmphasis,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

String _formatTime(DateTime dt) {
  // Reuses the agent date formatter so locale changes propagate, then
  // takes the time portion only — matches the design's `HH:MM` cell.
  final full = formatAgentDateTime(dt);
  final space = full.indexOf(' ');
  return space < 0 ? full : full.substring(space + 1);
}

class _TypePill extends StatelessWidget {
  const _TypePill({required this.type});
  final InstanceType type;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return _Pill(
      label: instanceTypeLabel(context.messages, type),
      bg: tokens.colors.surface.enabled,
      fg: tokens.colors.text.highEmphasis,
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final AgentLifecycle status;

  @override
  Widget build(BuildContext context) {
    final colors = context.designTokens.colors;
    final accent = switch (status) {
      AgentLifecycle.active => colors.interactive.enabled,
      AgentLifecycle.dormant => colors.text.mediumEmphasis,
      AgentLifecycle.destroyed => colors.alert.error.defaultColor,
      AgentLifecycle.created => colors.alert.info.defaultColor,
    };
    final bg = status == AgentLifecycle.dormant
        ? accent.withValues(alpha: 0.06)
        : accent.withValues(alpha: 0.14);
    return _Pill(
      label: agentLifecycleLabel(context.messages, status),
      bg: bg,
      fg: accent,
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.bg, required this.fg});
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
