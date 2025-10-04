import 'package:country_flags/country_flags.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/flags/language_flag.dart';

void main() {
  CountryFlag buildFlag(String code) {
    final widget = buildLanguageFlag(
      languageCode: code,
      height: 10,
      width: 20,
    );

    expect(widget, isA<CountryFlag>());
    return widget as CountryFlag;
  }

  test('returns Chinese flag override for zh', () {
    final flag = buildFlag('zh');

    expect(flag.flagCode, 'cn');
  });

  test('returns Nigerian flag override for Nigerian languages', () {
    final igboFlag = buildFlag('ig');
    final pidginFlag = buildFlag('pcm');
    final yorubaFlag = buildFlag('yo');

    expect(igboFlag.flagCode, 'ng');
    expect(pidginFlag.flagCode, 'ng');
    expect(yorubaFlag.flagCode, 'ng');
  });

  test('falls back to country_flags language mapping when no override exists',
      () {
    final flag = buildFlag('fr');

    expect(flag.flagCode, 'fr');
  });
}
