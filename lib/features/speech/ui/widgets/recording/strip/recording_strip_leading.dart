import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/state/recording_origin.dart';
import 'package:lotti/features/speech/state/recording_session.dart';
import 'package:lotti/features/speech/state/recording_subject.dart';
import 'package:lotti/features/speech/ui/widgets/recording/recording_controls.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:material_ui/material_ui.dart';

/// [route] without a query or a trailing slash, so two spellings of one
/// page compare equal.
String _normalisedRoute(String route) {
  final path = Uri.parse(route).path;
  return path.length > 1 && path.endsWith('/')
      ? path.substring(0, path.length - 1)
      : path;
}

/// Whether [activeRoute] is where [origin]'s take started — the strip then
/// says *Recording here* instead of offering a trip to where the user
/// already is. No origin is never here.
bool isOnRecordingOrigin(String activeRoute, RecordingOrigin? origin) =>
    origin != null && isSameRecordingRoute(activeRoute, origin.route);

/// Whether [a] and [b] name the same page, without query or trailing slash.
bool isSameRecordingRoute(String a, String b) =>
    _normalisedRoute(a) == _normalisedRoute(b);

/// What the leading part of the strip says, decided once for the strip and
/// the tray's header.
enum RecordingStripPlace {
  /// Away from where the take started: the way back.
  away,

  /// On the page where the take started.
  here,

  /// A take linked to nothing, or to a subject since deleted: nowhere to go.
  voiceNote,
}

/// The leading part of the strip and of its tray's header:
///
/// - **away** — ↩ and the subject's title, one button back to where the
///   take started ([RecordingSession.returnToOrigin]);
/// - **here** — a red dot (a pause glyph while paused) and *Recording here*
///   (*Paused here*); not a button;
/// - **voice note** — the dot and *Voice note*; never a button.
///
/// [compact] — on the strip — it is the glyph alone, in a square as tall as
/// the controls, and the words are only what a screen reader hears: a
/// title cut to a few letters says little, and the strip gives its room to
/// the level instead.
///
/// It follows the route on screen, so arriving at the origin turns the way
/// back into *here* without a tap. The status is a live region, so a
/// screen reader hears a pause or a resume once.
class RecordingStripLeading extends ConsumerWidget {
  const RecordingStripLeading({this.compact = false, super.key});

  /// The glyph alone, its words for a screen reader only.
  final bool compact;

  static const Key backKey = ValueKey('recording-strip-back');

  /// The one square every leading glyph sits in — the dot, the pause mark,
  /// the way back, the receipt's tick — so the words after it never shift
  /// when the strip changes state.
  static const double glyphSlot = IconSizes.m;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paused = ref.watch(
      audioRecorderControllerProvider.select(
        (state) => state.status == AudioRecorderStatus.paused,
      ),
    );
    final origin = ref.watch(
      audioRecorderControllerProvider.select((state) => state.origin),
    );
    final subjectId = ref.watch(
      audioRecorderControllerProvider.select((state) => state.linkedId),
    );
    final subject = subjectId == null
        ? null
        : ref.watch(recordingSubjectProvider(subjectId));
    // A subject still loading keeps its place; one that is gone, or that
    // never was, is a voice note. One with no words to name it by is still
    // somewhere to go back to.
    final title = recordingSubjectTitle(subject?.value);
    final gone = subject != null && subject.hasValue && subject.value == null;
    final nav = ref.watch(navServiceProvider);
    return ListenableBuilder(
      listenable: nav.activeRouteChanges,
      builder: (context, _) {
        final place = subjectId == null || gone
            ? RecordingStripPlace.voiceNote
            : isOnRecordingOrigin(nav.activeRoute, origin)
            ? RecordingStripPlace.here
            : RecordingStripPlace.away;
        return switch (place) {
          RecordingStripPlace.away => _BackToOrigin(
            paused: paused,
            compact: compact,
            title: title,
            onTap: origin == null
                ? null
                : () =>
                      ref.read(recordingSessionProvider).returnToOrigin(origin),
          ),
          RecordingStripPlace.here => _Status(
            paused: paused,
            compact: compact,
            label: paused
                ? context.messages.recordingStripPausedHere
                : context.messages.recordingStripRecordingHere,
          ),
          RecordingStripPlace.voiceNote => _Status(
            paused: paused,
            compact: compact,
            label: context.messages.recordingStripVoiceNote,
          ),
        };
      },
    );
  }
}

/// The red dot of a running take, or the pause glyph of a held one.
class _LiveGlyph extends StatelessWidget {
  const _LiveGlyph({required this.paused});

  final bool paused;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return SizedBox.square(
      dimension: RecordingStripLeading.glyphSlot,
      child: Center(
        child: paused
            ? Icon(
                LottiIcons.pause,
                size: IconSizes.s,
                color: tokens.colors.text.mediumEmphasis,
              )
            : const DesignSystemBadge.dot(
                tone: DesignSystemBadgeTone.danger,
                excludeFromSemantics: true,
              ),
      ),
    );
  }
}

/// The dot and one line of words — *Recording here*, *Voice note* — or,
/// [compact], the dot alone, the words its label.
class _Status extends StatelessWidget {
  const _Status({
    required this.paused,
    required this.compact,
    required this.label,
  });

  final bool paused;
  final bool compact;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    if (compact) {
      return Semantics(
        liveRegion: true,
        label: label,
        child: SizedBox.square(
          dimension: tokens.spacing.step9,
          child: _LiveGlyph(paused: paused),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step3),
      child: Row(
        children: [
          _LiveGlyph(paused: paused),
          SizedBox(width: tokens.spacing.step3),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: recordingTitleStyle(tokens),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ↩ and the subject's title — [compact], ↩ alone: one button back.
class _BackToOrigin extends StatelessWidget {
  const _BackToOrigin({
    required this.paused,
    required this.compact,
    required this.title,
    required this.onTap,
  });

  final bool paused;
  final bool compact;

  /// The subject's title; null while it loads.
  final String? title;

  /// Null where the take has no origin to go back to.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final caption = paused
        ? messages.recordingStripPausedFor
        : messages.recordingStripRecordingFor;
    final name = title ?? '';
    final tap = onTap;
    final glyph = tap != null
        ? Icon(
            LottiIcons.back,
            size: RecordingStripLeading.glyphSlot,
            color: tokens.colors.interactive.enabled,
          )
        : _LiveGlyph(paused: paused);
    final Widget content;
    if (compact) {
      content = SizedBox.square(
        dimension: tokens.spacing.step9,
        child: Center(child: glyph),
      );
    } else {
      content = Padding(
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step3),
        child: Row(
          // As wide as its words, so the way back is a bounded target and
          // the rest of the tray's header is not.
          mainAxisSize: MainAxisSize.min,
          children: [
            glyph,
            SizedBox(width: tokens.spacing.step3),
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: recordingTitleStyle(tokens),
              ),
            ),
          ],
        ),
      );
    }
    if (tap == null) {
      return Semantics(
        label: name,
        value: caption,
        liveRegion: true,
        excludeSemantics: true,
        child: content,
      );
    }
    // One button by the way back; its value is the status, live, so a
    // pause or a resume is heard once.
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Semantics(
        button: true,
        label: messages.recordingStripBackTo(name),
        value: caption,
        liveRegion: true,
        excludeSemantics: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: RecordingStripLeading.backKey,
            borderRadius: BorderRadius.circular(tokens.radii.m),
            onTap: tap,
            // At least a full tap target; taller with the text size, so the
            // caption and the title never clip.
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: tokens.spacing.step9),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: 1,
                heightFactor: 1,
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
