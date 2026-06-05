import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/geolocation.dart';

void main() {
  group('EntryText JSON round-trips — static examples', () {
    EntryText roundTrip(EntryText t) => EntryText.fromJson(
          jsonDecode(jsonEncode(t.toJson())) as Map<String, dynamic>,
        );

    test('minimal EntryText (plainText only) survives JSON round-trip', () {
      const t = EntryText(plainText: 'Hello world');
      final decoded = roundTrip(t);
      expect(decoded, t, reason: 'minimal EntryText round-trip');
      expect(decoded.plainText, 'Hello world');
      expect(decoded.markdown, isNull);
      expect(decoded.quill, isNull);
      expect(decoded.geolocation, isNull);
    });

    test('EntryText with markdown survives JSON round-trip', () {
      const t = EntryText(
        plainText: 'Hello world',
        markdown: '# Hello\n\nworld',
      );
      final decoded = roundTrip(t);
      expect(decoded, t, reason: 'markdown EntryText round-trip');
      expect(decoded.markdown, '# Hello\n\nworld');
      expect(decoded.quill, isNull);
    });

    test('EntryText with quill delta survives JSON round-trip', () {
      const quillJson = r'[{"insert":"Hello"},{"insert":"\n"}]';
      const t = EntryText(
        plainText: 'Hello',
        quill: quillJson,
      );
      final decoded = roundTrip(t);
      expect(decoded, t, reason: 'quill EntryText round-trip');
      expect(decoded.quill, quillJson);
      expect(decoded.markdown, isNull);
    });

    test('EntryText with both markdown and quill survives JSON round-trip', () {
      const t = EntryText(
        plainText: 'Draft',
        markdown: '**Draft**',
        quill: '[]',
      );
      final decoded = roundTrip(t);
      expect(decoded, t, reason: 'both fields EntryText round-trip');
      expect(decoded.markdown, '**Draft**');
      expect(decoded.quill, '[]');
    });

    test('EntryText with geolocation survives JSON round-trip', () {
      final geo = Geolocation(
        createdAt: DateTime(2024, 5),
        latitude: 52.5200,
        longitude: 13.4050,
        geohashString: 'u33d',
      );
      final t = EntryText(
        plainText: 'At the Brandenburg Gate',
        geolocation: geo,
      );
      final decoded = roundTrip(t);
      expect(decoded, t, reason: 'geolocation EntryText round-trip');
      expect(decoded.geolocation?.latitude, 52.5200);
      expect(decoded.geolocation?.longitude, 13.4050);
    });

    test('EntryText with all fields survives JSON round-trip', () {
      final geo = Geolocation(
        createdAt: DateTime(2024, 3, 15),
        latitude: 48.8566,
        longitude: 2.3522,
        geohashString: 'u09t',
        timezone: 'Europe/Paris',
      );
      final t = EntryText(
        plainText: 'Paris notes',
        markdown: '## Paris\nGreat city',
        quill: '[{"insert":"Paris notes"}]',
        geolocation: geo,
      );
      final decoded = roundTrip(t);
      expect(decoded, t, reason: 'full EntryText round-trip');
      expect(decoded.plainText, 'Paris notes');
      expect(decoded.geolocation?.timezone, 'Europe/Paris');
    });

    test('EntryText with empty plainText survives JSON round-trip', () {
      const t = EntryText(plainText: '');
      final decoded = roundTrip(t);
      expect(decoded, t);
      expect(decoded.plainText, '');
    });

    test('EntryText equality — same fields are equal', () {
      const a = EntryText(
        plainText: 'Hello',
        markdown: '**Hello**',
      );
      const b = EntryText(
        plainText: 'Hello',
        markdown: '**Hello**',
      );
      expect(a, b);
    });

    test('EntryText equality — different markdown are not equal', () {
      const a = EntryText(plainText: 'Hello', markdown: '# Hello');
      const b = EntryText(plainText: 'Hello', markdown: '## Hello');
      expect(a, isNot(equals(b)));
    });
  });

  group('EntryText Glados round-trips', () {
    glados.Glados(
      glados.any.generatedEntryText,
      glados.ExploreConfig(numRuns: 120),
    ).test('EntryText round-trips through JSON', (scenario) {
      final t = scenario.entryText;
      final decoded = EntryText.fromJson(
        jsonDecode(jsonEncode(t.toJson())) as Map<String, dynamic>,
      );
      expect(decoded, t, reason: '$scenario');
      expect(decoded.plainText, t.plainText, reason: 'plainText preserved');
      expect(decoded.markdown, t.markdown, reason: 'markdown preserved');
      expect(decoded.quill, t.quill, reason: 'quill preserved');
    }, tags: 'glados');
  });
}

// ---------------------------------------------------------------------------
// Glados generator helpers for EntryText.
// ---------------------------------------------------------------------------

class _GeneratedEntryText {
  const _GeneratedEntryText({
    required this.plainTextSlot,
    required this.markdownSlot,
    required this.quillSlot,
    required this.hasGeo,
  });

  final int plainTextSlot;
  final int markdownSlot;
  final int quillSlot;
  final bool hasGeo;

  static const _texts = [
    '',
    'Hello world',
    'Simple note',
    'Note with "quotes"',
    r'Note with \ backslash',
    'Multi\nline',
  ];

  EntryText get entryText {
    final plainText = _texts[plainTextSlot % _texts.length];
    final markdown = markdownSlot % 3 == 0
        ? null
        : '# Heading $markdownSlot\n\nContent $markdownSlot';
    final quill = quillSlot % 4 == 0
        ? null
        : '[{"insert":"text-$quillSlot"},{"insert":"\\n"}]';
    final geo = hasGeo
        ? Geolocation(
            createdAt: DateTime(2024, (plainTextSlot % 12) + 1),
            latitude: (plainTextSlot % 181) - 90.0,
            longitude: (plainTextSlot % 361) - 180.0,
            geohashString: 'gh$plainTextSlot',
          )
        : null;

    return EntryText(
      plainText: plainText,
      markdown: markdown,
      quill: quill,
      geolocation: geo,
    );
  }

  @override
  String toString() =>
      '_GeneratedEntryText(plainTextSlot: $plainTextSlot, '
      'markdownSlot: $markdownSlot, quillSlot: $quillSlot, '
      'hasGeo: $hasGeo)';
}

extension _AnyEntryText on glados.Any {
  glados.Generator<_GeneratedEntryText> get generatedEntryText =>
      glados.CombinableAny(this).combine4(
        glados.IntAnys(this).intInRange(0, 5),
        glados.IntAnys(this).intInRange(0, 15),
        glados.IntAnys(this).intInRange(0, 15),
        glados.any.bool,
        (plainTextSlot, markdownSlot, quillSlot, hasGeo) =>
            _GeneratedEntryText(
          plainTextSlot: plainTextSlot,
          markdownSlot: markdownSlot,
          quillSlot: quillSlot,
          hasGeo: hasGeo,
        ),
      );
}
