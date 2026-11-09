import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/front_agent/model/front_due_section.dart';
import 'package:lotti/features/front_agent/model/front_routing_index.dart';

void main() {
  final today = DateTime(2026, 11, 9);
  final friday = DateTime(2026, 11, 13);
  final week = FrontDueSection(
    window: FrontDueWindow.upcoming,
    today: today,
    through: friday,
  );

  test('stores its window and days as dates, and reads them back the same', () {
    expect(week.toJson(), {
      'window': 'upcoming',
      'today': '2026-11-09',
      'through': '2026-11-13',
    });
    expect(FrontDueSection.fromJson(week.toJson()), week);
  });

  test('stores a day without its time of day', () {
    final late = FrontDueSection(
      window: FrontDueWindow.today,
      today: DateTime(2026, 11, 9, 23, 30),
      through: DateTime(2026, 11, 9, 23, 30),
    );

    expect(late.toJson()['today'], '2026-11-09');
    expect(FrontDueSection.fromJson(late.toJson())!.today, today);
  });

  test('a section this build cannot read is dropped, never thrown', () {
    for (final json in <Object?>[
      null,
      'today',
      {'window': 'soon', 'today': '2026-11-09', 'through': '2026-11-09'},
      {'window': 'today', 'through': '2026-11-09'},
      {'window': 'today', 'today': '2026-11-09'},
      {'window': 'today', 'today': 'monday', 'through': '2026-11-09'},
    ]) {
      expect(FrontDueSection.fromJson(json), isNull, reason: '$json');
    }
  });

  test('ends today when nothing later is in it', () {
    expect(
      FrontDueSection(
        window: FrontDueWindow.all,
        today: today,
        through: today,
      ).endsToday,
      isTrue,
    );
    expect(week.endsToday, isFalse);
  });

  test('is equal, and hashes alike, only with the same window and days', () {
    final same = FrontDueSection(
      window: FrontDueWindow.upcoming,
      today: DateTime(2026, 11, 9),
      through: DateTime(2026, 11, 13),
    );

    expect(same, week);
    expect(same.hashCode, week.hashCode);
    expect({
      week,
      same,
      FrontDueSection(
        window: FrontDueWindow.all,
        today: today,
        through: friday,
      ),
      FrontDueSection(
        window: FrontDueWindow.upcoming,
        today: DateTime(2026, 11, 8),
        through: friday,
      ),
      FrontDueSection(
        window: FrontDueWindow.upcoming,
        today: today,
        through: DateTime(2026, 11, 14),
      ),
    }, hasLength(4));
  });

  test('names its window and days', () {
    expect(
      week.toString(),
      'FrontDueSection(upcoming, 2026-11-09–2026-11-13)',
    );
  });
}
