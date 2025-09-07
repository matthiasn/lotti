import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/utils/time_locale_service.dart';

void main() {
  group('TimeLocaleService', () {
    test('returns Monday (1) by default when locale is null/empty', () async {
      final svc = TimeLocaleService();
      expect(await svc.firstDayOfWeekIndex(), 1);
      expect(await svc.firstDayOfWeekIndex(locale: ''), 1);
    });

    test('returns Sunday (0) for en_US', () async {
      final svc = TimeLocaleService();
      expect(await svc.firstDayOfWeekIndex(locale: 'en_US'), 0);
      expect(await svc.firstDayOfWeekIndex(locale: 'en-US'), 0);
    });

    test('returns Monday (1) for en_GB and de_DE', () async {
      final svc = TimeLocaleService();
      expect(await svc.firstDayOfWeekIndex(locale: 'en_GB'), 1);
      expect(await svc.firstDayOfWeekIndex(locale: 'en-GB'), 1);
      expect(await svc.firstDayOfWeekIndex(locale: 'de_DE'), 1);
      expect(await svc.firstDayOfWeekIndex(locale: 'de-DE'), 1);
    });
  });
}
