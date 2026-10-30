import 'dart:convert';

import 'package:collection/collection.dart';

/// EmbeddingGemma's tokenizer, ported from the Hugging Face `tokenizers`
/// pipeline its `tokenizer.json` describes, so the app can feed the ONNX
/// model without a native tokenizer library.
///
/// The pipeline, in the order `tokenizers` runs it:
///
/// 1. **Added tokens** are cut out of the raw text first, leftmost-longest
///    (`<start_of_turn>`, runs of newlines, …); each becomes its own id.
/// 2. Every other segment is **normalized**, each space replaced by `▁`. The
///    file's pre-tokenizer splits on spaces, of which none are left, so the
///    whole segment is one BPE word.
/// 3. **BPE**: the segment's characters, each one missing from the vocabulary
///    replaced by its UTF-8 byte tokens (`<0xNN>`), are merged pair by pair,
///    the lowest-ranked merge first and the leftmost among equal ranks.
/// 4. The ids are wrapped in `<bos>` … `<eos>`, the file's post-processor.
///
/// Parity with `tokenizers` itself is checked by
/// `tool/embedding_eval/tokenizer_parity_test.dart`.
class GemmaTokenizer {
  GemmaTokenizer._(
    this._vocab,
    this._merges,
    this._addedTokens,
    this._byteIds, {
    required this.bosId,
    required this.eosId,
  });

  /// Builds the tokenizer from a decoded `tokenizer.json`.
  ///
  /// Throws a [FormatException] when the file describes any other pipeline
  /// than the one ported here, rather than tokenizing it differently.
  factory GemmaTokenizer.fromTokenizerJson(Map<String, dynamic> json) {
    final model = json['model'] as Map<String, dynamic>;
    _expect(
      model['type'] == 'BPE' &&
          model['byte_fallback'] == true &&
          model['dropout'] == null &&
          model['continuing_subword_prefix'] == null &&
          model['end_of_word_suffix'] == null &&
          model['ignore_merges'] != true,
      'a BPE model with byte fallback and no affixes',
    );
    _expect(
      _isSpaceReplace(json['normalizer']),
      "a normalizer replacing ' ' with '$_spaceMark'",
    );
    final pre = json['pre_tokenizer'] as Map<String, dynamic>?;
    _expect(
      pre == null ||
          (pre['type'] == 'Split' &&
              (pre['pattern'] as Map<String, dynamic>)['String'] == ' '),
      'no pre-tokenizer, or one splitting on spaces',
    );
    _expect(
      _isBosEosTemplate(json['post_processor']),
      'a post-processor wrapping the text in <bos> … <eos>',
    );

    final vocab = (model['vocab'] as Map<String, dynamic>).map(
      (token, id) => MapEntry(token, id as int),
    );
    _expect(
      vocab.values.every((id) => id >= 0 && id <= _idMask),
      'ids below ${1 << _idBits}',
    );
    final byteIds = [
      for (var byte = 0; byte < 256; byte++)
        vocab[_byteToken(byte)] ??
            (throw FormatException('missing byte token ${_byteToken(byte)}')),
    ];

    // Keyed by the pair of ids, valued by rank and the merged id. A pair
    // listed twice keeps its last rank, as `tokenizers` does.
    final merges = <int, int>{};
    final mergeList = model['merges'] as List<dynamic>;
    for (var rank = 0; rank < mergeList.length; rank++) {
      final entry = mergeList[rank];
      final (left, right) = entry is String
          ? _splitMerge(entry)
          : ((entry as List<dynamic>)[0] as String, entry[1] as String);
      final leftId = vocab[left];
      final rightId = vocab[right];
      final mergedId = vocab['$left$right'];
      if (leftId == null || rightId == null || mergedId == null) {
        throw FormatException('merge "$left $right" is not in the vocabulary');
      }
      merges[_pairKey(leftId, rightId)] = rank << _idBits | mergedId;
    }

    final addedTokens = _AddedTokenTrie();
    for (final token in json['added_tokens'] as List<dynamic>) {
      final added = token as Map<String, dynamic>;
      _expect(
        added['normalized'] == false &&
            added['lstrip'] == false &&
            added['rstrip'] == false &&
            added['single_word'] == false,
        'added tokens matched on the raw text only',
      );
      addedTokens.add(added['content'] as String, added['id'] as int);
    }

    return GemmaTokenizer._(
      vocab,
      merges,
      addedTokens,
      byteIds,
      bosId: vocab['<bos>'] ?? (throw const FormatException('no <bos>')),
      eosId: vocab['<eos>'] ?? (throw const FormatException('no <eos>')),
    );
  }

  static const _spaceMark = '▁';

  /// Ids are below 2^18 (EmbeddingGemma's vocabulary has 262,144 entries),
  /// so a pair of ids, or a rank beside an id, packs into one int.
  static const _idBits = 18;
  static const int _idMask = (1 << _idBits) - 1;

  final Map<String, int> _vocab;
  final Map<int, int> _merges;
  final _AddedTokenTrie _addedTokens;
  final List<int> _byteIds;

  /// The id that opens every encoding.
  final int bosId;

  /// The id that closes every encoding.
  final int eosId;

  /// The model's input ids for [text], `<bos>` and `<eos>` included.
  List<int> encode(String text) {
    final ids = [bosId];
    var start = 0;
    for (final match in _addedTokens.matches(text)) {
      _encodeSegment(text.substring(start, match.start), ids);
      ids.add(match.id);
      start = match.end;
    }
    _encodeSegment(text.substring(start), ids);
    return ids..add(eosId);
  }

  void _encodeSegment(String segment, List<int> out) {
    if (segment.isEmpty) return;
    final normalized = segment.replaceAll(' ', _spaceMark);

    final symbols = <int>[];
    for (final rune in normalized.runes) {
      final id = _vocab[String.fromCharCode(rune)];
      if (id != null) {
        symbols.add(id);
      } else {
        for (final byte in utf8.encode(String.fromCharCode(rune))) {
          symbols.add(_byteIds[byte]);
        }
      }
    }
    out.addAll(_mergeAll(symbols));
  }

  /// Applies the merges to [symbols] the way `tokenizers`' `Word::merge_all`
  /// does: a queue of mergeable neighbours, lowest rank first and leftmost
  /// among equals, where a queued pair that has since changed is skipped.
  List<int> _mergeAll(List<int> symbols) {
    final count = symbols.length;
    final ids = List.of(symbols);
    final prev = List.generate(count, (i) => i - 1);
    final next = List.generate(count, (i) => i + 1 < count ? i + 1 : -1);
    final alive = List.filled(count, true);
    final queue = PriorityQueue<_Merge>();

    void enqueue(int pos) {
      final right = next[pos];
      if (right < 0) return;
      final merge = _merges[_pairKey(ids[pos], ids[right])];
      if (merge != null) {
        queue.add(_Merge(pos, merge >> _idBits, merge & _idMask));
      }
    }

    for (var pos = 0; pos < count - 1; pos++) {
      enqueue(pos);
    }

    while (queue.isNotEmpty) {
      final top = queue.removeFirst();
      final pos = top.pos;
      final right = next[pos];
      if (!alive[pos] || right < 0) continue;
      final current = _merges[_pairKey(ids[pos], ids[right])];
      if (current == null || current & _idMask != top.mergedId) continue;

      ids[pos] = top.mergedId;
      alive[right] = false;
      next[pos] = next[right];
      if (next[pos] >= 0) prev[next[pos]] = pos;

      if (prev[pos] >= 0) enqueue(prev[pos]);
      enqueue(pos);
    }

    return [
      for (var i = 0; i < count; i++)
        if (alive[i]) ids[i],
    ];
  }

  static int _pairKey(int left, int right) => left << _idBits | right;

  static String _byteToken(int byte) =>
      '<0x${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}>';

  static (String, String) _splitMerge(String merge) {
    final space = merge.indexOf(' ');
    if (space < 0) throw FormatException('malformed merge "$merge"');
    return (merge.substring(0, space), merge.substring(space + 1));
  }

  static bool _isSpaceReplace(Object? normalizer) {
    if (normalizer is! Map<String, dynamic>) return false;
    final pattern = normalizer['pattern'];
    return normalizer['type'] == 'Replace' &&
        pattern is Map<String, dynamic> &&
        pattern['String'] == ' ' &&
        normalizer['content'] == _spaceMark;
  }

  static bool _isBosEosTemplate(Object? processor) {
    if (processor is! Map<String, dynamic> ||
        processor['type'] != 'TemplateProcessing') {
      return false;
    }
    final single = processor['single'];
    if (single is! List<dynamic> || single.length != 3) return false;
    String? part(int index, String kind) {
      final entry = single[index];
      if (entry is! Map<String, dynamic>) return null;
      final body = entry[kind];
      return body is Map<String, dynamic> && body['type_id'] == 0
          ? body['id'] as String?
          : null;
    }

    return part(0, 'SpecialToken') == '<bos>' &&
        part(1, 'Sequence') == 'A' &&
        part(2, 'SpecialToken') == '<eos>';
  }

  static void _expect(bool condition, String what) {
    if (!condition) {
      throw FormatException('expected $what, as EmbeddingGemma ships');
    }
  }
}

/// A queued merge of the symbol at [pos] with its right neighbour.
class _Merge implements Comparable<_Merge> {
  _Merge(this.pos, this.rank, this.mergedId);

  final int pos;
  final int rank;
  final int mergedId;

  @override
  int compareTo(_Merge other) =>
      rank != other.rank ? rank - other.rank : pos - other.pos;
}

/// One added token found in the text, by UTF-16 offsets.
typedef _AddedTokenMatch = ({int start, int end, int id});

/// The added tokens as a trie over UTF-16 code units, matched
/// leftmost-longest as `tokenizers` matches them.
class _AddedTokenTrie {
  final _root = _TrieNode();

  void add(String content, int id) {
    var node = _root;
    for (final unit in content.codeUnits) {
      node = node.children.putIfAbsent(unit, _TrieNode.new);
    }
    node.id = id;
  }

  Iterable<_AddedTokenMatch> matches(String text) sync* {
    var start = 0;
    while (start < text.length) {
      var node = _root;
      _AddedTokenMatch? longest;
      for (var i = start; i < text.length; i++) {
        final child = node.children[text.codeUnitAt(i)];
        if (child == null) break;
        node = child;
        final id = node.id;
        if (id != null) longest = (start: start, end: i + 1, id: id);
      }
      if (longest != null) {
        yield longest;
        start = longest.end;
      } else {
        start++;
      }
    }
  }
}

class _TrieNode {
  final children = <int, _TrieNode>{};
  int? id;
}
