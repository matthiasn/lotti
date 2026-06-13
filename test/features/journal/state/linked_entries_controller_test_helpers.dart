//ignore_for_file: avoid_positional_boolean_parameters

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';

/// Riverpod notifier override pinning the include-hidden toggle to a fixed
/// value (a fake, not a mocktail Mock — it overrides the real notifier).
class FakeIncludeHiddenController extends IncludeHiddenController {
  FakeIncludeHiddenController(this._value);
  final bool _value;

  @override
  bool build({required String id}) => _value;
}

/// Synchronous links override for the unresolved-fallback test, so the
/// provider can run without registering a journal repository or stubbing
/// async loads.
class StaticLinksController extends LinkedEntriesController {
  StaticLinksController(this._links);
  final List<EntryLink> _links;

  @override
  Future<List<EntryLink>> build({required String id}) {
    state = AsyncData(_links);
    return SynchronousFuture(_links);
  }
}
