// The synthetic `tokenizer.json` the on-device embedding tests build their
// tokenizers from.

/// EmbeddingGemma's post-processor: `<bos>` … `<eos>`, ids 2 and 1.
const Map<String, Object> bosEosTemplate = {
  'type': 'TemplateProcessing',
  'single': [
    {
      'SpecialToken': {'id': '<bos>', 'type_id': 0},
    },
    {
      'Sequence': {'id': 'A', 'type_id': 0},
    },
    {
      'SpecialToken': {'id': '<eos>', 'type_id': 0},
    },
  ],
  'special_tokens': {
    '<bos>': {
      'id': '<bos>',
      'ids': [2],
      'tokens': ['<bos>'],
    },
    '<eos>': {
      'id': '<eos>',
      'ids': [1],
      'tokens': ['<eos>'],
    },
  },
};

/// A `tokenizer.json` shaped like EmbeddingGemma's, over a small vocabulary:
/// the specials, the 256 byte tokens, then [tokens] in order.
Map<String, dynamic> tokenizerJson({
  List<String> tokens = const [],
  List<Object> merges = const [],
  List<String> addedTokens = const [],
  Map<String, Object?> modelOverrides = const {},
  Map<String, Object?> addedTokenOverrides = const {},
  Object? normalizer = const {
    'type': 'Replace',
    'pattern': {'String': ' '},
    'content': '▁',
  },
  Object? preTokenizer = const {
    'type': 'Split',
    'pattern': {'String': ' '},
    'behavior': 'MergedWithPrevious',
    'invert': false,
  },
  Object? postProcessor = bosEosTemplate,
  bool withBytes = true,
}) {
  final vocab = <String, int>{};
  void add(String token) => vocab.putIfAbsent(token, () => vocab.length);
  ['<pad>', '<eos>', '<bos>', '<unk>'].forEach(add);
  if (withBytes) {
    for (var byte = 0; byte < 256; byte++) {
      add('<0x${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}>');
    }
  }
  tokens.forEach(add);
  addedTokens.forEach(add);
  return {
    'normalizer': normalizer,
    'pre_tokenizer': preTokenizer,
    'post_processor': postProcessor,
    'model': {
      'type': 'BPE',
      'dropout': null,
      'unk_token': '<unk>',
      'continuing_subword_prefix': null,
      'end_of_word_suffix': null,
      'fuse_unk': true,
      'byte_fallback': true,
      'ignore_merges': false,
      'vocab': vocab,
      'merges': merges,
      ...modelOverrides,
    },
    'added_tokens': [
      for (final content in ['<pad>', '<eos>', '<bos>', ...addedTokens])
        {
          'id': vocab[content],
          'content': content,
          'single_word': false,
          'lstrip': false,
          'rstrip': false,
          'normalized': false,
          'special': content.startsWith('<'),
          ...addedTokenOverrides,
        },
    ],
  };
}
