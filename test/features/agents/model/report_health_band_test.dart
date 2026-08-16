import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/report_health_band.dart';

import '../../../test_utils/glados_generators.dart';

enum _Band { onTrack, needsAttention }

/// A band name re-spelled the way a model might emit it: every letter's
/// case flipped per [caseMask], every position padded with [separator]
/// (whitespace or punctuation). The letters — the only thing band parsing
/// may depend on — are unchanged. The shrinker converges to the canonical
/// lowercase, separator-free spelling.
class _DecoratedBand {
  const _DecoratedBand({
    required this.band,
    required this.caseMask,
    required this.separator,
  });

  final _Band band;
  final int caseMask;
  final String separator;

  String get raw {
    final buffer = StringBuffer(separator);
    final letters = band.name.split('');
    for (var i = 0; i < letters.length; i++) {
      final letter = letters[i];
      final flip = (caseMask >> (i % 15)) & 1 == 1;
      buffer
        ..write(
          flip
              ? (letter == letter.toLowerCase()
                    ? letter.toUpperCase()
                    : letter.toLowerCase())
              : letter,
        )
        ..write(separator);
    }
    return buffer.toString();
  }

  @override
  String toString() => '_DecoratedBand(${band.name} as "$raw")';
}

extension _AnyHealthBand on glados.Any {
  glados.Generator<_DecoratedBand> get decoratedBand => combine3(
    choose(_Band.values),
    intInRange(0, 1 << 15),
    choose(const ['', ' ', '-', '_', '.', '\n']),
    (_Band band, int caseMask, String separator) => _DecoratedBand(
      band: band,
      caseMask: caseMask,
      separator: separator,
    ),
  );
}

void main() {
  final bands = {for (final band in _Band.values) band.name: band};

  test('band parsing normalizes case and punctuation — one wire value per '
      'band, however a model spells it', () {
    expect(parseReportHealthBand('onTrack', bands), _Band.onTrack);
    expect(parseReportHealthBand('On Track', bands), _Band.onTrack);
    expect(parseReportHealthBand('on-track', bands), _Band.onTrack);
    expect(
      parseReportHealthBand(' needs_attention ', bands),
      _Band.needsAttention,
    );
    expect(
      parseReportHealthBand('unknown', bands),
      isNull,
      reason: 'an unknown band never becomes a rendered chip',
    );
  });

  test('confidence fails closed outside [0, 1] and on non-numbers', () {
    expect(parseReportHealthConfidence(0.7), 0.7);
    expect(parseReportHealthConfidence('0.25'), 0.25);
    expect(parseReportHealthConfidence(0), 0);
    expect(parseReportHealthConfidence(1), 1);
    expect(parseReportHealthConfidence(1.1), isNull);
    expect(parseReportHealthConfidence(-0.1), isNull);
    expect(parseReportHealthConfidence(double.nan), isNull);
    expect(parseReportHealthConfidence(double.infinity), isNull);
    expect(parseReportHealthConfidence('not a number'), isNull);
    expect(parseReportHealthConfidence(null), isNull);
    expect(parseReportHealthConfidence(const []), isNull);
  });

  group('band-contract properties', () {
    glados.Glados(
      glados.any.decoratedBand,
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'every case/punctuation spelling of a band resolves to exactly '
      'that band',
      (decorated) {
        expect(
          parseReportHealthBand(decorated.raw, bands),
          decorated.band,
          reason: '$decorated',
        );
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.decoratedBand,
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'a spelling whose letters match no band fails closed to null, '
      'however it is decorated',
      (decorated) {
        expect(
          parseReportHealthBand('${decorated.raw}zz', bands),
          isNull,
          reason: '$decorated',
        );
      },
      tags: 'glados',
    );

    glados.Glados2(
      glados.any.intInRange(-2500, 2501),
      glados.any.singleWhitespace,
      glados.ExploreConfig(numRuns: 200),
    ).test(
      'confidence admits exactly [0, 1], and a numeric string parses '
      'like its number',
      (thousandths, padding) {
        final value = thousandths / 1000;
        final expected = value >= 0 && value <= 1 ? value : null;
        expect(parseReportHealthConfidence(value), expected);
        expect(
          parseReportHealthConfidence('$padding$value$padding'),
          expected,
          reason: 'string and number representations must agree for $value',
        );
      },
      tags: 'glados',
    );
  });
}
