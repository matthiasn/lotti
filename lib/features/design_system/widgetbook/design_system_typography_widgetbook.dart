import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent buildDesignSystemTypographyWidgetbookComponent() {
  return WidgetbookComponent(
    name: 'Typography',
    useCases: [
      WidgetbookUseCase(
        name: 'Overview',
        builder: (context) => const _TypographyOverviewPage(),
      ),
    ],
  );
}

class _TypographyOverviewPage extends StatelessWidget {
  const _TypographyOverviewPage();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wideLayout = constraints.maxWidth >= 1240;
        final spacing = tokens.spacing.sectionGap;
        final board = const _TypographyBoard();
        final details = const _TypographyDetails();

        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(tokens.spacing.step6),
            child: wideLayout
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: board),
                      SizedBox(width: spacing),
                      SizedBox(
                        width: 280,
                        child: details,
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      board,
                      SizedBox(height: spacing),
                      details,
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _TypographyBoard extends StatelessWidget {
  const _TypographyBoard();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.sectionCards),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step2),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 980;
            final panels = [
              const _TypographyPanel(
                heading: 'Light Scale',
                tokens: dsTokensLight,
              ),
              const _TypographyPanel(
                heading: 'Dark Scale',
                tokens: dsTokensDark,
              ),
            ];

            if (stacked) {
              return Column(
                children: [
                  panels.first,
                  SizedBox(height: tokens.spacing.step2),
                  panels.last,
                ],
              );
            }

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: panels.first),
                  SizedBox(width: tokens.spacing.step2),
                  Expanded(child: panels.last),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TypographyPanel extends StatelessWidget {
  const _TypographyPanel({
    required this.heading,
    required this.tokens,
  });

  final String heading;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    final foreground = tokens.colors.text.highEmphasis;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.background.level01,
        borderRadius: BorderRadius.circular(tokens.radii.sectionCards),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              heading,
              style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
            SizedBox(height: tokens.spacing.step5),
            LayoutBuilder(
              builder: (context, constraints) {
                return SizedBox(
                  width: constraints.maxWidth,
                  child: FittedBox(
                    alignment: Alignment.topLeft,
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: _typographySpecimenBoardWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final specimen in _typographySpecimens)
                            _TypographySpecimenLine(
                              specimen: specimen,
                              tokens: tokens,
                              foreground: foreground,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TypographySpecimenLine extends StatelessWidget {
  const _TypographySpecimenLine({
    required this.specimen,
    required this.tokens,
    required this.foreground,
  });

  final _TypographySpecimen specimen;
  final DsTokens tokens;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final style = specimen.resolve(tokens).copyWith(color: foreground);
    final fontSize = style.fontSize ?? 14;
    final lineHeight = (style.height ?? 1.0) * fontSize;
    final bottomSpacing = math.max(tokens.spacing.step2, lineHeight * 0.18);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomSpacing),
      child: SizedBox(
        height: lineHeight,
        child: Text(
          specimen.label,
          maxLines: 1,
          softWrap: false,
          style: style,
        ),
      ),
    );
  }
}

class _TypographyDetails extends StatelessWidget {
  const _TypographyDetails();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TypographyInfoCard(
          title: 'Font Family',
          child: Text(
            dsTokensLight.typography.family.text,
            style: dsTokensLight.typography.styles.heading.heading2.copyWith(
              color: dsTokensLight.colors.text.highEmphasis,
            ),
          ),
        ),
        SizedBox(height: tokens.spacing.step4),
        _TypographyInfoCard(
          title: 'Font Weights',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Inter Bold (700)',
                style: dsTokensLight.typography.styles.subtitle.subtitle1
                    .copyWith(
                      color: dsTokensLight.colors.text.highEmphasis,
                    ),
              ),
              SizedBox(height: tokens.spacing.step2),
              Text(
                'Inter SemiBold (600)',
                style: dsTokensLight.typography.styles.subtitle.subtitle1
                    .copyWith(
                      fontWeight: dsTokensLight.typography.weight.semiBold,
                      color: dsTokensLight.colors.text.highEmphasis,
                    ),
              ),
              SizedBox(height: tokens.spacing.step2),
              Text(
                'Inter Regular (400)',
                style: dsTokensLight.typography.styles.body.bodyMedium.copyWith(
                  color: dsTokensLight.colors.text.highEmphasis,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: tokens.spacing.step4),
        _TypographyInfoCard(
          title: 'Figures',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '2,946',
                style: dsTokensLight.typography.styles.display.display2
                    .copyWith(
                      color: dsTokensLight.colors.text.highEmphasis,
                    ),
              ),
              Text(
                '1,830',
                style: dsTokensLight.typography.styles.heading.heading1
                    .copyWith(
                      color: dsTokensLight.colors.text.highEmphasis,
                    ),
              ),
              Text(
                '1,127',
                style: dsTokensLight.typography.styles.subtitle.subtitle1
                    .copyWith(
                      color: dsTokensLight.colors.text.highEmphasis,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TypographyInfoCard extends StatelessWidget {
  const _TypographyInfoCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: tokens.typography.styles.subtitle.subtitle2.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step3),
        DecoratedBox(
          decoration: BoxDecoration(
            color: dsTokensLight.colors.background.level01,
            borderRadius: BorderRadius.circular(tokens.radii.m),
            border: Border.all(color: tokens.colors.decorative.level01),
          ),
          child: Padding(
            padding: EdgeInsets.all(tokens.spacing.step5),
            child: SizedBox(
              width: double.infinity,
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}

class _TypographySpecimen {
  const _TypographySpecimen({
    required this.label,
    required this.resolve,
  });

  final String label;
  final TextStyle Function(DsTokens tokens) resolve;
}

final _typographySpecimens = <_TypographySpecimen>[
  _TypographySpecimen(
    label: 'Display 0 / Inter Bold',
    resolve: (tokens) => tokens.typography.styles.display.display0,
  ),
  _TypographySpecimen(
    label: 'Display 1 / Inter Bold',
    resolve: (tokens) => tokens.typography.styles.display.display1,
  ),
  _TypographySpecimen(
    label: 'Display 2 / Inter Bold',
    resolve: (tokens) => tokens.typography.styles.display.display2,
  ),
  _TypographySpecimen(
    label: 'Display 3 / Inter Bold',
    resolve: (tokens) => TextStyle(
      fontFamily: tokens.typography.family.display,
      fontSize: tokens.typography.size.display3,
      fontWeight: tokens.typography.weight.bold,
      height:
          tokens.typography.lineHeight.display3 /
          tokens.typography.size.display3,
      letterSpacing: tokens.typography.letterSpacing.display3,
    ),
  ),
  _TypographySpecimen(
    label: 'Heading 1 / Inter Bold',
    resolve: (tokens) => tokens.typography.styles.heading.heading1,
  ),
  _TypographySpecimen(
    label: 'Heading 2 / Inter Bold',
    resolve: (tokens) => tokens.typography.styles.heading.heading2,
  ),
  _TypographySpecimen(
    label: 'Heading 3 / Inter Bold',
    resolve: (tokens) => tokens.typography.styles.heading.heading3,
  ),
  _TypographySpecimen(
    label: 'Subtitle 1 / Inter SemiBold',
    resolve: (tokens) => tokens.typography.styles.subtitle.subtitle1,
  ),
  _TypographySpecimen(
    label: 'Subtitle 2 / Inter SemiBold',
    resolve: (tokens) => tokens.typography.styles.subtitle.subtitle2,
  ),
  _TypographySpecimen(
    label: 'Body Large / Inter Regular',
    resolve: (tokens) => tokens.typography.styles.body.bodyLarge,
  ),
  _TypographySpecimen(
    label: 'Body Medium / Inter Regular',
    resolve: (tokens) => tokens.typography.styles.body.bodyMedium,
  ),
  _TypographySpecimen(
    label: 'Body Small / Inter Regular',
    resolve: (tokens) => tokens.typography.styles.body.bodySmall,
  ),
  _TypographySpecimen(
    label: 'Caption / Inter Regular',
    resolve: (tokens) => tokens.typography.styles.others.caption,
  ),
  _TypographySpecimen(
    label: 'OVERLINE / INTER BOLD',
    resolve: (tokens) => tokens.typography.styles.others.overline,
  ),
];

const _typographySpecimenBoardWidth = 1520.0;
