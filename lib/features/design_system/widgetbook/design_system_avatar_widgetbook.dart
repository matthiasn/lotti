import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/avatars/design_system_avatar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent buildDesignSystemAvatarWidgetbookComponent() {
  return WidgetbookComponent(
    name: 'Avatars',
    useCases: [
      WidgetbookUseCase(
        name: 'Overview',
        builder: (context) => const _AvatarOverviewPage(),
      ),
    ],
  );
}

class _AvatarOverviewPage extends StatelessWidget {
  const _AvatarOverviewPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          _AvatarSection(
            title: context.messages.designSystemAvatarStatusMatrixTitle,
            child: const _AvatarStatusMatrix(),
          ),
          const SizedBox(height: 32),
          _AvatarSection(
            title: context.messages.designSystemAvatarSizeMatrixTitle,
            child: const _AvatarSizeMatrix(),
          ),
        ],
      ),
    );
  }
}

class _AvatarSection extends StatelessWidget {
  const _AvatarSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}

class _AvatarStatusMatrix extends StatelessWidget {
  const _AvatarStatusMatrix();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final descriptionStyle = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.lowEmphasis,
    );

    return Wrap(
      spacing: 24,
      runSpacing: 24,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...DesignSystemAvatarStatus.values.map((status) {
          final label = _labelForStatus(context, status);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DesignSystemAvatar(
                image: _placeholderImage,
                size: DesignSystemAvatarSize.xxl64,
                status: status,
                semanticsLabel: label,
              ),
              const SizedBox(height: 8),
              Text(label, style: descriptionStyle),
            ],
          );
        }),
      ],
    );
  }
}

class _AvatarSizeMatrix extends StatelessWidget {
  const _AvatarSizeMatrix();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final size in DesignSystemAvatarSize.values)
          DesignSystemAvatar(
            image: _placeholderImage,
            size: size,
            semanticsLabel: size.name,
          ),
      ],
    );
  }
}

String _labelForStatus(
  BuildContext context,
  DesignSystemAvatarStatus status,
) {
  final messages = context.messages;
  return switch (status) {
    DesignSystemAvatarStatus.enabled => messages.designSystemAvatarEnabledLabel,
    DesignSystemAvatarStatus.connected =>
      messages.designSystemAvatarConnectedLabel,
    DesignSystemAvatarStatus.away => messages.designSystemAvatarAwayLabel,
    DesignSystemAvatarStatus.busy => messages.designSystemAvatarBusyLabel,
  };
}

const _placeholderImage = AssetImage(
  'assets/design_system/avatar_placeholder.png',
);
