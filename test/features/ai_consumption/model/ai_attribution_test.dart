import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';

void main() {
  test('content parts round-trip every structured evidence field', () {
    const part = AiContentPart(
      type: AiContentPartType.toolCall,
      text: 'result',
      name: 'lookup',
      arguments: {'query': 'weather'},
      attachment: AiArtifactReference(
        type: AiArtifactType.journalImage,
        id: 'image-1',
        subId: 'crop-1',
      ),
      mediaType: 'application/json',
      sha256: 'digest',
      byteLength: 42,
    );

    final json = jsonDecode(jsonEncode(part.toJson())) as Map<String, dynamic>;

    expect(AiContentPart.fromJson(json), part);
  });
}
