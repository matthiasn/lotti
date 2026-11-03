import 'package:lotti/classes/change_source.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/supported_language.dart';
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/logic/repositories/journal_repository.dart';
import 'package:lotti/services/domain_logging.dart';

/// What became of an event agent's `set_event_language` call.
class EventLanguageResult {
  const EventLanguageResult({
    required this.success,
    required this.message,
    this.didWrite = false,
  });

  /// Whether the call was well-formed and the event's language now stands —
  /// set by this call or already set. False for a refused call.
  final bool success;

  /// What the model is told.
  final String message;

  /// Whether this call stored the language.
  final bool didWrite;
}

/// Sets the language an event's record is kept in, from its voice memos.
///
/// The agent's half of `EventData.languageCode`: it only ever **fills an
/// empty language**, and only once the event has a voice memo to hear it in
/// — the first recording is what the language is suggested from. Once a
/// language is set, by the agent or the user, it is the user's to change;
/// the call reports the language that stands instead. The write itself is
/// conditional on the stored row (`JournalRepository.changeEventData`), so a
/// language the user picked between the agent's read and its write is kept.
class EventLanguageHandler {
  EventLanguageHandler({
    required this.eventId,
    required this.journalRepository,
    required this._domainLogger,
  });

  final String eventId;
  final JournalRepository journalRepository;
  final DomainLogger _domainLogger;

  Future<EventLanguageResult> handle(String languageCode) async {
    final code = languageCode.trim().toLowerCase();
    if (code.isEmpty) {
      return const EventLanguageResult(
        success: false,
        message: 'Error: "languageCode" must not be empty.',
      );
    }
    final language = SupportedLanguage.fromCode(code);
    if (language == null) {
      return EventLanguageResult(
        success: false,
        message:
            'Error: unsupported language code "$code". Use one of: '
            '${SupportedLanguage.values.map((l) => l.code).join(', ')}.',
      );
    }

    final event = await journalRepository.getJournalEntityById(eventId);
    if (event is! JournalEvent || event.meta.deletedAt != null) {
      return const EventLanguageResult(
        success: false,
        message: 'Error: the event no longer exists.',
      );
    }
    if (_standing(event) case final String standing) {
      return EventLanguageResult(success: true, message: standing);
    }

    if (!await _hasVoiceMemo()) {
      return const EventLanguageResult(
        success: false,
        message:
            'Not set: the event has no transcribed voice memo yet, and its '
            'language is taken from the first one. Write in the language of '
            "the event's notes for now.",
      );
    }

    final stored = await journalRepository.changeEventData(
      eventId,
      (data) => data.languageCode != null
          ? null
          : data.copyWith(
              languageCode: language.code,
              languageSource: ChangeSource.agent,
            ),
    );
    if (!stored) {
      _domainLogger.log(
        LogDomain.agentWorkflow,
        'event language write refused',
        subDomain: 'EventLanguageHandler',
        level: InsightLevel.warn,
      );
      return const EventLanguageResult(
        success: false,
        message: "Error: the event's language could not be stored.",
      );
    }

    // Read back what stands: a language set between the read above and the
    // write was kept by the conditional write, and is the one to write in.
    final after = await journalRepository.getJournalEntityById(eventId);
    if (after is JournalEvent && after.data.languageCode != language.code) {
      if (_standing(after) case final String standing) {
        return EventLanguageResult(success: true, message: standing);
      }
    }
    _domainLogger.log(
      LogDomain.agentWorkflow,
      'event language set from a voice memo',
      subDomain: 'EventLanguageHandler',
    );
    return EventLanguageResult(
      success: true,
      didWrite: true,
      message:
          'Event language set to "${language.code}" (${language.name}). '
          'Write the recap and every suggestion in ${language.name}.',
    );
  }

  /// The answer for an event whose language is already set, or null while
  /// it has none.
  static String? _standing(JournalEvent event) {
    final current = event.data.languageCode;
    if (current == null) return null;
    final name = SupportedLanguage.fromCode(current)?.name ?? current;
    final by = event.data.languageSource == ChangeSource.user
        ? 'the user'
        : 'you, from a voice memo';
    return 'The event\'s language is already "$current" ($name), set by $by; '
        'it is not changed. Write the recap and every suggestion in $name.';
  }

  Future<bool> _hasVoiceMemo() async {
    final linked = await journalRepository.getLinkedEntities(
      linkedTo: eventId,
    );
    return linked.any(
      (entity) =>
          entity is JournalAudio &&
          entity.meta.deletedAt == null &&
          (entity.entryText?.plainText.trim().isNotEmpty ?? false),
    );
  }
}
