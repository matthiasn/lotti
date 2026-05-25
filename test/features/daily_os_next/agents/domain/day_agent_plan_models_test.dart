import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_plan_models.dart';

void main() {
  group('DayAgentEnergyBand', () {
    test('roundtrips through JSON', () {
      final band = DayAgentEnergyBand(
        start: DateTime(2026, 5, 25, 9),
        end: DateTime(2026, 5, 25, 12),
        level: DayAgentEnergyLevel.high,
        label: 'HIGH ENERGY',
      );

      final decoded = DayAgentEnergyBand.fromJson(
        jsonDecode(jsonEncode(band.toJson())) as Map<String, dynamic>,
      );

      expect(decoded, band);
      expect(decoded.hashCode, band.hashCode);
    });

    glados.Glados<_GeneratedEnergyBand>(
      glados.any.energyBand,
      glados.ExploreConfig(numRuns: 120),
    ).test('roundtrips generated bands through JSON', (generated) {
      final band = generated.toBand();

      final decoded = DayAgentEnergyBand.fromJson(
        jsonDecode(jsonEncode(band.toJson())) as Map<String, dynamic>,
      );

      expect(decoded, band, reason: '$generated');
      expect(decoded.toJson(), band.toJson(), reason: '$generated');
    }, tags: 'glados');
  });

  group('DayAgentLearningBullet', () {
    test('roundtrips through JSON', () {
      const bullet = DayAgentLearningBullet(
        text: 'Heavy planned days ran over capacity.',
        tone: DayAgentLearningBulletTone.warning,
      );

      final decoded = DayAgentLearningBullet.fromJson(
        jsonDecode(jsonEncode(bullet.toJson())) as Map<String, dynamic>,
      );

      expect(decoded, bullet);
      expect(decoded.hashCode, bullet.hashCode);
    });
  });

  group('DayAgentLearningCard', () {
    test('roundtrips through JSON with bullets', () {
      final card = DayAgentLearningCard(
        id: 'week_so_far',
        overline: 'Week so far',
        summary: 'Recent plans averaged 330 scheduled minute(s).',
        bullets: const [
          DayAgentLearningBullet(
            text: 'Average capacity was 420 minute(s).',
            tone: DayAgentLearningBulletTone.info,
          ),
          DayAgentLearningBullet(
            text: 'Keep a buffer before late meetings.',
            tone: DayAgentLearningBulletTone.positive,
          ),
        ],
      );

      final decoded = DayAgentLearningCard.fromJson(
        jsonDecode(jsonEncode(card.toJson())) as Map<String, dynamic>,
      );

      expect(decoded, card);
      expect(decoded.kind, 'standard');
      expect(decoded.hashCode, card.hashCode);
    });

    test('defensively freezes bullets passed at construction', () {
      final bullets = <DayAgentLearningBullet>[
        const DayAgentLearningBullet(
          text: 'Initial',
          tone: DayAgentLearningBulletTone.info,
        ),
      ];
      final card = DayAgentLearningCard(
        id: 'card',
        overline: 'Overline',
        summary: 'Summary',
        bullets: bullets,
      );

      bullets.add(
        const DayAgentLearningBullet(
          text: 'Injected after construction',
          tone: DayAgentLearningBulletTone.warning,
        ),
      );

      expect(card.bullets, hasLength(1));
      expect(
        () => card.bullets.add(
          const DayAgentLearningBullet(
            text: 'Cannot append',
            tone: DayAgentLearningBulletTone.warning,
          ),
        ),
        throwsUnsupportedError,
      );
    });
  });
}

class _GeneratedEnergyBand {
  const _GeneratedEnergyBand({
    required this.startMinute,
    required this.durationMinute,
    required this.level,
    required this.labelIndex,
  });

  final int startMinute;
  final int durationMinute;
  final DayAgentEnergyLevel level;
  final int labelIndex;

  DayAgentEnergyBand toBand() {
    final start = DateTime(2026, 5, 25).add(
      Duration(minutes: startMinute % (24 * 60)),
    );
    return DayAgentEnergyBand(
      start: start,
      end: start.add(Duration(minutes: 1 + durationMinute % 360)),
      level: level,
      label: 'band-$labelIndex-${level.name}',
    );
  }

  @override
  String toString() {
    return '_GeneratedEnergyBand('
        'startMinute: $startMinute, durationMinute: $durationMinute, '
        'level: $level, labelIndex: $labelIndex)';
  }
}

extension _AnyDayAgentPlanModels on glados.Any {
  glados.Generator<DayAgentEnergyLevel> get energyLevel =>
      glados.AnyUtils(this).choose(DayAgentEnergyLevel.values);

  glados.Generator<_GeneratedEnergyBand> get energyBand =>
      glados.CombinableAny(this).combine4(
        glados.IntAnys(this).intInRange(0, 100000),
        glados.IntAnys(this).intInRange(0, 100000),
        energyLevel,
        glados.IntAnys(this).intInRange(0, 1000),
        (
          int startMinute,
          int durationMinute,
          DayAgentEnergyLevel level,
          int labelIndex,
        ) => _GeneratedEnergyBand(
          startMinute: startMinute,
          durationMinute: durationMinute,
          level: level,
          labelIndex: labelIndex,
        ),
      );
}
