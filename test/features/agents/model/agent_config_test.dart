import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';

void main() {
  group('AgentMessageMetadata.milestone', () {
    // The JSON value for each milestone is the cross-device sync wire format
    // and the key the State-as-Projection fold matches on (PR 4). Renaming an
    // enum value would silently break already-synced markers, so pin the exact
    // wire strings here as a regression guard.
    const wireValues = {
      AgentMilestone.wakeCompleted: 'wakeCompleted',
      AgentMilestone.oneOnOneCompleted: 'oneOnOneCompleted',
      AgentMilestone.feedbackScanCompleted: 'feedbackScanCompleted',
      AgentMilestone.dailyWakeCompleted: 'dailyWakeCompleted',
      AgentMilestone.weeklyReviewCompleted: 'weeklyReviewCompleted',
    };

    test('covers every milestone value', () {
      expect(wireValues.keys, unorderedEquals(AgentMilestone.values));
    });

    for (final entry in wireValues.entries) {
      final milestone = entry.key;
      final wire = entry.value;

      test('$milestone serialises to "$wire" and round-trips', () {
        final metadata = AgentMessageMetadata(milestone: milestone);

        // Encode through a real JSON pass to exercise the wire format.
        final json =
            jsonDecode(jsonEncode(metadata.toJson())) as Map<String, dynamic>;
        expect(json['milestone'], wire);

        final restored = AgentMessageMetadata.fromJson(json);
        expect(restored.milestone, milestone);
        expect(restored, metadata);
      });
    }

    test('defaults to null and leaves other fields intact', () {
      const metadata = AgentMessageMetadata(runKey: 'rk-1', toolName: 'tool');

      expect(metadata.milestone, isNull);

      final restored = AgentMessageMetadata.fromJson(metadata.toJson());
      expect(restored.milestone, isNull);
      expect(restored.runKey, 'rk-1');
      expect(restored.toolName, 'tool');
    });

    test('absent milestone key deserialises to null (backward compat)', () {
      // A row written before the field existed has no `milestone` key.
      final restored = AgentMessageMetadata.fromJson(
        const {'runKey': 'rk-legacy'},
      );

      expect(restored.milestone, isNull);
      expect(restored.runKey, 'rk-legacy');
    });

    test(
      'unknown milestone value deserialises to null (forward compat)',
      () {
        // A newer client may emit a milestone this build does not know about;
        // it must degrade to null rather than throw on deserialisation.
        final restored = AgentMessageMetadata.fromJson(
          const {'milestone': 'someFutureMilestone'},
        );

        expect(restored.milestone, isNull);
      },
    );
  });
}
