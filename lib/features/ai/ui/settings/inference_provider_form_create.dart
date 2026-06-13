import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/util/ai_provider_visual.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:url_launcher/url_launcher.dart';

// Create-mode chrome: breadcrumbs, step indicator, header/footer,
// flat fields and the connection status strip.

/// Container that stacks the create-mode chrome — breadcrumbs, step
/// indicator, and the provider-tinted hero card — above the form.
/// Encapsulates the responsive logic so the build path stays clean:
/// the page just plugs in `CreateModeChrome(providerType: …)` and the
/// helper picks the right padding + spacing per viewport. Wide
/// (>= 720) viewports keep the breadcrumbs row visible; narrower
/// surfaces drop them because the AppBar leading-back arrow already
/// expresses the same navigation intent.
class CreateModeChrome extends StatelessWidget {
  const CreateModeChrome({
    required this.providerType,
    required this.onChooseProvider,
    super.key,
  });

  final InferenceProviderType providerType;
  final VoidCallback onChooseProvider;

  /// Breakpoint above which the breadcrumb row + the tappable
  /// "Choose provider" step are shown. Below this width the AppBar
  /// back-arrow IS the primary back affordance, and showing a second
  /// crumb-row on a phone-sized viewport would just crowd the form.
  static const double _wideBreakpoint = 720;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= _wideBreakpoint;
    final providerName = aiProviderDisplayName(
      type: providerType,
      messages: messages,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step6,
        tokens.spacing.step3,
        tokens.spacing.step6,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isWide) ...[
            _AddProviderBreadcrumbs(providerName: providerName),
            SizedBox(height: tokens.spacing.step4),
          ],
          _AddProviderStepIndicator(
            onChoosePressed: isWide ? onChooseProvider : null,
          ),
          SizedBox(height: tokens.spacing.step5),
          _AddProviderHeaderCard(providerType: providerType),
        ],
      ),
    );
  }
}

/// Compact breadcrumb strip rendered above the form when adding a new
/// provider. Mirrors the desktop reference design:
/// `Settings › AI Settings › Add provider › [provider name]`. On
/// narrow viewports the component truncates earlier crumbs to the
/// available width — the last (provider name) crumb is always visible
/// because it's the most location-specific.
class _AddProviderBreadcrumbs extends StatelessWidget {
  const _AddProviderBreadcrumbs({required this.providerName});

  final String providerName;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final caption = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.lowEmphasis,
    );
    final activeCaption = caption.copyWith(
      color: tokens.colors.text.highEmphasis,
      fontWeight: tokens.typography.weight.semiBold,
    );
    final separator = Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step2),
      child: Text('›', style: caption),
    );
    return DefaultTextStyle.merge(
      style: caption,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(messages.settingsV2DetailRootCrumb, style: caption),
          separator,
          Text(messages.settingsAiTitle, style: caption),
          separator,
          Text(messages.aiProviderConnectBreadcrumbAdd, style: caption),
          separator,
          Text(providerName, style: activeCaption),
        ],
      ),
    );
  }
}

/// Three-step horizontal indicator: "Choose provider › Connect ›
/// Review". The active step is bold + accent-coloured. The
/// `Choose provider` step renders as a back-affordance link on
/// desktop so the user can jump back to the picker without losing
/// the form state — mobile preserves the same back navigation via
/// the AppBar's leading arrow.
class _AddProviderStepIndicator extends StatelessWidget {
  const _AddProviderStepIndicator({this.onChoosePressed});

  /// Tap callback for the first step. When `null` the step is
  /// rendered as plain text (mobile) — back navigation is handled by
  /// the AppBar arrow, so a duplicate affordance would just be
  /// crowding.
  final VoidCallback? onChoosePressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final inactiveStyle = tokens.typography.styles.body.bodySmall.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );
    final activeStyle = inactiveStyle.copyWith(
      color: tokens.colors.text.highEmphasis,
      fontWeight: tokens.typography.weight.semiBold,
    );
    final separator = Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step3),
      child: Icon(
        Icons.chevron_right_rounded,
        size: tokens.spacing.step5,
        color: tokens.colors.text.lowEmphasis,
      ),
    );
    final chooseLabel = messages.aiProviderConnectStepChoose;
    final chooseWidget = onChoosePressed == null
        ? Text(chooseLabel, style: inactiveStyle)
        : Semantics(
            button: true,
            child: InkWell(
              onTap: onChoosePressed,
              borderRadius: BorderRadius.circular(tokens.radii.s),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.step2,
                  vertical: tokens.spacing.step1,
                ),
                child: Text(chooseLabel, style: inactiveStyle),
              ),
            ),
          );
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        chooseWidget,
        separator,
        Text(messages.aiProviderConnectStepConnect, style: activeStyle),
        separator,
        Text(messages.aiProviderConnectStepReview, style: inactiveStyle),
      ],
    );
  }
}

/// Provider-tinted hero card sitting above the form fields. Carries
/// the provider's icon in a tinted square + the localised
/// `Connect <provider name>` title + the provider's tagline. The
/// accent + surface come from `aiProviderVisual` so the same
/// per-provider chrome the rest of the AI Settings surface uses is
/// reproduced here without re-declaring colours.
class _AddProviderHeaderCard extends StatelessWidget {
  const _AddProviderHeaderCard({required this.providerType});

  final InferenceProviderType providerType;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final accent = aiProviderAccent(type: providerType, tokens: tokens);
    final surface = aiProviderSurface(type: providerType, tokens: tokens);
    final providerName = aiProviderDisplayName(
      type: providerType,
      messages: messages,
    );
    final tagline = aiProviderTagline(type: providerType, messages: messages);
    return Container(
      padding: EdgeInsets.all(tokens.spacing.step5),
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.l),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: tokens.spacing.step9,
            height: tokens.spacing.step9,
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(tokens.radii.m),
            ),
            child: Icon(
              aiProviderIcon(providerType),
              color: accent,
              size: tokens.spacing.step7,
            ),
          ),
          SizedBox(width: tokens.spacing.step5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  messages.aiProviderConnectPageTitle(providerName),
                  style: tokens.typography.styles.heading.heading3.copyWith(
                    color: tokens.colors.text.highEmphasis,
                    fontWeight: tokens.typography.weight.semiBold,
                  ),
                ),
                if (tagline.isNotEmpty) ...[
                  SizedBox(height: tokens.spacing.step2),
                  Text(
                    tagline,
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Footer action row used in the create flow: Back to providers /
/// Save as draft / Save & continue. The three buttons reflow onto
/// multiple rows on narrow viewports via `Wrap`.
class AddProviderFooterBar extends StatelessWidget {
  const AddProviderFooterBar({
    required this.onBack,
    required this.onSaveDraft,
    required this.onSaveAndContinue,
    required this.canSaveDraft,
    required this.canSaveAndContinue,
    required this.isSaving,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback? onSaveDraft;
  final VoidCallback? onSaveAndContinue;

  /// Loose gate for the draft button — true as soon as the form has
  /// the minimum fields a draft needs (display name + preselected
  /// provider type). Distinct from [canSaveAndContinue] because the
  /// draft path is allowed to persist a partial config that wouldn't
  /// pass full validation.
  final bool canSaveDraft;

  /// Strict gate for the primary CTA — requires the form to fully
  /// validate (display name, API key for cloud providers, base URL
  /// shape) before the FTUE workflow is allowed to fire.
  final bool canSaveAndContinue;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step6,
        vertical: tokens.spacing.step4,
      ),
      decoration: BoxDecoration(
        color: tokens.colors.background.level01,
        border: Border(
          top: BorderSide(
            color: tokens.colors.decorative.level01,
          ),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: tokens.spacing.step3,
        runSpacing: tokens.spacing.step3,
        children: [
          DesignSystemButton(
            label: messages.aiProviderConnectBackToProviders,
            variant: DesignSystemButtonVariant.tertiary,
            size: DesignSystemButtonSize.large,
            leadingIcon: Icons.arrow_back_rounded,
            onPressed: isSaving ? null : onBack,
          ),
          Wrap(
            spacing: tokens.spacing.step3,
            runSpacing: tokens.spacing.step3,
            children: [
              DesignSystemButton(
                label: messages.aiProviderConnectSaveAsDraft,
                variant: DesignSystemButtonVariant.secondary,
                size: DesignSystemButtonSize.large,
                onPressed: canSaveDraft && !isSaving ? onSaveDraft : null,
              ),
              DesignSystemButton(
                label: messages.aiProviderConnectSaveAndContinue,
                size: DesignSystemButtonSize.large,
                trailingIcon: Icons.arrow_forward_rounded,
                onPressed: canSaveAndContinue && !isSaving
                    ? onSaveAndContinue
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tone for the right-hand hint text in a [FlatField]. `helper`
/// renders as a low-emphasis caption; `link` renders as an accent-
/// coloured, underlined string. When a `hintRightUrl` is supplied
/// alongside the `link` tone, the hint becomes a real tap target
/// that opens the URL in an external browser.
enum FlatFieldHintTone { helper, link }

/// Flat row used in the create-mode form: a CAPITAL caption on the
/// left, an optional right-hand hint, and the field widget below.
/// Replaces the legacy `AiFormSection` wrapper for the redesigned
/// connect form so the layout matches the reference screenshot
/// (caption + right-hand hint + field, with no surrounding card).
class FlatField extends StatelessWidget {
  const FlatField({
    required this.label,
    required this.child,
    this.hintRight,
    this.hintRightTone = FlatFieldHintTone.helper,
    this.hintRightUrl,
    super.key,
  });

  final String label;
  final Widget child;
  final String? hintRight;
  final FlatFieldHintTone hintRightTone;

  /// Optional URL launched when the user taps the right-hand hint.
  /// Only honored when [hintRightTone] is `FlatFieldHintTone.link`.
  final String? hintRightUrl;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final captionStyle = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.lowEmphasis,
      letterSpacing: 1.2,
      fontWeight: tokens.typography.weight.semiBold,
    );
    final isLink = hintRightTone == FlatFieldHintTone.link;
    final hintStyle = tokens.typography.styles.body.bodySmall.copyWith(
      color: isLink
          ? tokens.colors.interactive.enabled
          : tokens.colors.text.mediumEmphasis,
      decoration: isLink && hintRightUrl != null
          ? TextDecoration.underline
          : TextDecoration.none,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label.toUpperCase(), style: captionStyle),
            ),
            if (hintRight != null && hintRight!.isNotEmpty)
              Flexible(child: _buildHintRight(hintStyle)),
          ],
        ),
        SizedBox(height: tokens.spacing.step2),
        child,
      ],
    );
  }

  Widget _buildHintRight(TextStyle style) {
    final text = Text(
      hintRight!,
      style: style,
      textAlign: TextAlign.end,
      overflow: TextOverflow.ellipsis,
    );
    final url = hintRightUrl;
    if (hintRightTone != FlatFieldHintTone.link || url == null) {
      return text;
    }
    return Semantics(
      link: true,
      child: InkWell(
        onTap: () => _launchHintUrl(url),
        mouseCursor: SystemMouseCursors.click,
        child: text,
      ),
    );
  }

  Future<void> _launchHintUrl(String url) async {
    // Console URLs in `aiProviderKeyConsoleUrl` are stored as bare
    // hosts (e.g. `platform.openai.com`) so the rendered hint stays
    // compact. Prepend `https://` when the parsed URI lacks a scheme
    // so the launcher receives a fully-qualified target instead of
    // bailing out on the `hasScheme` guard.
    var uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!uri.hasScheme) {
      uri = Uri.tryParse('https://$url');
      if (uri == null || !uri.hasScheme) return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
