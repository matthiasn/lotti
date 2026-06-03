import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_config.dart';

void main() {
  group('DayAgentConfig', () {
    test('default constructor exposes the documented planning defaults', () {
      const config = DayAgentConfig();
      expect(config.capacityMinutes, 480);
      expect(config.workingHoursStart, '09:00');
      expect(config.workingHoursEnd, '17:00');
      expect(config.energyBands, ['morning', 'afternoon', 'evening']);
      expect(config.maxRefinementRounds, 3);
    });

    test('toJson serialises all five fields for the default config', () {
      expect(const DayAgentConfig().toJson(), {
        'capacityMinutes': 480,
        'workingHoursStart': '09:00',
        'workingHoursEnd': '17:00',
        'energyBands': ['morning', 'afternoon', 'evening'],
        'maxRefinementRounds': 3,
      });
    });

    test('toJson reflects custom values', () {
      const config = DayAgentConfig(
        capacityMinutes: 600,
        workingHoursStart: '08:30',
        workingHoursEnd: '18:00',
        energyBands: ['am', 'pm'],
        maxRefinementRounds: 5,
      );
      expect(config.toJson(), {
        'capacityMinutes': 600,
        'workingHoursStart': '08:30',
        'workingHoursEnd': '18:00',
        'energyBands': ['am', 'pm'],
        'maxRefinementRounds': 5,
      });
    });
  });
}
