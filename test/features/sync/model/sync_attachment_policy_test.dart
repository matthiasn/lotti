import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/model/sync_attachment_policy.dart';
import 'package:lotti/features/sync/model/sync_message.dart';

void main() {
  group('shouldSendJournalAttachments', () {
    test('a new entry always carries its blob', () {
      expect(
        shouldSendJournalAttachments(
          status: SyncEntryStatus.initial,
          includeAttachments: null,
          resendAttachmentsFlag: false,
        ),
        isTrue,
      );
    });

    test('an ordinary edit sends JSON only', () {
      expect(
        shouldSendJournalAttachments(
          status: SyncEntryStatus.update,
          includeAttachments: null,
          resendAttachmentsFlag: false,
        ),
        isFalse,
      );
    });

    test(
      'an update opting in carries its blob — the re-sync/backfill case',
      () {
        expect(
          shouldSendJournalAttachments(
            status: SyncEntryStatus.update,
            includeAttachments: true,
            resendAttachmentsFlag: false,
          ),
          isTrue,
        );
      },
    );

    test('the resend flag forces the blob onto an update', () {
      expect(
        shouldSendJournalAttachments(
          status: SyncEntryStatus.update,
          includeAttachments: null,
          resendAttachmentsFlag: true,
        ),
        isTrue,
      );
    });

    test(
      'an explicit opt-out never suppresses a new entry or the resend flag',
      () {
        // `includeAttachments: false` is a *positive* opt-in absent, not a veto:
        // a peer that has never seen the entry still needs the blob, and the
        // operator escape hatch must stay authoritative. Reading it as a veto
        // would reintroduce the silently-blank-media failure through the back
        // door.
        expect(
          shouldSendJournalAttachments(
            status: SyncEntryStatus.initial,
            includeAttachments: false,
            resendAttachmentsFlag: false,
          ),
          isTrue,
        );
        expect(
          shouldSendJournalAttachments(
            status: SyncEntryStatus.update,
            includeAttachments: false,
            resendAttachmentsFlag: true,
          ),
          isTrue,
        );
      },
    );
  });
}
