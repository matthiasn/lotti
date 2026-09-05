import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

export 'package:lotti/features/projects/ui/widgets/shared_tag_widgets.dart';

class NoResultsPane extends StatelessWidget {
  const NoResultsPane({
    this.title,
    this.body,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String? title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LottiIcons.folderOpen,
              size: IconSizes.xxl,
              color: ShowcasePalette.lowText(context),
            ),
            SizedBox(height: tokens.spacing.step4),
            Semantics(
              header: true,
              child: Text(
                title ?? context.messages.projectShowcaseNoResults,
                textAlign: TextAlign.center,
                style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                  color: ShowcasePalette.highText(context),
                ),
              ),
            ),
            if (body != null) ...[
              SizedBox(height: tokens.spacing.step2),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: tokens.typography.styles.body.bodyMedium.copyWith(
                  color: ShowcasePalette.mediumText(context),
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: tokens.spacing.step5),
              DesignSystemButton(
                label: actionLabel!,
                variant: DesignSystemButtonVariant.secondary,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
