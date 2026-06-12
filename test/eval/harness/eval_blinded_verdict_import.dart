// Imports model-identity-blinded judge verdicts back into raw eval runs.
//
// The blinded judge packet is reviewer-facing; the raw run remains the audit
// record consumed by TraceWriter, EvalRunVerifier, and EvalReporter. This module
// validates the public judge packet and private key before normalizing each
// blinded verdict into the raw sibling `.verdict.json` file.

import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;

import 'eval_models.dart';
import 'eval_provenance.dart';
import 'trace_writer.dart';

class EvalBlindedVerdictImportResult {
  const EvalBlindedVerdictImportResult({
    required this.importedVerdictFiles,
    required this.privateKeyFile,
    required this.judgeManifestFile,
  });

  final List<File> importedVerdictFiles;
  final File privateKeyFile;
  final File judgeManifestFile;

  int get importedCount => importedVerdictFiles.length;
}

abstract final class EvalBlindedVerdictImporter {
  static const schemaVersion = 1;
  static const verdictKind = 'lotti.blindedTraceExport.verdict';

  static Future<EvalBlindedVerdictImportResult> importRun({
    required EvalRunArtifacts run,
    required TraceWriter writer,
    required Directory exportDir,
    bool overwrite = false,
  }) async {
    final privateKeyFile = File('${exportDir.path}/private/key.json');
    final judgeManifestFile = File('${exportDir.path}/judge/manifest.json');
    final judgeDir = Directory('${exportDir.path}/judge');
    final privateKey = await _readJsonObject(privateKeyFile);
    final judgeManifest = await _readJsonObject(judgeManifestFile);
    final privateKeyDigest = EvalProvenance.digestJson(privateKey);
    final judgeManifestDigest = EvalProvenance.digestJson(judgeManifest);
    _validateExportRoots(
      run: run,
      privateKey: privateKey,
      judgeManifest: judgeManifest,
      judgeManifestDigest: judgeManifestDigest,
      judgeManifestFile: judgeManifestFile,
    );

    final manifestEntries = _judgeManifestEntriesById(judgeManifest);
    final bindings = _privateKeyBindings(privateKey);
    _rejectDuplicateBindings(bindings);
    _validateTraceCount(
      label: 'private key',
      expected: _requiredInt(privateKey, 'traceCount'),
      actual: bindings.length,
    );
    _validateTraceCount(
      label: 'judge manifest',
      expected: _requiredInt(judgeManifest, 'traceCount'),
      actual: manifestEntries.length,
    );

    final writes = <_VerdictWrite>[];
    final expectedVerdictPaths = <String>{};
    for (final binding in bindings) {
      final manifestEntry = manifestEntries[binding.blindedTraceId];
      if (manifestEntry == null) {
        throw StateError(
          'Private key references blinded trace ${binding.blindedTraceId} '
          'missing from judge manifest.',
        );
      }
      await _validateBinding(
        binding: binding,
        manifestEntry: manifestEntry,
        judgeDir: judgeDir,
        run: run,
        writer: writer,
      );

      final blindedVerdictFile = File(
        p.join(judgeDir.path, _blindedVerdictPath(binding.judgeFile)),
      );
      expectedVerdictPaths.add(p.normalize(blindedVerdictFile.path));
      if (!blindedVerdictFile.existsSync()) {
        throw StateError(
          'Missing blinded verdict for ${binding.blindedTraceId}: '
          '${blindedVerdictFile.path}',
        );
      }
      final verdict =
          (await _readBlindedVerdict(
            file: blindedVerdictFile,
            binding: binding,
            expectedPromptDigest: run.manifest.promptDigest,
          )).withBlindedImport(
            BlindedVerdictImportRecord(
              blindedTraceId: binding.blindedTraceId,
              reviewPayloadDigest: binding.reviewPayloadDigest,
              judgeManifestDigest: judgeManifestDigest,
              privateKeyDigest: privateKeyDigest,
              sourceManifestDigest: _requiredString(
                privateKey,
                'sourceManifestDigest',
              ),
              rawTraceDigest: binding.rawTraceDigest,
            ),
          );
      final rawTraceFile = File(
        p.join(writer.runDir(run.manifest.runId), binding.rawTraceFile),
      );
      final rawVerdictFile = writer.verdictFileForTrace(rawTraceFile);
      _validateRawVerdictFile(
        binding: binding,
        rawVerdictFile: rawVerdictFile,
      );
      if (rawVerdictFile.existsSync() && !overwrite) {
        throw StateError(
          'Refusing to overwrite existing raw verdict for '
          '${binding.blindedTraceId}: ${rawVerdictFile.path}',
        );
      }
      writes.add(
        _VerdictWrite(
          rawTraceFile: rawTraceFile,
          verdict: verdict,
        ),
      );
    }

    await _rejectUnexpectedVerdicts(
      judgeDir: judgeDir,
      expectedPaths: expectedVerdictPaths,
    );

    final imported = <File>[];
    for (final write in writes) {
      imported.add(
        await writer.writeVerdict(write.rawTraceFile, write.verdict),
      );
    }
    return EvalBlindedVerdictImportResult(
      importedVerdictFiles: List.unmodifiable(imported),
      privateKeyFile: privateKeyFile,
      judgeManifestFile: judgeManifestFile,
    );
  }

  static void _validateExportRoots({
    required EvalRunArtifacts run,
    required Map<String, dynamic> privateKey,
    required Map<String, dynamic> judgeManifest,
    required String judgeManifestDigest,
    required File judgeManifestFile,
  }) {
    _requireKind(
      privateKey,
      'lotti.blindedTraceExport.privateKey',
      'private key',
    );
    _requireKind(
      judgeManifest,
      'lotti.blindedTraceExport.judge',
      'judge manifest',
    );
    final runId = _requiredString(privateKey, 'sourceRunId');
    if (runId != run.manifest.runId) {
      throw StateError(
        'Blinded private key sourceRunId "$runId" does not match run '
        '"${run.manifest.runId}".',
      );
    }
    final sourceRunDigest = _requiredString(privateKey, 'sourceRunDigest');
    final expectedRunDigest = EvalProvenance.digestText(run.manifest.runId);
    if (sourceRunDigest != expectedRunDigest) {
      throw StateError(
        'Blinded private key sourceRunDigest "$sourceRunDigest" does not '
        'match "$expectedRunDigest".',
      );
    }
    final sourceManifestDigest = _requiredString(
      privateKey,
      'sourceManifestDigest',
    );
    if (sourceManifestDigest != run.manifest.manifestDigest) {
      throw StateError(
        'Blinded private key sourceManifestDigest "$sourceManifestDigest" '
        'does not match run manifest "${run.manifest.manifestDigest}".',
      );
    }
    final expectedJudgeManifestDigest = _requiredString(
      privateKey,
      'judgeManifestDigest',
    );
    if (expectedJudgeManifestDigest != judgeManifestDigest) {
      throw StateError(
        'Blinded private key judgeManifestDigest '
        '"$expectedJudgeManifestDigest" '
        'does not match ${judgeManifestFile.path} '
        '"$judgeManifestDigest".',
      );
    }
    if (judgeManifest['modelIdentityVisible'] != false) {
      throw StateError('Judge manifest is not model-identity blinded.');
    }
    if (judgeManifest['profileVisible'] != true) {
      throw StateError('Judge manifest is not profile-visible.');
    }
  }

  static Future<void> _validateBinding({
    required _BlindedTraceBinding binding,
    required Map<String, dynamic> manifestEntry,
    required Directory judgeDir,
    required EvalRunArtifacts run,
    required TraceWriter writer,
  }) async {
    if (_requiredString(manifestEntry, 'file') != binding.judgeFile) {
      throw StateError(
        'Judge manifest file for ${binding.blindedTraceId} does not match '
        'private key.',
      );
    }
    if (_requiredString(manifestEntry, 'reviewPayloadDigest') !=
        binding.reviewPayloadDigest) {
      throw StateError(
        'Judge manifest reviewPayloadDigest for ${binding.blindedTraceId} '
        'does not match private key.',
      );
    }
    if (binding.runId != run.manifest.runId) {
      throw StateError(
        'Private key entry ${binding.blindedTraceId} has runId '
        '"${binding.runId}", expected "${run.manifest.runId}".',
      );
    }
    final rawTraceFile = File(
      p.join(writer.runDir(run.manifest.runId), binding.rawTraceFile),
    );
    if (!rawTraceFile.existsSync()) {
      throw StateError(
        'Private key entry ${binding.blindedTraceId} references missing raw '
        'trace: ${rawTraceFile.path}',
      );
    }
    final rawTraceDigest = await writer.traceDigest(rawTraceFile);
    if (rawTraceDigest != binding.rawTraceDigest) {
      throw StateError(
        'Private key rawTraceDigest for ${binding.blindedTraceId} is '
        '${binding.rawTraceDigest}, expected $rawTraceDigest.',
      );
    }
    _validateBindingTraceMetadata(
      binding: binding,
      trace: _traceForRawFile(
        binding: binding,
        run: run,
        writer: writer,
      ),
    );
    await _validateBlindedTraceFile(binding, judgeDir);
  }

  static EvalTrace _traceForRawFile({
    required _BlindedTraceBinding binding,
    required EvalRunArtifacts run,
    required TraceWriter writer,
  }) {
    for (final trace in run.traces) {
      final file = writer.traceFileFor(
        runId: trace.runId,
        scenarioId: trace.scenario.id,
        profileName: trace.profile.name,
        agentDirectiveVariantName: trace.agentDirectiveVariant.name,
        trialIndex: trace.trialIndex,
        cascadeWake: trace.cascadeWake,
      );
      if (file.uri.pathSegments.last == binding.rawTraceFile) {
        return trace;
      }
    }
    throw StateError(
      'Private key entry ${binding.blindedTraceId} references raw trace '
      '${binding.rawTraceFile}, but it is not present in the run.',
    );
  }

  static void _validateBindingTraceMetadata({
    required _BlindedTraceBinding binding,
    required EvalTrace trace,
  }) {
    final expected = <String, Object?>{
      'runId': trace.runId,
      'scenarioId': trace.scenario.id,
      'scenarioDigest': trace.provenance.scenarioDigest,
      'profileName': trace.profile.name,
      'profileDigest': trace.provenance.profileDigest,
      'modelClass': trace.profile.modelClass.name,
      'agentDirectiveVariantName': trace.agentDirectiveVariant.name,
      'agentDirectiveVariantDigest':
          trace.provenance.agentDirectiveVariantDigest,
      'trialIndex': trace.trialIndex,
      if (trace.cascadeWake != null) 'cascadeWake': trace.cascadeWake!.toJson(),
    };
    const equality = DeepCollectionEquality();
    for (final entry in expected.entries) {
      final actual = binding.sourceJson[entry.key];
      final expectedValue = entry.value;
      final matches = equality.equals(actual, expectedValue);
      if (matches) continue;
      throw StateError(
        'Private key ${entry.key} for ${binding.blindedTraceId} is '
        '$actual, expected $expectedValue.',
      );
    }
    if (trace.cascadeWake == null &&
        binding.sourceJson.containsKey('cascadeWake')) {
      throw StateError(
        'Private key cascadeWake for ${binding.blindedTraceId} is present, '
        'but the raw trace is not a cascade wake.',
      );
    }
  }

  static Future<void> _validateBlindedTraceFile(
    _BlindedTraceBinding binding,
    Directory judgeDir,
  ) async {
    final blindedTraceFile = File(p.join(judgeDir.path, binding.judgeFile));
    if (!blindedTraceFile.existsSync()) {
      throw StateError(
        'Missing blinded trace for ${binding.blindedTraceId}: '
        '${blindedTraceFile.path}',
      );
    }
    final json = await _readJsonObject(blindedTraceFile);
    _requireKind(
      json,
      'lotti.blindedTraceExport.trace',
      blindedTraceFile.path,
    );
    if (_requiredString(json, 'blindedTraceId') != binding.blindedTraceId) {
      throw StateError(
        'Blinded trace id in ${blindedTraceFile.path} does not match '
        'private key ${binding.blindedTraceId}.',
      );
    }
    final reviewPayload =
        json['reviewPayload'] as Map<String, dynamic>? ??
        (throw StateError(
          'Blinded trace ${binding.blindedTraceId} is missing reviewPayload.',
        ));
    final actualReviewDigest = EvalProvenance.digestJson(reviewPayload);
    final declaredReviewDigest = _requiredString(json, 'reviewPayloadDigest');
    if (declaredReviewDigest != actualReviewDigest) {
      throw StateError(
        'Blinded trace ${binding.blindedTraceId} reviewPayloadDigest '
        '$declaredReviewDigest does not match $actualReviewDigest.',
      );
    }
    if (binding.reviewPayloadDigest != actualReviewDigest) {
      throw StateError(
        'Private key reviewPayloadDigest for ${binding.blindedTraceId} is '
        '${binding.reviewPayloadDigest}, expected $actualReviewDigest.',
      );
    }
    final contract = json['verdictContract'] as Map<String, dynamic>? ?? {};
    if (contract['reviewPayloadDigest'] != binding.reviewPayloadDigest ||
        contract['judge.profileVisible'] != true ||
        contract['judge.modelIdentityVisible'] != false) {
      throw StateError(
        'Blinded trace ${binding.blindedTraceId} verdictContract does not '
        'match the private key and blinded-review policy.',
      );
    }
  }

  static Future<JudgeVerdict> _readBlindedVerdict({
    required File file,
    required _BlindedTraceBinding binding,
    required String expectedPromptDigest,
  }) async {
    final json = await _readJsonObject(file);
    _requireKind(json, verdictKind, file.path);
    if (_requiredString(json, 'blindedTraceId') != binding.blindedTraceId) {
      throw StateError(
        'Blinded verdict ${file.path} is for ${json['blindedTraceId']}, '
        'expected ${binding.blindedTraceId}.',
      );
    }
    final reviewPayloadDigest = _requiredString(json, 'reviewPayloadDigest');
    if (reviewPayloadDigest != binding.reviewPayloadDigest) {
      throw StateError(
        'Blinded verdict ${file.path} reviewPayloadDigest '
        '"$reviewPayloadDigest" does not match private key '
        '"${binding.reviewPayloadDigest}".',
      );
    }
    final verdictJson =
        json['verdict'] as Map<String, dynamic>? ??
        (throw StateError('Blinded verdict ${file.path} is missing verdict.'));
    final verdict = JudgeVerdict.fromJson(verdictJson);
    if (verdict.traceDigest != null) {
      throw StateError(
        'Blinded verdict ${file.path} must not include a raw traceDigest; '
        'the importer binds the raw trace digest after validation.',
      );
    }
    if (!verdict.judge.profileVisible) {
      throw StateError(
        'Blinded verdict ${file.path} judge.profileVisible must be true.',
      );
    }
    if (verdict.judge.modelIdentityVisible) {
      throw StateError(
        'Blinded verdict ${file.path} judge.modelIdentityVisible must be '
        'false.',
      );
    }
    if (verdict.judge.promptDigest != expectedPromptDigest) {
      throw StateError(
        'Blinded verdict ${file.path} judge.promptDigest '
        '"${verdict.judge.promptDigest}" does not match run prompt digest '
        '"$expectedPromptDigest".',
      );
    }
    return verdict;
  }

  static Future<void> _rejectUnexpectedVerdicts({
    required Directory judgeDir,
    required Set<String> expectedPaths,
  }) async {
    final tracesDir = Directory('${judgeDir.path}/traces');
    if (!tracesDir.existsSync()) return;
    final unexpected = <String>[];
    await for (final entity in tracesDir.list()) {
      if (entity is! File || !entity.path.endsWith('.blinded-verdict.json')) {
        continue;
      }
      final normalized = p.normalize(entity.path);
      if (!expectedPaths.contains(normalized)) {
        unexpected.add(entity.uri.pathSegments.last);
      }
    }
    if (unexpected.isEmpty) return;
    unexpected.sort();
    throw StateError(
      'Unexpected blinded verdict file(s): ${unexpected.join(', ')}',
    );
  }

  static Map<String, Map<String, dynamic>> _judgeManifestEntriesById(
    Map<String, dynamic> judgeManifest,
  ) {
    final entries = _requiredObjectList(judgeManifest, 'traces');
    return _indexByBlindedTraceId(entries, 'judge manifest');
  }

  static List<_BlindedTraceBinding> _privateKeyBindings(
    Map<String, dynamic> privateKey,
  ) {
    final entries = _requiredObjectList(privateKey, 'entries');
    _indexByBlindedTraceId(entries, 'private key');
    return [
      for (final entry in entries) _BlindedTraceBinding.fromJson(entry),
    ];
  }

  static void _rejectDuplicateBindings(List<_BlindedTraceBinding> bindings) {
    final rawVerdictDuplicates = _duplicates(
      bindings.map((binding) => binding.rawVerdictFile),
    );
    if (rawVerdictDuplicates.isNotEmpty) {
      throw StateError(
        'Duplicate rawVerdictFile binding(s): '
        '${(rawVerdictDuplicates.toList()..sort()).join(', ')}',
      );
    }
    final judgeFileDuplicates = _duplicates(
      bindings.map((binding) => binding.judgeFile),
    );
    if (judgeFileDuplicates.isNotEmpty) {
      throw StateError(
        'Duplicate judgeFile binding(s): '
        '${(judgeFileDuplicates.toList()..sort()).join(', ')}',
      );
    }
  }

  static Set<String> _duplicates(Iterable<String> values) {
    final seen = <String>{};
    final duplicates = <String>{};
    for (final value in values) {
      if (!seen.add(value)) duplicates.add(value);
    }
    return duplicates;
  }

  static Map<String, Map<String, dynamic>> _indexByBlindedTraceId(
    List<Map<String, dynamic>> entries,
    String label,
  ) {
    final byId = <String, Map<String, dynamic>>{};
    final duplicates = <String>{};
    for (final entry in entries) {
      final id = _requiredString(entry, 'blindedTraceId');
      if (byId.containsKey(id)) duplicates.add(id);
      byId[id] = entry;
    }
    if (duplicates.isNotEmpty) {
      throw StateError(
        'Duplicate blindedTraceId(s) in $label: '
        '${(duplicates.toList()..sort()).join(', ')}',
      );
    }
    return byId;
  }

  static List<Map<String, dynamic>> _requiredObjectList(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];
    if (value is! List) {
      throw StateError('Expected $key to be a list.');
    }
    return [
      for (final item in value)
        if (item is Map<String, dynamic>)
          item
        else
          throw StateError('Expected $key entries to be objects.'),
    ];
  }

  static Future<Map<String, dynamic>> _readJsonObject(File file) async {
    if (!file.existsSync()) {
      throw StateError('Missing blinded import artifact: ${file.path}');
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Expected JSON object in ${file.path}.');
    }
    return decoded;
  }

  static void _requireKind(
    Map<String, dynamic> json,
    String expectedKind,
    String label,
  ) {
    if (json['schemaVersion'] != schemaVersion ||
        json['kind'] != expectedKind) {
      throw StateError(
        'Expected $label to be $expectedKind schemaVersion $schemaVersion.',
      );
    }
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) return value;
    throw StateError('Expected non-empty string field "$key".');
  }

  static int _requiredInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is int) return value;
    throw StateError('Expected integer field "$key".');
  }

  static void _validateTraceCount({
    required String label,
    required int expected,
    required int actual,
  }) {
    if (expected == actual) return;
    throw StateError('$label traceCount is $expected, expected $actual.');
  }

  static String _blindedVerdictPath(String judgeFile) {
    _validateRelativePath(judgeFile, 'judgeFile');
    if (!judgeFile.endsWith('.blinded-trace.json')) {
      throw StateError('judgeFile must end with .blinded-trace.json.');
    }
    return judgeFile.replaceFirst(
      RegExp(r'\.blinded-trace\.json$'),
      '.blinded-verdict.json',
    );
  }

  static void _validateRawVerdictFile({
    required _BlindedTraceBinding binding,
    required File rawVerdictFile,
  }) {
    if (rawVerdictFile.uri.pathSegments.last != binding.rawVerdictFile) {
      throw StateError(
        'Private key rawVerdictFile for ${binding.blindedTraceId} is '
        '${binding.rawVerdictFile}, expected '
        '${rawVerdictFile.uri.pathSegments.last}.',
      );
    }
  }

  static void _validateRelativePath(String value, String field) {
    if (p.isAbsolute(value)) {
      throw StateError('$field must be relative: $value');
    }
    final normalized = p.normalize(value);
    final segments = p.split(normalized);
    if (segments.any((segment) => segment == '..' || segment.isEmpty)) {
      throw StateError('$field must not escape the export directory: $value');
    }
  }

  static void _validateFilename(String value, String field) {
    if (value != p.basename(value) || value.contains(r'\')) {
      throw StateError('$field must be a filename, got: $value');
    }
  }
}

class _BlindedTraceBinding {
  _BlindedTraceBinding({
    required this.sourceJson,
    required this.blindedTraceId,
    required this.judgeFile,
    required this.rawTraceFile,
    required this.rawVerdictFile,
    required this.rawTraceDigest,
    required this.reviewPayloadDigest,
    required this.runId,
  });

  factory _BlindedTraceBinding.fromJson(Map<String, dynamic> json) {
    final judgeFile = EvalBlindedVerdictImporter._requiredString(
      json,
      'judgeFile',
    );
    EvalBlindedVerdictImporter._validateRelativePath(judgeFile, 'judgeFile');
    final rawTraceFile = EvalBlindedVerdictImporter._requiredString(
      json,
      'rawTraceFile',
    );
    EvalBlindedVerdictImporter._validateFilename(
      rawTraceFile,
      'rawTraceFile',
    );
    final rawVerdictFile = EvalBlindedVerdictImporter._requiredString(
      json,
      'rawVerdictFile',
    );
    EvalBlindedVerdictImporter._validateFilename(
      rawVerdictFile,
      'rawVerdictFile',
    );
    final rawTraceDigest = EvalBlindedVerdictImporter._requiredString(
      json,
      'rawTraceDigest',
    );
    if (!EvalProvenance.isDigest(rawTraceDigest)) {
      throw StateError('rawTraceDigest is not a sha256 digest.');
    }
    final reviewPayloadDigest = EvalBlindedVerdictImporter._requiredString(
      json,
      'reviewPayloadDigest',
    );
    if (!EvalProvenance.isDigest(reviewPayloadDigest)) {
      throw StateError('reviewPayloadDigest is not a sha256 digest.');
    }
    return _BlindedTraceBinding(
      sourceJson: json,
      blindedTraceId: EvalBlindedVerdictImporter._requiredString(
        json,
        'blindedTraceId',
      ),
      judgeFile: judgeFile,
      rawTraceFile: rawTraceFile,
      rawVerdictFile: rawVerdictFile,
      rawTraceDigest: rawTraceDigest,
      reviewPayloadDigest: reviewPayloadDigest,
      runId: EvalBlindedVerdictImporter._requiredString(json, 'runId'),
    );
  }

  final Map<String, dynamic> sourceJson;
  final String blindedTraceId;
  final String judgeFile;
  final String rawTraceFile;
  final String rawVerdictFile;
  final String rawTraceDigest;
  final String reviewPayloadDigest;
  final String runId;
}

class _VerdictWrite {
  const _VerdictWrite({
    required this.rawTraceFile,
    required this.verdict,
  });

  final File rawTraceFile;
  final JudgeVerdict verdict;
}
