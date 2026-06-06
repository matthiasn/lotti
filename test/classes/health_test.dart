import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/health.dart';

void main() {
  group('QuantitativeData JSON round-trips — static examples', () {
    final dateFrom = DateTime(2024, 3, 15, 8);
    final dateTo = DateTime(2024, 3, 15, 9);

    QuantitativeData roundTrip(QuantitativeData d) => QuantitativeData.fromJson(
      jsonDecode(jsonEncode(d.toJson())) as Map<String, dynamic>,
    );

    test('CumulativeQuantityData minimal fields survives JSON round-trip', () {
      final d = QuantitativeData.cumulativeQuantityData(
        dateFrom: dateFrom,
        dateTo: dateTo,
        value: 8500,
        dataType: 'HealthDataType.STEPS',
        unit: 'count',
      );
      final decoded = roundTrip(d);
      expect(decoded, d, reason: 'cumulative minimal round-trip');
      final typed = decoded as CumulativeQuantityData;
      expect(typed.value, 8500);
      expect(typed.dataType, 'HealthDataType.STEPS');
      expect(typed.unit, 'count');
      expect(typed.deviceType, isNull);
      expect(typed.platformType, isNull);
    });

    test(
      'CumulativeQuantityData with all optional fields survives round-trip',
      () {
        final d = QuantitativeData.cumulativeQuantityData(
          dateFrom: dateFrom,
          dateTo: dateTo,
          value: 1234.5,
          dataType: 'HealthDataType.ACTIVE_ENERGY_BURNED',
          unit: 'kcal',
          deviceType: 'iPhone',
          platformType: 'iOS',
        );
        final decoded = roundTrip(d);
        expect(decoded, d, reason: 'cumulative full round-trip');
        final typed = decoded as CumulativeQuantityData;
        expect(typed.deviceType, 'iPhone');
        expect(typed.platformType, 'iOS');
      },
    );

    test('DiscreteQuantityData minimal fields survives JSON round-trip', () {
      final d = QuantitativeData.discreteQuantityData(
        dateFrom: dateFrom,
        dateTo: dateTo,
        value: 72,
        dataType: 'HealthDataType.HEART_RATE',
        unit: 'bpm',
      );
      final decoded = roundTrip(d);
      expect(decoded, d, reason: 'discrete minimal round-trip');
      final typed = decoded as DiscreteQuantityData;
      expect(typed.value, 72);
      expect(typed.sourceName, isNull);
      expect(typed.sourceId, isNull);
      expect(typed.deviceId, isNull);
    });

    test(
      'DiscreteQuantityData with all optional fields survives round-trip',
      () {
        final d = QuantitativeData.discreteQuantityData(
          dateFrom: dateFrom,
          dateTo: dateTo,
          value: 98.6,
          dataType: 'HealthDataType.BODY_TEMPERATURE',
          unit: 'degF',
          deviceType: 'Apple Watch',
          platformType: 'watchOS',
          sourceName: 'Health',
          sourceId: 'com.apple.Health',
          deviceId: 'device-uuid-1234',
        );
        final decoded = roundTrip(d);
        expect(decoded, d, reason: 'discrete full round-trip');
        final typed = decoded as DiscreteQuantityData;
        expect(typed.sourceName, 'Health');
        expect(typed.sourceId, 'com.apple.Health');
        expect(typed.deviceId, 'device-uuid-1234');
        expect(typed.deviceType, 'Apple Watch');
        expect(typed.platformType, 'watchOS');
      },
    );

    test('DiscreteQuantityData with integer value survives round-trip', () {
      final d = QuantitativeData.discreteQuantityData(
        dateFrom: dateFrom,
        dateTo: dateTo,
        value: 100,
        dataType: 'HealthDataType.STEP_COUNT',
        unit: 'count',
      );
      final decoded = roundTrip(d);
      expect(decoded, d, reason: 'integer value discrete round-trip');
      expect((decoded as DiscreteQuantityData).value, 100);
    });

    test('CumulativeQuantityData with double value survives round-trip', () {
      final d = QuantitativeData.cumulativeQuantityData(
        dateFrom: dateFrom,
        dateTo: dateTo,
        value: 3.14159,
        dataType: 'custom.pi',
        unit: 'unitless',
      );
      final decoded = roundTrip(d);
      expect(decoded, d);
      expect(
        (decoded as CumulativeQuantityData).value,
        closeTo(3.14159, 1e-10),
      );
    });
  });

  group('QuantitativeData Glados round-trips', () {
    glados.Glados(
      glados.any.generatedQuantitativeData,
      glados.ExploreConfig(numRuns: 120),
    ).test('QuantitativeData round-trips through JSON', (scenario) {
      final data = scenario.data;
      final decoded = QuantitativeData.fromJson(
        jsonDecode(jsonEncode(data.toJson())) as Map<String, dynamic>,
      );
      expect(decoded, data, reason: '$scenario');
      // Verify discriminator field survived: both variants have same dateFrom/dateTo
      expect(decoded.dateFrom, data.dateFrom, reason: 'dateFrom preserved');
      expect(decoded.dateTo, data.dateTo, reason: 'dateTo preserved');
    }, tags: 'glados');
  });
}

// ---------------------------------------------------------------------------
// Glados generator helpers for QuantitativeData.
// ---------------------------------------------------------------------------

enum _GeneratedQuantitativeDataKind {
  cumulative,
  discrete,
}

class _GeneratedQuantitativeData {
  const _GeneratedQuantitativeData({
    required this.kind,
    required this.dateSlot,
    required this.valueSlot,
    required this.dataTypeSlot,
    required this.optionalsSlot,
  });

  final _GeneratedQuantitativeDataKind kind;
  final int dateSlot;
  final int valueSlot;
  final int dataTypeSlot;
  final int optionalsSlot;

  QuantitativeData get data {
    final dateFrom = DateTime.utc(
      2024,
      (dateSlot % 12) + 1,
      (dateSlot % 28) + 1,
      8,
    );
    final dateTo = dateFrom.add(const Duration(hours: 1));
    final value = valueSlot.isEven ? valueSlot * 1.0 : valueSlot + 0.5;
    final dataType = 'HealthDataType.TYPE_$dataTypeSlot';
    final unit = optionalsSlot.isEven ? 'count' : 'kcal';
    final deviceType = optionalsSlot % 3 == 0 ? null : 'device-$optionalsSlot';
    final platformType = optionalsSlot % 4 == 0 ? null : 'iOS';

    return switch (kind) {
      _GeneratedQuantitativeDataKind.cumulative =>
        QuantitativeData.cumulativeQuantityData(
          dateFrom: dateFrom,
          dateTo: dateTo,
          value: value,
          dataType: dataType,
          unit: unit,
          deviceType: deviceType,
          platformType: platformType,
        ),
      _GeneratedQuantitativeDataKind.discrete =>
        QuantitativeData.discreteQuantityData(
          dateFrom: dateFrom,
          dateTo: dateTo,
          value: value,
          dataType: dataType,
          unit: unit,
          deviceType: deviceType,
          platformType: platformType,
          sourceName: optionalsSlot % 5 == 0 ? null : 'source-$optionalsSlot',
          sourceId: optionalsSlot % 6 == 0 ? null : 'src-id-$optionalsSlot',
          deviceId: optionalsSlot % 7 == 0 ? null : 'dev-id-$optionalsSlot',
        ),
    };
  }

  @override
  String toString() =>
      '_GeneratedQuantitativeData(kind: $kind, dateSlot: $dateSlot, '
      'valueSlot: $valueSlot, dataTypeSlot: $dataTypeSlot)';
}

extension _AnyHealth on glados.Any {
  glados.Generator<_GeneratedQuantitativeDataKind> get _quantitativeDataKind =>
      glados.AnyUtils(this).choose(_GeneratedQuantitativeDataKind.values);

  glados.Generator<_GeneratedQuantitativeData> get generatedQuantitativeData =>
      glados.CombinableAny(this).combine5(
        _quantitativeDataKind,
        glados.IntAnys(this).intInRange(0, 50),
        glados.IntAnys(this).intInRange(0, 1000),
        glados.IntAnys(this).intInRange(0, 30),
        glados.IntAnys(this).intInRange(0, 15),
        (kind, dateSlot, valueSlot, dataTypeSlot, optionalsSlot) =>
            _GeneratedQuantitativeData(
              kind: kind,
              dateSlot: dateSlot,
              valueSlot: valueSlot,
              dataTypeSlot: dataTypeSlot,
              optionalsSlot: optionalsSlot,
            ),
      );
}
