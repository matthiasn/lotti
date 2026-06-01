import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/skill_assignment.dart';

void main() {
  group('SkillAssignment', () {
    test('automate defaults to false', () {
      const assignment = SkillAssignment(skillId: 'skill-1');

      expect(assignment.skillId, 'skill-1');
      expect(assignment.automate, isFalse);
    });

    test('automate can be set to true', () {
      const assignment = SkillAssignment(skillId: 'skill-2', automate: true);

      expect(assignment.automate, isTrue);
    });

    test('JSON round-trip preserves skillId and automate=true', () {
      const assignment = SkillAssignment(skillId: 'skill-abc', automate: true);

      final decoded = SkillAssignment.fromJson(
        jsonDecode(jsonEncode(assignment.toJson())) as Map<String, dynamic>,
      );

      expect(decoded.skillId, 'skill-abc');
      expect(decoded.automate, isTrue);
      expect(decoded, assignment);
    });

    test('JSON round-trip preserves default automate=false', () {
      const assignment = SkillAssignment(skillId: 'skill-xyz');

      final decoded = SkillAssignment.fromJson(
        jsonDecode(jsonEncode(assignment.toJson())) as Map<String, dynamic>,
      );

      expect(decoded.skillId, 'skill-xyz');
      expect(decoded.automate, isFalse);
      expect(decoded, assignment);
    });

    test('JSON without automate field deserializes with false default', () {
      final json = <String, dynamic>{'skillId': 'skill-legacy'};
      final decoded = SkillAssignment.fromJson(json);

      expect(decoded.skillId, 'skill-legacy');
      expect(decoded.automate, isFalse);
    });

    test('equality distinguishes skillId and automate', () {
      const a = SkillAssignment(skillId: 'skill-1', automate: true);
      const b = SkillAssignment(skillId: 'skill-1', automate: true);
      // ignore: avoid_redundant_argument_values
      const c = SkillAssignment(skillId: 'skill-1', automate: false);
      const d = SkillAssignment(skillId: 'skill-2', automate: true);

      expect(a, b);
      expect(a, isNot(c));
      expect(a, isNot(d));
    });

    test('copyWith updates fields independently', () {
      // ignore: avoid_redundant_argument_values
      const original = SkillAssignment(skillId: 'skill-1', automate: false);
      final toggled = original.copyWith(automate: true);
      final renamed = original.copyWith(skillId: 'skill-2');

      expect(toggled.skillId, 'skill-1');
      expect(toggled.automate, isTrue);
      expect(renamed.skillId, 'skill-2');
      expect(renamed.automate, isFalse);
    });
  });
}
