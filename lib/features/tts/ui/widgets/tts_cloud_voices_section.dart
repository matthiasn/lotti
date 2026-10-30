import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/supported_language.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/lists/design_system_grouped_list.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tts/cloud/voxtral_voice_catalog.dart';
import 'package:lotti/features/tts/model/tts_playback_state.dart';
import 'package:lotti/features/tts/state/cloud_voice_settings_providers.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';
import 'package:lotti/features/tts/state/tts_settings_controller.dart';
import 'package:lotti/features/tts/ui/playback_failure_toast.dart';
import 'package:lotti/features/tts/ui/widgets/tts_cloud_voice_picker.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/settings/settings_form_section.dart';
import 'package:material_ui/material_ui.dart';

/// The Cloud voices section of Speech settings: for each provider a profile
/// reads aloud with, one row per language its catalog covers, naming the
/// voice that speaks it.
///
/// The user's own languages — the app's, and every language they picked a
/// voice for — come first; the rest of a catalog that covers twenty-odd
/// languages waits behind one "Other languages" row, so the section stays the
/// size of what is actually used. A row with several voices opens
/// [showCloudVoicePicker]; a row with one plays it. Every row's speaker plays
/// the voice in use without opening anything.
///
/// Without any such profile it says where a cloud voice comes from instead,
/// so nobody looks for a missing read-aloud control.
class TtsCloudVoicesSection extends ConsumerWidget {
  const TtsCloudVoicesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = context.messages;
    final spacing = context.designTokens.spacing;
    // The previous value is kept while profiles reload, so a sync never
    // swaps the rows for a spinner.
    final services = ref.watch(cloudVoiceServicesProvider).value ?? const [];
    // The heading alone, and the rows as a grouped list under it: list rows
    // carry their own inset, so the form card's padding would double it.
    final heading = SettingsFormSection(
      title: messages.speechSettingsCloudVoicesLabel,
      description: services.isEmpty
          ? messages.speechSettingsCloudVoicesNone
          : messages.speechSettingsCloudVoicesDescription,
      children: const [],
    );
    if (services.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(bottom: spacing.sectionGap),
        child: heading,
      );
    }
    return Padding(
      padding: EdgeInsets.only(bottom: spacing.sectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The heading brings its own gap to what follows it.
          heading,
          // Keyed by identity, not position: a provider added or removed
          // must not hand one provider's rows to another.
          for (final (i, service) in services.indexed)
            Padding(
              key: ValueKey(service.provider.id),
              padding: EdgeInsets.only(top: i == 0 ? 0 : spacing.step5),
              child: _ServiceVoices(
                service: service,
                showName: services.length > 1,
              ),
            ),
        ],
      ),
    );
  }
}

/// [language]'s name in the UI language, or its code when the app has no
/// name for it.
String cloudVoiceLanguageName(BuildContext context, String language) =>
    SupportedLanguage.fromCode(language)?.localizedName(context) ??
    language.toUpperCase();

class _ServiceVoices extends ConsumerWidget {
  const _ServiceVoices({
    required this.service,
    required this.showName,
  });

  final CloudVoiceService service;
  final bool showName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final provider = voxtralVoiceCatalogProvider(service.provider);
    final catalog = ref.watch(provider);
    final caption = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );
    final state = switch (catalog) {
      AsyncValue(hasValue: true) => null,
      AsyncValue(hasError: true) => Row(
        spacing: tokens.spacing.step3,
        children: [
          Expanded(
            child: Text(
              messages.speechSettingsCloudVoicesUnavailable,
              style: caption,
            ),
          ),
          DesignSystemButton(
            label: messages.speechSettingsCloudVoicesRetry,
            variant: DesignSystemButtonVariant.secondary,
            onPressed: () => ref.invalidate(provider),
          ),
        ],
      ),
      _ => Center(
        child: DesignSystemSpinner(
          size: IconSizes.m,
          semanticsLabel: messages.speechSettingsCloudVoicesLoading,
        ),
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: tokens.spacing.step2,
      children: [
        if (showName) Text(service.provider.name, style: caption),
        if (catalog.value case final value?)
          _LanguageList(service: service, catalog: value)
        else
          DesignSystemGroupedList(
            padding: EdgeInsets.zero,
            children: [
              Padding(
                padding: EdgeInsets.all(tokens.spacing.cardPadding),
                child: state,
              ),
            ],
          ),
      ],
    );
  }
}

class _LanguageList extends ConsumerStatefulWidget {
  const _LanguageList({required this.service, required this.catalog});

  final CloudVoiceService service;
  final VoxtralVoiceCatalog catalog;

  @override
  ConsumerState<_LanguageList> createState() => _LanguageListState();
}

class _LanguageListState extends ConsumerState<_LanguageList> {
  bool _expanded = false;

  /// Every language shown among the user's own so far: one stays there
  /// while the page is open, even when its pick is cleared.
  final Set<String> _sticky = {};

  /// Languages whose picker was opened from this page. A voice picked there
  /// leaves the row where it was — a row that jumped to the top right after
  /// being edited would read as lost. Collapsing the list, or the next
  /// visit, regroups. Picks that merely finish loading from storage still
  /// join the user's languages.
  final Set<String> _touched = {};

  final GlobalKey _seamKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final chosen = ref.watch(
      ttsSettingsControllerProvider.select((s) => s.cloudVoiceByLanguage),
    );
    final appLanguage = Localizations.localeOf(context).languageCode;
    final names = {
      for (final language in widget.catalog.languageCodes)
        language: cloudVoiceLanguageName(context, language),
    };
    int byName(String a, String b) => names[a]!.compareTo(names[b]!);
    _sticky.addAll([
      if (names.containsKey(appLanguage)) appLanguage,
      ...chosen.keys.where(
        (l) => names.containsKey(l) && !_touched.contains(l),
      ),
    ]);
    final own = [
      // Sticky only while the catalog still has it: a refresh that drops a
      // language must drop its row, not fail the list.
      if (_sticky.contains(appLanguage) && names.containsKey(appLanguage))
        appLanguage,
      ...(_sticky
          .where((l) => l != appLanguage && names.containsKey(l))
          .toList()
        ..sort(byName)),
    ];
    final others = names.keys.where((l) => !own.contains(l)).toList()
      ..sort(byName);
    // With none of the user's languages in the catalog there is nothing to
    // put first, and a lone "More languages" row would hide everything.
    final disclosed = own.isNotEmpty && others.isNotEmpty;

    Widget row(
      String language, {
      required bool last,
      bool small = false,
      bool seam = false,
    }) => _LanguageRow(
      key: ValueKey(language),
      small: small,
      seam: seam,
      service: widget.service,
      catalog: widget.catalog,
      language: language,
      languageName: names[language]!,
      chosenVoiceId: chosen[language],
      showDivider: !last,
      onOpen: () => _touched.add(language),
    );

    final shownOthers = !disclosed || _expanded ? others : const <String>[];
    final withChoice = others
        .where((l) => widget.catalog.forLanguage(l).length > 1)
        .length;

    // At the seam it names the group below it, open or closed; at the end
    // of an open list it is the command that closes it.
    Widget disclosure({required bool atEnd}) => Semantics(
      expanded: _expanded,
      child: DesignSystemListItem(
        key: atEnd ? null : _seamKey,
        titleContent: Text(
          atEnd
              ? messages.speechSettingsCloudVoicesFewerLanguages
              : messages.speechSettingsCloudVoicesOtherLanguages(
                  others.length,
                ),
          // The rows' own size, a heavier weight: a header, not one more
          // language.
          style: tokens.typography.styles.subtitle.subtitle2.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
        // Closed, it says whether opening is worth it: how many of the
        // hidden languages have a voice to choose.
        subtitle: atEnd || _expanded || withChoice == 0
            ? null
            : messages.speechSettingsCloudVoicesWithChoice(withChoice),
        subtitleEmphasis: tokens.colors.text.lowEmphasis,
        size: DesignSystemListItemSize.small,
        // The seam runs the full width, unlike the inset row dividers.
        showDivider: _expanded && !atEnd,
        dividerIndent: 0,
        // A touch target tall, so the row keeps the floor with its label
        // centred.
        trailing: SizedBox(
          height: TapTargets.compact,
          child: Icon(
            _expanded ? LottiIcons.chevronUp : LottiIcons.chevronDown,
            size: IconSizes.s,
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
        onTap: () => setState(() {
          _expanded = !_expanded;
          // Collapsing regroups: a language picked below the seam joins the
          // user's own rather than hiding behind the disclosure.
          if (!_expanded) {
            _touched.clear();
            // Closed from the end of a long list: bring the seam back into
            // view rather than leave the reader below the section.
            if (atEnd) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final seam = _seamKey.currentContext;
                if (seam != null && seam.mounted) {
                  Scrollable.ensureVisible(seam, alignment: 0.3);
                }
              });
            }
          }
        }),
      ),
    );

    return DesignSystemGroupedList(
      padding: EdgeInsets.zero,
      children: [
        for (final (i, language) in own.indexed)
          row(
            language,
            last: !disclosed && i == own.length - 1,
            seam: disclosed && i == own.length - 1,
          ),
        // The disclosure stays at the seam between the user's languages and
        // the rest, so opening it never moves the control away.
        if (disclosed) disclosure(atEnd: false),
        // Smaller below the seam: the languages the user does not use read
        // lighter than their own.
        // The last of them meets the closing disclosure across the same
        // full-width rule as the seam above.
        for (final (i, language) in shownOthers.indexed)
          row(
            language,
            last: i == shownOthers.length - 1 && !(disclosed && _expanded),
            seam: disclosed && i == shownOthers.length - 1,
            small: disclosed,
          ),
        // A long open list closes from its end too, without scrolling back.
        if (disclosed && _expanded) disclosure(atEnd: true),
      ],
    );
  }
}

class _LanguageRow extends ConsumerWidget {
  const _LanguageRow({
    required this.service,
    required this.catalog,
    required this.language,
    required this.languageName,
    required this.chosenVoiceId,
    required this.showDivider,
    required this.onOpen,
    this.small = false,
    this.seam = false,
    super.key,
  });

  final CloudVoiceService service;
  final VoxtralVoiceCatalog catalog;
  final String language;
  final String languageName;
  final String? chosenVoiceId;
  final bool showDivider;

  /// Called as the row opens its picker.
  final VoidCallback onOpen;

  final bool small;

  /// A row whose divider meets a disclosure row: full width, the seam.
  final bool seam;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final chosen = chosenVoiceId == null ? null : catalog.byId(chosenVoiceId!);
    final voice = chosen ?? catalog.resolve(languageCode: language);
    final count = catalog.forLanguage(language).length;
    final emphasis = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.highEmphasis,
    );
    // One voice is nothing to choose between: the row plays it, says so,
    // and carries no chevron, instead of opening a list of one.
    final single = count < 2;
    final sourceId = voice == null
        ? null
        : cloudVoiceSampleSourceId(language, voice.id);
    if (sourceId != null) listenForPlaybackFailure(ref, context, sourceId);

    Future<void> play(TtsPlaybackController controller) =>
        speakCloudVoiceSample(
          controller,
          service: service,
          language: language,
          voiceId: voice!.id,
        );

    Future<void> playOrStop() async {
      final controller = ref.read(ttsPlaybackControllerProvider.notifier);
      final playback = ref.read(ttsPlaybackControllerProvider);
      if (playback.isActiveFor(sourceId!) &&
          playback.status != TtsPlaybackStatus.error) {
        await controller.stop(sourceId: sourceId);
      } else {
        await play(controller);
      }
    }

    return DesignSystemListItem(
      // Below the seam the title steps down too, so the user's own
      // languages stay the anchor once the list is open.
      titleContent: Text(
        languageName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        // A language the user picked a voice for is theirs on either tier:
        // its title is as strong as its subtitle.
        style: small && chosen == null
            ? tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              )
            : tokens.typography.styles.subtitle.subtitle2.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
      ),
      size: small
          ? DesignSystemListItemSize.small
          : DesignSystemListItemSize.medium,
      // The voice in use, "Your pick" when the user chose it, and how many
      // voices there are to choose from when there is a choice.
      subtitleSpans: [
        if (voice != null)
          TextSpan(
            text: voice.name,
            // Bright when the voice is the user's — above the seam, or
            // picked. Below the seam it is medium and the rest of the line
            // low (see subtitleEmphasis): readable, and never louder than
            // the language it serves.
            style: !small || chosen != null
                ? emphasis
                : tokens.typography.styles.others.caption.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
          ),
        if (chosen != null) ...[
          const TextSpan(text: ' · '),
          TextSpan(
            text: messages.speechSettingsCloudVoiceChosenTag,
            style: emphasis,
          ),
        ],
        // The count says there is a choice; a lone voice needs no words —
        // it has no chevron either.
        if (!single) ...[
          const TextSpan(text: ' · '),
          TextSpan(text: messages.speechSettingsCloudVoiceCount(count)),
        ],
      ],
      subtitleEmphasis: small && chosen == null
          ? tokens.colors.text.lowEmphasis
          : null,
      showDivider: showDivider,
      dividerIndent: seam ? 0 : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: tokens.spacing.step2,
        children: [
          if (sourceId != null)
            CloudVoicePreviewButton(
              sourceId: sourceId,
              voiceName: voice!.name,
              quiet: small && chosen == null,
              onPlay: play,
            ),
          // The chevron's width stays when there is none, so the speakers
          // line up on every row.
          SizedBox(
            width: IconSizes.s,
            child: single
                ? null
                : Icon(
                    LottiIcons.chevronRight,
                    size: IconSizes.s,
                    // Never fades with its row: it is how the few languages
                    // with a choice are found in a long list.
                    color: tokens.colors.text.mediumEmphasis,
                  ),
          ),
        ],
      ),
      onTap: single
          ? (sourceId == null ? null : playOrStop)
          : () {
              onOpen();
              showCloudVoicePicker(
                context,
                ref,
                service: service,
                catalog: catalog,
                language: language,
                languageName: languageName,
              );
            },
    );
  }
}
