import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/state/recording_origin.dart';
import 'package:lotti/features/speech/state/recording_session.dart';
import 'package:lotti/features/speech/state/recording_subject.dart';
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
    origin != null &&
    _normalisedRoute(activeRoute) == _normalisedRoute(origin.route);

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

/// The strip's leading part, which fills the room the controls leave:
///
/// - **away** — ↩, a small *Recording for* (*Paused · Recording for*) over
///   the subject's title; the whole part one button back to where the take
///   started ([RecordingSession.returnToOrigin]);
/// - **here** — a red dot (a pause glyph while paused) and *Recording here*
///   (*Paused here*); not a button;
/// - **voice note** — the dot and *Voice note*; never a button.
///
/// It follows the route on screen, so arriving at the origin turns the way
/// back into *here* without a tap. The status words are a live region, so a
/// screen reader hears a pause or a resume once.
class RecordingStripLeading extends ConsumerWidget {
  const RecordingStripLeading({super.key});

  static const Key backKey = ValueKey('recording-strip-back');

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
    // never was, is a voice note.
    final title = recordingSubjectTitle(subject?.value);
    final gone = subject != null && subject.hasValue && title == null;
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
            title: title,
            onTap: origin == null
                ? null
                : () =>
                      ref.read(recordingSessionProvider).returnToOrigin(origin),
          ),
          RecordingStripPlace.here => _Status(
            paused: paused,
            label: paused
                ? context.messages.recordingStripPausedHere
                : context.messages.recordingStripRecordingHere,
          ),
          RecordingStripPlace.voiceNote => _Status(
            paused: paused,
            label: context.messages.recordingStripVoiceNote,
          ),
        };
      },
    );
  }
}

/// The ink of the strip's captions.
TextStyle _captionStyle(DsTokens tokens) =>
    tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );

/// The ink of the strip's main line.
TextStyle _titleStyle(DsTokens tokens) =>
    tokens.typography.styles.body.bodySmall.copyWith(
      color: tokens.colors.text.highEmphasis,
    );

/// The red dot of a running take, or the pause glyph of a held one.
class _LiveGlyph extends StatelessWidget {
  const _LiveGlyph({required this.paused});

  final bool paused;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return paused
        ? Icon(
            LottiIcons.pause,
            size: IconSizes.s,
            color: tokens.colors.text.mediumEmphasis,
          )
        : const DesignSystemBadge.dot(
            tone: DesignSystemBadgeTone.danger,
            excludeFromSemantics: true,
          );
  }
}

/// The dot and one line of words — *Recording here*, *Voice note*.
class _Status extends StatelessWidget {
  const _Status({required this.paused, required this.label});

  final bool paused;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
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
                style: _titleStyle(tokens),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ↩ and *Recording for* over the subject's title: one button back.
class _BackToOrigin extends StatelessWidget {
  const _BackToOrigin({
    required this.paused,
    required this.title,
    required this.onTap,
  });

  final bool paused;

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
    final content = Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step3),
      child: Row(
        children: [
          if (tap != null) ...[
            Icon(
              LottiIcons.undo,
              size: IconSizes.m,
              color: tokens.colors.interactive.enabled,
            ),
            SizedBox(width: tokens.spacing.step3),
          ] else ...[
            _LiveGlyph(paused: paused),
            SizedBox(width: tokens.spacing.step3),
          ],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  liveRegion: true,
                  child: Text(
                    caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _captionStyle(tokens),
                  ),
                ),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _titleStyle(tokens),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (tap == null) return content;
    // One button by the way back; its value is the status, live, so a
    // pause or a resume is heard once.
    return Semantics(
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
    );
  }
}
