import 'package:lotti/features/design_system/components/callouts/design_system_inline_callout.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent buildDesignSystemInlineCalloutWidgetbookComponent() {
  return WidgetbookComponent(
    name: 'Inline Callout',
    useCases: [
      WidgetbookUseCase(
        name: 'Overview',
        builder: (context) => const _InlineCalloutOverviewPage(),
      ),
    ],
  );
}

class _InlineCalloutOverviewPage extends StatelessWidget {
  const _InlineCalloutOverviewPage();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    // The first two previews are the component's canonical production uses,
    // shown with their real (localized) copy.
    return Padding(
      padding: EdgeInsets.all(tokens.spacing.step6),
      child: ListView(
        children: [
          DesignSystemInlineCallout(
            icon: LottiIcons.warning,
            text: context.messages.syncDevicesPausedBanner(1),
          ),
          SizedBox(height: tokens.spacing.step4),
          DesignSystemInlineCallout(
            icon: LottiIcons.lock,
            text: context.messages.syncAddDeviceSecurityNote,
          ),
          SizedBox(height: tokens.spacing.step4),
          DesignSystemInlineCallout(
            icon: LottiIcons.info,
            tone: tokens.colors.alert.info.defaultColor,
            text: context.messages.designSystemCalloutInfoSample,
          ),
        ],
      ),
    );
  }
}
