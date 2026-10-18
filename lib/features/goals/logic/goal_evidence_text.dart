import 'package:lotti/features/ai/service/text_chunker.dart';

/// Clips one journal markdown field before it enters the model context.
///
/// The complete text remains in the journal and in the freshness digest. The
/// model only needs a recent semantic excerpt, and one pathological entry must
/// not consume the entire wake budget.
String truncateGoalEvidenceText(String text, int tokenBudget) {
  final trimmed = text.trim();
  if (tokenBudget <= 0 || trimmed.isEmpty) return '';
  if (TextChunker.estimateTokens(trimmed) <= tokenBudget) return trimmed;

  final runes = trimmed.runes.toList(growable: false);
  var low = 0;
  var high = runes.length;
  while (low < high) {
    final mid = (low + high + 1) ~/ 2;
    final candidate = '${String.fromCharCodes(runes.take(mid))}…';
    if (TextChunker.estimateTokens(candidate) <= tokenBudget) {
      low = mid;
    } else {
      high = mid - 1;
    }
  }
  return '${String.fromCharCodes(runes.take(low)).trimRight()}…';
}
