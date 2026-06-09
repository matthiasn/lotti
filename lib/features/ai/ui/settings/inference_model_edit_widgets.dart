part of 'inference_model_edit_page.dart';

class _HeaderStrip extends StatelessWidget {
  const _HeaderStrip({
    required this.modelName,
    required this.providerType,
    required this.providerName,
  });

  final String modelName;
  final InferenceProviderType? providerType;
  final String providerName;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final visual = aiProviderVisual(
      type: providerType,
      tokens: tokens,
      messages: messages,
    );
    final shownName = modelName.isNotEmpty
        ? modelName
        : messages.modelEditDisplayNameHint;
    return Container(
      padding: EdgeInsets.all(tokens.spacing.step4),
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.l),
      ),
      child: Row(
        children: [
          Container(
            width: tokens.spacing.step9,
            height: tokens.spacing.step9,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: visual.surface,
              borderRadius: BorderRadius.circular(tokens.radii.s),
            ),
            child: Icon(
              aiProviderIcon(providerType),
              size: tokens.spacing.step6,
              color: visual.accent,
            ),
          ),
          SizedBox(width: tokens.spacing.step4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  shownName,
                  style: tokens.typography.styles.heading.heading3.copyWith(
                    color: modelName.isNotEmpty
                        ? tokens.colors.text.highEmphasis
                        : tokens.colors.text.mediumEmphasis,
                    fontWeight: tokens.typography.weight.semiBold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: tokens.spacing.step1),
                Text(
                  providerName,
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: tokens.typography.styles.subtitle.subtitle1.copyWith(
            color: tokens.colors.text.highEmphasis,
            fontWeight: tokens.typography.weight.semiBold,
          ),
        ),
        SizedBox(height: tokens.spacing.step3),
        child,
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      padding: EdgeInsets.all(tokens.spacing.step4),
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.l),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

/// Tap-to-open selector field used by Provider / Input modalities /
/// Output modalities. Renders a read-only row that mirrors the visual
/// rhythm of `AiTextField` without instantiating a `TextEditingController`
/// — the previous `AbsorbPointer(AiTextField(controller: TextEditingController(...)))`
/// pattern leaked a controller on every rebuild.
class _SelectorField extends StatelessWidget {
  const _SelectorField({
    required this.label,
    required this.value,
    required this.isEmpty,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool isEmpty;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final borderColor = isEmpty
        ? tokens.colors.alert.warning.defaultColor.withValues(alpha: 0.4)
        : tokens.colors.text.lowEmphasis.withValues(alpha: 0.2);
    return Semantics(
      button: true,
      label: label,
      value: value,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radii.m),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step4,
            vertical: tokens.spacing.step3,
          ),
          decoration: BoxDecoration(
            color: tokens.colors.background.level01,
            borderRadius: BorderRadius.circular(tokens.radii.m),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Icon(
                Icons.tune_rounded,
                size: 18,
                color: tokens.colors.text.mediumEmphasis,
              ),
              SizedBox(width: tokens.spacing.step3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: tokens.typography.styles.others.caption.copyWith(
                        color: tokens.colors.text.mediumEmphasis,
                        fontWeight: tokens.typography.weight.semiBold,
                      ),
                    ),
                    SizedBox(height: tokens.spacing.step1),
                    Text(
                      value,
                      style: tokens.typography.styles.body.bodyMedium.copyWith(
                        color: isEmpty
                            ? tokens.colors.text.mediumEmphasis
                            : tokens.colors.text.highEmphasis,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: tokens.spacing.step2),
              Icon(
                Icons.arrow_drop_down_rounded,
                color: isEmpty
                    ? tokens.colors.alert.warning.defaultColor
                    : tokens.colors.text.mediumEmphasis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
