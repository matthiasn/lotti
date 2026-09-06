/// The recognizer configuration key used by the pinned sherpa runtime.
enum SherpaModelArchitecture {
  whisper,
  nemoTransducer,
  senseVoice,
  dolphin,
  omnilingual,
  fireRedAsr,
  fireRedAsrCtc,
  paraformer,
  wenetCtc,
  qwen3Asr,
  funasrNano;

  String get configurationKey => this == nemoTransducer ? 'transducer' : name;
}

/// One immutable, checksum-pinned artifact in an embedded speech model.
class SherpaModelFile {
  const SherpaModelFile(this.name, this.bytes, this.sha256);

  final String name;
  final int bytes;
  final String sha256;
}

/// A multilingual export supported by the embedded recognizer.
class SherpaModel {
  const SherpaModel({
    required this.id,
    required this.name,
    required this.revision,
    required this.files,
    this.repository,
    this.architecture = SherpaModelArchitecture.whisper,
    this.family = 'Whisper',
    this.publisher = 'OpenAI',
    this.languageCodes = const [],
    this.fileRoles = const {},
  });

  final String? repository;
  final SherpaModelArchitecture architecture;
  final String family;
  final String publisher;
  final List<String> languageCodes;
  final Map<String, String> fileRoles;

  /// Native artifact roles, independent of each upstream export's filenames.
  Map<String, String> get recognizerFiles =>
      architecture == SherpaModelArchitecture.whisper
      ? {'encoder': '$id-encoder.int8.onnx', 'decoder': '$id-decoder.int8.onnx'}
      : fileRoles;

  String get tokensFile => architecture == SherpaModelArchitecture.whisper
      ? '$id-tokens.txt'
      : 'tokens.txt';

  final String id;
  final String name;
  final String revision;
  final List<SherpaModelFile> files;

  int get bytes => files.fold(0, (total, file) => total + file.bytes);

  Uri uri(SherpaModelFile file) => Uri.parse(
    'https://huggingface.co/${repository ?? 'csukuangfj/sherpa-onnx-whisper-$id'}/'
    'resolve/$revision/${file.name}',
  );
}

/// Fixed upstream revisions prevent model downloads changing beneath a build.
const sherpaModels = [
  SherpaModel(
    id: 'large-v3',
    name: 'Whisper Large v3',
    revision: '2a6507094dd6020d939d78e3f1834a1d06267fca',
    files: [
      SherpaModelFile(
        'large-v3-encoder.int8.onnx',
        766671985,
        'd531cf17248acc43e8c09b472a0877055e770877857a5332fc1304b36534ec85',
      ),
      SherpaModelFile(
        'large-v3-decoder.int8.onnx',
        1008265203,
        'ebc6bfd88e162a46cb3edee8a7e727e1dcbc65cabecb19e2573695e4d495e1af',
      ),
      SherpaModelFile(
        'large-v3-tokens.txt',
        816730,
        'b34b360dbb493e781e479794586d661700670d65564001f23024971d1f2fa126',
      ),
    ],
  ),
  SherpaModel(
    id: 'turbo',
    name: 'Whisper Large v3 Turbo',
    revision: '2ca6ff69fc878651b770880507669577ac41c2ff',
    files: [
      SherpaModelFile(
        'turbo-encoder.int8.onnx',
        674716297,
        'b02dcdf54f348741e93fe732b67d933c8dcb6735655f710640143081db38878b',
      ),
      SherpaModelFile(
        'turbo-decoder.int8.onnx',
        361080764,
        '20accd02388482eb3a46bd615631adfdc85e1eb2c7db9ea3f02a40ffe6b81547',
      ),
      SherpaModelFile(
        'turbo-tokens.txt',
        816730,
        'b34b360dbb493e781e479794586d661700670d65564001f23024971d1f2fa126',
      ),
    ],
  ),
  SherpaModel(
    id: 'medium',
    name: 'Whisper Medium',
    revision: '8c31d28503847560985df21f90e14f0c736e075e',
    files: [
      SherpaModelFile(
        'medium-encoder.int8.onnx',
        374196283,
        '1c54582b4d829de0089f6cb63bbbdb3bf7555398bacaf855fbecf1a84dfd193e',
      ),
      SherpaModelFile(
        'medium-decoder.int8.onnx',
        571059257,
        '595d00a338a365a7bfa0ca7f296cabc639583bef770ab6130df90f49a6412747',
      ),
      SherpaModelFile(
        'medium-tokens.txt',
        816730,
        'b34b360dbb493e781e479794586d661700670d65564001f23024971d1f2fa126',
      ),
    ],
  ),
  SherpaModel(
    id: 'small',
    name: 'Whisper Small',
    revision: '8f3c18b358db4d1f2fc1eae49d75cd20989e4309',
    files: [
      SherpaModelFile(
        'small-encoder.int8.onnx',
        112442483,
        '4cbe7b22fa9026b843b60a68640c747de05bafb1a11b57edc0e66c232d9f33a9',
      ),
      SherpaModelFile(
        'small-decoder.int8.onnx',
        262226114,
        'acad50b5c782696e91b55914cc5ab4f756f1532f76e22aa6fc615f39fb69a8ee',
      ),
      SherpaModelFile(
        'small-tokens.txt',
        816730,
        'b34b360dbb493e781e479794586d661700670d65564001f23024971d1f2fa126',
      ),
    ],
  ),
  SherpaModel(
    id: 'base',
    name: 'Whisper Base',
    revision: 'bb53ee204431c90d314c1cc08d28d23e5b7927cc',
    files: [
      SherpaModelFile(
        'base-encoder.int8.onnx',
        29120534,
        '0b8fb1304b6109976038efff5ace81720e00386f3ff6b54ee8c75291ca0a1e11',
      ),
      SherpaModelFile(
        'base-decoder.int8.onnx',
        130672026,
        '9759d217388a01b3a4c7c15533201067b48ae819c4daafc8624e64b9409dc02d',
      ),
      SherpaModelFile(
        'base-tokens.txt',
        816730,
        'b34b360dbb493e781e479794586d661700670d65564001f23024971d1f2fa126',
      ),
    ],
  ),
  SherpaModel(
    id: 'tiny',
    name: 'Whisper Tiny',
    revision: '65176e2deb88badc814a94058666cadccc29b61c',
    files: [
      SherpaModelFile(
        'tiny-encoder.int8.onnx',
        12937772,
        'd24fb083ae3b1041fc24e97971d60e280c9342201fbb67b0ab428a8b4a51a434',
      ),
      SherpaModelFile(
        'tiny-decoder.int8.onnx',
        89855401,
        'd2fece8dd42771f1df975c6c0445770d0c292bf7547c2cae04a6c0cc57540925',
      ),
      SherpaModelFile(
        'tiny-tokens.txt',
        816730,
        'b34b360dbb493e781e479794586d661700670d65564001f23024971d1f2fa126',
      ),
    ],
  ),
  SherpaModel(
    id: 'large-v2',
    name: 'Whisper Large v2',
    revision: '1dce177ee978f227f39538443ae7c3bc611e9be4',
    files: [
      SherpaModelFile(
        'large-v2-encoder.int8.onnx',
        765934692,
        'f055f8397a69895818c1763fd001e47fb9ca51ea7efaccfafc1b635d121203a3',
      ),
      SherpaModelFile(
        'large-v2-decoder.int8.onnx',
        1008260083,
        'ea513c5bfcbdc422b025da8fc93065ab8706994ba90053af442145b9aa7c2ee8',
      ),
      SherpaModelFile(
        'large-v2-tokens.txt',
        816730,
        'b34b360dbb493e781e479794586d661700670d65564001f23024971d1f2fa126',
      ),
    ],
  ),
  SherpaModel(
    id: 'large-v1',
    name: 'Whisper Large v1',
    revision: '5ec7cc1eddcc63ec78aaae738f7023e8c6e048a1',
    files: [
      SherpaModelFile(
        'large-v1-encoder.int8.onnx',
        765934692,
        '1643928022a8fe0a40afff5935703751a6486aee65b99717daa14728fec273f6',
      ),
      SherpaModelFile(
        'large-v1-decoder.int8.onnx',
        1008260083,
        '1b43c7ae36ef8c4eed9d2e07eca6c96e51edb83ceda275146c5282e93a8c68b1',
      ),
      SherpaModelFile(
        'large-v1-tokens.txt',
        816730,
        'b34b360dbb493e781e479794586d661700670d65564001f23024971d1f2fa126',
      ),
    ],
  ),
  SherpaModel(
    id: 'parakeet-v3',
    name: 'Parakeet TDT 0.6B v3',
    revision: '2bda32ec70b097a55adaa07d9a7173915b43cc78',
    repository: 'csukuangfj/sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8',
    publisher: 'NVIDIA',
    architecture: SherpaModelArchitecture.nemoTransducer,
    family: 'Parakeet',
    languageCodes: [
      'bg',
      'hr',
      'cs',
      'da',
      'nl',
      'en',
      'et',
      'fi',
      'fr',
      'de',
      'el',
      'hu',
      'it',
      'lv',
      'lt',
      'mt',
      'pl',
      'pt',
      'ro',
      'sk',
      'sl',
      'es',
      'sv',
      'ru',
      'uk',
    ],
    fileRoles: {
      'encoder': 'encoder.int8.onnx',
      'decoder': 'decoder.int8.onnx',
      'joiner': 'joiner.int8.onnx',
    },
    files: [
      SherpaModelFile(
        'encoder.int8.onnx',
        652184281,
        'acfc2b4456377e15d04f0243af540b7fe7c992f8d898d751cf134c3a55fd2247',
      ),
      SherpaModelFile(
        'decoder.int8.onnx',
        11845275,
        '179e50c43d1a9de79c8a24149a2f9bac6eb5981823f2a2ed88d655b24248db4e',
      ),
      SherpaModelFile(
        'joiner.int8.onnx',
        6355277,
        '3164c13fc2821009440d20fcb5fdc78bff28b4db2f8d0f0b329101719c0948b3',
      ),
      SherpaModelFile(
        'tokens.txt',
        93939,
        'd58544679ea4bc6ac563d1f545eb7d474bd6cfa467f0a6e2c1dc1c7d37e3c35d',
      ),
    ],
  ),
  SherpaModel(
    id: 'sensevoice',
    name: 'SenseVoice Small',
    revision: '2365baeacb507f821a0c8120fcee3d484dba7a07',
    repository: 'csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17',
    publisher: 'FunAudioLLM',
    architecture: SherpaModelArchitecture.senseVoice,
    family: 'SenseVoice',
    languageCodes: ['zh', 'en', 'ja', 'ko', 'yue'],
    fileRoles: {
      'model': 'model.int8.onnx',
    },
    files: [
      SherpaModelFile(
        'model.int8.onnx',
        239233841,
        'c71f0ce00bec95b07744e116345e33d8cbbe08cef896382cf907bf4b51a2cd51',
      ),
      SherpaModelFile(
        'tokens.txt',
        315894,
        'f449eb28dc567533d7fa59be34e2abca8784f771850c78a47fb731a31429a1dc',
      ),
    ],
  ),
  SherpaModel(
    id: 'dolphin-base',
    name: 'Dolphin Base',
    revision: '1f3a53d0ecf658f8b0974e2cfde368eee40732fa',
    repository:
        'csukuangfj/sherpa-onnx-dolphin-base-ctc-multi-lang-int8-2025-04-02',
    publisher: 'Dataocean AI',
    architecture: SherpaModelArchitecture.dolphin,
    family: 'Dolphin',
    fileRoles: {
      'model': 'model.int8.onnx',
    },
    files: [
      SherpaModelFile(
        'model.int8.onnx',
        103729802,
        'a3aa46c97f3f60f135ff949793cb05fabe7a0b3c484dc2e3cc699d354ee11b76',
      ),
      SherpaModelFile(
        'tokens.txt',
        504662,
        'c3788261a51df1899ea4b210b552cd42139204de72c0ad60f6cebb199078872e',
      ),
    ],
  ),
  SherpaModel(
    id: 'dolphin-small',
    name: 'Dolphin Small',
    revision: 'c8b6689509acfcd744c04e5e169164f9ac4cae32',
    repository:
        'csukuangfj/sherpa-onnx-dolphin-small-ctc-multi-lang-int8-2025-04-02',
    publisher: 'Dataocean AI',
    architecture: SherpaModelArchitecture.dolphin,
    family: 'Dolphin',
    fileRoles: {
      'model': 'model.int8.onnx',
    },
    files: [
      SherpaModelFile(
        'model.int8.onnx',
        249658954,
        'c1afcb9265de0ebd853eb8f570b371f399a6f9b2b9af9a3cb17c2e509171e697',
      ),
      SherpaModelFile(
        'tokens.txt',
        504662,
        'c3788261a51df1899ea4b210b552cd42139204de72c0ad60f6cebb199078872e',
      ),
    ],
  ),
  SherpaModel(
    id: 'omnilingual-300m',
    name: 'Omnilingual 300M',
    revision: '6fc542a3b0661c8278cca1230c34deb989f31202',
    repository:
        'csukuangfj2/sherpa-onnx-omnilingual-asr-1600-languages-300M-ctc-int8-2025-11-12',
    publisher: 'Meta',
    architecture: SherpaModelArchitecture.omnilingual,
    family: 'Omnilingual',
    fileRoles: {
      'model': 'model.int8.onnx',
    },
    files: [
      SherpaModelFile(
        'model.int8.onnx',
        365352120,
        'e7c4e54ee4c4c47829cc6667d5d00ed8ea7bef1dcfeef0fce766f77752a2726c',
      ),
      SherpaModelFile(
        'tokens.txt',
        86423,
        'a7a044c52cb29cbe8b0dc1953e92cefd4ca16b0ed968177b6beab21f9a7d0b31',
      ),
    ],
  ),
  SherpaModel(
    id: 'omnilingual-1b',
    name: 'Omnilingual 1B',
    revision: 'c765c919b1e7dfb03f55f7318eb0649f47015cb4',
    repository:
        'csukuangfj2/sherpa-onnx-omnilingual-asr-1600-languages-1B-ctc-int8-2025-11-12',
    publisher: 'Meta',
    architecture: SherpaModelArchitecture.omnilingual,
    family: 'Omnilingual',
    fileRoles: {
      'model': 'model.int8.onnx',
    },
    files: [
      SherpaModelFile(
        'model.int8.onnx',
        1031628252,
        'f7b74c964039162423b83e3fa950ce24810c9a635d9ff8468b5f4d142b7c1e8c',
      ),
      SherpaModelFile(
        'tokens.txt',
        86423,
        'a7a044c52cb29cbe8b0dc1953e92cefd4ca16b0ed968177b6beab21f9a7d0b31',
      ),
    ],
  ),
  SherpaModel(
    id: 'omnilingual-1b-v2',
    name: 'Omnilingual 1B v2',
    revision: '5243e02858d1428b8fbeeb5f7f1cc6fccf4d9433',
    repository:
        'csukuangfj2/sherpa-onnx-omnilingual-asr-1600-languages-1B-ctc-v2-int8-2026-02-05',
    publisher: 'Meta',
    architecture: SherpaModelArchitecture.omnilingual,
    family: 'Omnilingual',
    fileRoles: {
      'model': 'model.int8.onnx',
    },
    files: [
      SherpaModelFile(
        'model.int8.onnx',
        1032239439,
        '8af72da192fc2c8567c328d4f8059bdf47f182a0369077893c295ef39740c637',
      ),
      SherpaModelFile(
        'tokens.txt',
        90630,
        '7d99997ef207ff14c2cfe825f2aa037528ea250113cc3c6392bfe49326884ba6',
      ),
    ],
  ),
  SherpaModel(
    id: 'firered-asr2',
    name: 'FireRed ASR2',
    revision: '374cff185e952c40fcf2f6da972a3b6cf340608d',
    repository: 'csukuangfj2/sherpa-onnx-fire-red-asr2-zh_en-int8-2026-02-26',
    publisher: 'FireRedTeam',
    architecture: SherpaModelArchitecture.fireRedAsr,
    family: 'FireRed',
    languageCodes: ['zh', 'en'],
    fileRoles: {
      'encoder': 'encoder.int8.onnx',
      'decoder': 'decoder.int8.onnx',
    },
    files: [
      SherpaModelFile(
        'encoder.int8.onnx',
        817286833,
        '54048d66b6e8f3c80ea7ce95efe794587b0fd81d7271651d0decd3803852ae82',
      ),
      SherpaModelFile(
        'decoder.int8.onnx',
        417291928,
        'b840ce7196ae4a14d05ae84bbf56082b6b61ccec5610fda907dddbcea37354ff',
      ),
      SherpaModelFile(
        'tokens.txt',
        79172,
        '1bc613de2112d257e61a349c3e72d1b1a9cf19c33d3ca954197ad2171e5ea07b',
      ),
    ],
  ),
  SherpaModel(
    id: 'firered-asr2-ctc',
    name: 'FireRed ASR2 CTC',
    revision: '423be1acfdc5d8aaa5a485fb6263fe4ea8570b06',
    repository:
        'csukuangfj2/sherpa-onnx-fire-red-asr2-ctc-zh_en-int8-2026-02-25',
    publisher: 'FireRedTeam',
    architecture: SherpaModelArchitecture.fireRedAsrCtc,
    family: 'FireRed',
    languageCodes: ['zh', 'en'],
    fileRoles: {
      'model': 'model.int8.onnx',
    },
    files: [
      SherpaModelFile(
        'model.int8.onnx',
        775861420,
        'ca3dbabd82170110cc0b343c2890866d449984bc9cd92b9a18371ff80a81bb99',
      ),
      SherpaModelFile(
        'tokens.txt',
        79172,
        '1bc613de2112d257e61a349c3e72d1b1a9cf19c33d3ca954197ad2171e5ea07b',
      ),
    ],
  ),
  SherpaModel(
    id: 'paraformer-bilingual',
    name: 'Paraformer Chinese / English',
    revision: '4b891f7b5c73d874e607797a4b0578fd4c35dd4b',
    repository: 'csukuangfj/sherpa-onnx-paraformer-bilingual-zh-en',
    publisher: 'Alibaba',
    architecture: SherpaModelArchitecture.paraformer,
    family: 'Paraformer',
    languageCodes: ['zh', 'en'],
    fileRoles: {
      'model': 'model.int8.onnx',
    },
    files: [
      SherpaModelFile(
        'model.int8.onnx',
        223385835,
        '9ada9127ca5b82320385ac12340eb8b05dee64fd45cf8cf593ec693826ec2fd7',
      ),
      SherpaModelFile(
        'tokens.txt',
        75756,
        '59aba8873a2ed1e122c25fee421e25f283b63290efbde85c1f01a853d83cb6e6',
      ),
    ],
  ),
  SherpaModel(
    id: 'paraformer-trilingual',
    name: 'Paraformer Chinese / Cantonese / English',
    revision: '8d90151338178bb433354c9fb677bd3acb8023cd',
    repository: 'csukuangfj/sherpa-onnx-paraformer-trilingual-zh-cantonese-en',
    publisher: 'Alibaba',
    architecture: SherpaModelArchitecture.paraformer,
    family: 'Paraformer',
    languageCodes: ['zh', 'yue', 'en'],
    fileRoles: {
      'model': 'model.int8.onnx',
    },
    files: [
      SherpaModelFile(
        'model.int8.onnx',
        244684152,
        'eb3cdd288f535cf73258f491cdd7d68ad5a00aee135c0bba4c0884ea8d926144',
      ),
      SherpaModelFile(
        'tokens.txt',
        118931,
        '8e4593d7a2eb2404ff82976b5494265e9a06283ca4d5e8605bf7b4fed557a492',
      ),
    ],
  ),
  SherpaModel(
    id: 'wenet-yue',
    name: 'WeNet Cantonese / Chinese / English',
    revision: 'c911764e8227cf372ee60adc75f7f407e5b8c905',
    repository:
        'csukuangfj/sherpa-onnx-wenetspeech-yue-u2pp-conformer-ctc-zh-en-cantonese-int8-2025-09-10',
    publisher: 'WeNet',
    architecture: SherpaModelArchitecture.wenetCtc,
    family: 'WeNet',
    languageCodes: ['yue', 'zh', 'en'],
    fileRoles: {
      'model': 'model.int8.onnx',
    },
    files: [
      SherpaModelFile(
        'model.int8.onnx',
        134698500,
        '201bfd9e12ec4ac9ee3b23c5e071d9fa2381a8b21df317e2e08a170d6f1f55d3',
      ),
      SherpaModelFile(
        'tokens.txt',
        85361,
        'c7750677a1183606d2fd6f16d792e06e70d9843dba8a0c6e23a9dec78e06977a',
      ),
    ],
  ),
  SherpaModel(
    id: 'qwen3-asr',
    name: 'Qwen3 ASR 0.6B',
    revision: '68818b2313fe77bd06f6a7c5068ff3ef59d02b8a',
    repository: 'csukuangfj2/sherpa-onnx-qwen3-asr-0.6B-int8-2026-03-25',
    publisher: 'Alibaba',
    architecture: SherpaModelArchitecture.qwen3Asr,
    family: 'Qwen3 ASR',
    fileRoles: {
      'convFrontend': 'conv_frontend.onnx',
      'encoder': 'encoder.int8.onnx',
      'decoder': 'decoder.int8.onnx',
      'tokenizer': 'tokenizer',
    },
    files: [
      SherpaModelFile(
        'conv_frontend.onnx',
        44148281,
        'd22dc4423e0940e49884e903d2ea2f7e5567c14fc1aed97e4e26d6b8f208ef9e',
      ),
      SherpaModelFile(
        'encoder.int8.onnx',
        182491662,
        '60748d3e6744a57c9c91e1b17424a6c2990567e8adceb0783940c03ed98fa9d9',
      ),
      SherpaModelFile(
        'decoder.int8.onnx',
        755914231,
        '4f6885be5959ae26af3089d38ee7972c5fafbeeb1cf8d5e76eab6d8b61ca5771',
      ),
      SherpaModelFile(
        'tokenizer/vocab.json',
        2776833,
        'ca10d7e9fb3ed18575dd1e277a2579c16d108e32f27439684afa0e10b1440910',
      ),
      SherpaModelFile(
        'tokenizer/merges.txt',
        1671853,
        '8831e4f1a044471340f7c0a83d7bd71306a5b867e95fd870f74d0c5308a904d5',
      ),
      SherpaModelFile(
        'tokenizer/tokenizer_config.json',
        12487,
        '4942d005604266809309cabc9f4e9cb89ce855d59b14681fdc0e1cc62ea26c4c',
      ),
    ],
  ),
  SherpaModel(
    id: 'funasr-nano',
    name: 'FunASR Nano',
    revision: '6f16bd378457e13f36ccf3910df9017f96c346fb',
    repository: 'csukuangfj/sherpa-onnx-funasr-nano-int8-2025-12-30',
    publisher: 'FunAudioLLM',
    architecture: SherpaModelArchitecture.funasrNano,
    family: 'FunASR Nano',
    languageCodes: ['zh', 'en', 'ja'],
    fileRoles: {
      'encoderAdaptor': 'encoder_adaptor.int8.onnx',
      'llm': 'llm.int8.onnx',
      'embedding': 'embedding.int8.onnx',
      'tokenizer': 'Qwen3-0.6B',
    },
    files: [
      SherpaModelFile(
        'encoder_adaptor.int8.onnx',
        237792748,
        'f36dea2e30fbc33b5db1d7a7265cc976c5e5586c77b042d5adb1ad27c72db422',
      ),
      SherpaModelFile(
        'llm.int8.onnx',
        600356593,
        'dfbf9aa3be41bccc257587f151e15c63fbe1b549f2b517f5ccd5bdce3bf4322a',
      ),
      SherpaModelFile(
        'embedding.int8.onnx',
        155584380,
        '95e61cd0c9c3b9543339a4cf973c95c116815e745ccc1e0285cbd81f76d18644',
      ),
      SherpaModelFile(
        'Qwen3-0.6B/vocab.json',
        2776833,
        'ca10d7e9fb3ed18575dd1e277a2579c16d108e32f27439684afa0e10b1440910',
      ),
      SherpaModelFile(
        'Qwen3-0.6B/merges.txt',
        1671853,
        '8831e4f1a044471340f7c0a83d7bd71306a5b867e95fd870f74d0c5308a904d5',
      ),
      SherpaModelFile(
        'Qwen3-0.6B/tokenizer.json',
        11422654,
        'aeb13307a71acd8fe81861d94ad54ab689df773318809eed3cbe794b4492dae4',
      ),
    ],
  ),
];
